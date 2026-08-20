/*
 * CTTZipCorpusGen.c - Implementation of 8 Standard Benchmark Corpus Generators
 */

#include "include/CTTZipCorpusGen.h"
#include <string.h>

static inline uint32_t lcg_next(uint32_t *state) {
    *state = (*state * 1103515245U + 12345U);
    return *state;
}

static inline uint32_t xorshift32(uint32_t *state) {
    uint32_t x = *state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *state = x;
    return x;
}

static void gen_text(uint8_t *dest, size_t size) {
    static const char alphabet[] = "abcdefghiklmnopqrstuvwy";
    static const size_t alphabet_len = sizeof(alphabet) - 1;
    
    uint32_t rng = 0x7e47da7a;
    char words[128][16];
    size_t word_lens[128];
    
    for (int i = 0; i < 128; i++) {
        uint32_t len = 3 + (lcg_next(&rng) % 8);
        word_lens[i] = len;
        for (uint32_t j = 0; j < len; j++) {
            words[i][j] = alphabet[lcg_next(&rng) % alphabet_len];
        }
        words[i][len] = '\0';
    }
    
    size_t written = 0;
    size_t word_count = 0;
    while (written < size) {
        uint32_t r1 = lcg_next(&rng) & 127;
        uint32_t r2 = lcg_next(&rng) & 127;
        uint32_t idx = r1 & r2;
        
        const char *w = words[idx];
        size_t len = word_lens[idx];
        
        for (size_t j = 0; j < len && written < size; j++) {
            char c = w[j];
            if (j == len - 1 && (lcg_next(&rng) % 6 == 0)) {
                c = alphabet[lcg_next(&rng) % alphabet_len];
            }
            dest[written++] = (uint8_t)c;
        }
        
        if (written >= size) break;
        word_count++;
        if (word_count % 12 == 0) {
            dest[written++] = '.';
            if (written < size) dest[written++] = '\n';
        } else if (lcg_next(&rng) % 16 == 0) {
            dest[written++] = ',';
            if (written < size) dest[written++] = ' ';
        } else {
            dest[written++] = ' ';
        }
    }
}

static void gen_short_match(uint8_t *dest, size_t size) {
    uint32_t rng = 0xc001cafe;
    uint8_t patterns[8][8];
    size_t pattern_lens[8];
    
    for (int i = 0; i < 8; i++) {
        pattern_lens[i] = 3 + (lcg_next(&rng) % 6);
        for (size_t j = 0; j < pattern_lens[i]; j++) {
            patterns[i][j] = (uint8_t)(lcg_next(&rng) >> 24);
        }
    }
    
    size_t written = 0;
    while (written < size) {
        uint32_t r = lcg_next(&rng) & 15;
        if (r == 0) {
            uint8_t b = (uint8_t)(lcg_next(&rng) >> 24);
            size_t count = 6 + (lcg_next(&rng) % 18);
            for (size_t j = 0; j < count && written < size; j++) {
                dest[written++] = b;
            }
        } else if (r <= 2) {
            int slot = lcg_next(&rng) % 8;
            pattern_lens[slot] = 3 + (lcg_next(&rng) % 6);
            for (size_t j = 0; j < pattern_lens[slot]; j++) {
                patterns[slot][j] = (uint8_t)(lcg_next(&rng) >> 24);
            }
        } else if (r == 3) {
            dest[written++] = (uint8_t)(lcg_next(&rng) >> 24);
        } else {
            int slot = lcg_next(&rng) % 8;
            for (size_t j = 0; j < pattern_lens[slot] && written < size; j++) {
                dest[written++] = patterns[slot][j];
            }
        }
    }
}

static void gen_dna(uint8_t *dest, size_t size) {
    static const char bases[4] = {'A', 'C', 'G', 'T'};
    uint32_t rng = 0x01234567;
    for (size_t i = 0; i < size; i++) {
        dest[i] = (uint8_t)bases[(lcg_next(&rng) >> 24) & 3];
    }
}

static void gen_random(uint8_t *dest, size_t size) {
    uint32_t rng = 0xdeadbeef;
    for (size_t i = 0; i < size; i++) {
        dest[i] = (uint8_t)(lcg_next(&rng) >> 24);
    }
}

static void gen_literals(uint8_t *dest, size_t size) {
    uint32_t rng = 0x600dd1ce;
    for (size_t i = 0; i < size; i++) {
        uint32_t r1 = lcg_next(&rng) >> 24;
        if ((lcg_next(&rng) & 3) != 0) {
            uint32_t r2 = lcg_next(&rng) >> 24;
            dest[i] = (uint8_t)(r1 & r2);
        } else {
            dest[i] = (uint8_t)r1;
        }
    }
}

