// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! TTZip Standalone Native CLI & Interactive TUI Application Entry Point.

use clap::{CommandFactory, Parser};
use ttzip_tui::cli::{
    execute_bench, execute_create, execute_extract, execute_join, execute_list, execute_recover,
    execute_repair, execute_split, run_interactive_tui, Cli, Commands,
};

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Some(Commands::List {
            archive,
            password,
            json,
        }) => execute_list(&archive, password.as_deref(), json).map_err(|e| e.into()),
        Some(Commands::Extract {
            archive,
            output,
            password,
            threads,
            verbose,
        }) => execute_extract(
            &archive,
            output.as_deref(),
            password.as_deref(),
            threads,
            verbose,
        )
        .map_err(|e| e.into()),
        Some(Commands::Create {
            archive,
            sources,
            format,
            level,
            password,
            threads,
            volume_size,
        }) => execute_create(
            &archive,
            &sources,
            format.as_deref(),
            level,
            password.as_deref(),
            threads,
            volume_size.as_deref(),
        )
        .map_err(|e| e.into()),
        Some(Commands::Recover {
            archive,
            dictionary,
            threads,
            json,
        }) => execute_recover(&archive, &dictionary, threads, json).map_err(|e| e.into()),
        Some(Commands::Repair {
            damaged_archive,
            output,
            format,
            json,
        }) => execute_repair(&damaged_archive, &output, format.as_deref(), json).map_err(|e| e.into()),
        Some(Commands::Split {
            source_archive,
            volume_size,
            output_dir,
            naming,
        }) => execute_split(
            &source_archive,
            &volume_size,
            output_dir.as_deref(),
            naming.as_deref(),
        )
        .map_err(|e| e.into()),
        Some(Commands::Join {
            first_volume,
            output,
            json,
        }) => execute_join(&first_volume, &output, json).map_err(|e| e.into()),
        Some(Commands::Bench {
            mips,
            pareto,
            threads,
            dict_mb,
            iterations,
        }) => execute_bench(mips, pareto, threads, dict_mb, iterations).map_err(|e| e.into()),
        None => {
            if let Some(archive_path) = cli.archive {
                if !archive_path.exists() {
                    eprintln!("[ERROR] Target archive does not exist: {}", archive_path.display());
                    std::process::exit(1);
                }
                run_interactive_tui(archive_path)
            } else {
                let mut cmd = Cli::command();
                let _ = cmd.print_help();
                println!();
                Ok(())
            }
        }
    };

    if let Err(err) = result {
        eprintln!("[ERROR] {}", err);
        std::process::exit(1);
    }
}
