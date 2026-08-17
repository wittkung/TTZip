/**
 * @file CTTZipSysAlloc.h
 * @brief TTZip 高性能物理页对齐内存分配与系统级文件预分配抽象
 * @details 统一封装 Apple Silicon 16KB 页对齐与 POSIX/Win32 对称内存释放通道。
 * @version 4.0
 * @author TTZip Core Engineering Team
 */

#ifndef CTTZipSysAlloc_h
#define CTTZipSysAlloc_h

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 在 APFS 或底层文件系统上为指定文件描述符预分配连续物理磁盘空间
 * 
 * @param[in] fd          已打开且具备写权限的文件描述符
 * @param[in] target_size 目标分配字节大小，必须 >= 0
 * 
 * @return 0 成功分配；非 0 表示系统调用失败或不支持
 * 
 * @note 内部自动处理 F_PREALLOCATE 与 ftruncate 逻辑尺寸截断
 */
int ttzip_core_apfs_preallocate_file(int fd, int64_t target_size);

/**
 * @brief 申请 16KB (16384 字节) 对齐的物理内存页缓冲区
 * 
 * @param[in] size 申请的字节长度，必须 > 0
 * 
 * @return 成功返回 16KB 对齐的内存裸指针；失败返回 NULL
 * 
 * @note [Ownership] 调用方拥有返回指针的所有权，必须且只能调用 ``ttzip_core_aligned_free_16k`` 释放
 */
void* ttzip_core_aligned_alloc_16k(size_t size);

/**
 * @brief 释放由 ``ttzip_core_aligned_alloc_16k`` 分配的 16KB 对齐内存
 * 
 * @param[in] ptr 待释放的对齐内存指针；若传入 NULL 则安全静默返回
 * 
 * @note [Ownership] 释放后该指针立即失效，严禁二次释放 (Double Free)
 */
void ttzip_core_aligned_free_16k(void* ptr);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipSysAlloc_h */
