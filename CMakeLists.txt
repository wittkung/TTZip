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
    ${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/native_deflate
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
    "${CMAKE_CURRENT_SOURCE_DIR}/Sources/CTTZipBridge/native_deflate/*.c"
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
