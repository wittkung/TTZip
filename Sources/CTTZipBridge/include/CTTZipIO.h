/**
 * @file CTTZipIO.h
 * @brief TTZip 高性能 I/O 引擎、文件递归扫描与防御性全写入抽象
 * @details 对标 libarchive `archive_read_disk.c` 与 `archive_write_disk.c`，
 *          提供原子全写入、递归目录遍历以及生命周期受控的条目列表管理。
 * @version 4.0
 * @author TTZip Core Engineering Team
 */

#ifndef CTTZIP_IO_H
#define CTTZIP_IO_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 归档输入/输出单文件条目元数据与载荷结构体
 */
typedef struct {
    char src_path[4096];     /**< 源文件系统物理绝对路径 (UTF-8) */
    char rel_path[2048];     /**< 归档内部相对路径 (已过滤安全路径) */
    uint64_t file_size;      /**< 原始未压缩字节大小 */
    uint32_t crc32;          /**< 原始数据 CRC32 校验和 */
    uint32_t mtime;          /**< UNIX 修改时间戳 (秒) */
    bool is_directory;       /**< 是否为目录条目 */
    uint8_t* payload_buf;    /**< 预读载荷缓冲区指针 (若无需预读则为 NULL) */
} ttzip_io_entry_t;

/**
 * @brief 动态扩容的文件条目列表集合
 */
typedef struct {
    ttzip_io_entry_t* entries; /**< 连续分配的条目数组指针 */
    size_t count;              /**< 当前有效条目数量 */
    size_t capacity;           /**< 当前数组已分配容量 */
} ttzip_io_file_list_t;

/**
 * @brief 递归扫描指定目录并收集全部文件与子目录条目
 * 
 * @param[in]     base_path 扫描起始根目录绝对路径
 * @param[in]     rel_path  当前相对路径前缀 (根目录传入 "")
 * @param[in,out] list      目标文件列表结构体指针
 * 
 * @return 0 成功；非 0 表示发生 I/O 错误或拒绝访问
 */
int ttzip_io_collect_recursive(const char* base_path, const char* rel_path, ttzip_io_file_list_t* list);

/**
 * @brief 释放由 ``ttzip_io_collect_recursive`` 分配的文件列表及内部资源
 * 
 * @param[in,out] list 待释放的文件列表指针
 * 
 * @note [Ownership] 内部自动释放 `payload_buf` 与 `entries` 堆内存
 */
void ttzip_io_file_list_free(ttzip_io_file_list_t* list);

/**
 * @brief 循环写入全部数据至文件描述符，严格防护短写入与 SSIZE_MAX 溢出
 * 
 * @param[in] fd    已打开且具备写权限的目标文件描述符
 * @param[in] buf   待写入的数据起始缓冲区
 * @param[in] count 待写入的字节长度
 * 
 * @return 实际写入的字节总数；若失败返回 -1
 */
ssize_t ttzip_io_write_all(int fd, const void* buf, size_t count);

/**
 * @brief 预分配 APFS 磁盘空间
 */
int ttzip_io_apfs_preallocate(int fd, int64_t size);

/**
 * @brief 递归创建目录
 */
int ttzip_io_mkdir_p(const char *dir_path);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_IO_H */
