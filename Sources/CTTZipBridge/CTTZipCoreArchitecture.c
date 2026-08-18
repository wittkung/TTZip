// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipCoreArchitecture.h"
#include "include/CTTZipSysAlloc.h"
#include "include/CTTZipCRC32Neon.h"
#include "include/CTTZipSpawnPipelines.h"

// All core architecture sub-modules (APFS allocation, ARM NEON CRC32, POSIX spawn pipelines)
// are modularized into dedicated single-responsibility translation units:
// - CTTZipSysAlloc.c
// - CTTZipCRC32Neon.c
// - CTTZipSpawnPipelines.c
