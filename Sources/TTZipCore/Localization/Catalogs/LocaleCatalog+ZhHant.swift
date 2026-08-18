// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Traditional Chinese localization string catalog (`zh-Hant`).
public enum LocaleCatalogZhHant {
    public static let strings: [String: String] = [
        "common.cancel": "取消",
        "common.ok": "確定",
        "common.done": "完成",
        "common.save": "儲存",
        "common.close": "關閉",
        "common.retry": "重試",
        "common.success": "成功",
        "common.failed": "失敗",
        "common.loading": "載入中...",
        "common.warning": "警告",
        "common.error": "錯誤",
        "common.processing": "處理中...",
        
        "archive.compress": "壓縮",
        "archive.extract": "解壓縮",
        "archive.compressing": "正在壓縮...",
        "archive.extracting": "正在解壓縮...",
        "archive.compress_success": "封存壓縮成功",
        "archive.extract_success": "封存解壓縮成功",
        "archive.compress_failed": "壓縮失敗",
        "archive.extract_failed": "解壓縮失敗",
        "archive.password_required": "需要解密密碼",
        "archive.incorrect_password": "解密密碼不正確",
        "archive.corrupt_data": "封存資料損壞",
        "archive.unsupported_format": "不支援的封存格式",
        "archive.format": "格式",
        "archive.compression_level": "壓縮等級",
        "archive.split_volume": "分卷壓縮",
        "archive.encryption": "加密保護",
        
        "cli.usage_header": "TTZip CLI — 高效能原生封存與壓縮解壓縮引擎",
        "cli.subcommands": "子命令列表",
        "cli.global_options": "全域選項",
        "cli.error_missing_arg": "缺少必要參數: %@",
        "cli.error_file_not_found": "未找到檔案: %@",
        "cli.error_invalid_format": "無效的壓縮格式: %@",
        "cli.dry_run_prefix": "[模擬執行] 擬執行操作: %@",
        "cli.bench_running": "正在針對格式 %@ 執行基準測試 (輪次 %d/%d)...",
        "cli.test_summary": "測試彙總: %d 項通過, %d 項失敗 (耗時 %.2fs)",
        
        "benchmark.throughput": "吞吐速率",
        "benchmark.compression_ratio": "壓縮率",
        "benchmark.duration": "耗時",
        "benchmark.memory_usage": "記憶體開銷",
        "benchmark.peak_throughput": "歷史峰值吞吐",
        "benchmark.speedup": "加速比",
        
        "error.file_not_found": "指定的檔案或目錄不存在。",
        "error.permission_denied": "存取路徑權限被拒絕。",
        "error.disk_full": "目標磁碟空間已滿。",
        "error.zip_slip_detected": "偵測並攔截到 Zip Slip 目錄穿越惡意路徑攻擊。",
        "error.corrupted_header": "封存檔標頭 Magic 校驗失敗或已損壞。",
        "error.crc_mismatch": "解壓縮資料 CRC32 校驗碼不符。",
        "error.out_of_memory": "記憶體緩衝區配置超限。",
        "error.operation_cancelled": "使用者已取消操作。",
        
        "settings.title": "偏好設定",
        "settings.general": "一般",
        "settings.language": "介面語言",
        "settings.byte_units": "容量單位",
        "settings.license_status": "商業授權狀態",
        "settings.hardware_topology": "Apple Silicon 硬體加速拓撲",
        
        "vault.title": "密碼鑰匙圈",
        "vault.unlock_prompt": "請輸入密碼解鎖鑰匙圈",
        "vault.add_password": "新增密碼",
        "vault.empty_vault": "鑰匙圈尚無儲存密碼"
    ]
}
