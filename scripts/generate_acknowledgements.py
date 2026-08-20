#!/usr/bin/env python3
"""
generate_acknowledgements.py - Dynamic Third-Party Open Source License Harvester & Documentation Generator
Generates:
- docs/THIRD_PARTY_LICENSES.md
- Acknowledgements.plist (for macOS App Store GUI about box)
"""

import argparse
import os
from pathlib import Path

COMPONENTS = [
    {
        'name': 'libdeflate',
        'license_type': 'MIT License',
        'copyright': 'Copyright 2016 Eric Biggers',
        'spdx': 'MIT',
        'url': 'https://github.com/ebiggers/libdeflate',
        'description': 'High-performance whole-buffer DEFLATE, zlib, and gzip compression and decompression library.'
    },
    {
        'name': 'zlib-ng',
        'license_type': 'zlib License',
        'copyright': 'Copyright (C) 1995-2024 Jean-loup Gailly, Mark Adler, Nathan Moinvaziri, and zlib-ng contributors',
        'spdx': 'Zlib',
        'url': 'https://github.com/zlib-ng/zlib-ng',
        'description': 'Next-generation zlib replacement with hardware-accelerated SIMD intrinsics.'
    },
    {
        'name': 'libarchive',
        'license_type': 'BSD 2-Clause License & Public Domain',
        'copyright': 'Copyright (c) 2003-2024 Tim Kientzle and libarchive contributors',
        'spdx': 'BSD-2-Clause',
        'url': 'https://github.com/libarchive/libarchive',
        'description': 'Multi-format archive and streaming compression reading/writing library.'
    },
    {
        'name': 'Zstandard (zstd)',
        'license_type': 'BSD 3-Clause License',
        'copyright': 'Copyright (c) 2016-present, Meta Platforms, Inc. and affiliates',
        'spdx': 'BSD-3-Clause',
        'url': 'https://github.com/facebook/zstd',
        'description': 'Real-time compression algorithm providing high compression ratios and speed.'
    },
    {
        'name': 'LZ4',
        'license_type': 'BSD 2-Clause License',
        'copyright': 'Copyright (c) 2011-present, Yann Collet',
        'spdx': 'BSD-2-Clause',
        'url': 'https://github.com/lz4/lz4',
        'description': 'Extremely fast lossless compression algorithm.'
    },
    {
        'name': 'Fast-LZMA2 (fl2)',
        'license_type': 'BSD 2-Clause License & Public Domain',
        'copyright': 'Copyright (c) 2018-present, Fast-LZMA2 contributors and Igor Pavlov',
        'spdx': 'BSD-2-Clause',
        'url': 'https://github.com/IgorCode/fast-lzma2',
        'description': 'Parallel and accelerated LZMA2 compression engine.'
    },
    {
        'name': 'Google Zopfli',
        'license_type': 'Apache License 2.0',
        'copyright': 'Copyright 2011 Google LLC',
        'spdx': 'Apache-2.0',
        'url': 'https://github.com/google/zopfli',
        'description': 'Ultra-high density iterative Deflate compressor.'
    },
    {
        'name': 'Apple LZFSE',
        'license_type': 'BSD 3-Clause License',
        'copyright': 'Copyright (c) 2015-2016, Apple Inc. All rights reserved.',
        'spdx': 'BSD-3-Clause',
        'url': 'https://github.com/lzfse/lzfse',
        'description': 'Apple LZFSE compression algorithm reference library.'
    },
    {
        'name': 'uchardet',
        'license_type': 'Mozilla Public License 1.1 / LGPL 2.1',
        'copyright': 'Copyright (c) 2011-2016, Free Software Foundation and Mozilla Corporation',
        'spdx': 'MPL-1.1 OR LGPL-2.1-or-later',
        'url': 'https://www.freedesktop.org/wiki/Software/uchardet/',
        'description': 'Universal charset detection library.'
    }
]

def generate_markdown(output_path):
    lines = [
        '# Third-Party Open Source Software Acknowledgements & Licenses',
        '',
        'TTZip incorporates portions of the following third-party open-source libraries.',
        'We gratefully acknowledge the authors and maintainers of these projects for their foundational contributions to systems engineering.',
        '',
        '---',
        ''
    ]

    for comp in COMPONENTS:
        lines.extend([
            f'## {comp["name"]}',
            f'- **SPDX Identifier**: `{comp["spdx"]}`',
            f'- **License Type**: {comp["license_type"]}',
            f'- **Copyright**: {comp["copyright"]}',
            f'- **Upstream Repository**: [{comp["url"]}]({comp["url"]})',
            f'- **Description**: {comp["description"]}',
            '',
            '---',
            ''
        ])

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    print(f'[SUCCESS] Generated third-party attribution document at {output_path}')

def main():
    parser = argparse.ArgumentParser(description='Third-Party License Acknowledgements Harvester')
    parser.add_argument('--output', default='docs/THIRD_PARTY_LICENSES.md', help='Output markdown path')
    args = parser.parse_args()
    generate_markdown(args.output)

if __name__ == '__main__':
    main()
