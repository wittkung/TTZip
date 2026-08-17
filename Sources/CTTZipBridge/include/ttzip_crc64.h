/**
 * @file ttzip_crc64.h
 * @brief ARM64 PMULL 硬件加速与标量回退 CRC64 (ECMA-182) 校验引擎
 * @details 基于 ARMv8-A vmull_p64 无进位乘法实现 4 路 64 字节向量折叠与 Barrett 模约化。
 * @version 1.0
 * @author TTZip Core Engineering Team
 */

#ifndef TTZIP_CRC64_H
#define TTZIP_CRC64_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 计算 CRC64 (ECMA-182) 校验码（自动进行 Apple Silicon 硬件加速分发）
 * @param[in] buf  输入数据指针（允许为 NULL，此时直接返回 crc）
 * @param[in] size 数据字节长度
 * @param[in] crc  初始 CRC 种子（标准初始值为 0）
 * @return 计算后的 64 位 CRC 校验码（反转进出）
 */
uint64_t ttzip_crc64(const uint8_t *buf, size_t size, uint64_t crc);

/**
 * @brief 直接调用 ARM64 PMULL 硬件加速计算 CRC64 (ECMA-182)
 * @param[in] buf  输入数据指针
 * @param[in] size 数据字节长度
 * @param[in] crc  初始 CRC 种子
 * @return 计算后的 64 位 CRC 校验码
 */
uint64_t ttzip_crc64_pmull(const uint8_t *buf, size_t size, uint64_t crc);

/**
 * @brief 标量 Slicing-by-8 查表法计算 CRC64 (ECMA-182)
 * @param[in] buf  输入数据指针
 * @param[in] size 数据字节长度
 * @param[in] crc  初始 CRC 种子
 * @return 计算后的 64 位 CRC 校验码
 */
uint64_t ttzip_crc64_scalar(const uint8_t *buf, size_t size, uint64_t crc);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_CRC64_H
