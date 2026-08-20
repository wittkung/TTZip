/*
 * CTTZipCorpusGen.h - High-Performance In-Memory Deterministic Benchmark Corpus Generator
 * Faithfully reproducing zlib-ng test_data_p.h algorithms with caller-allocated zero-heap buffers.
 */

#ifndef CTTZIP_CORPUS_GEN_H
#define CTTZIP_CORPUS_GEN_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    TTZIP_CORPUS_TEXT = 0,
    TTZIP_CORPUS_SHORT_MATCH,
    TTZIP_CORPUS_DNA,
    TTZIP_CORPUS_RANDOM,
    TTZIP_CORPUS_LITERALS,
    TTZIP_CORPUS_MIXED,
    TTZIP_CORPUS_REALISTIC_RGB,
    TTZIP_CORPUS_STRIPED_RGB,
    TTZIP_CORPUS_COUNT
} ttzip_corpus_type_t;

/**
 * Generate deterministic corpus directly into caller-allocated memory.
 * Zero internal heap allocations (0 malloc / 0 free).
 */
void ttzip_generate_corpus(ttzip_corpus_type_t type, void *dest_buffer, size_t size);

/**
 * Return human-readable corpus identifier string.
 */
const char *ttzip_corpus_type_name(ttzip_corpus_type_t type);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_CORPUS_GEN_H */
