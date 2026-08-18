cmake_minimum_required(VERSION 3.20)
project(TTZip LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 1. 跨平台编译选项与安全标志
if(MSVC)
    add_compile_options(
        /W4
        /O2
        /utf-8
        /MD
        /guard:cf
        /D_CRT_SECURE_NO_WARNINGS
        /D_CRT_NONSTDC_NO_DEPRECATE
    )
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "AMD64|x86_64")
        add_compile_options(/arch:AVX2)
    endif()
else()
    add_compile_options(
        -Wall
        -Wextra
        -O3
        -fvisibility=hidden
    )
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
        add_compile_options(-march=armv8.2-a+crypto)
    endif()
endif()

# 2. 第三方子模块与外部依赖 (zlib-ng 现代化流式 Deflate 加速)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/Vendor/zlib-ng/CMakeLists.txt")
    set(ZLIB_COMPAT ON CACHE BOOL "Enable zlib compatibility mode" FORCE)
    set(ZLIB_ENABLE_TESTS OFF CACHE BOOL "Disable zlib-ng tests" FORCE)
    set(DYNAMIC_CPU_DISPATCH ON CACHE BOOL "Enable dynamic CPU dispatch (AVX2/AVX-512/NEON)" FORCE)
    set(WITH_AVX512 ON CACHE BOOL "Enable AVX-512 acceleration" FORCE)
    set(WITH_AVX512VNNI ON CACHE BOOL "Enable AVX-512 VNNI acceleration" FORCE)
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static library" FORCE)
    set(INSTALL_UTILS OFF CACHE BOOL "Disable building utils" FORCE)
    set(ZLIB_NG_ENABLE_TESTS OFF CACHE BOOL "Disable tests" FORCE)
    
    add_subdirectory(Vendor/zlib-ng EXCLUDE_FROM_ALL)
endif()

# 3. 头文件全局搜索路径
set(TTZIP_INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/include
    ${CMAKE_CURRENT_SOURCE_DIR}/Vendor/include
    ${CMAKE_CURRENT_SOURCE_DIR}/Vendor/include/uchardet
)

# 导出 zlib-ng include 目录
if(TARGET zlibstatic)
    list(APPEND TTZIP_INCLUDE_DIRS
        $<TARGET_PROPERTY:zlibstatic,INCLUDE_DIRECTORIES>
        ${CMAKE_CURRENT_SOURCE_DIR}/Vendor/zlib-ng
        ${CMAKE_CURRENT_BINARY_DIR}/Vendor/zlib-ng
    )
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/Vendor/zlib-ng")
    list(APPEND TTZIP_INCLUDE_DIRS
        ${CMAKE_CURRENT_SOURCE_DIR}/Vendor/zlib-ng
        ${CMAKE_CURRENT_BINARY_DIR}/Vendor/zlib-ng
    )
endif()

# 4. 收集 CTTZipBridge 核心源码
set(CTTZIP_CORE_SOURCES
    Sources/CTTZipBridge/CTTZipBridge.c
    Sources/CTTZipBridge/CTTZipCommon.c
    Sources/CTTZipBridge/CTTZipStreamCoder.c
    Sources/CTTZipBridge/CTTZipPlatformTimer.c
    Sources/CTTZipBridge/CTTZipDiagnostics.c
    Sources/CTTZipBridge/CTTZipCoreArchitecture.c
    Sources/CTTZipBridge/CTTZipSysAlloc.c
    Sources/CTTZipBridge/CTTZipUtils.c
    Sources/CTTZipBridge/CTTZipParser.c
    Sources/CTTZipBridge/CTTZipSliceProfiler.c
    Sources/CTTZipBridge/CTTZipIO.c
    Sources/CTTZipBridge/CTTZipBridge_ZipChunkedStream.c
    Sources/CTTZipBridge/CTTZipAdler32Neon.c
    Sources/CTTZipBridge/CTTZipSuperChunk.c
    Sources/CTTZipBridge/CTTZipHeuristicTuner.c
    Sources/CTTZipBridge/ttzip_platform_detect.c
    Sources/CTTZipBridge/ttzip_lzma2_fast_encoder.c
    Sources/CTTZipBridge/ttzip_lzma2_branchless_rc.c
    Sources/CTTZipBridge/ttzip_7z_header_parser.c
    Sources/CTTZipBridge/ttzip_7z_header_writer.c
    Sources/CTTZipBridge/ttzip_tar_native.c
    Sources/CTTZipBridge/ttzip_native_archive.c
    Sources/CTTZipBridge/ttzip_crc64.c
    Sources/CTTZipBridge/ttzip_huffman_inplace.c
)

# 架构硬件加速分支
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64" AND (APPLE OR MSVC))
    list(APPEND CTTZIP_CORE_SOURCES
        Sources/CTTZipBridge/CTTZipCRC32Neon.c
        Sources/CTTZipBridge/ttzip_bcj_arm64_neon.c
        Sources/CTTZipBridge/ttzip_7z_crypto_neon.c
        Sources/CTTZipBridge/ttzip_7z_kdf_arm64.c
        Sources/CTTZipBridge/ttzip_lzma_hc4_neon.c
    )
endif()

# 平台专有源码分支 (macOS APFS / Linux / Windows)
if(APPLE)
    list(APPEND CTTZIP_CORE_SOURCES
        Sources/CTTZipBridge/CTTZipBridge_APFS.c
        Sources/CTTZipBridge/CTTZipBridge_LZFSE.c
    )
endif()

# 5. 构建目标：CTTZipBridge 静态库
add_library(CTTZipBridge STATIC ${CTTZIP_CORE_SOURCES})
target_include_directories(CTTZipBridge PUBLIC ${TTZIP_INCLUDE_DIRS})
target_compile_definitions(CTTZipBridge PUBLIC TTZIP_BUILD_STATIC)

# 6. 链接第三方与系统库
if(TARGET zlibstatic)
    target_link_libraries(CTTZipBridge PUBLIC zlibstatic)
elseif(MSVC)
    target_link_libraries(CTTZipBridge PUBLIC zlibstatic)
endif()

# Windows 平台系统链接库
if(WIN32)
    target_link_libraries(CTTZipBridge PRIVATE
        Bcrypt
        Synchronization
        Shlwapi
    )
endif()
