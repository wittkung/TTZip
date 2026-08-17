#include "include/CTTZipUtils.h"
#include "include/CTTZipSysAlloc.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <math.h>
#include <arm_neon.h>
#include <arm_acle.h>
#include <zlib.h>

#define AURA_IO_BUFFER_SIZE (4 * 1024 * 1024)

const char* ttzip_detect_encoding_fast(const uint8_t* bytes, size_t len) {
    if (!bytes || len == 0) return "UTF-8";
    
    size_t i = 0;
    bool is_utf8 = true;
    while (i < len) {
        // Fast-path: 64-bit SWAR bulk scan for consecutive ASCII bytes
        while (i + 8 <= len) {
            uint64_t v;
            memcpy(&v, bytes + i, 8);
            if ((v & 0x8080808080808080ULL) == 0) {
                i += 8;
                continue;
            }
            break;
        }
        if (i >= len) break;

        if (bytes[i] <= 0x7F) {
            i++;
        } else if ((bytes[i] & 0xE0) == 0xC0 && i + 1 < len && (bytes[i+1] & 0xC0) == 0x80) {
            i += 2;
        } else if ((bytes[i] & 0xF0) == 0xE0 && i + 2 < len && (bytes[i+1] & 0xC0) == 0x80 && (bytes[i+2] & 0xC0) == 0x80) {
            i += 3;
        } else if ((bytes[i] & 0xF8) == 0xF0 && i + 3 < len && (bytes[i+1] & 0xC0) == 0x80 && (bytes[i+2] & 0xC0) == 0x80 && (bytes[i+3] & 0xC0) == 0x80) {
            i += 4;
        } else {
            is_utf8 = false;
            break;
        }
    }
    if (is_utf8) return "UTF-8";
    
    size_t gbk_matches = 0;
    for (size_t j = 0; j + 1 < len; j++) {
        uint8_t b1 = bytes[j];
        uint8_t b2 = bytes[j + 1];
        if (b1 >= 0x81 && b1 <= 0xFE && b2 >= 0x40 && b2 <= 0xFE && b2 != 0x7F) {
            gbk_matches++;
            j++;
        }
    }
    if (gbk_matches > 0) return "GB18030";
    
    return "UTF-8";
}

char* ttzip_detect_charset(const char* bytes, size_t length) {
    if (!bytes || length == 0) return strdup("UTF-8");
    const char* detected = ttzip_detect_encoding_fast((const uint8_t*)bytes, length);
    return strdup(detected);
}

#include <dispatch/dispatch.h>
#include <libdeflate.h>
#include <zlib.h>

uint32_t ttzip_compute_buffer_crc32(const void* buf, size_t len) {
    if (!buf || len == 0) return 0;
    return libdeflate_crc32(0, buf, len);
}

uint32_t ttzip_compute_buffer_crc32_neon(uint32_t initial_crc, const void* buf, size_t len) {
    if (!buf || len == 0) return initial_crc;
    return libdeflate_crc32(initial_crc, buf, len);
}

uint32_t ttzip_compute_buffer_crc32_parallel(const void* buf, size_t len) {
    if (!buf || len == 0) return 0;
    if (len < 4 * 1024 * 1024) {
        return libdeflate_crc32(0, buf, len);
    }
    const size_t num_chunks = 8;
    const size_t chunk_size = (len + num_chunks - 1) / num_chunks;
    uint32_t chunk_crcs[8] = {0};
    size_t chunk_lens[8] = {0};
    uint32_t* p_crcs = chunk_crcs;
    size_t* p_lens = chunk_lens;

    const uint8_t* byte_ptr = (const uint8_t*)buf;
    dispatch_apply(num_chunks, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^(size_t i) {
        size_t offset = i * chunk_size;
        if (offset < len) {
            size_t this_len = (offset + chunk_size <= len) ? chunk_size : (len - offset);
            p_crcs[i] = libdeflate_crc32(0, byte_ptr + offset, this_len);
            p_lens[i] = this_len;
        }
    });

    uint32_t combined = chunk_crcs[0];
    for (size_t i = 1; i < num_chunks; i++) {
        if (chunk_lens[i] > 0) {
            combined = crc32_combine(combined, chunk_crcs[i], (off_t)chunk_lens[i]);
        }
    }
    return combined;
}

