# typed: false
# frozen_string_literal: true

# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression CLI utility for macOS.

class Ttzip < Formula
  desc "Ultra-high-performance native archiving and compression CLI engine for macOS"
  homepage "https://github.com/wittkung/TTZip"
  version "1.0.0"
  license :cannot_be_redistributed

  if Hardware::CPU.arm? || Hardware::CPU.intel?
    url "https://github.com/wittkung/TTZip/releases/download/v1.0.0/ttzip-cli-v1.0.0-macos-universal.tar.gz"
    sha256 "3b3a1e226bec4fc825f9418fbd2f9f81b26c8c3b4fd0d57607e8e29802d730b8"
  end

  def install
    bin.install "ttzip-cli" => "ttzip"
  end

  test do
    # Verify version output
    assert_match "ttzip-cli", shell_output("#{bin}/ttzip --version")
    
    # Verify archive creation and extraction roundtrip
    (testpath/"hello.txt").write "Hello, TTZip Open-Core High Performance Engine!"
    system "#{bin}/ttzip", "create", testpath/"hello.tar.zst", testpath/"hello.txt"
    assert_predicate testpath/"hello.tar.zst", :exist?
    
    system "#{bin}/ttzip", "extract", testpath/"hello.tar.zst", testpath/"extracted"
    assert_equal "Hello, TTZip Open-Core High Performance Engine!", (testpath/"extracted/hello.txt").read
  end
end
