#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include "include/CTTZipCommon.h"
#include "include/CTTZipIO.h"
#include "include/CTTZipSysAlloc.h"

int ttzip_io_mkdir_p(const char *dir_path) {
    return ttzip_common_mkdir_p(dir_path);
}

int ttzip_io_collect_recursive(const char* base_path, const char* rel_path, ttzip_io_file_list_t* list) {
    if (!base_path || !list) return -1;
    
    struct stat st;
    if (lstat(base_path, &st) != 0) return -1;

    if (list->count >= list->capacity) {
        size_t new_cap = (list->capacity == 0) ? 64 : (list->capacity * 2);
        ttzip_io_entry_t* new_entries = (ttzip_io_entry_t*)realloc(list->entries, sizeof(ttzip_io_entry_t) * new_cap);
        if (!new_entries) return -1;
        list->entries = new_entries;
        list->capacity = new_cap;
    }

    ttzip_io_entry_t* item = &list->entries[list->count++];
    memset(item, 0, sizeof(ttzip_io_entry_t));
    snprintf(item->src_path, sizeof(item->src_path), "%s", base_path);
    snprintf(item->rel_path, sizeof(item->rel_path), "%s", rel_path ? rel_path : "");
    item->is_directory = S_ISDIR(st.st_mode);
    item->file_size = item->is_directory ? 0 : (uint64_t)st.st_size;
    item->mtime = (uint32_t)st.st_mtime;

    if (item->is_directory) {
        DIR* dir = opendir(base_path);
        if (dir) {
            int dfd = dirfd(dir);
            struct dirent* entry;
            while ((entry = readdir(dir)) != NULL) {
                if (entry->d_name[0] == '.' && (entry->d_name[1] == '\0' || (entry->d_name[1] == '.' && entry->d_name[2] == '\0')))
                    continue;
                
                char child_base[4096];
                char child_rel[2048];
                snprintf(child_base, sizeof(child_base), "%s/%s", base_path, entry->d_name);
                if (rel_path && rel_path[0] != '\0') {
                    snprintf(child_rel, sizeof(child_rel), "%s/%s", rel_path, entry->d_name);
                } else {
                    snprintf(child_rel, sizeof(child_rel), "%s", entry->d_name);
                }

                if (entry->d_type == DT_REG && dfd >= 0) {
                    struct stat cst;
                    if (fstatat(dfd, entry->d_name, &cst, AT_SYMLINK_NOFOLLOW) == 0) {
                        if (list->count >= list->capacity) {
                            size_t new_cap = list->capacity * 2;
                            ttzip_io_entry_t* new_entries = (ttzip_io_entry_t*)realloc(list->entries, sizeof(ttzip_io_entry_t) * new_cap);
                            if (new_entries) {
                                list->entries = new_entries;
                                list->capacity = new_cap;
                            }
                        }
                        if (list->count < list->capacity) {
                            ttzip_io_entry_t* citem = &list->entries[list->count++];
                            memset(citem, 0, sizeof(ttzip_io_entry_t));
                            snprintf(citem->src_path, sizeof(citem->src_path), "%s", child_base);
                            snprintf(citem->rel_path, sizeof(citem->rel_path), "%s", child_rel);
                            citem->is_directory = false;
                            citem->file_size = (uint64_t)cst.st_size;
                            citem->mtime = (uint32_t)cst.st_mtime;
                        }
                        continue;
                    }
                }
                ttzip_io_collect_recursive(child_base, child_rel, list);
            }
            closedir(dir);
        }
    }
    return 0;
}

void ttzip_io_file_list_free(ttzip_io_file_list_t* list) {
    if (list) {
        if (list->entries) {
            for (size_t i = 0; i < list->count; i++) {
                if (list->entries[i].payload_buf) {
                    free(list->entries[i].payload_buf);
                    list->entries[i].payload_buf = NULL;
                }
            }
            free(list->entries);
            list->entries = NULL;
        }
        list->count = 0;
        list->capacity = 0;
    }
}

ssize_t ttzip_io_write_all(int fd, const void* buf, size_t count) {
    const char* p = (const char*)buf;
    size_t total_written = 0;
    while (total_written < count) {
        size_t chunk = count - total_written;
#if defined(SSIZE_MAX)
        if (chunk > (size_t)SSIZE_MAX) {
            chunk = (size_t)SSIZE_MAX;
        }
#endif
        ssize_t written = write(fd, p + total_written, chunk);
        if (written <= 0) {
            if (written < 0 && (errno == EINTR || errno == EAGAIN)) continue;
            return (total_written > 0) ? (ssize_t)total_written : written;
        }
        total_written += (size_t)written;
    }
    return (ssize_t)total_written;
}

int ttzip_io_apfs_preallocate(int fd, int64_t size) {
    return ttzip_core_apfs_preallocate_file(fd, size);
}
