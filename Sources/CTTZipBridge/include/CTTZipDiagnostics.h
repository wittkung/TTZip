#ifndef CTTZIPDIAGNOSTICS_H
#define CTTZIPDIAGNOSTICS_H

#include <stdint.h>
#include <stdbool.h>

typedef struct {
    const char* layer;        // e.g. "C:7zDecoder", "C:LZMA2Enc"
    const char* operation;    // e.g. "extract", "compress"
    const char* file_path;    // current file being operated on
    int64_t     file_size;
    int         error_code;
    char        detail[256];
} ttzip_diag_context_t;

void ttzip_diag_enter(const char* layer, const char* operation, const char* path, int64_t size);
void ttzip_diag_set_error(int code, const char* detail);
void ttzip_diag_leave(void);
const ttzip_diag_context_t* ttzip_diag_current(void);

void ttzip_install_signal_handlers(void);

#endif
