#!/usr/bin/env bash
set -e

echo "=========================================="
echo "🧪 Running TTZip Full Test & Verification Suite"
echo "=========================================="

cd "$(dirname "$0")/.."

echo "--> Testing Tar Native Engine..."
swift test --filter TarNativeEngineTests

echo "--> Testing Tar Edge Cases..."
swift test --filter TarVariantEdgeCasesTests

echo "--> Testing 7z Native Engine..."
swift test --filter SevenZipBridgeTests

echo "--> Testing Security & Compliance..."
swift test --filter SecurityAndComplianceTests

echo "--> Testing Archive Extractor..."
swift test --filter ArchiveExtractorTests

echo "--> Testing Password Vault V4..."
swift test --filter PasswordVaultV4Tests

echo "--> Testing Archive Spec Integrity & Parser Safety..."
swift test --filter ArchiveSpecIntegrityTests

echo "--> Testing APFS Zero Copy Architecture..."
swift test --filter ZipStoreZeroCopyTests

echo "--> Testing AppViewState Sub-States..."
swift test --filter AppViewStateSubStateTests

echo "=========================================="
echo "✅ ALL TEST SUITES PASSED CLEANLY!"
echo "=========================================="
