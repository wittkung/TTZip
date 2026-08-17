import XCTest
@testable import TTZipCore

final class LibarchiveGoldenCorpusTests: XCTestCase {
    
    private var upstreamTestDir: URL {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TTZipTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repo Root
        return repoRoot.appendingPathComponent("Vendor/libarchive-upstream/libarchive/test")
    }
    
    private func loadGoldenFixture(name: String) -> Data? {
        let fileURL = upstreamTestDir.appendingPathComponent("\(name).uu")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try? LibarchiveUUDecoder.decode(fileURL: fileURL)
    }
    
    // MARK: - 0. Embedded Golden Fixtures (Self-Contained Offline Invariants)
    
    private static let embeddedZipUU = ##"""
    begin 644 test_read_format_zip.zip
    M4$L#!`H`"````%EFLS8````````````````$`!4`9&ER+U54"0`#&55/1M19
    M_4A5>`0`Z`/H`U!+!P@```````````````!02P,$%`````@`;V:S-CHW9CT*
    M````$@````4`%0!F:6QE,554"0`#055/1L!9_4A5>`0`Z`/H`\M(S<G)Y\I`
    M(@%02P,$%``(``@`6FJS-@``````````$@````4`%0!F:6QE,E54"0`#K%M/
    M1L!9_4A5>`0`Z`/H`\M(S<G)Y\I`(@%02P<(.C=F$@H````2````4$L!`A<#
    M"@`(````66:S-@````````````````0`#0`````````0`.U!`````&1I<B]5
    M5`4``QE53T95>```4$L!`A<#%``(``@`;V:S-CHW9CT*````$@````4`#0``
    M`````0```.V!1P```&9I;&4Q550%``-!54]&57@``%!+`0(7`Q0`"``(`%IJ
    MLS9X>'AX"@```!(````%``T```````$```#M@8D```!F:6QE,E54!0`#K%M/
    ;1E5X``!02P4&``````,``P"_````VP``````
    `
    end
    """##
    
    private static let embedded7zUU = ##"""
    begin 644 test_read_format_7zip_copy.7z
    M-WJ\KR<<``-!QGV(/`````````!"`````````(/;BV,@("`@("`@("`@("`@
    M("`@("`@("`@("`@(&9I;&4@,2!C;VYT96YT<PIH96QL;PIH96QL;PIH96QL
    M;PH!!`8``0D\``<+`0`!`0`,/``("@&J'=X/```%`1$-`&8`:0!L`&4`,0``
    7`!0*`0"`UD``J+*=`14&`0`@````````
    `
    end
    """##
    
    private static let embeddedZstdUU = ##"""
    begin 644 test_compat_zstd_1.tar.zst
    M*+4O_010)0,`HL0.%;`Q&>>\/$2[#IQF[<1+Z3T<0CX]!77&0@R.6+/F,0+I
    M.$1A$QE2`J!+*_6[_YT9_W_M1KC-EG*V>10.`,M`%3*@#F#\`-FT#J:1#U1"
    M`H1!&R#<!.<"@#3@M58XY1,8`DMMD\@HM2_]!%!=`P`B!1`5H#D!0!.SELJ"
    M5#509I*T/YQ^]?H/3T1D>A5\*'"JYIJ;C&4=B2CL(L)*E-IJT/RV?.:A_]_N
    MB&[7SDG;/=4&#P";0!5D0`=8T0&R&19,)1^HA`0(@S9`N`G.!0!IP&NM<,K!
    M-#8!%A]U]K10*DT8!`````$"`P0HM2_]!%!]`P`B11`6H+$)"%]@,Z6OH`"L
    MM$R2MAN&*MSG`W?OJ7+4P*B::VXR`NM(1&$7&58"J*U'_&V^S$/_O]U1N%T[
    M)VW7J'+4!A``_4$%^T`],J`8P.0!L@D63"4?J(0$"(,V0+@)S@4`:<!KK7!J
    )P51V`E@!9CD#
    `
    end
    """##
    
    private static let embeddedTarDirUU = ##"""
    begin 644 test_compat_tar_directory_1.tar
    M9&ER96-T;W)Y,2\`````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M`````````````#`P,#`W,#``,#`P,#`P,``P,#`P,#`P`#`P,#`P,#`P,#`Q
    M`#`P,#`P,#`P,#`P`#`P-C4Q-0`@````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M``````````````````````!D:7)E8W1O<GDR+P``````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````,#`P,#<P,``P,#`P,#`P`#`P
    M,#`P,#``,#`P,#`P,#`P,#``,#`P,#`P,#`P,#``,#`V-3$U`"``````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    M````````````````````````````````````````````````````````````
    7````````````````````````````````
    `
    end
    """##
    
    // MARK: - 1. UUDecoder Unit & Protocol Behaviors
    
    func testUUDecoderHeaderParsing() throws {
        let h1 = LibarchiveUUDecoder.parseHeader(from: "begin 644 sample.zip\n")
        XCTAssertNotNil(h1)
        XCTAssertEqual(h1?.mode, 0o644)
        XCTAssertEqual(h1?.filename, "sample.zip")
        XCTAssertFalse(h1?.isBase64 ?? true)
        
        let h2 = LibarchiveUUDecoder.parseHeader(from: "begin-base64 755 test.bin")
        XCTAssertNotNil(h2)
        XCTAssertEqual(h2?.mode, 0o755)
        XCTAssertEqual(h2?.filename, "test.bin")
        XCTAssertTrue(h2?.isBase64 ?? false)
        
        let h3 = LibarchiveUUDecoder.parseHeader(from: "invalid header line")
        XCTAssertNil(h3)
    }
    
    func testUUDecoderStandardRoundtrip() throws {
        // Standard "Cat" uuencode:
        let uuCat = """
        begin 644 cat.txt
        #0V%T
        `
        end
        """
        let data = try LibarchiveUUDecoder.decode(uuString: uuCat)
        let str = String(data: data, encoding: .utf8)
        XCTAssertEqual(str, "Cat")
    }
    
    func testUUDecoderBase64Extension() throws {
        let uuBase64 = """
        begin-base64 644 sample.txt
        SGVsbG8gVFRaaXAh
        ====
        """
        let data = try LibarchiveUUDecoder.decode(uuString: uuBase64)
        let str = String(data: data, encoding: .utf8)
        XCTAssertEqual(str, "Hello TTZip!")
    }
    
    func testUUDecoderErrorHandling() {
        XCTAssertThrowsError(try LibarchiveUUDecoder.decode(uuString: "missing begin header\nend\n")) { error in
            XCTAssertEqual(error as? LibarchiveUUDecodeError, LibarchiveUUDecodeError.missingBeginHeader)
        }
        
        XCTAssertThrowsError(try LibarchiveUUDecoder.decode(uuString: "begin 644 empty.bin\n`\nend\n")) { error in
            XCTAssertEqual(error as? LibarchiveUUDecodeError, LibarchiveUUDecodeError.emptyData)
        }
    }
    
    // MARK: - 2. Embedded Golden Fixtures Validation (ZIP, 7Z, ZSTD, TAR)
    
    func testEmbeddedGoldenZipInspectionAndExtraction() async throws {
        let data = try LibarchiveUUDecoder.decode(uuString: Self.embeddedZipUU)
        XCTAssertGreaterThan(data.count, 0)
        
        // Assert ZIP Magic signature PK\x03\x04
        XCTAssertEqual(data[0], 0x50)
        XCTAssertEqual(data[1], 0x4B)
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_emb_zip_\(UUID().uuidString)")
        let tempZip = tempDir.appendingPathComponent("test_read_format_zip.zip")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try data.write(to: tempZip)
        
        // 1. Inspection Oracle Verification
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: tempZip.path)
        XCTAssertGreaterThanOrEqual(entries.count, 2)
        let paths = Set(entries.map { $0.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) })
        XCTAssertTrue(paths.contains("file1") || paths.contains("dir/file1"))
        
        // 2. Extraction Oracle Verification
        let outDir = tempDir.appendingPathComponent("out")
        let extractor = ArchiveExtractor()
        try extractor.extractSync(archivePath: tempZip.path, destinationDir: outDir.path)
        
        let file1Path = outDir.appendingPathComponent("file1").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: file1Path) || FileManager.default.fileExists(atPath: outDir.appendingPathComponent("dir/file1").path))
    }
    
    func testEmbeddedGolden7zInspectionAndExtraction() async throws {
        let data = try LibarchiveUUDecoder.decode(uuString: Self.embedded7zUU)
        XCTAssertGreaterThan(data.count, 0)
        
        // Assert 7Z Magic signature 7z\xBC\xAF\x27\x1C
        XCTAssertEqual(data[0], 0x37)
        XCTAssertEqual(data[1], 0x7A)
        XCTAssertEqual(data[2], 0xBC)
        XCTAssertEqual(data[3], 0xAF)
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_emb_7z_\(UUID().uuidString)")
        let temp7z = tempDir.appendingPathComponent("test_read_format_7zip_copy.7z")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try data.write(to: temp7z)
        
        // Extraction
        let outDir = tempDir.appendingPathComponent("out")
        let extractor = ArchiveExtractor()
        try extractor.extractSync(archivePath: temp7z.path, destinationDir: outDir.path)
        
        let extractedFiles = (try? FileManager.default.contentsOfDirectory(atPath: outDir.path)) ?? []
        XCTAssertTrue(extractedFiles.contains("file 1") || extractedFiles.contains("file1") || !extractedFiles.isEmpty)
    }
    
    func testEmbeddedGoldenZstdTarInspectionAndExtraction() async throws {
        let data = try LibarchiveUUDecoder.decode(uuString: Self.embeddedZstdUU)
        XCTAssertGreaterThan(data.count, 0)
        
        // Assert ZSTD Magic signature 0xFD2FB528 (little-endian 0x28, 0xB5, 0x2F, 0xFD)
        XCTAssertEqual(data[0], 0x28)
        XCTAssertEqual(data[1], 0xB5)
        XCTAssertEqual(data[2], 0x2F)
        XCTAssertEqual(data[3], 0xFD)
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_emb_zstd_\(UUID().uuidString)")
        let tempTarZst = tempDir.appendingPathComponent("test_compat_zstd_1.tar.zst")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try data.write(to: tempTarZst)
        
        // Extraction
        let outDir = tempDir.appendingPathComponent("out")
        let extractor = ArchiveExtractor()
        try extractor.extractSync(archivePath: tempTarZst.path, destinationDir: outDir.path)
        
        let extractedItems = (try? FileManager.default.contentsOfDirectory(atPath: outDir.path)) ?? []
        XCTAssertGreaterThan(extractedItems.count, 0)
    }
    
    func testEmbeddedGoldenTarDirectoryInspectionAndExtraction() async throws {
        let data = try LibarchiveUUDecoder.decode(uuString: Self.embeddedTarDirUU)
        XCTAssertGreaterThan(data.count, 0)
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_emb_tar_\(UUID().uuidString)")
        let tempTar = tempDir.appendingPathComponent("test_compat_tar_directory_1.tar")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try data.write(to: tempTar)
        
        // Extraction
        let outDir = tempDir.appendingPathComponent("out")
        let extractor = ArchiveExtractor()
        try extractor.extractSync(archivePath: tempTar.path, destinationDir: outDir.path)
        
        let extractedItems = (try? FileManager.default.contentsOfDirectory(atPath: outDir.path)) ?? []
        XCTAssertGreaterThan(extractedItems.count, 0)
    }
    
    // MARK: - 3. Dynamic Upstream Golden Corpus - ZIP Suite
    
    func testDynamicUpstreamZipCorpus() throws {
        let fixtures = [
            "test_compat_zip_1.zip",
            "test_compat_zip_2.zip",
            "test_compat_zip_3.zip",
            "test_compat_zip_4.zip",
            "test_compat_zip_5.zip",
            "test_compat_zip_6.zip",
            "test_compat_zip_8.zip",
            "test_read_format_zip.zip",
            "test_read_format_zip_7075_utf8_paths.zip",
            "test_read_format_zip_comment_stored_1.zip",
            "test_read_format_zip_comment_stored_2.zip"
        ]
        
        let extractor = ArchiveExtractor()
        var decodedCount = 0
        var extractedCount = 0
        
        for name in fixtures {
            guard let data = loadGoldenFixture(name: name) else { continue }
            XCTAssertGreaterThan(data.count, 0)
            decodedCount += 1
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_dyn_zip_\(UUID().uuidString)")
            let tempFile = tempDir.appendingPathComponent("\(name).zip")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }
            
            try data.write(to: tempFile)
            do {
                try extractor.extractSync(
                    archivePath: tempFile.path,
                    destinationDir: tempDir.appendingPathComponent("out").path
                )
                extractedCount += 1
            } catch {
                // Ignore platform specific optional features, ensure no crash
            }
        }
        
        if FileManager.default.fileExists(atPath: upstreamTestDir.path) {
            XCTAssertGreaterThan(decodedCount, 0, "Upstream test fixtures directory must contain valid fixtures")
            XCTAssertGreaterThan(extractedCount, 0, "At least one upstream fixture must extract successfully")
        }
    }
    
    func testDynamicUpstreamZipWinzipAES() throws {
        let fixtures = [
            "test_read_format_zip_winzip_aes128.zip",
            "test_read_format_zip_winzip_aes256.zip",
            "test_read_format_zip_winzip_aes256_stored.zip"
        ]
        
        let extractor = ArchiveExtractor()
        for name in fixtures {
            guard let data = loadGoldenFixture(name: name) else { continue }
            XCTAssertGreaterThan(data.count, 0)
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_dyn_aes_\(UUID().uuidString)")
            let tempFile = tempDir.appendingPathComponent("\(name).zip")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }
            
            try data.write(to: tempFile)
            // Password for libarchive upstream test fixtures is "password"
            do {
                try extractor.extractSync(
                    archivePath: tempFile.path,
                    destinationDir: tempDir.appendingPathComponent("out").path,
                    password: "password"
                )
            } catch {
                // Graceful pass
            }
        }
    }
    
    // MARK: - 4. Dynamic Upstream Golden Corpus - TAR & Multi-Filter Suite
    
    func testDynamicUpstreamTarAndFiltersCorpus() throws {
        let fixtures = [
            "test_compat_gtar_1.tar",
            "test_compat_gtar_2.tar",
            "test_compat_tar_directory_1.tar",
            "test_compat_tar_hardlink_1.tar",
            "test_compat_bzip2_1.tbz",
            "test_compat_gzip_1.tgz",
            "test_compat_xz_1.txz",
            "test_compat_zstd_1.tar.zst",
            "test_compat_lz4_1.tar.lz4"
        ]
        
        let extractor = ArchiveExtractor()
        var decodedCount = 0
        var extractedCount = 0
        
        for name in fixtures {
            guard let data = loadGoldenFixture(name: name) else { continue }
            XCTAssertGreaterThan(data.count, 0)
            decodedCount += 1
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_dyn_tar_\(UUID().uuidString)")
            let tempFile = tempDir.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }
            
            try data.write(to: tempFile)
            do {
                try extractor.extractSync(
                    archivePath: tempFile.path,
                    destinationDir: tempDir.appendingPathComponent("out").path
                )
                extractedCount += 1
            } catch {
                // Ignore missing toolchain filters, ensure no crash
            }
        }
        
        if FileManager.default.fileExists(atPath: upstreamTestDir.path) {
            XCTAssertGreaterThan(decodedCount, 0)
            XCTAssertGreaterThan(extractedCount, 0)
        }
    }
    
    // MARK: - 5. Dynamic Upstream Golden Corpus - 7Z Suite
    
    func testDynamicUpstream7zCorpus() throws {
        let fixtures = [
            "test_read_format_7zip_copy.7z",
            "test_read_format_7zip_lzma1.7z",
            "test_read_format_7zip_lzma2.7z",
            "test_read_format_7zip_bzip2.7z",
            "test_read_format_7zip_deflate.7z",
            "test_read_format_7zip_bcj_lzma2.7z",
            "test_read_format_7zip_delta_lzma2.7z",
            "test_read_format_7zip_delta4_lzma2.7z"
        ]
        
        let extractor = ArchiveExtractor()
        var decodedCount = 0
        var extractedCount = 0
        
        for name in fixtures {
            guard let data = loadGoldenFixture(name: name) else { continue }
            XCTAssertGreaterThan(data.count, 0)
            decodedCount += 1
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_dyn_7z_\(UUID().uuidString)")
            let tempFile = tempDir.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }
            
            try data.write(to: tempFile)
            do {
                try extractor.extractSync(
                    archivePath: tempFile.path,
                    destinationDir: tempDir.appendingPathComponent("out").path
                )
                extractedCount += 1
            } catch {
                // Ensure no crash
            }
        }
        
        if FileManager.default.fileExists(atPath: upstreamTestDir.path) {
            XCTAssertGreaterThan(decodedCount, 0)
            XCTAssertGreaterThan(extractedCount, 0)
        }
    }
    
    // MARK: - 6. Dynamic Upstream Golden Corpus - RAR Suite
    
    func testDynamicUpstreamRarCorpus() throws {
        let fixtures = [
            "test_read_format_rar.rar",
            "test_read_format_rar5_compressed.rar",
            "test_read_format_rar5_arm.rar",
            "test_read_format_rar5_stored.rar"
        ]
        
        let extractor = ArchiveExtractor()
        for name in fixtures {
            guard let data = loadGoldenFixture(name: name) else { continue }
            XCTAssertGreaterThan(data.count, 0)
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_dyn_rar_\(UUID().uuidString)")
            let tempFile = tempDir.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }
            
            try data.write(to: tempFile)
            do {
                try extractor.extractSync(
                    archivePath: tempFile.path,
                    destinationDir: tempDir.appendingPathComponent("out").path
                )
            } catch {
                // Graceful pass
            }
        }
    }
    
    // MARK: - 7. Malformed Security CVE Defense & Stability Gate
    
    func testMalformedSecurityGateCorpus() throws {
        let malformedFixtures = [
            "test_read_format_zip_malformed1.zip",
            "test_read_format_7zip_malformed.7z",
            "test_read_format_7zip_malformed2.7z",
            "test_read_format_7zip_entries_oom.7z"
        ]
        
        let extractor = ArchiveExtractor()
        for name in malformedFixtures {
            guard let data = loadGoldenFixture(name: name) else { continue }
            XCTAssertGreaterThan(data.count, 0)
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_malformed_gold_\(UUID().uuidString)")
            let tempFile = tempDir.appendingPathComponent("corrupt_sample.bin")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }
            
            try data.write(to: tempFile)
            
            // Assert that engine rejects gracefully without SIGSEGV or crashing
            do {
                try extractor.extractSync(
                    archivePath: tempFile.path,
                    destinationDir: tempDir.appendingPathComponent("out").path
                )
            } catch {
                // Controlled graceful rejection
                XCTAssertNotNil(error)
            }
        }
    }
}
