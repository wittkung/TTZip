#include "include/CTTZipBridge.h"
#include "include/ttzip_lzma2_enc_native.h"
#include <spawn.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <dirent.h>
#include <pthread/qos.h>
#include <pthread/spawn.h>
#include <crt_externs.h>

#include <sys/sysctl.h>
#include <compression.h>
#include <libgen.h>
#include "include/ttzip_lzma2_dec_native.h"

static int get_system_cores(void) {
    int count = 0;
    size_t size = sizeof(count);
    if (sysctlbyname("hw.ncpu", &count, &size, NULL, 0) == 0 && count > 0) {
        return count;
    }
    return 16;
}

#include <lzma.h>

int ttzip_lzma2_compress_mt_c(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_compressed_len,
    int level
) {
    if (!src || !dst || !out_compressed_len || dst_capacity == 0) return -1;
    
    int cores = get_system_cores();
    if (cores <= 0) cores = 8;
    
    if (src_len <= 16 * 1024 * 1024 && level <= 1) {
        lzma_options_lzma opt;
        lzma_lzma_preset(&opt, 1);
        opt.dict_size = 64 * 1024;
        opt.mode = LZMA_MODE_FAST;
        opt.nice_len = 16;
        opt.mf = LZMA_MF_HC4;
        opt.depth = 2;
        lzma_filter filters[2] = {
            { .id = LZMA_FILTER_LZMA2, .options = &opt },
            { .id = LZMA_VLI_UNKNOWN, .options = NULL }
        };
        lzma_stream strm = LZMA_STREAM_INIT;
        lzma_ret ret = lzma_raw_encoder(&strm, filters);
        if (ret == LZMA_OK) {
            strm.next_in = src;
            strm.avail_in = src_len;
            strm.next_out = dst;
            strm.avail_out = dst_capacity;
            ret = lzma_code(&strm, LZMA_FINISH);
            if (ret == LZMA_STREAM_END || ret == LZMA_OK) {
                *out_compressed_len = strm.total_out;
                lzma_end(&strm);
                return 0;
            }
            lzma_end(&strm);
        }
    }
    
    uint32_t preset = (level <= 1) ? 1 : ((level >= 9) ? 9 : (uint32_t)level);
    lzma_options_lzma opt;
    if (lzma_lzma_preset(&opt, preset)) {
        size_t res = compression_encode_buffer((uint8_t*)dst, dst_capacity, src, src_len, NULL, COMPRESSION_LZMA);
        if (res == 0) return -2;
        *out_compressed_len = res;
        return 0;
    }
    if (level <= 1) {
        opt.dict_size = 64 * 1024;
        opt.mode = LZMA_MODE_FAST;
        opt.nice_len = 16;
        opt.mf = LZMA_MF_HC4;
        opt.depth = 2;
    }
    
    lzma_filter filters[2] = {
        { .id = LZMA_FILTER_LZMA2, .options = &opt },
        { .id = LZMA_VLI_UNKNOWN, .options = NULL }
    };
    
    lzma_mt mt_options = {
        .flags = 0,
        .threads = (uint32_t)cores,
        .block_size = (level <= 1) ? (4 * 1024 * 1024) : (2 * 1024 * 1024),
        .timeout = 0,
        .preset = preset,
        .filters = filters,
        .check = LZMA_CHECK_NONE
    };
    
    lzma_stream strm = LZMA_STREAM_INIT;
    lzma_ret ret = lzma_stream_encoder_mt(&strm, &mt_options);
    if (ret != LZMA_OK) {
        size_t res = compression_encode_buffer((uint8_t*)dst, dst_capacity, src, src_len, NULL, COMPRESSION_LZMA);
        if (res == 0) return -2;
        *out_compressed_len = res;
        return 0;
    }
    
    strm.next_in = src;
    strm.avail_in = src_len;
    strm.next_out = dst;
    strm.avail_out = dst_capacity;
    
    ret = lzma_code(&strm, LZMA_FINISH);
    if (ret != LZMA_STREAM_END && ret != LZMA_OK) {
        lzma_end(&strm);
        size_t res = compression_encode_buffer((uint8_t*)dst, dst_capacity, src, src_len, NULL, COMPRESSION_LZMA);
        if (res == 0) return -2;
        *out_compressed_len = res;
        return 0;
    }
    
    *out_compressed_len = strm.total_out;
    lzma_end(&strm);
    return 0;
}

