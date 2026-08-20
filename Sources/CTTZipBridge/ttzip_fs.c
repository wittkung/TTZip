// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "ttzip_fs.h"
#include "ttzip_windows.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#if defined(TTZIP_OS_WINDOWS)
  #include <windows.h>
  #include <direct.h>
#else
  #include <dirent.h>
  #include <sys/stat.h>
  #include <sys/types.h>
  #include <sys/mman.h>
  #include <unistd.h>
  #include <fcntl.h>
#endif

#if defined(TTZIP_OS_WINDOWS)

struct ttzip_dir_iterator {
    wchar_t  root_path_w[TTZIP_WIN_MAX_PATH];
    char     root_path_utf8[4096];
    HANDLE   h_find;
    WIN32_FIND_DATAW find_data;
    bool     first_entry;
};

ttzip_dir_iterator_t* ttzip_fs_opendir(const char* utf8_root_path) {
    if (!utf8_root_path || !*utf8_root_path) return NULL;
    
    ttzip_dir_iterator_t* it = (ttzip_dir_iterator_t*)calloc(1, sizeof(ttzip_dir_iterator_t));
    if (!it) return NULL;
    
    strncpy(it->root_path_utf8, utf8_root_path, sizeof(it->root_path_utf8) - 1);
    
    wchar_t* raw_w = ttzip_utf8_to_utf16(utf8_root_path);
    if (!raw_w) {
        free(it);
        return NULL;
    }
    
    // Format search pattern: \\?\C:\path\*
    if (wcsncmp(raw_w, TTZIP_WIN_LONG_PATH_PREFIX, 4) == 0) {
        swprintf(it->root_path_w, TTZIP_WIN_MAX_PATH, L"%s\\*", raw_w);
    } else {
        swprintf(it->root_path_w, TTZIP_WIN_MAX_PATH, L"%s%s\\*", TTZIP_WIN_LONG_PATH_PREFIX, raw_w);
    }
    free(raw_w);
    
    it->h_find = FindFirstFileW(it->root_path_w, &it->find_data);
    if (it->h_find == INVALID_HANDLE_VALUE) {
        free(it);
        return NULL;
    }
    it->first_entry = true;
    return it;
}