static void gen_mixed(uint8_t *dest, size_t size) {
    uint32_t rng = 0xb1a5b1a5;
    size_t written = 0;
    while (written < size) {
        uint32_t mode = lcg_next(&rng) % 100;
        if (mode < 86) {
            size_t lit_count = 1 + (lcg_next(&rng) % 12);
            for (size_t j = 0; j < lit_count && written < size; j++) {
                dest[written++] = (uint8_t)(lcg_next(&rng) >> 24);
            }
            if (written >= 16 && written < size) {
                size_t match_len = 4 + (lcg_next(&rng) % 14);
                size_t max_dist = written < 4096 ? written : 4096;
                size_t dist = 8 + (lcg_next(&rng) % (max_dist - 7));
                for (size_t j = 0; j < match_len && written < size; j++) {
                    dest[written] = dest[written - dist];
                    written++;
                }
            }
        } else if (mode < 96) {
            uint8_t sym[24];
            for (int k = 0; k < 24; k++) sym[k] = (uint8_t)(lcg_next(&rng) >> 24);
            for (int rep = 0; rep < 4 && written < size; rep++) {
                sym[lcg_next(&rng) % 24] = (uint8_t)(lcg_next(&rng) >> 24);
                for (int k = 0; k < 24 && written < size; k++) {
                    dest[written++] = sym[k];
                }
            }
        } else {
            size_t zeros = 64 + (lcg_next(&rng) % 384);
            for (size_t j = 0; j < zeros && written < size; j++) {
                dest[written++] = 0;
            }
        }
    }
}

static void gen_realistic_rgb(uint8_t *dest, size_t size) {
    uint32_t rng = 0x12345678;
    size_t pixels = size / 3;
    size_t width = 256;
    if (pixels < width) width = pixels > 0 ? pixels : 1;
    
    for (size_t i = 0; i < pixels; i++) {
        size_t x = i % width;
        size_t y = i / width;
        
        int base_r = (int)((x * 255) / width);
        int base_g = (int)((y * 255) / (pixels / width + 1));
        int base_b = (int)(((x + y) * 128) / width);
        
        int n_r = (int)(xorshift32(&rng) & 0x1F) - 15;
        int n_g = (int)(xorshift32(&rng) & 0x1F) - 15;
        int n_b = (int)(xorshift32(&rng) & 0x1F) - 15;
        
        int r = base_r + n_r; if (r < 0) r = 0; if (r > 255) r = 255;
        int g = base_g + n_g; if (g < 0) g = 0; if (g > 255) g = 255;
        int b = base_b + n_b; if (b < 0) b = 0; if (b > 255) b = 255;
        
        dest[i * 3 + 0] = (uint8_t)r;
        dest[i * 3 + 1] = (uint8_t)g;
        dest[i * 3 + 2] = (uint8_t)b;
    }
    for (size_t i = pixels * 3; i < size; i++) {
        dest[i] = 0;
    }
}

static void gen_striped_rgb(uint8_t *dest, size_t size) {
    size_t pixels = size / 3;
    size_t part1 = pixels / 3;
    size_t part2 = (pixels * 2) / 3;
    
    for (size_t i = 0; i < part1; i++) {
        dest[i * 3 + 0] = 255; dest[i * 3 + 1] = 0; dest[i * 3 + 2] = 0;
    }
    for (size_t i = part1; i < part2; i++) {
        dest[i * 3 + 0] = 0; dest[i * 3 + 1] = 255; dest[i * 3 + 2] = 0;
    }
    for (size_t i = part2; i < pixels; i++) {
        dest[i * 3 + 0] = 0; dest[i * 3 + 1] = 0; dest[i * 3 + 2] = 255;
    }
    for (size_t i = pixels * 3; i < size; i++) {
        dest[i] = 0;
    }
}

void ttzip_generate_corpus(ttzip_corpus_type_t type, void *dest_buffer, size_t size) {
    if (!dest_buffer || size == 0) return;
    uint8_t *dest = (uint8_t *)dest_buffer;
    switch (type) {
        case TTZIP_CORPUS_TEXT: gen_text(dest, size); break;
        case TTZIP_CORPUS_SHORT_MATCH: gen_short_match(dest, size); break;
        case TTZIP_CORPUS_DNA: gen_dna(dest, size); break;
        case TTZIP_CORPUS_RANDOM: gen_random(dest, size); break;
        case TTZIP_CORPUS_LITERALS: gen_literals(dest, size); break;
        case TTZIP_CORPUS_MIXED: gen_mixed(dest, size); break;
        case TTZIP_CORPUS_REALISTIC_RGB: gen_realistic_rgb(dest, size); break;
        case TTZIP_CORPUS_STRIPED_RGB: gen_striped_rgb(dest, size); break;
        default: memset(dest, 0, size); break;
    }
}

const char *ttzip_corpus_type_name(ttzip_corpus_type_t type) {
    switch (type) {
        case TTZIP_CORPUS_TEXT: return "text";
        case TTZIP_CORPUS_SHORT_MATCH: return "short_match";
        case TTZIP_CORPUS_DNA: return "dna";
        case TTZIP_CORPUS_RANDOM: return "random";
        case TTZIP_CORPUS_LITERALS: return "literals";
        case TTZIP_CORPUS_MIXED: return "mixed";
        case TTZIP_CORPUS_REALISTIC_RGB: return "realistic_rgb";
        case TTZIP_CORPUS_STRIPED_RGB: return "striped_rgb";
        default: return "unknown";
    }
}