int ttzip_lzma2_decompress_mt_c(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_decompressed_len
) {
    if (!src || !dst || !out_decompressed_len || dst_capacity == 0) return -1;
    size_t res = compression_decode_buffer((uint8_t*)dst, dst_capacity, src, src_len, NULL, COMPRESSION_LZMA);
    if (res == 0) {
        if (ttzip_lzma2_decode_block_native(src, src_len, dst, dst_capacity, out_decompressed_len) == 0) {
            return 0;
        }
        return -2;
    }
    *out_decompressed_len = res;
    return 0;
}

static char g_7zz_bin_path[1024] = "";
static pthread_mutex_t g_7zz_path_lock = PTHREAD_MUTEX_INITIALIZER;
static int g_dev_null_fd = -1;

static const char* const SEVENZIP_CANDIDATE_PATHS[] = {
    "/opt/homebrew/bin/7zz",
    "/usr/local/bin/7zz",
    "/usr/bin/7zz",
    "/opt/homebrew/bin/7z",
    "/usr/local/bin/7z",
    NULL
};

static int get_dev_null_fd(void) {
    if (g_dev_null_fd < 0) {
        g_dev_null_fd = open("/dev/null", O_WRONLY);
    }
    return g_dev_null_fd;
}

static char** get_process_environ(void) {
    return *_NSGetEnviron();
}

static char g_resolved_7zz_bin_path[1024] = "";
static bool g_has_resolved_7zz = false;

void ttzip_register_7zz_binary(const char* bin_path) {
    if (bin_path && bin_path[0] != '\0') {
        pthread_mutex_lock(&g_7zz_path_lock);
        snprintf(g_7zz_bin_path, sizeof(g_7zz_bin_path), "%s", bin_path);
        snprintf(g_resolved_7zz_bin_path, sizeof(g_resolved_7zz_bin_path), "%s", bin_path);
        g_has_resolved_7zz = true;
        pthread_mutex_unlock(&g_7zz_path_lock);
    }
}

const char* ttzip_get_7zz_binary_path(void) {
    if (g_has_resolved_7zz) {
        return g_resolved_7zz_bin_path;
    }
    pthread_mutex_lock(&g_7zz_path_lock);
    if (g_has_resolved_7zz) {
        pthread_mutex_unlock(&g_7zz_path_lock);
        return g_resolved_7zz_bin_path;
    }
    if (g_7zz_bin_path[0] != '\0' && access(g_7zz_bin_path, X_OK) == 0) {
        snprintf(g_resolved_7zz_bin_path, sizeof(g_resolved_7zz_bin_path), "%s", g_7zz_bin_path);
        g_has_resolved_7zz = true;
        pthread_mutex_unlock(&g_7zz_path_lock);
        return g_resolved_7zz_bin_path;
    }
    for (int i = 0; SEVENZIP_CANDIDATE_PATHS[i] != NULL; i++) {
        if (access(SEVENZIP_CANDIDATE_PATHS[i], X_OK) == 0) {
            snprintf(g_resolved_7zz_bin_path, sizeof(g_resolved_7zz_bin_path), "%s", SEVENZIP_CANDIDATE_PATHS[i]);
            g_has_resolved_7zz = true;
            pthread_mutex_unlock(&g_7zz_path_lock);
            return g_resolved_7zz_bin_path;
        }
    }
    snprintf(g_resolved_7zz_bin_path, sizeof(g_resolved_7zz_bin_path), "%s", g_7zz_bin_path[0] != '\0' ? g_7zz_bin_path : "/opt/homebrew/bin/7zz");
    g_has_resolved_7zz = true;
    pthread_mutex_unlock(&g_7zz_path_lock);
    return g_resolved_7zz_bin_path;
}

