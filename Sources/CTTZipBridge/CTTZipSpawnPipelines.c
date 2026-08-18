// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipSpawnPipelines.h"

#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <spawn.h>
#include <errno.h>
#include <sys/wait.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#include <sys/qos.h>
#include <pthread/qos.h>
#include <pthread/spawn.h>
#include <crt_externs.h>
static char** get_process_environ(void) {
    return *_NSGetEnviron();
}
#else
extern char** environ;
static char** get_process_environ(void) {
    return environ;
}
#endif

static int get_cached_dev_null_fd(void) {
    static int s_fd = -1;
    if (s_fd < 0) {
        int fd = open("/dev/null", O_RDWR);
        if (fd >= 0) s_fd = fd;
    }
    return s_fd;
}

static void split_input_path(const char* input_dir, char* dir_path, size_t dir_len, char* file_name, size_t file_len) {
    strncpy(dir_path, input_dir, dir_len);
    dir_path[dir_len - 1] = '\0';
    
    char* last_slash = strrchr(dir_path, '/');
    if (last_slash) {
        *last_slash = '\0';
        strncpy(file_name, last_slash + 1, file_len);
    } else {
        strncpy(file_name, input_dir, file_len);
        strncpy(dir_path, ".", dir_len);
    }
    file_name[file_len - 1] = '\0';
    dir_path[dir_len - 1] = '\0';
}

int ttzip_core_posix_spawn_fast(
    const char* bin_path,
    const char* const* argv,
    const char* working_dir
) {
    if (!bin_path || !argv) return -1;
    
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    
    int null_fd = get_cached_dev_null_fd();
    if (null_fd >= 0) {
        posix_spawn_file_actions_adddup2(&actions, null_fd, STDIN_FILENO);
        posix_spawn_file_actions_adddup2(&actions, null_fd, STDOUT_FILENO);
        posix_spawn_file_actions_adddup2(&actions, null_fd, STDERR_FILENO);
    }
    
    if (working_dir && strlen(working_dir) > 0) {
#if defined(__APPLE__)
        posix_spawn_file_actions_addchdir_np(&actions, working_dir);
#endif
    }
    
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
#if defined(__APPLE__)
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    posix_spawnattr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE);
    short flags = POSIX_SPAWN_CLOEXEC_DEFAULT;
    posix_spawnattr_setflags(&attr, flags);
#endif

    pid_t pid;
    int status = posix_spawn(&pid, bin_path, &actions, &attr, (char* const*)argv, get_process_environ());
    
    posix_spawnattr_destroy(&attr);
    posix_spawn_file_actions_destroy(&actions);
    
    if (status != 0) return status;
    
    int wstatus;
    while (waitpid(pid, &wstatus, 0) < 0) {
        if (errno == EINTR) continue;
        return -1;
    }
    return (WIFEXITED(wstatus) && WEXITSTATUS(wstatus) == 0) ? 0 : -1;
}

static int run_tar_compress_pipeline(
    const char* tar_bin,
    const char* filter_bin,
    const char* const filter_argv[],
    const char* input_dir,
    const char* output_path
) {
    char dir_path[PATH_MAX];
    char file_name[NAME_MAX];
    split_input_path(input_dir, dir_path, sizeof(dir_path), file_name, sizeof(file_name));

    int pipefds[2];
    if (pipe(pipefds) != 0) return -1;

    int out_fd = open(output_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out_fd < 0) {
        close(pipefds[0]);
        close(pipefds[1]);
        return -1;
    }

    posix_spawn_file_actions_t tar_actions;
    posix_spawn_file_actions_init(&tar_actions);
    posix_spawn_file_actions_adddup2(&tar_actions, pipefds[1], STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&tar_actions, pipefds[0]);
    posix_spawn_file_actions_addclose(&tar_actions, pipefds[1]);
#if defined(__APPLE__)
    posix_spawn_file_actions_addchdir_np(&tar_actions, dir_path);
#endif

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
#if defined(__APPLE__)
    posix_spawnattr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE);
