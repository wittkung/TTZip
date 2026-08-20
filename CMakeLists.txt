cmake_minimum_required(VERSION 3.20)
project(TTZip VERSION 1.0.0 LANGUAGES C CXX)

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
        -Wno-unused-parameter
        -Wno-unused-function
        -O3
    )
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
    ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge
    ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/fast-lzma2
    ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/zopfli
    ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/lzfse
    ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/snappy
    ${CMAKE_CURRENT_SOURCE_DIR}/Vendor/include
    ${CMAKE_CURRENT_SOURCE_DIR}/Vendor/include/uchardet
)

# 4. 收集 CTTZipBridge 核心源码
file(GLOB CTTZIP_CORE_SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/*.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/fast-lzma2/*.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/zopfli/*.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/lzfse/*.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/snappy/*.cc"
)

# 5. 构建静态库与目标
add_library(ttzip STATIC ${CTTZIP_CORE_SOURCES})
target_include_directories(ttzip PUBLIC 
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/include>
    $<INSTALL_INTERFACE:include/ttzip>
)
target_include_directories(ttzip PRIVATE
    ${TTZIP_INCLUDE_DIRS}
)
target_compile_definitions(ttzip PUBLIC TTZIP_BUILD_STATIC)

# 平台专有系统链接库与外部依赖
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/Vendor/libTTZipVendor.a")
    target_link_libraries(ttzip PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/Vendor/libTTZipVendor.a")
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/Vendor/lib")
    file(GLOB VENDOR_LIBS "${CMAKE_CURRENT_SOURCE_DIR}/Vendor/lib/*.a")
    target_link_libraries(ttzip PUBLIC ${VENDOR_LIBS})
endif()

if(WIN32)
    target_link_libraries(ttzip PRIVATE
        Bcrypt
        Synchronization
        Shlwapi
    )
elseif(APPLE)
    find_library(COMPRESSION_LIB Compression)
    if(COMPRESSION_LIB)
        target_link_libraries(ttzip PRIVATE ${COMPRESSION_LIB})
    endif()
    find_library(SECURITY_LIB Security)
    if(SECURITY_LIB)
        target_link_libraries(ttzip PUBLIC ${SECURITY_LIB})
    endif()
    target_link_libraries(ttzip PRIVATE bz2 z)
elseif(UNIX)
    target_link_libraries(ttzip PRIVATE pthread m dl)
    find_package(ZLIB QUIET)
    if(ZLIB_FOUND)
        target_link_libraries(ttzip PRIVATE ZLIB::ZLIB)
    endif()
    find_package(BZip2 QUIET)
    if(BZIP2_FOUND)
        target_link_libraries(ttzip PRIVATE BZip2::BZip2)
    endif()
endif()

# 6. 构建独立纯 C 命令行工具 ttzip-cli
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/cli/main.c")
    add_executable(ttzip-cli cli/main.c)
    target_link_libraries(ttzip-cli PRIVATE ttzip)
    target_include_directories(ttzip-cli PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/include
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge
    )
endif()

# 7. 构建 C SDK 开发者示例 ttzip-quickstart
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/examples/quickstart.c")
    add_executable(ttzip-quickstart examples/quickstart.c)
    target_link_libraries(ttzip-quickstart PRIVATE ttzip)
    target_include_directories(ttzip-quickstart PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/include
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge
    )
endif()

# 8. 安装与导出配置
include(GNUInstallDirs)
install(TARGETS ttzip ttzip-cli
    EXPORT TTZipTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)
install(DIRECTORY Sources/CTTZipBridge/include/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/ttzip
)
install(EXPORT TTZipTargets
    FILE TTZipTargets.cmake
    NAMESPACE TTZip::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/TTZip
)

# ==============================================================================
# 9. 自动化 C11 测试套件与 CTest 接入 (Zero-Dependency Pure C11 Harness)
# ==============================================================================
option(BUILD_TESTING "Build TTZip automated C test suite" ON)
option(ENABLE_SANITIZERS "Enable AddressSanitizer and UndefinedBehaviorSanitizer" OFF)

if(ENABLE_SANITIZERS)
    if(MSVC)
        target_compile_options(ttzip PUBLIC /fsanitize=address)
    else()
        target_compile_options(ttzip PUBLIC 
            -fsanitize=address,undefined 
            -fno-omit-frame-pointer
            -fno-sanitize-recover=all
        )
        target_link_options(ttzip PUBLIC 
            -fsanitize=address,undefined
        )
    endif()
endif()

if(BUILD_TESTING AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/c/test_main.c")
    include(CTest)

    set(TTZIP_TEST_SOURCES
        tests/c/test_main.c
        tests/c/test_crc_neon.c
        tests/c/test_magic_sniff.c
        tests/c/test_strnatcmp.c
        tests/c/test_deflate_zopfli.c
        tests/c/test_7z_lzma2.c
        tests/c/test_tar_container.c
        tests/c/test_security_zipslip.c
        tests/c/test_concurrency_threadpool.c
        tests/c/test_blosc_engine.c
        tests/c/test_huffman_inplace.c
        tests/c/test_snappy_engine.c
        tests/c/test_dmg_lzfse.c
        tests/c/test_archive_tree.c
        tests/c/test_matchfinder_neon.c
        tests/c/test_adler_crc64.c
        tests/c/test_entropy_evaluator.c
        tests/c/test_matchfinder_advanced.c
        tests/c/test_blosc_slicing.c
        tests/c/test_crypto_lz4_snappy.c
        tests/c/test_deflate_stream_coder.c
        tests/c/test_platform_isa.c
        tests/c/test_cve_regressions.c
        tests/c/test_compat_archives.c
        tests/c/test_fs_metadata.c
        tests/c/test_cpu_topology.c
    )

    add_executable(ttzip_c_test_runner ${TTZIP_TEST_SOURCES})
    target_link_libraries(ttzip_c_test_runner PRIVATE ttzip)
    target_include_directories(ttzip_c_test_runner PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/c
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/include
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/lzfse
    )

    if(ENABLE_SANITIZERS)
        if(MSVC)
            target_compile_options(ttzip_c_test_runner PRIVATE /fsanitize=address)
        else()
            target_compile_options(ttzip_c_test_runner PRIVATE 
                -fsanitize=address,undefined 
                -fno-omit-frame-pointer
                -fno-sanitize-recover=all
            )
            target_link_options(ttzip_c_test_runner PRIVATE 
                -fsanitize=address,undefined
            )
        endif()
    endif()

    set(TEST_SUITES
        crc_neon
        magic_sniff
        strnatcmp
        deflate_zopfli
        7z_lzma2
        tar_container
        security_zipslip
        concurrency_threadpool
        blosc_engine
        huffman_inplace
        snappy_engine
        dmg_lzfse
        archive_tree
        matchfinder_neon
        adler_crc64
        entropy_evaluator
        matchfinder_advanced
        blosc_slicing
        crypto_lz4_snappy
        deflate_stream_coder
        platform_isa
        cve_regressions
        compat_archives
        fs_metadata
        cpu_topology
    )

    foreach(suite IN LISTS TEST_SUITES)
        add_test(NAME "c_test_${suite}" COMMAND ttzip_c_test_runner "${suite}")
        set_tests_properties("c_test_${suite}" PROPERTIES
            TIMEOUT 10
            LABELS "microkernel;c11"
        )
    endforeach()

    add_test(NAME "c_test_all" COMMAND ttzip_c_test_runner "all")
    set_tests_properties("c_test_all" PROPERTIES
        TIMEOUT 30
        LABELS "full;c11"
    )

    # 9.5. TTZip LibFuzzer Harness Target
    add_executable(ttzip_fuzzer tests/fuzz/fuzz_extract_engine.c)
    target_link_libraries(ttzip_fuzzer PRIVATE ttzip)
    target_include_directories(ttzip_fuzzer PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/include
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge
    )

    # 10. TTZip C11 Native Benchmark Runner
    set(TTZIP_BENCH_SOURCES
        tests/c/bench_main.c
        tests/c/bench_codecs.c
        tests/c/bench_checksums.c
        tests/c/bench_formats.c
        tests/c/bench_pareto.c
        tests/c/bench_stress_vfs.c
    )
    add_executable(ttzip_benchmark_runner ${TTZIP_BENCH_SOURCES})
    target_link_libraries(ttzip_benchmark_runner PRIVATE ttzip)
    target_include_directories(ttzip_benchmark_runner PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/c
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/include
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/lzfse
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/fast-lzma2
    )
    if(ENABLE_SANITIZERS AND NOT MSVC)
        target_compile_options(ttzip_benchmark_runner PRIVATE 
            -fsanitize=address,undefined 
            -fno-omit-frame-pointer
            -fno-sanitize-recover=all
        )
        target_link_options(ttzip_benchmark_runner PRIVATE 
            -fsanitize=address,undefined
        )
    endif()

    add_test(NAME "c_bench_all" COMMAND ttzip_benchmark_runner "--all")
    set_tests_properties("c_bench_all" PROPERTIES
        TIMEOUT 60
        LABELS "benchmark;c11"
    )
endif()

