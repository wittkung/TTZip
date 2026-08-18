// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Spanish localization string catalog (`es`).
public enum LocaleCatalogEs {
    public static let strings: [String: String] = [
        "common.cancel": "Cancelar",
        "common.ok": "Aceptar",
        "common.done": "Hecho",
        "common.save": "Guardar",
        "common.close": "Cerrar",
        "common.retry": "Reintentar",
        "common.success": "Éxito",
        "common.failed": "Error",
        "common.loading": "Cargando...",
        "common.warning": "Advertencia",
        "common.error": "Error",
        "common.processing": "Procesando...",
        
        "archive.compress": "Comprimir",
        "archive.extract": "Extraer",
        "archive.compressing": "Comprimiendo...",
        "archive.extracting": "Extrayendo...",
        "archive.compress_success": "Archivo creado con éxito",
        "archive.extract_success": "Archivo extraído con éxito",
        "archive.compress_failed": "Fallo en la compresión",
        "archive.extract_failed": "Fallo en la extracción",
        "archive.password_required": "Se requiere contraseña",
        "archive.incorrect_password": "Contraseña incorrecta",
        "archive.corrupt_data": "Los datos del archivo están corruptos",
        "archive.unsupported_format": "Formato de archivo no compatible",
        "archive.format": "Formato",
        "archive.compression_level": "Nivel de compresión",
        "archive.split_volume": "Dividir en volúmenes",
        "archive.encryption": "Cifrado",
        
        "cli.usage_header": "TTZip CLI — Motor nativo de archivado de alto rendimiento",
        "cli.subcommands": "Comandos",
        "cli.global_options": "Opciones globales",
        "cli.error_missing_arg": "Falta el argumento requerido: %@",
        "cli.error_file_not_found": "Archivo no encontrado: %@",
        "cli.error_invalid_format": "Formato de archivo no válido: %@",
        "cli.dry_run_prefix": "[SIMULACIÓN] Acción a ejecutar: %@",
        "cli.bench_running": "Ejecutando benchmark para formato %@ (Pase %d/%d)...",
        "cli.test_summary": "Resumen de pruebas: %d superadas, %d fallidas en %.2fs",
        
        "benchmark.throughput": "Rendimiento",
        "benchmark.compression_ratio": "Tasa",
        "benchmark.duration": "Duración",
        "benchmark.memory_usage": "Memoria",
        "benchmark.peak_throughput": "Rendimiento máximo",
        "benchmark.speedup": "Aceleración",
        
        "error.file_not_found": "El archivo o directorio especificado no existe.",
        "error.permission_denied": "Permiso denegado para acceder a la ruta.",
        "error.disk_full": "El disco de destino está lleno.",
        "error.zip_slip_detected": "Ataque de salto de directorio Zip Slip detectado y bloqueado.",
        "error.corrupted_header": "Error en la comprobación Magic del encabezado o archivo corrupto.",
        "error.crc_mismatch": "Discrepancia en la suma de comprobación CRC32 de los datos extraídos.",
        "error.out_of_memory": "Memoria insuficiente para la asignación del búfer.",
        "error.operation_cancelled": "Operación cancelada por el usuario.",
        
        "settings.title": "Preferencias",
        "settings.general": "General",
        "settings.language": "Idioma",
        "settings.byte_units": "Unidades de bytes",
        "settings.license_status": "Estado de la licencia",
        "settings.hardware_topology": "Topología de hardware",
        
        "vault.title": "Bóveda de contraseñas",
        "vault.unlock_prompt": "Introduzca la contraseña para desbloquear la bóveda",
        "vault.add_password": "Añadir contraseña",
        "vault.empty_vault": "La bóveda está vacía"
    ]
}