#endif

    const char* tar_argv[] = { tar_bin, "-cf", "-", file_name, NULL };
    pid_t tar_pid;
    int status1 = posix_spawn(&tar_pid, tar_bin, &tar_actions, &attr, (char* const*)tar_argv, get_process_environ());
    posix_spawn_file_actions_destroy(&tar_actions);

    posix_spawn_file_actions_t filter_actions;
    posix_spawn_file_actions_init(&filter_actions);
    posix_spawn_file_actions_adddup2(&filter_actions, pipefds[0], STDIN_FILENO);
    posix_spawn_file_actions_adddup2(&filter_actions, out_fd, STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&filter_actions, pipefds[0]);
    posix_spawn_file_actions_addclose(&filter_actions, pipefds[1]);
    posix_spawn_file_actions_addclose(&filter_actions, out_fd);

    pid_t filter_pid;
    int status2 = posix_spawn(&filter_pid, filter_bin, &filter_actions, &attr, (char* const*)filter_argv, get_process_environ());
    posix_spawn_file_actions_destroy(&filter_actions);
    posix_spawnattr_destroy(&attr);

    close(pipefds[0]);
    close(pipefds[1]);
    close(out_fd);

    if (status1 != 0 || status2 != 0) return -1;

    int wstatus1, wstatus2;
    waitpid(tar_pid, &wstatus1, 0);
    waitpid(filter_pid, &wstatus2, 0);

    return (WIFEXITED(wstatus2) && WEXITSTATUS(wstatus2) == 0) ? 0 : -1;
}

int ttzip_compress_tar_pbzip2(const char* tar_bin, const char* pbzip2_bin, const char* input_dir, const char* output_path, int level, int cores) {
    if (!tar_bin || !pbzip2_bin || !input_dir || !output_path) return -1;
    char lvl_arg[16], core_arg[16];
    snprintf(lvl_arg, sizeof(lvl_arg), "-%d", level);
    snprintf(core_arg, sizeof(core_arg), "-p%d", cores);
    const char* pb_argv[] = { pbzip2_bin, lvl_arg, core_arg, "-m2000", NULL };
    return run_tar_compress_pipeline(tar_bin, pbzip2_bin, pb_argv, input_dir, output_path);
}

int ttzip_compress_tar_pixz(const char* tar_bin, const char* pixz_bin, const char* input_dir, const char* output_path, int level, int cores) {
    if (!tar_bin || !pixz_bin || !input_dir || !output_path) return -1;
    char lvl_arg[16], core_arg[16];
    snprintf(lvl_arg, sizeof(lvl_arg), "-%d", level);
    snprintf(core_arg, sizeof(core_arg), "%d", cores);
    const char* px_argv[] = { pixz_bin, "-p", core_arg, lvl_arg, NULL };
    return run_tar_compress_pipeline(tar_bin, pixz_bin, px_argv, input_dir, output_path);
}

int ttzip_decompress_tar_pixz(const char* pixz_bin, const char* tar_bin, const char* archive_path, const char* dest_dir, int cores) {
    if (!pixz_bin || !tar_bin || !archive_path || !dest_dir) return -1;
    
    int pipefds[2];
    if (pipe(pipefds) != 0) return -1;
    
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
#if defined(__APPLE__)
    posix_spawnattr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE);
#endif

    posix_spawn_file_actions_t px_actions;
    posix_spawn_file_actions_init(&px_actions);
    posix_spawn_file_actions_adddup2(&px_actions, pipefds[1], STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&px_actions, pipefds[0]);
    posix_spawn_file_actions_addclose(&px_actions, pipefds[1]);
    
    const char* px_argv[] = { pixz_bin, "-d", "-i", archive_path, NULL };
    pid_t px_pid;
    int status1 = posix_spawn(&px_pid, pixz_bin, &px_actions, &attr, (char* const*)px_argv, get_process_environ());
    posix_spawn_file_actions_destroy(&px_actions);
    
    int null_fd = get_cached_dev_null_fd();
    posix_spawn_file_actions_t tar_actions;
    posix_spawn_file_actions_init(&tar_actions);
    posix_spawn_file_actions_adddup2(&tar_actions, pipefds[0], STDIN_FILENO);
    if (null_fd >= 0) {
        posix_spawn_file_actions_adddup2(&tar_actions, null_fd, STDERR_FILENO);
    }
    posix_spawn_file_actions_addclose(&tar_actions, pipefds[0]);
    posix_spawn_file_actions_addclose(&tar_actions, pipefds[1]);
