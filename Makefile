# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.

.PHONY: all build release reinstall install app cli test clean help

all: reinstall

help:
	@./scripts/reinstall.sh --help

build:
	@swift build

release:
	@swift build -c release

reinstall:
	@./scripts/reinstall.sh

install:
	@./scripts/reinstall.sh

app:
	@./scripts/reinstall.sh --app

cli:
	@./scripts/reinstall.sh --cli

mas:
	@./scripts/reinstall.sh --mas

test:
	@swift test

clean:
	@rm -rf .build dist
