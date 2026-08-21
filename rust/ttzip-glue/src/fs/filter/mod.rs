// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zero-allocation Archive Filter DSL & GlobSet Path Filter engine.

pub mod expr;
pub mod lexer;
pub mod parser;
pub mod pattern;
pub mod utils;

pub use expr::*;
pub use lexer::*;
pub use parser::*;
pub use pattern::*;
pub use utils::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dsl_lexer_and_parser_ast() {
        let query = "ext:rs,swift AND size:>10MB OR (name:*.log NOT modified:<1d)";
        let expr = DslParser::parse_str(query).expect("Should parse query");
        let desc = expr.dsl_description();
        assert!(desc.contains("AND"));
        assert!(desc.contains("OR"));
    }

    #[test]
    fn test_dsl_zero_allocation_evaluation() {
        let query = "ext:txt AND size:<5000";
        let expr = DslParser::parse_str(query).expect("Valid query");

        let t1 = FilterTarget::new("docs/readme.txt", 1024, 1000);
        assert!(expr.evaluate(&t1));

        let t2 = FilterTarget::new("docs/readme.txt", 10000, 1000);
        assert!(!expr.evaluate(&t2));

        let t3 = FilterTarget::new("docs/readme.pdf", 1024, 1000);
        assert!(!expr.evaluate(&t3));
    }

    #[test]
    fn test_path_pattern_filter_rules() {
        let includes = ["*.swift", "src/**"];
        let excludes = ["*.tmp", "build/*"];
        let filter = PathPatternFilter::new(&includes, &excludes, true, true)
            .expect("Should create filter");

        assert!(filter.should_include("src/main.swift"));
        assert!(filter.should_include("Engine.swift"));
        assert!(!filter.should_include("build/out.bin"));
        assert!(!filter.should_include("temp.tmp"));
        assert!(!filter.should_include(".git/config"));
        assert!(!filter.should_include(".DS_Store"));
    }

    #[test]
    fn test_strip_leading_components() {
        assert_eq!(
            strip_leading_components("a/b/c/d.txt", 1),
            Some("b/c/d.txt")
        );
        assert_eq!(strip_leading_components("a/b/c/d.txt", 2), Some("c/d.txt"));
        assert_eq!(strip_leading_components("a/b/c/d.txt", 3), Some("d.txt"));
        assert_eq!(strip_leading_components("a/b/c/d.txt", 4), None);
        assert_eq!(strip_leading_components("a/b/c", 0), Some("a/b/c"));
        assert_eq!(
            strip_leading_components("/var/log/app.log", 2),
            Some("app.log")
        );
        assert_eq!(
            strip_leading_components("./src/models/item.swift", 1),
            Some("models/item.swift")
        );
    }

    #[test]
    fn test_vcs_and_mac_metadata() {
        assert!(is_vcs_metadata(".git"));
        assert!(is_vcs_metadata("project/.git/HEAD"));
        assert!(is_vcs_metadata(".gitignore"));
        assert!(!is_vcs_metadata("src/git_helper.swift"));

        assert!(is_mac_junk_metadata(".DS_Store"));
        assert!(is_mac_junk_metadata("folder/.DS_Store"));
        assert!(is_mac_junk_metadata("__MACOSX/._image.png"));
        assert!(is_mac_junk_metadata("._file.txt"));
        assert!(!is_mac_junk_metadata("document.pdf"));
    }
}
