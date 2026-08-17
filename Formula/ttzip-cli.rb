# typed: false
# frozen_string_literal: true

# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression CLI utility for macOS.

class TtzipCli < Formula
  desc "High-performance native archive and compression CLI utility for macOS"
  homepage "https://github.com/wittkung/TTZip"
  url "https://github.com/wittkung/TTZip/releases/download/v1.0.0/ttzip-cli-v1.0.0-darwin-universal.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license :cannot_be_redistributed

  depends_on :macos => :sonoma

  def install
    bin.install "bin/ttzip-cli"
    man1.install "share/man/man1/ttzip-cli.1"
    bash_completion.install "share/bash-completion/completions/ttzip-cli"
    zsh_completion.install "share/zsh/site-functions/_ttzip-cli"
    fish_completion.install "share/fish/vendor_completions.d/ttzip-cli.fish"
  end

  test do
    assert_match "ttzip-cli", shell_output("#{bin}/ttzip-cli --version")
    (testpath/"hello.txt").write("TTZip Homebrew Test Verification")
    system "#{bin}/ttzip-cli", "create", "-f", "zip", "test.zip", "hello.txt"
    assert_predicate testpath/"test.zip", :exist?
    system "#{bin}/ttzip-cli", "test", "test.zip"
  end
end
