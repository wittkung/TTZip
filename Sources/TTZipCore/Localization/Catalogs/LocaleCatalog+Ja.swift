// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Japanese localization string catalog (`ja`).
public enum LocaleCatalogJa {
    public static let strings: [String: String] = [
        "common.cancel": "キャンセル",
        "common.ok": "OK",
        "common.done": "完了",
        "common.save": "保存",
        "common.close": "閉じる",
        "common.retry": "再試行",
        "common.success": "成功",
        "common.failed": "失敗",
        "common.loading": "読み込み中...",
        "common.warning": "警告",
        "common.error": "エラー",
        "common.processing": "処理中...",
        
        "archive.compress": "圧縮",
        "archive.extract": "解凍",
        "archive.compressing": "圧縮中...",
        "archive.extracting": "解凍中...",
        "archive.compress_success": "アーカイブの作成が完了しました",
        "archive.extract_success": "アーカイブの解凍が完了しました",
        "archive.compress_failed": "圧縮に失敗しました",
        "archive.extract_failed": "解凍に失敗しました",
        "archive.password_required": "パスワードが必要です",
        "archive.incorrect_password": "パスワードが正しくありません",
        "archive.corrupt_data": "アーカイブデータが破損しています",
        "archive.unsupported_format": "サポートされていない形式です",
        "archive.format": "形式",
        "archive.compression_level": "圧縮レベル",
        "archive.split_volume": "分割圧縮",
        "archive.encryption": "暗号化",
        
        "cli.usage_header": "TTZip CLI — 高性能ネイティブアーカイブ・圧縮エンジン",
        "cli.subcommands": "コマンド一覧",
        "cli.global_options": "グローバルオプション",
        "cli.error_missing_arg": "必須引数が不足しています: %@",
        "cli.error_file_not_found": "ファイルが見つかりません: %@",
        "cli.error_invalid_format": "無効なアーカイブ形式です: %@",
        "cli.dry_run_prefix": "[ドライラン] 実行予定の操作: %@",
        "cli.bench_running": "フォーマット %@ のベンチマークを実行中 (パス %d/%d)...",
        "cli.test_summary": "テスト結果: %d 件成功, %d 件失敗 (所要時間 %.2fs)",
        
        "benchmark.throughput": "スループット",
        "benchmark.compression_ratio": "圧縮率",
        "benchmark.duration": "所要時間",
        "benchmark.memory_usage": "メモリ使用量",
        "benchmark.peak_throughput": "ピークスループット",
        "benchmark.speedup": "高速化率",
        
        "error.file_not_found": "指定されたファイルまたはディレクトリが存在しません。",
        "error.permission_denied": "パスへのアクセス権限がありません。",
        "error.disk_full": "ディスクの空き容量が不足しています。",
        "error.zip_slip_detected": "Zip Slip ディレクトリトラバーサル攻撃を検出し遮断しました。",
        "error.corrupted_header": "アーカイブヘッダーの Magic チェックに失敗したか破損しています。",
        "error.crc_mismatch": "解凍データの CRC32 チェックサムが一致しません。",
        "error.out_of_memory": "メモリ割り当て上限を超過しました。",
        "error.operation_cancelled": "ユーザーによって操作がキャンセルされました。",
        
        "settings.title": "環境設定",
        "settings.general": "一般",
        "settings.language": "言語",
        "settings.byte_units": "サイズ単位",
        "settings.license_status": "ライセンス状態",
        "settings.hardware_topology": "Apple Silicon ハードウェアアクセラレーション",
        
        "vault.title": "パスワード保管庫",
        "vault.unlock_prompt": "保管庫のロックを解除するパスワードを入力",
        "vault.add_password": "パスワードを追加",
        "vault.empty_vault": "保存されたパスワードはありません"
    ]
}
