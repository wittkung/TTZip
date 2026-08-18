// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Simplified Chinese localization string catalog (`zh-Hans`).
public enum LocaleCatalogZhHans {
    public static let strings: [String: String] = [
        "common.cancel": "取消",
        "common.ok": "确定",
        "common.done": "完成",
        "common.save": "保存",
        "common.close": "关闭",
        "common.retry": "重试",
        "common.success": "成功",
        "common.failed": "失败",
        "common.loading": "加载中...",
        "common.warning": "警告",
        "common.error": "错误",
        "common.processing": "处理中...",
        
        "archive.compress": "压缩",
        "archive.extract": "解压",
        "archive.compressing": "正在压缩...",
        "archive.extracting": "正在解压...",
        "archive.compress_success": "归档打包成功",
        "archive.extract_success": "归档解压成功",
        "archive.compress_failed": "压缩失败",
        "archive.extract_failed": "解压失败",
        "archive.password_required": "需要解密密码",
        "archive.incorrect_password": "解密密码不正确",
        "archive.corrupt_data": "归档数据损坏",
        "archive.unsupported_format": "不支持的归档格式",
        "archive.format": "格式",
        "archive.compression_level": "压缩级别",
        "archive.split_volume": "分卷压缩",
        "archive.encryption": "加密保护",
        
        "cli.usage_header": "TTZip CLI — 高性能原生归档与压缩解压引擎",
        "cli.subcommands": "子命令列表",
        "cli.global_options": "全局选项",
        "cli.error_missing_arg": "缺少必要参数: %@",
        "cli.error_file_not_found": "未找到文件: %@",
        "cli.error_invalid_format": "无效的压缩格式: %@",
        "cli.dry_run_prefix": "[模拟运行] 拟执行操作: %@",
        "cli.bench_running": "正在针对格式 %@ 运行基准测试 (轮次 %d/%d)...",
        "cli.test_summary": "测试汇总: %d 项通过, %d 项失败 (耗时 %.2fs)",
        
        "benchmark.throughput": "吞吐速率",
        "benchmark.compression_ratio": "压缩率",
        "benchmark.duration": "耗时",
        "benchmark.memory_usage": "内存开销",
        "benchmark.peak_throughput": "历史峰值吞吐",
        "benchmark.speedup": "加速比",
        
        "error.file_not_found": "指定的文件或目录不存在。",
        "error.permission_denied": "访问路径权限被拒绝。",
        "error.disk_full": "目标磁盘空间已满。",
        "error.zip_slip_detected": "检测并拦截到 Zip Slip 目录穿越恶意路径攻击。",
        "error.corrupted_header": "归档文件头 Magic 校验失败或已损坏。",
        "error.crc_mismatch": "解压数据 CRC32 校验码不匹配。",
        "error.out_of_memory": "内存缓冲区分配超限。",
        "error.operation_cancelled": "用户已取消操作。",
        
        "settings.title": "偏好设置",
        "settings.general": "通用",
        "settings.language": "界面语言",
        "settings.byte_units": "容量单位",
        "settings.license_status": "商业授权状态",
        "settings.hardware_topology": "Apple Silicon 硬件加速拓扑",
        
        "vault.title": "密码钥匙串",
        "vault.unlock_prompt": "请输入密码解锁钥匙串",
        "vault.add_password": "新增密码",
        "vault.empty_vault": "钥匙串暂无保存密码"
    ]
}
