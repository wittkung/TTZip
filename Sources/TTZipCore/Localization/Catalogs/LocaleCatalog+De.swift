// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// German localization string catalog (`de`).
public enum LocaleCatalogDe {
    public static let strings: [String: String] = [
        "common.cancel": "Abbrechen",
        "common.ok": "OK",
        "common.done": "Fertig",
        "common.save": "Speichern",
        "common.close": "Schließen",
        "common.retry": "Wiederholen",
        "common.success": "Erfolg",
        "common.failed": "Fehlgeschlagen",
        "common.loading": "Laden...",
        "common.warning": "Warnung",
        "common.error": "Fehler",
        "common.processing": "Verarbeitung...",
        
        "archive.compress": "Komprimieren",
        "archive.extract": "Entpacken",
        "archive.compressing": "Komprimierung läuft...",
        "archive.extracting": "Entpacken läuft...",
        "archive.compress_success": "Archiv erfolgreich erstellt",
        "archive.extract_success": "Archiv erfolgreich entpackt",
        "archive.compress_failed": "Komprimierung fehlgeschlagen",
        "archive.extract_failed": "Entpacken fehlgeschlagen",
        "archive.password_required": "Passwort erforderlich",
        "archive.incorrect_password": "Falsches Passwort",
        "archive.corrupt_data": "Archivdaten sind beschädigt",
        "archive.unsupported_format": "Nicht unterstütztes Archivformat",
        "archive.format": "Format",
        "archive.compression_level": "Kompressionsstufe",
        "archive.split_volume": "Teilarchiv erstellen",
        "archive.encryption": "Verschlüsselung",
        
        "cli.usage_header": "TTZip CLI — Hochleistungsfähige native Archivierungs-Engine",
        "cli.subcommands": "Befehle",
        "cli.global_options": "Globale Optionen",
        "cli.error_missing_arg": "Erforderliches Argument fehlt: %@",
        "cli.error_file_not_found": "Datei nicht gefunden: %@",
        "cli.error_invalid_format": "Ungültiges Archivformat: %@",
        "cli.dry_run_prefix": "[PROBELAUF] Würde ausführen: %@",
        "cli.bench_running": "Benchmark für Format %@ wird ausgeführt (Durchlauf %d/%d)...",
        "cli.test_summary": "Test-Zusammenfassung: %d bestanden, %d fehlgeschlagen in %.2fs",
        
        "benchmark.throughput": "Durchsatz",
        "benchmark.compression_ratio": "Kompressionsrate",
        "benchmark.duration": "Dauer",
        "benchmark.memory_usage": "Speicher",
        "benchmark.peak_throughput": "Spitzendurchsatz",
        "benchmark.speedup": "Beschleunigung",
        
        "error.file_not_found": "Die angegebene Datei oder das Verzeichnis existiert nicht.",
        "error.permission_denied": "Zugriff auf Pfad verweigert.",
        "error.disk_full": "Ziellaufwerk ist voll.",
        "error.zip_slip_detected": "Zip-Slip-Pfadüberschreitungsangriff erkannt und blockiert.",
        "error.corrupted_header": "Archivkopfzeilen-Magic-Prüfung fehlgeschlagen oder beschädigt.",
        "error.crc_mismatch": "CRC32-Prüfsummenabweichung in extrahierten Daten.",
        "error.out_of_memory": "Nicht genügend Speicher für Pufferreservierung.",
        "error.operation_cancelled": "Vorgang vom Benutzer abgebrochen.",
        
        "settings.title": "Einstellungen",
        "settings.general": "Allgemein",
        "settings.language": "Sprache",
        "settings.byte_units": "Größeneinheiten",
        "settings.license_status": "Lizenzstatus",
        "settings.hardware_topology": "Hardware-Topologie",
        
        "vault.title": "Passwort-Tresor",
        "vault.unlock_prompt": "Passwort zum Entsperren des Tresors eingeben",
        "vault.add_password": "Passwort hinzufügen",
        "vault.empty_vault": "Tresor ist leer"
    ]
}
