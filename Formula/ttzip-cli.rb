# typed: false
# frozen_string_literal: true

# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression CLI utility for macOS.

class TtzipCli < Formula
  desc "High-performance native archive and compression CLI utility for macOS"
  homepage "https://github.com/wittkung/TTZip"
  url "https://github.com/wittkung/TTZip/releases/download/v1.0.0/ttzip-cli-v1.0.0-darwin-universal.tar.gz"
  sha256 "eba1bae313a0a8f403d9681c68eeddc5555743e32b6329d7afefc81dd655051b"
  license :cannot_be_redistributed

  depends_on :macos => :sonoma

  def install
    bin.install "bin/ttzip-cli"
    bin.install "bin/ttzip" if File.exist?("bin/ttzip")
    man1.install "share/man/man1/ttzip-cli.1" if File.exist?("share/man/man1/ttzip-cli.1")
    bash_completion.install "share/bash-completion/completions/ttzip-cli" if File.exist?("share/bash-completion/completions/ttzip-cli")
    zsh_completion.install "share/zsh/site-functions/_ttzip-cli" if File.exist?("share/zsh/site-functions/_ttzip-cli")
    fish_completion.install "share/fish/vendor_completions.d/ttzip-cli.fish" if File.exist?("share/fish/vendor_completions.d/ttzip-cli.fish")
  end

  test do
    assert_match "ttzip", shell_output("#{bin}/ttzip --version")
    assert_match "platform", shell_output("#{bin}/ttzip doctor --json")
    (testpath/"hello.txt").write("TTZip Homebrew Test Verification")
    system "#{bin}/ttzip", "a", "test.zip", "hello.txt"
    assert_predicate testpath/"test.zip", :exist?
    system "#{bin}/ttzip", "t", "test.zip"
  end
end
