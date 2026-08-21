// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Path pattern filter engine, glob matcher, and zero-allocation metadata detectors.

use globset::{GlobBuilder, GlobSet, GlobSetBuilder};

/// Precompiled GlobSet engine evaluating include/exclude rules with Aho-Corasick DFA speed.
#[derive(Debug, Clone)]
pub struct PathPatternFilter {
    include_set: Option<GlobSet>,
    exclude_set: Option<GlobSet>,
    raw_includes: Vec<String>,
    raw_excludes: Vec<String>,
    pub exclude_vcs: bool,
    pub no_mac_metadata: bool,
}

impl PathPatternFilter {
    /// Compiles a new PathPatternFilter from include and exclude pattern slices.
    pub fn new(
        include_patterns: &[&str],
        exclude_patterns: &[&str],
        exclude_vcs: bool,
        no_mac_metadata: bool,
    ) -> Result<Self, String> {
        let include_set = if !include_patterns.is_empty() {
            let mut builder = GlobSetBuilder::new();
            for &pat in include_patterns {
                add_glob_variants(&mut builder, pat)?;
            }
            Some(builder.build().map_err(|e| e.to_string())?)
        } else {
            None
        };

        let exclude_set = if !exclude_patterns.is_empty() {
            let mut builder = GlobSetBuilder::new();
            for &pat in exclude_patterns {
                add_glob_variants(&mut builder, pat)?;
            }
            Some(builder.build().map_err(|e| e.to_string())?)
        } else {
            None
        };

        Ok(Self {
            include_set,
            exclude_set,
            raw_includes: include_patterns.iter().map(|s| s.to_string()).collect(),
            raw_excludes: exclude_patterns.iter().map(|s| s.to_string()).collect(),
            exclude_vcs,
            no_mac_metadata,
        })
    }

    /// Evaluates whether the given path should be included.
    #[inline]
    pub fn should_include(&self, path: &str) -> bool {
        if self.exclude_vcs && is_vcs_metadata(path) {
            return false;
        }
        if self.no_mac_metadata && is_mac_junk_metadata(path) {
            return false;
        }

        let clean_path = path.strip_prefix('/').unwrap_or(path);

        if let Some(ref inc_set) = self.include_set {
            let matched = inc_set.is_match(clean_path) || inc_set.is_match(path)
                || self.raw_includes.iter().any(|p| glob_matches(p, path, true));
            if !matched {
                return false;
            }
            return true;
        }

        if let Some(ref exc_set) = self.exclude_set {
            let matched = exc_set.is_match(clean_path) || exc_set.is_match(path)
                || self.raw_excludes.iter().any(|p| glob_matches(p, path, true));
            if matched {
                return false;
            }
        }

        true
    }

    /// Evaluates whether the given path should be excluded.
    #[inline]
    pub fn should_exclude(&self, path: &str) -> bool {
        !self.should_include(path)
    }
}

/// Helper to add glob pattern variants into a GlobSetBuilder.
fn add_glob_variants(builder: &mut GlobSetBuilder, pattern: &str) -> Result<(), String> {
    let clean_pat = pattern.strip_prefix('/').unwrap_or(pattern);

    let g1 = GlobBuilder::new(clean_pat)
        .literal_separator(clean_pat.contains('/'))
        .build()
        .map_err(|e| e.to_string())?;
    builder.add(g1);

    if !clean_pat.contains('/') {
        let pat_prefix = format!("**/{}", clean_pat);
        if let Ok(g) = GlobBuilder::new(&pat_prefix).build() {
            builder.add(g);
        }
    }
    Ok(())
}

/// Matches a single glob pattern against a target path.
pub fn glob_matches(pattern: &str, path: &str, case_sensitive: bool) -> bool {
    let clean_path = path.strip_prefix('/').unwrap_or(path);
    let clean_pat = pattern.strip_prefix('/').unwrap_or(pattern);

    // 1. Direct glob matching with literal_separator if pattern contains '/'
    let has_slash = clean_pat.contains('/');
    if let Ok(glob) = GlobBuilder::new(clean_pat)
        .case_insensitive(!case_sensitive)
        .literal_separator(has_slash)
        .build()
    {
        let matcher = glob.compile_matcher();
        if matcher.is_match(clean_path) || matcher.is_match(path) {
            return true;
        }
    }

    // 2. Double-star wildcard prefix if pattern does not contain '/'
    if !has_slash {
        let prefixed = format!("**/{}", clean_pat);
        if let Ok(glob) = GlobBuilder::new(&prefixed)
            .case_insensitive(!case_sensitive)
            .build()
        {
            if glob.compile_matcher().is_match(clean_path) {
                return true;
            }
        }

        // Component matching
        for comp in clean_path.split('/') {
            if let Ok(glob) = GlobBuilder::new(clean_pat)
                .case_insensitive(!case_sensitive)
                .build()
            {
                if glob.compile_matcher().is_match(comp) {
                    return true;
                }
            }
        }
    }

    false
}

/// Zero-allocation fast leading path component stripping.
pub fn strip_leading_components(path: &str, count: usize) -> Option<&str> {
    if count == 0 {
        return Some(path);
    }
    if path.is_empty() {
        return None;
    }

    let bytes = path.as_bytes();
    let mut i = 0;
    let len = bytes.len();

    // 1. Skip leading slashes
    while i < len && bytes[i] == b'/' {
        i += 1;
    }

    // 2. Skip leading "./"
    if i < len && bytes[i] == b'.' {
        let next = i + 1;
        if next < len && bytes[next] == b'/' {
            i = next + 1;
            while i < len && bytes[i] == b'/' {
                i += 1;
            }
        }
    }

    let mut stripped_count = 0;
    while stripped_count < count && i < len {
        while i < len && bytes[i] != b'/' {
            i += 1;
        }
        stripped_count += 1;
        while i < len && bytes[i] == b'/' {
            i += 1;
        }
    }

    if stripped_count == count && i < len {
        let rem = &path[i..];
        if rem.is_empty() {
            None
        } else {
            Some(rem)
        }
    } else {
        None
    }
}

/// Checks if path matches VCS metadata directories or control files.
#[inline]
pub fn is_vcs_metadata(path: &str) -> bool {
    for comp in path.split('/') {
        if comp.is_empty() {
            continue;
        }
        match comp {
            ".git" | ".svn" | ".hg" | ".bzr" | "CVS" | "_darcs" | ".hgignore"
            | ".gitignore" | ".gitmodules" | ".gitattributes" | ".gitkeep"
            | ".hgtags" | ".svnignore" | ".bzrignore" => return true,
            _ => {}
        }
    }
    false
}

/// Checks if path matches macOS junk, AppleDouble, or OS metadata files.
#[inline]
pub fn is_mac_junk_metadata(path: &str) -> bool {
    for comp in path.split('/') {
        if comp.is_empty() {
            continue;
        }
        if comp.starts_with("._") {
            return true;
        }
        match comp {
            ".DS_Store" | "__MACOSX" | ".Spotlight-V100" | ".Trashes"
            | ".fseventsd" | ".TemporaryItems" | ".VolumeIcon.icns"
            | "Thumbs.db" | "$RECYCLE.BIN" | "ehthumbs.db" | "Desktop.ini" => return true,
            _ => {}
        }
    }
    false
}
