// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Filter DSL scanning, parsing, AST representations, and evaluation engine.

pub mod helpers;
pub mod lexer;
pub mod models;
pub mod parser;

pub use helpers::*;
pub use lexer::*;
pub use models::*;
pub use parser::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_filter_dsl_lexer_tokens() {
        let q = "name == \"*.log\" AND size > 1MB OR (date < 2026-01-01 NOT ext:rs,swift)";
        let tokens = DslLexer::new(q).tokenize().expect("Tokenize success");
        assert!(tokens.contains(&DslToken::And));
        assert!(tokens.contains(&DslToken::Or));
        assert!(tokens.contains(&DslToken::Not));
        assert!(tokens.contains(&DslToken::LeftParen));
        assert!(tokens.contains(&DslToken::Equals));
        assert!(tokens.contains(&DslToken::GreaterThan));
        assert!(tokens.contains(&DslToken::LessThan));
    }

    #[test]
    fn test_filter_dsl_binary_comparison_ast() {
        let q = "name == \"*.log\" AND size > 1MB AND date < 2026-01-01";
        let expr = DslParser::parse_str(q).expect("Parse query");
        let t_match = FilterTarget::new("logs/server.log", 2 * 1024 * 1024, 1700000000);
        let t_wrong_ext = FilterTarget::new("logs/server.txt", 2 * 1024 * 1024, 1700000000);
        let t_small_size = FilterTarget::new("logs/server.log", 500, 1700000000);
        assert!(expr.evaluate(&t_match));
        assert!(!expr.evaluate(&t_wrong_ext));
        assert!(!expr.evaluate(&t_small_size));
    }

    #[test]
    fn test_filter_dsl_nested_parentheses_and_not() {
        let q = "(ext:pdf OR ext:docx) AND size >= 100KB AND NOT name:\"*draft*\"";
        let expr = DslParser::parse_str(q).expect("Parse query");
        let t1 = FilterTarget::new("final_doc.pdf", 200 * 1024, 1700000000);
        let t2 = FilterTarget::new("my_draft.pdf", 200 * 1024, 1700000000);
        assert!(expr.evaluate(&t1));
        assert!(!expr.evaluate(&t2));
    }

    #[test]
    fn test_filter_dsl_date_civil_parsing() {
        let epoch = parse_civil_date("2026-01-01").expect("Civil date parse");
        assert_eq!(epoch, 1767225600);
        let q = "date >= 2026-01-01";
        let expr = DslParser::parse_str(q).expect("Parse date query");
        assert!(expr.evaluate(&FilterTarget::new("a.bin", 10, 1767225601)));
        assert!(!expr.evaluate(&FilterTarget::new("a.bin", 10, 1767225599)));
    }

    #[test]
    fn test_filter_dsl_fallback_mode() {
        let bad_query = "ext: && ( size:>";
        let expr = DslParser::parse_or_fallback(bad_query);
        assert!(!expr.evaluate(&FilterTarget::new("readme.txt", 100, 1000)));
    }
}