#if defined(__APPLE__)
    posix_spawn_file_actions_addchdir_np(&tar_actions, dest_dir);
#endif
    
    const char* tar_argv[] = { tar_bin, "-xf", "-", NULL };
    pid_t tar_pid;
    int status2 = posix_spawn(&tar_pid, tar_bin, &tar_actions, &attr, (char* const*)tar_argv, get_process_environ());
    posix_spawn_file_actions_destroy(&tar_actions);
    posix_spawnattr_destroy(&attr);
    
    close(pipefds[0]);
    close(pipefds[1]);
    
    if (status1 != 0 || status2 != 0) return -1;
    
    int wstatus1, wstatus2;
    waitpid(px_pid, &wstatus1, 0);
    waitpid(tar_pid, &wstatus2, 0);
    
    return (WIFEXITED(wstatus2) && WEXITSTATUS(wstatus2) == 0) ? 0 : -1;
}

int ttzip_compress_tar_plzip(const char* tar_bin, const char* plzip_bin, const char* input_dir, const char* output_path, int level, int cores) {
    if (!tar_bin || !plzip_bin || !input_dir || !output_path) return -1;
    char lvl_arg[16], core_arg[16];
    snprintf(lvl_arg, sizeof(lvl_arg), "-%d", level);
    snprintf(core_arg, sizeof(core_arg), "-n%d", cores);
    const char* pl_argv[] = { plzip_bin, core_arg, "-m256", lvl_arg, NULL };
    return run_tar_compress_pipeline(tar_bin, plzip_bin, pl_argv, input_dir, output_path);
}

int ttzip_compress_plzip(const char* plzip_bin, const char* input_path, const char* output_path, int level, int cores) {
    if (!plzip_bin || !input_path || !output_path) return -1;
    
    int in_fd = open(input_path, O_RDONLY);
    if (in_fd < 0) return -1;
    
    int out_fd = open(output_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out_fd < 0) {
        close(in_fd);
        return -1;
    }
    
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
#if defined(__APPLE__)
    posix_spawnattr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE);
#endif

    char lvl_arg[16], core_arg[16];
    snprintf(lvl_arg, sizeof(lvl_arg), "-%d", level);
    snprintf(core_arg, sizeof(core_arg), "-n%d", cores);
    
    posix_spawn_file_actions_t pl_actions;
    posix_spawn_file_actions_init(&pl_actions);
    posix_spawn_file_actions_adddup2(&pl_actions, in_fd, STDIN_FILENO);
    posix_spawn_file_actions_adddup2(&pl_actions, out_fd, STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&pl_actions, in_fd);
    posix_spawn_file_actions_addclose(&pl_actions, out_fd);
    
    const char* pl_argv[] = { plzip_bin, core_arg, "-B1MiB", "-m256", lvl_arg, NULL };
    pid_t pl_pid;
    int status = posix_spawn(&pl_pid, plzip_bin, &pl_actions, &attr, (char* const*)pl_argv, get_process_environ());
    posix_spawn_file_actions_destroy(&pl_actions);
    posix_spawnattr_destroy(&attr);
    
    close(in_fd);
    close(out_fd);
    
    if (status != 0) return -1;
    
    int wstatus;
    waitpid(pl_pid, &wstatus, 0);
    return (WIFEXITED(wstatus) && WEXITSTATUS(wstatus) == 0) ? 0 : -1;
}

int ttzip_decompress_tar_plzip(const char* plzip_bin, const char* tar_bin, const char* archive_path, const char* dest_dir, int cores) {
    if (!plzip_bin || !tar_bin || !archive_path || !dest_dir) return -1;
    
    int pipefds[2];
    if (pipe(pipefds) != 0) return -1;
    
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
#if defined(__APPLE__)
    posix_spawnattr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE);
