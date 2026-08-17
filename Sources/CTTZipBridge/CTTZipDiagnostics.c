#include "include/CTTZipDiagnostics.h"
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>

static _Thread_local ttzip_diag_context_t thread_diag_ctx;

void ttzip_diag_enter(const char* layer, const char* operation, const char* path, int64_t size) {
    thread_diag_ctx.layer = layer;
    thread_diag_ctx.operation = operation;
    thread_diag_ctx.file_path = path;
    thread_diag_ctx.file_size = size;
    thread_diag_ctx.error_code = 0;
    thread_diag_ctx.detail[0] = '\0';
}

void ttzip_diag_set_error(int code, const char* detail) {
    thread_diag_ctx.error_code = code;
    if (detail) {
        snprintf(thread_diag_ctx.detail, sizeof(thread_diag_ctx.detail), "%s", detail);
    } else {
        thread_diag_ctx.detail[0] = '\0';
    }
}

void ttzip_diag_leave(void) {
    thread_diag_ctx.layer = NULL;
    thread_diag_ctx.operation = NULL;
    thread_diag_ctx.file_path = NULL;
    thread_diag_ctx.file_size = 0;
    thread_diag_ctx.error_code = 0;
    thread_diag_ctx.detail[0] = '\0';
}

const ttzip_diag_context_t* ttzip_diag_current(void) {
    return &thread_diag_ctx;
}

// Minimal async-signal-safe integer to string conversion
static void reverse_string(char* str, int len) {
    int start = 0;
    int end = len - 1;
    while (start < end) {
        char temp = str[start];
        str[start] = str[end];
        str[end] = temp;
        start++;
        end--;
    }
}

static int int64_to_string(int64_t num, char* str) {
    int i = 0;
    bool is_negative = false;
    
    if (num == 0) {
        str[i++] = '0';
        str[i] = '\0';
        return i;
    }
    
    if (num < 0) {
        is_negative = true;
        num = -num;
    }
    
    while (num != 0) {
        int rem = num % 10;
        str[i++] = (rem > 9) ? (rem - 10) + 'a' : rem + '0';
        num = num / 10;
    }
    
    if (is_negative) {
        str[i++] = '-';
    }
    
    str[i] = '\0';
    reverse_string(str, i);
    return i;
}

static size_t custom_strlen(const char* str) {
    size_t len = 0;
    while (str && str[len]) {
        len++;
    }
    return len;
}

static void ttzip_signal_handler(int sig) {
    // Write out pre-formatted text segments to avoid complex formatting
    const char* sig_name = (sig == SIGBUS) ? "SIGBUS" : ((sig == SIGSEGV) ? "SIGSEGV" : "UNKNOWN");
    
    const char* p1 = "\n🔴 [TTZip CRASH] Signal=";
    const char* p2 = " | Layer=";
    const char* p3 = " | Op=";
    const char* p4 = " | File=";
    const char* p5 = " (";
    const char* p6 = " bytes)\n";
    const char* unknown = "unknown";
    
    write(2, p1, custom_strlen(p1));
    write(2, sig_name, custom_strlen(sig_name));
    
    const ttzip_diag_context_t* ctx = ttzip_diag_current();
    
    write(2, p2, custom_strlen(p2));
    const char* layer = (ctx && ctx->layer) ? ctx->layer : unknown;
    write(2, layer, custom_strlen(layer));
    
    write(2, p3, custom_strlen(p3));
    const char* op = (ctx && ctx->operation) ? ctx->operation : unknown;
    write(2, op, custom_strlen(op));
    
    write(2, p4, custom_strlen(p4));
    const char* file = (ctx && ctx->file_path) ? ctx->file_path : unknown;
    write(2, file, custom_strlen(file));
    
    write(2, p5, custom_strlen(p5));
    
    char num_buf[32];
    int64_t size = (ctx) ? ctx->file_size : 0;
    int len = int64_to_string(size, num_buf);
    write(2, num_buf, len);
    
    write(2, p6, custom_strlen(p6));
    
    _exit(128 + sig);
}

void ttzip_install_signal_handlers(void) {
    struct sigaction sa;
    sa.sa_handler = ttzip_signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    
    // 忽略 SIGPIPE，将管道中断转化为同步 EPIPE 错误以便优雅退出状态码 141
    signal(SIGPIPE, SIG_IGN);
}

int ttzip_err_combine(int err1, int err2) {
    return (err1 < err2) ? err1 : err2;
}
