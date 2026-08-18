// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipCoreArchitecture.h
 * @brief Core hardware architecture and low-level subsystem inclusions.
 */

#ifndef CTTZipCoreArchitecture_h
#define CTTZipCoreArchitecture_h

#include "CTTZipSysAlloc.h"
#include "CTTZipCRC32Neon.h"
#include "CTTZipSpawnPipelines.h"
#include "CTTZipCacheTopology.h"
#include "CTTZipFilterPipeline.h"
#include "CTTZipSparseSlicing.h"
#include "CTTZipPrefetchPipeline.h"
#include "CTTZipVLMeta.h"
#include "CTTZipTensorSlicing.h"

#endif // CTTZipCoreArchitecture_h