int ttzip_fs_readdir(ttzip_dir_iterator_t* it, ttzip_fs_entry_t* out_entry) {
    if (!it || it->h_find == INVALID_HANDLE_VALUE || !out_entry) return -1;
    
    while (1) {
        if (!it->first_entry) {
            if (!FindNextFileW(it->h_find, &it->find_data)) {
                if (GetLastError() == ERROR_NO_MORE_FILES) {
                    return 1; // EOF
                }
                return -1;
            }
        }
        it->first_entry = false;
        
        // Skip . and ..
        if (wcscmp(it->find_data.cFileName, L".") == 0 || wcscmp(it->find_data.cFileName, L"..") == 0) {
            continue;
        }
        
        char* filename_utf8 = ttzip_utf16_to_utf8(it->find_data.cFileName);
        if (!filename_utf8) continue;
        
        memset(out_entry, 0, sizeof(ttzip_fs_entry_t));
        strncpy(out_entry->path, filename_utf8, sizeof(out_entry->path) - 1);
        free(filename_utf8);
        
        out_entry->is_directory = (it->find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
        out_entry->is_symlink = (it->find_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
        out_entry->size_bytes = ((uint64_t)it->find_data.nFileSizeHigh << 32) | it->find_data.nFileSizeLow;
        
        // Convert FILETIME to Unix epoch
        ULARGE_INTEGER ull;
        ull.LowPart = it->find_data.ftLastWriteTime.dwLowDateTime;
        ull.HighPart = it->find_data.ftLastWriteTime.dwHighDateTime;
        out_entry->mtime_epoch_secs = (ull.QuadPart - 116444736000000000ULL) / 10000000ULL;
        out_entry->posix_mode = out_entry->is_directory ? 0755 : 0644;
        return 0;
    }
}

void ttzip_fs_closedir(ttzip_dir_iterator_t* it) {
    if (!it) return;
    if (it->h_find != INVALID_HANDLE_VALUE) {
        FindClose(it->h_find);
    }
    free(it);
}

int ttzip_fs_stat(const char* utf8_path, ttzip_fs_entry_t* out_entry) {
    if (!utf8_path || !out_entry) return -1;
    
    wchar_t* path_w = ttzip_utf8_to_utf16(utf8_path);
    if (!path_w) return -1;
    
    wchar_t full_path_w[TTZIP_WIN_MAX_PATH];
    if (wcsncmp(path_w, TTZIP_WIN_LONG_PATH_PREFIX, 4) == 0) {
        wcsncpy(full_path_w, path_w, TTZIP_WIN_MAX_PATH - 1);
    } else {
        swprintf(full_path_w, TTZIP_WIN_MAX_PATH, L"%s%s", TTZIP_WIN_LONG_PATH_PREFIX, path_w);
    }
    free(path_w);
    
    WIN32_FILE_ATTRIBUTE_DATA fad;
    if (!GetFileAttributesExW(full_path_w, GetFileExInfoStandard, &fad)) {
        return -1;
    }
    
    memset(out_entry, 0, sizeof(ttzip_fs_entry_t));
    strncpy(out_entry->path, utf8_path, sizeof(out_entry->path) - 1);
    out_entry->is_directory = (fad.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    out_entry->is_symlink = (fad.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
    out_entry->size_bytes = ((uint64_t)fad.nFileSizeHigh << 32) | fad.nFileSizeLow;
    
    ULARGE_INTEGER ull;
    ull.LowPart = fad.ftLastWriteTime.dwLowDateTime;
    ull.HighPart = fad.ftLastWriteTime.dwHighDateTime;
    out_entry->mtime_epoch_secs = (ull.QuadPart - 116444736000000000ULL) / 10000000ULL;
    out_entry->posix_mode = out_entry->is_directory ? 0755 : 0644;
    return 0;
}

int ttzip_fs_mkdir_p(const char* utf8_path, uint32_t mode) {
    (void)mode;
    if (!utf8_path || !*utf8_path) return -1;
    
    char temp[4096];
    strncpy(temp, utf8_path, sizeof(temp) - 1);
    temp[sizeof(temp) - 1] = '\0';
    
    for (char* p = temp + 1; *p; p++) {
        if (*p == '/' || *p == '\\') {
            char save = *p;
            *p = '\0';
            wchar_t* dir_w = ttzip_utf8_to_utf16(temp);
            if (dir_w) {
                CreateDirectoryW(dir_w, NULL);
                free(dir_w);
            }
            *p = save;
        }
    }
    wchar_t* final_w = ttzip_utf8_to_utf16(temp);
    if (final_w) {
        CreateDirectoryW(final_w, NULL);
        free(final_w);
    }
    return 0;
}

const void* ttzip_fs_mmap_read(const char* utf8_path, uint64_t* out_length) {
    if (!utf8_path || !out_length) return NULL;
    *out_length = 0;
    
    wchar_t* path_w = ttzip_utf8_to_utf16(utf8_path);
    if (!path_w) return NULL;
    
    HANDLE h_file = CreateFileW(path_w, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    free(path_w);
    if (h_file == INVALID_HANDLE_VALUE) return NULL;
    
    LARGE_INTEGER size;
    if (!GetFileSizeEx(h_file, &size) || size.QuadPart == 0) {
        CloseHandle(h_file);
        return NULL;
    }
    *out_length = (uint64_t)size.QuadPart;
    
    HANDLE h_map = CreateFileMappingW(h_file, NULL, PAGE_READONLY, 0, 0, NULL);
    CloseHandle(h_file); // Safe to close after mapping object created
    if (!h_map) return NULL;
    
    const void* ptr = MapViewOfFile(h_map, FILE_MAP_READ, 0, 0, 0);
    CloseHandle(h_map);
    return ptr;
}

void ttzip_fs_munmap(const void* ptr, uint64_t length) {
    (void)length;
    if (ptr) {
        UnmapViewOfFile(ptr);
    }
}

#else /* POSIX (macOS / Linux) */

struct ttzip_dir_iterator {
    DIR*  dir;
    char  root_path[4096];
};

ttzip_dir_iterator_t* ttzip_fs_opendir(const char* utf8_root_path) {
    if (!utf8_root_path || !*utf8_root_path) return NULL;
    
    DIR* d = opendir(utf8_root_path);
    if (!d) return NULL;
    
    ttzip_dir_iterator_t* it = (ttzip_dir_iterator_t*)calloc(1, sizeof(ttzip_dir_iterator_t));
    if (!it) {
        closedir(d);
        return NULL;
    }
    it->dir = d;
    strncpy(it->root_path, utf8_root_path, sizeof(it->root_path) - 1);
    return it;
}

int ttzip_fs_readdir(ttzip_dir_iterator_t* it, ttzip_fs_entry_t* out_entry) {
    if (!it || !it->dir || !out_entry) return -1;
    
    struct dirent* de = NULL;
    while ((de = readdir(it->dir)) != NULL) {
        if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) {
            continue;
        }
        
        char full_path[4096];
        snprintf(full_path, sizeof(full_path), "%s/%s", it->root_path, de->d_name);
        
        struct stat st;
        if (lstat(full_path, &st) != 0) {
            continue;
        }
        
        memset(out_entry, 0, sizeof(ttzip_fs_entry_t));
        strncpy(out_entry->path, de->d_name, sizeof(out_entry->path) - 1);
        out_entry->size_bytes = (uint64_t)st.st_size;
        out_entry->mtime_epoch_secs = (uint64_t)st.st_mtime;
        out_entry->posix_mode = (uint32_t)(st.st_mode & 0777);
        out_entry->is_directory = S_ISDIR(st.st_mode);
        out_entry->is_symlink = S_ISLNK(st.st_mode);
        
        if (out_entry->is_symlink) {
            ssize_t len = readlink(full_path, out_entry->symlink_target, sizeof(out_entry->symlink_target) - 1);
            if (len > 0) {
                out_entry->symlink_target[len] = '\0';
            }
        }
        return 0;
    }
    return 1; // EOF
}

void ttzip_fs_closedir(ttzip_dir_iterator_t* it) {
    if (!it) return;
    if (it->dir) {
        closedir(it->dir);
    }
    free(it);
}

int ttzip_fs_stat(const char* utf8_path, ttzip_fs_entry_t* out_entry) {
    if (!utf8_path || !out_entry) return -1;
    
    struct stat st;
    if (lstat(utf8_path, &st) != 0) return -1;
    
    memset(out_entry, 0, sizeof(ttzip_fs_entry_t));
    strncpy(out_entry->path, utf8_path, sizeof(out_entry->path) - 1);
    out_entry->size_bytes = (uint64_t)st.st_size;
    out_entry->mtime_epoch_secs = (uint64_t)st.st_mtime;
    out_entry->posix_mode = (uint32_t)(st.st_mode & 0777);
    out_entry->is_directory = S_ISDIR(st.st_mode);
    out_entry->is_symlink = S_ISLNK(st.st_mode);
    
    if (out_entry->is_symlink) {
        ssize_t len = readlink(utf8_path, out_entry->symlink_target, sizeof(out_entry->symlink_target) - 1);
        if (len > 0) {
            out_entry->symlink_target[len] = '\0';
        }
    }
    return 0;
}

int ttzip_fs_mkdir_p(const char* utf8_path, uint32_t mode) {
    if (!utf8_path || !*utf8_path) return -1;
    if (mode == 0) mode = 0755;
    
    char temp[4096];
    strncpy(temp, utf8_path, sizeof(temp) - 1);
    temp[sizeof(temp) - 1] = '\0';
    
    for (char* p = temp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(temp, (mode_t)mode);
            *p = '/';
        }
    }
    return mkdir(temp, (mode_t)mode) == 0 || errno == EEXIST ? 0 : -1;
}

const void* ttzip_fs_mmap_read(const char* utf8_path, uint64_t* out_length) {
    if (!utf8_path || !out_length) return NULL;
    *out_length = 0;
    
    int fd = open(utf8_path, O_RDONLY);
    if (fd < 0) return NULL;
    
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size == 0) {
        close(fd);
        return NULL;
    }
    *out_length = (uint64_t)st.st_size;
    
    void* ptr = mmap(NULL, (size_t)st.st_size, PROT_READ, MAP_SHARED, fd, 0);
    close(fd);
    if (ptr == MAP_FAILED) return NULL;
    
#if defined(MADV_SEQUENTIAL) && defined(MADV_WILLNEED)
    posix_madvise(ptr, (size_t)st.st_size, POSIX_MADV_SEQUENTIAL | POSIX_MADV_WILLNEED);
#endif
    return ptr;
}

void ttzip_fs_munmap(const void* ptr, uint64_t length) {
    if (ptr && length > 0) {
        munmap((void*)ptr, (size_t)length);
    }
}

#endif
