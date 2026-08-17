#include "include/CTTZipCoreArchitecture.h"
#include "include/CTTZipSysAlloc.h"
#include "include/CTTZipCRC32Neon.h"
#include "include/CTTZipSpawnPipelines.h"

// All core architecture sub-modules (APFS allocation, ARM NEON CRC32, POSIX spawn pipelines)
// have been modularized into dedicated single-responsibility files:
// - CTTZipSysAlloc.c
// - CTTZipCRC32Neon.c
// - CTTZipSpawnPipelines.c
