// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// French localization string catalog (`fr`).
public enum LocaleCatalogFr {
    public static let strings: [String: String] = [
        "common.cancel": "Annuler",
        "common.ok": "OK",
        "common.done": "Terminé",
        "common.save": "Enregistrer",
        "common.close": "Fermer",
        "common.retry": "Réessayer",
        "common.success": "Succès",
        "common.failed": "Échec",
        "common.loading": "Chargement...",
        "common.warning": "Avertissement",
        "common.error": "Erreur",
        "common.processing": "Traitement...",
        
        "archive.compress": "Compresser",
        "archive.extract": "Extraire",
        "archive.compressing": "Compression en cours...",
        "archive.extracting": "Extraction en cours...",
        "archive.compress_success": "Archive créée avec succès",
        "archive.extract_success": "Archive extraite avec succès",
        "archive.compress_failed": "Échec de la compression",
        "archive.extract_failed": "Échec de l'extraction",
        "archive.password_required": "Mot de passe requis",
        "archive.incorrect_password": "Mot de passe incorrect",
        "archive.corrupt_data": "Les données de l'archive sont corrompues",
        "archive.unsupported_format": "Format d'archive non pris en charge",
        "archive.format": "Format",
        "archive.compression_level": "Niveau de compression",
        "archive.split_volume": "Découpage en volumes",
        "archive.encryption": "Chiffrement",
        
        "cli.usage_header": "TTZip CLI — Moteur natif d'archivage haute performance",
        "cli.subcommands": "Commandes",
        "cli.global_options": "Options globales",
        "cli.error_missing_arg": "Argument requis manquant : %@",
        "cli.error_file_not_found": "Fichier introuvable : %@",
        "cli.error_invalid_format": "Format d'archive invalide : %@",
        "cli.dry_run_prefix": "[SIMULATION] Action prévue : %@",
        "cli.bench_running": "Exécution du benchmark pour le format %@ (Passe %d/%d)...",
        "cli.test_summary": "Résumé des tests : %d réussis, %d échoués en %.2fs",
        
        "benchmark.throughput": "Débit",
        "benchmark.compression_ratio": "Taux",
        "benchmark.duration": "Durée",
        "benchmark.memory_usage": "Mémoire",
        "benchmark.peak_throughput": "Débit de pointe",
        "benchmark.speedup": "Accélération",
        
        "error.file_not_found": "Le fichier ou répertoire spécifié n'existe pas.",
        "error.permission_denied": "Permission refusée pour accéder au chemin.",
        "error.disk_full": "L'espace disque de destination est saturé.",
        "error.zip_slip_detected": "Attaque par traversée de répertoire Zip Slip détectée et bloquée.",
        "error.corrupted_header": "Échec de vérification du Magic d'en-tête ou archive corrompue.",
        "error.crc_mismatch": "Non-concordance de la somme de contrôle CRC32 dans les données extraites.",
        "error.out_of_memory": "Mémoire insuffisante pour l'allocation du tampon.",
        "error.operation_cancelled": "Opération annulée par l'utilisateur.",
        
        "settings.title": "Préférences",
        "settings.general": "Général",
        "settings.language": "Langue",
        "settings.byte_units": "Unités d'octets",
        "settings.license_status": "État de la licence",
        "settings.hardware_topology": "Topologie matérielle",
        
        "vault.title": "Trousseau de mots de passe",
        "vault.unlock_prompt": "Entrez le mot de passe pour déverrouiller le trousseau",
        "vault.add_password": "Ajouter un mot de passe",
        "vault.empty_vault": "Le trousseau est vide"
    ]
}