#endif

    char core_arg[16];
    snprintf(core_arg, sizeof(core_arg), "-n%d", cores);

    posix_spawn_file_actions_t pl_actions;
    posix_spawn_file_actions_init(&pl_actions);
    posix_spawn_file_actions_adddup2(&pl_actions, pipefds[1], STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&pl_actions, pipefds[0]);
    posix_spawn_file_actions_addclose(&pl_actions, pipefds[1]);
    
    const char* pl_argv[] = { plzip_bin, "-d", core_arg, "-c", archive_path, NULL };
    pid_t pl_pid;
    int status1 = posix_spawn(&pl_pid, plzip_bin, &pl_actions, &attr, (char* const*)pl_argv, get_process_environ());
    posix_spawn_file_actions_destroy(&pl_actions);
    
    int null_fd = get_cached_dev_null_fd();
    posix_spawn_file_actions_t tar_actions;
    posix_spawn_file_actions_init(&tar_actions);
    posix_spawn_file_actions_adddup2(&tar_actions, pipefds[0], STDIN_FILENO);
    if (null_fd >= 0) {
        posix_spawn_file_actions_adddup2(&tar_actions, null_fd, STDERR_FILENO);
    }
    posix_spawn_file_actions_addclose(&tar_actions, pipefds[0]);
    posix_spawn_file_actions_addclose(&tar_actions, pipefds[1]);
#if defined(__APPLE__)
    posix_spawn_file_actions_addchdir_np(&tar_actions, dest_dir);
#endif
    
    const char* tar_argv[] = { tar_bin, "-xf", "-", NULL };
    pid_t tar_pid;
    int status2 = posix_spawn(&tar_pid, tar_bin, &tar_actions, &attr, (char* const*)tar_argv, get_process_environ());
    posix_spawn_file_actions_destroy(&tar_actions);
    posix_spawnattr_destroy(&attr);
    
    close(pipefds[0]);
    close(pipefds[1]);
    
    if (status1 != 0 || status2 != 0) return -1;
    
    int wstatus1, wstatus2;
    waitpid(pl_pid, &wstatus1, 0);
    waitpid(tar_pid, &wstatus2, 0);
    
    if (WIFEXITED(wstatus1) && WEXITSTATUS(wstatus1) == 0) return 0;
    if (WIFSIGNALED(wstatus1) && WTERMSIG(wstatus1) == SIGPIPE) return 0;
    return (WIFEXITED(wstatus2) && WEXITSTATUS(wstatus2) == 0) ? 0 : -1;
}

int ttzip_decompress_plzip(const char* plzip_bin, const char* archive_path, const char* output_path, int cores) {
    if (!plzip_bin || !archive_path || !output_path) return -1;
    
    int out_fd = open(output_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out_fd < 0) return -1;
    
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
#if defined(__APPLE__)
    posix_spawnattr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE);
#endif

    char core_arg[16];
    snprintf(core_arg, sizeof(core_arg), "-n%d", cores);
    
    posix_spawn_file_actions_t pl_actions;
    posix_spawn_file_actions_init(&pl_actions);
    posix_spawn_file_actions_adddup2(&pl_actions, out_fd, STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&pl_actions, out_fd);
    
    const char* pl_argv[] = { plzip_bin, "-d", core_arg, "-c", archive_path, NULL };
    pid_t pl_pid;
    int status = posix_spawn(&pl_pid, plzip_bin, &pl_actions, &attr, (char* const*)pl_argv, get_process_environ());
    posix_spawn_file_actions_destroy(&pl_actions);
    posix_spawnattr_destroy(&attr);
    
    close(out_fd);
    if (status != 0) return -1;
    
    int wstatus;
    waitpid(pl_pid, &wstatus, 0);
    return (WIFEXITED(wstatus) && WEXITSTATUS(wstatus) == 0) ? 0 : -1;
}
