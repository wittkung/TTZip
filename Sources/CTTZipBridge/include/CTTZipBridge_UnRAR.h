#ifndef CTTZIP_BRIDGE_UNRAR_H
#ifndef CTTZIP_BRIDGE_UNRAR_H
#define CTTZIP_BRIDGE_UNRAR_H

#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_unrar_extract_archive(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
);

int ttzip_unrar_inspect_entry_count(const char* archive_path);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_BRIDGE_UNRAR_H */
#endif