int ttzip_spawn_7zz_extract(
    const char* bin_path,
    const char* archive_path,
    const char* destination_dir,
    const char* password
) {
    char local_bin[1024];
    if (!bin_path || bin_path[0] == '\0') {
        snprintf(local_bin, sizeof(local_bin), "%s", ttzip_get_7zz_binary_path());
        bin_path = local_bin;
    }

    char out_arg[1024];
    snprintf(out_arg, sizeof(out_arg), "-o%s", destination_dir);
    ttzip_common_mkdir_p(destination_dir);
    
    char pass_arg[512];
    bool has_pass = (password && password[0] != '\0');
    if (has_pass) {
        pass_arg[0] = '-';
        pass_arg[1] = 'p';
        size_t plen = strlen(password);
        if (plen < sizeof(pass_arg) - 3) {
            memcpy(pass_arg + 2, password, plen + 1);
        } else {
            snprintf(pass_arg, sizeof(pass_arg), "-p%s", password);
        }
    }

    char* argv[16];
    int idx = 0;
    argv[idx++] = (char*)bin_path;
    argv[idx++] = "x";
    argv[idx++] = out_arg;
    argv[idx++] = "-y";
    if (has_pass) {
        argv[idx++] = pass_arg;
    }
    argv[idx++] = (char*)archive_path;
    argv[idx] = NULL;

    int ret = ttzip_core_posix_spawn_fast(bin_path, (const char* const*)argv, NULL);
    if (ret != 0) return ret;

    DIR* d = opendir(destination_dir);
    if (!d) return -101;
    struct dirent* entry;
    bool has_files = false;
    while ((entry = readdir(d)) != NULL) {
        if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0 && strcmp(entry->d_name, ".DS_Store") != 0) {
            has_files = true;
            break;
        }
    }
    closedir(d);

    if (!has_files) {
        ttzip_log_c(3, "🚨 [TTZip C 引擎错误] 7zz 解压进程成功退出(0)，但目标解压目录无有效文件产出: %s\n", destination_dir);
        return -102;
    }
    return 0;
}

int ttzip_spawn_7zz_compress_in_dir(
    const char* bin_path,
    const char* output_archive_path,
    const char* working_dir,
    const char* const* input_paths,
    size_t input_count,
    int level,
    const char* password
) {
    if (!output_archive_path || !input_paths || input_count == 0) return -1;
    if (!bin_path || bin_path[0] == '\0') {
        bin_path = ttzip_get_7zz_binary_path();
    }

    char local_dir[1024] = {0};
    char local_file[1024] = {0};
    const char* actual_working_dir = working_dir;

    if (input_count == 1 && (!working_dir || working_dir[0] == '\0') && input_paths[0]) {
        const char* last_slash = strrchr(input_paths[0], '/');
        if (last_slash && last_slash != input_paths[0]) {
            size_t dlen = (size_t)(last_slash - input_paths[0]);
            if (dlen < sizeof(local_dir)) {
                memcpy(local_dir, input_paths[0], dlen);
                local_dir[dlen] = '\0';
                actual_working_dir = local_dir;
            }
            size_t flen = strlen(last_slash + 1);
            if (flen < sizeof(local_file)) {
                memcpy(local_file, last_slash + 1, flen + 1);
            }
        }
    }

    char mx_arg[64];
    mx_arg[0] = '-'; mx_arg[1] = 'm'; mx_arg[2] = 'x'; mx_arg[3] = '=';
    mx_arg[4] = '0' + (level % 10);
    mx_arg[5] = '\0';

    char pass_arg[512];
    bool has_pass = (password && password[0] != '\0');
    if (has_pass) {
        pass_arg[0] = '-'; pass_arg[1] = 'p';
        size_t plen = strlen(password);
        if (plen < sizeof(pass_arg) - 3) {
            memcpy(pass_arg + 2, password, plen + 1);
        } else {
            snprintf(pass_arg, sizeof(pass_arg), "-p%s", password);
        }
    }

    size_t total_alloc_args = input_count + 32;
    char** argv = (char**)malloc(sizeof(char*) * total_alloc_args);
    if (!argv) return -1;

    int idx = 0;
    argv[idx++] = (char*)bin_path;
    argv[idx++] = "a";
    argv[idx++] = "-y";
    argv[idx++] = "-t7z";
    argv[idx++] = mx_arg;
    argv[idx++] = "-mmt=on";
    argv[idx++] = "-bsp0";
    if (level >= 8) {
        argv[idx++] = "-md=64m";
        argv[idx++] = "-ms=on";
        argv[idx++] = "-myx=9";
    }
    if (has_pass) {
        argv[idx++] = "-mhe=on";
        argv[idx++] = pass_arg;
    }
    argv[idx++] = (char*)output_archive_path;

    if (input_count == 1 && local_file[0] != '\0') {
        argv[idx++] = local_file;
    } else {
        for (size_t i = 0; i < input_count; i++) {
            if (input_paths[i]) {
                argv[idx++] = (char*)input_paths[i];
            }
        }
    }
    argv[idx] = NULL;

    int ret = ttzip_core_posix_spawn_fast(bin_path, (const char* const*)argv, actual_working_dir);
    free(argv);
    if (ret != 0) {
        ttzip_log_c(3, "🚨 [TTZip C] posix_spawn failed ret=%d, bin_path='%s'\n", ret, bin_path ? bin_path : "NULL");
        return ret;
    }

    struct stat st;
    if (stat(output_archive_path, &st) != 0 || st.st_size == 0) {
        ttzip_log_c(3, "🚨 [TTZip C 引擎错误] 7zz 打包进程成功退出(0)，但生成的压缩包不存在或大小为 0 字节: %s\n", output_archive_path);
        return -103;
    }
    return 0;
}

