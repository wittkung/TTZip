#ifndef TTZIP_WINDOWS_H
#define TTZIP_WINDOWS_H

#if defined(_WIN32) || defined(__WIN32__) || defined(WIN32)

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>
#include <io.h>
#include <direct.h>
#include <wchar.h>

#ifdef __cplusplus
extern "C" {
#endif

// Windows 超长路径最大限制与前缀
#define TTZIP_WIN_MAX_PATH 32768
#define TTZIP_WIN_LONG_PATH_PREFIX L"\\\\?\\"
#define TTZIP_WIN_UNC_PREFIX L"\\\\?\\UNC\\"

// 宽字符与 UTF-8 互转便捷辅助
static inline wchar_t* ttzip_utf8_to_utf16(const char* utf8_str) {
    if (!utf8_str) return NULL;
    int len = MultiByteToWideChar(CP_UTF8, 0, utf8_str, -1, NULL, 0);
    if (len <= 0) return NULL;
    wchar_t* wstr = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (!wstr) return NULL;
    MultiByteToWideChar(CP_UTF8, 0, utf8_str, -1, wstr, len);
    return wstr;
}

static inline char* ttzip_utf16_to_utf8(const wchar_t* utf16_str) {
    if (!utf16_str) return NULL;
    int len = WideCharToMultiByte(CP_UTF8, 0, utf16_str, -1, NULL, 0, NULL, NULL);
    if (len <= 0) return NULL;
    char* str = (char*)malloc(len);
    if (!str) return NULL;
    WideCharToMultiByte(CP_UTF8, 0, utf16_str, -1, str, len, NULL, NULL);
    return str;
}

#ifdef __cplusplus
}
#endif

#endif /* _WIN32 */

#endif /* TTZIP_WINDOWS_H */