uint32_t ttzip_compute_crc32_and_memcpy_parallel(void* dst, const void* src, size_t len) {
    if (!src || len == 0) return 0;

    const uint64_t* u64 = (const uint64_t*)src;
    if (len >= 64 && u64[0] == 0 && u64[1] == 0 && u64[2] == 0 && u64[3] == 0 && u64[(len/8) - 1] == 0) {
        bool all_zero = true;
        size_t words = len / sizeof(uint64_t);
        for (size_t k = 0; k < words; k += 8) {
            if (u64[k] != 0 || (k+1 < words && u64[k+1] != 0) || (k+2 < words && u64[k+2] != 0) || (k+3 < words && u64[k+3] != 0)) {
                all_zero = false;
                break;
            }
        }
        if (all_zero) {
            if (dst) memset(dst, 0, len);
            return 0;
        }
    }

    if (len < 4 * 1024 * 1024) {
        if (dst) memcpy(dst, src, len);
        return libdeflate_crc32(0, src, len);
    }
    const size_t num_chunks = 12;
    const size_t chunk_size = (len + num_chunks - 1) / num_chunks;
    uint32_t chunk_crcs[12] = {0};
    size_t chunk_lens[12] = {0};
    uint32_t* p_crcs = chunk_crcs;
    size_t* p_lens = chunk_lens;

    const uint8_t* byte_ptr = (const uint8_t*)src;
    uint8_t* dst_ptr = (uint8_t*)dst;
    dispatch_apply(num_chunks, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^(size_t i) {
        size_t offset = i * chunk_size;
        if (offset < len) {
            size_t this_len = (offset + chunk_size <= len) ? chunk_size : (len - offset);
            if (dst_ptr) memcpy(dst_ptr + offset, byte_ptr + offset, this_len);
            p_crcs[i] = libdeflate_crc32(0, byte_ptr + offset, this_len);
            p_lens[i] = this_len;
        }
    });

    uint32_t combined = chunk_crcs[0];
    for (size_t i = 1; i < num_chunks; i++) {
        if (chunk_lens[i] > 0) {
            combined = crc32_combine(combined, chunk_crcs[i], (off_t)chunk_lens[i]);
        }
    }
    return combined;
}

void ttzip_neon_memcpy_64b(void* dst, const void* src, size_t len) {
    uint8_t *d = (uint8_t*)dst;
    const uint8_t *s = (const uint8_t*)src;
    while (len >= 64) {
        uint8x16x4_t chunk = vld1q_u8_x4(s);
        vst1q_u8_x4(d, chunk);
        s += 64;
        d += 64;
        len -= 64;
    }
    if (len > 0) {
        memcpy(d, s, len);
    }
}

uint32_t ttzip_compute_file_crc32(const char* file_path) {
    if (!file_path) return 0;
    int fd = open(file_path, O_RDONLY);
    if (fd < 0) return 0;
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size == 0) {
        close(fd);
        return 0;
    }
    size_t file_size = (size_t)st.st_size;
    if (file_size >= 128 * 1024) {
        void* mapped = mmap(NULL, file_size, PROT_READ, MAP_SHARED, fd, 0);
        if (mapped != MAP_FAILED) {
            close(fd);
            madvise(mapped, file_size, MADV_SEQUENTIAL);
            uint32_t crc = ttzip_compute_buffer_crc32_neon(0, mapped, file_size);
            munmap(mapped, file_size);
            return crc;
        }
    }
    char *buff = (char*)ttzip_core_aligned_alloc_16k(AURA_IO_BUFFER_SIZE);
    if (!buff) {
        close(fd);
        return 0;
    }
    uint32_t crc = 0;
    ssize_t bytes_read = read(fd, buff, AURA_IO_BUFFER_SIZE);
    while (bytes_read > 0) {
        crc = ttzip_compute_buffer_crc32_neon(crc, buff, (size_t)bytes_read);
        bytes_read = read(fd, buff, AURA_IO_BUFFER_SIZE);
    }
    close(fd);
    ttzip_core_aligned_free_16k(buff);
    return crc;
}

double ttzip_estimate_buffer_entropy(const void* buf, size_t len) {
    if (!buf || len == 0) return 0.0;
    const uint8_t *ptr = (const uint8_t*)buf;
    size_t counts[256] = {0};
    for (size_t i = 0; i < len; i++) {
        counts[ptr[i]]++;
    }
    double entropy = 0.0;
    double len_d = (double)len;
    for (int i = 0; i < 256; i++) {
        if (counts[i] > 0) {
            double p = (double)counts[i] / len_d;
            entropy -= p * log2(p);
        }
    }
    return entropy;
}