int ttzip_extract_7z_libarchive_c(
    const char* archive_path,
    const char* dest_dir,
    const char* password
) {
    if (!archive_path || !dest_dir) return TTZIP_ERR_INVALID_PARAM;
    ttzip_common_mkdir_p(dest_dir);
    
    struct archive* a = archive_read_new();
    if (!a) return TTZIP_ERR_OUT_OF_MEMORY;
    
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    
    if (password && password[0] != '\0') {
        archive_read_add_passphrase(a, password);
    }
    
    struct archive* ext = archive_write_disk_new();
    if (!ext) {
        archive_read_free(a);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }
    
    int flags = ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_SECURE_NODOTDOT | ARCHIVE_EXTRACT_UNLINK;
    archive_write_disk_set_options(ext, flags);
    
    if (archive_read_open_filename(a, archive_path, 10240) != ARCHIVE_OK) {
        archive_write_free(ext);
        archive_read_free(a);
        return TTZIP_ERR_OPEN_FAILED;
    }
    
    struct archive_entry* entry;
    int r;
    int extracted_count = 0;
    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char* entry_pathname = archive_entry_pathname(entry);
        if (ttzip_is_mac_junk(entry_pathname)) {
            archive_read_data_skip(a);
            continue;
        }
        
        char full_dest_path[4096];
        ttzip_common_join_path(full_dest_path, sizeof(full_dest_path), dest_dir, entry_pathname);
        
        char parent_dir[4096];
        strncpy(parent_dir, full_dest_path, sizeof(parent_dir) - 1);
        parent_dir[sizeof(parent_dir) - 1] = '\0';
        char* last_slash = strrchr(parent_dir, '/');
        if (last_slash && last_slash != parent_dir) {
            *last_slash = '\0';
            ttzip_common_mkdir_p(parent_dir);
        }
        
        archive_entry_set_pathname(entry, full_dest_path);
        
        int h_res = archive_write_header(ext, entry);
        if (h_res >= ARCHIVE_WARN) {
            const void* buff;
            size_t size;
            int64_t offset;
            int data_err = 0;
            int r_block = ARCHIVE_OK;
            while ((r_block = archive_read_data_block(a, &buff, &size, &offset)) == ARCHIVE_OK) {
                if (archive_write_data_block(ext, buff, size, offset) < ARCHIVE_WARN) {
                    data_err = 1;
                    break;
                }
            }
            if (r_block != ARCHIVE_EOF && r_block != ARCHIVE_OK) {
                data_err = 1;
            }
            archive_write_finish_entry(ext);
            if (!data_err) {
                extracted_count++;
            }
        } else {
            archive_read_data_skip(a);
        }
    }
    
    archive_write_close(ext);
    archive_write_free(ext);
    archive_read_close(a);
    archive_read_free(a);
    return (extracted_count > 0 && (r == ARCHIVE_EOF || r == ARCHIVE_OK)) ? TTZIP_OK : -1;
}

int ttzip_extract_7z_native_c(
    const char* archive_path,
    const char* destination_dir,
    const char* password
) {
    if (!archive_path || !destination_dir) return -1;
    int res = ttzip_7z_extract_native_parallel_c(archive_path, destination_dir, password);
    if (res == TTZIP_OK) {
        return TTZIP_OK;
    }
    return ttzip_extract_7z_libarchive_c(archive_path, destination_dir, password);
}

int ttzip_create_7z_native_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    const char* password
) {
    if (!output_path || !input_paths || input_count == 0) return TTZIP_ERR_INVALID_PARAM;

    return ttzip_create_7z_lzma2_native_c(output_path, input_paths, input_count, level, password);
}

int ttzip_spawn_7zz_compress(
    const char* bin_path,
    const char* output_archive_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    const char* password
) {
    return ttzip_spawn_7zz_compress_in_dir(bin_path, output_archive_path, NULL, input_paths, input_count, level, password);
}
