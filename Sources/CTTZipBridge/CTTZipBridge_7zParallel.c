#include "include/CTTZipBridge_7zParallel.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipBridge_Crypto.h"
#include "include/ttzip_lzma2_dec_native.h"
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <string.h>
#include <stdio.h>
#include <dispatch/dispatch.h>

static ssize_t write_all(int fd, const void* buf, size_t count) {
    size_t written = 0;
    const char* ptr = (const char*)buf;
    while (written < count) {
        ssize_t res = write(fd, ptr + written, count - written);
        if (res <= 0) return -1;
        written += (size_t)res;
    }
    return (ssize_t)written;
}

int ttzip_7z_extract_parallel_c(
    const char* archive_path,
    const char* destination_dir,
    const char* password
) {
    (void)password;
    if (!archive_path || !destination_dir) return -1;

    int fd = open(archive_path, O_RDONLY);
    if (fd < 0) return -2;

    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size <= 32) {
        close(fd);
        return -3;
    }

    size_t file_size = (size_t)st.st_size;
    void* map_ptr = mmap(NULL, file_size, PROT_READ, MAP_SHARED, fd, 0);
    close(fd);

    if (map_ptr == MAP_FAILED) return -4;
    madvise(map_ptr, file_size, MADV_WILLNEED);

    const uint8_t* hdr = (const uint8_t*)map_ptr;
    if (hdr[0] != 0x37 || hdr[1] != 0x7A || hdr[2] != 0xBC || hdr[3] != 0xAF || hdr[4] != 0x27 || hdr[5] != 0x1C) {
        munmap(map_ptr, file_size);
        return -4;
    }

    munmap(map_ptr, file_size);
    return 0;
}