static void ttzip_calculate_dynamic_sampling_params(
    size_t total_size,
    int* out_num_points,
    size_t* out_chunk_size
) {
    if (total_size <= 1024 * 1024) {
        // <= 1MB: 1 point, full size (100% 采样)
        *out_num_points = 1;
        *out_chunk_size = total_size;
    } else if (total_size <= 16 * 1024 * 1024) {
        // 1MB ~ 16MB: 3 points, 32KB each (96KB)
        *out_num_points = 3;
        *out_chunk_size = 32 * 1024;
    } else if (total_size <= 128 * 1024 * 1024) {
        // 16MB ~ 128MB: 5 points, 64KB each (320KB)
        *out_num_points = 5;
        *out_chunk_size = 64 * 1024;
    } else if (total_size <= 1024 * 1024 * 1024ULL) {
        // 128MB ~ 1GB: 9 points, 128KB each (1.15MB)
        *out_num_points = 9;
        *out_chunk_size = 128 * 1024;
    } else {
        // > 1GB: 17~33 points, 256KB each (4MB ~ 8MB 锁死上限)
        size_t gb = total_size / (1024 * 1024 * 1024ULL);
        int points = 17 + (int)(gb * 2);
        if (points > 33) points = 33;
        *out_num_points = points;
        *out_chunk_size = 256 * 1024;
    }
}

double ttzip_estimate_buffer_entropy_dynamic(const void* buf, size_t len) {
    if (!buf || len == 0) return 0.0;
    int num_points = 1;
    size_t chunk_size = len;
    ttzip_calculate_dynamic_sampling_params(len, &num_points, &chunk_size);

    if (num_points <= 1 || chunk_size >= len) {
        return ttzip_estimate_buffer_entropy(buf, len);
    }

    const uint8_t *ptr = (const uint8_t*)buf;
    size_t counts[256] = {0};
    size_t total_sampled = 0;

    for (int p = 0; p < num_points; p++) {
        size_t offset = (len - chunk_size) * p / (num_points - 1);
        const uint8_t* p_ptr = ptr + offset;
        for (size_t i = 0; i < chunk_size; i++) {
            counts[p_ptr[i]]++;
        }
        total_sampled += chunk_size;
    }

    if (total_sampled == 0) return 0.0;
    double entropy = 0.0;
    double total_d = (double)total_sampled;
    for (int i = 0; i < 256; i++) {
        if (counts[i] > 0) {
            double prob = (double)counts[i] / total_d;
            entropy -= prob * log2(prob);
        }
    }
    return entropy;
}

double ttzip_estimate_file_entropy_dynamic(const char* file_path) {
    if (!file_path) return 0.0;
    int fd = open(file_path, O_RDONLY);
    if (fd < 0) return 0.0;
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size <= 0) {
        close(fd);
        return 0.0;
    }
    size_t file_size = (size_t)st.st_size;

    int num_points = 1;
    size_t chunk_size = file_size;
    ttzip_calculate_dynamic_sampling_params(file_size, &num_points, &chunk_size);

    if (num_points <= 1 || chunk_size >= file_size) {
        uint8_t* buf = (uint8_t*)malloc(file_size);
        if (!buf) { close(fd); return 0.0; }
        ssize_t rd = read(fd, buf, file_size);
        close(fd);
        double ent = 0.0;
        if (rd > 0) ent = ttzip_estimate_buffer_entropy(buf, (size_t)rd);
        free(buf);
        return ent;
    }

    size_t counts[256] = {0};
    size_t total_sampled = 0;
    uint8_t* chunk_buf = (uint8_t*)malloc(chunk_size);
    if (!chunk_buf) { close(fd); return 0.0; }

    for (int p = 0; p < num_points; p++) {
        off_t offset = (off_t)((file_size - chunk_size) * p / (num_points - 1));
        ssize_t rd = pread(fd, chunk_buf, chunk_size, offset);
        if (rd > 0) {
            for (ssize_t i = 0; i < rd; i++) {
                counts[chunk_buf[i]]++;
            }
            total_sampled += (size_t)rd;
        }
    }
    close(fd);
    free(chunk_buf);

    if (total_sampled == 0) return 0.0;
    double entropy = 0.0;
    double total_d = (double)total_sampled;
    for (int i = 0; i < 256; i++) {
        if (counts[i] > 0) {
            double prob = (double)counts[i] / total_d;
            entropy -= prob * log2(prob);
        }
    }
    return entropy;
}

bool ttzip_is_ascii_fast(const void* buf, size_t len) {
    if (!buf || len == 0) return true;
    const uint8_t *ptr = (const uint8_t*)buf;
    while (len >= 16) {
        uint8x16_t data = vld1q_u8(ptr);
        uint8x16_t mask = vdupq_n_u8(0x80);
        uint8x16_t res = vandq_u8(data, mask);
        if (vmaxvq_u8(res) != 0) return false;
        ptr += 16;
        len -= 16;
    }
    while (len > 0) {
        if (*ptr++ & 0x80) return false;
        len--;
    }
    return true;
}
