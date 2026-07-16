import XCTest
@testable import VowriteKit

/// Tests for `SherpaModelManager.extractTar` — the minimal POSIX/UStar tar
/// extractor used on iOS (macOS shells out to `/usr/bin/tar` instead).
///
/// Regression coverage for a bounds crash: a truncated archive (header claims
/// more file data than actually follows) sliced `tarData[offset..<(offset+fileSize)]`
/// without checking the upper bound was within `tarData.count`, trapping with a
/// fatal "range out of bounds" error instead of throwing a catchable `SherpaError`.
/// This is a real-world scenario (interrupted/corrupted download), not just a
/// synthetic edge case.
final class SherpaTarExtractionTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Fixture builder

    /// Builds a single 512-byte POSIX/UStar tar header block. Checksum field is
    /// left zeroed — `extractTar` never validates it, only name/size/typeflag.
    private func makeTarHeader(name: String, size: Int, typeFlag: UInt8) -> Data {
        var header = Data(count: 512)

        let nameBytes = Array(name.utf8.prefix(100))
        header.replaceSubrange(0..<nameBytes.count, with: nameBytes)

        // Bytes 124..<136 (12 bytes): file size in octal ASCII.
        let sizeOctal = String(size, radix: 8)
        let padded = String(repeating: "0", count: max(0, 11 - sizeOctal.count)) + sizeOctal
        let sizeBytes = Array(padded.utf8.prefix(12))
        header.replaceSubrange(124..<(124 + sizeBytes.count), with: sizeBytes)

        // Byte 156: type flag ('0' or NUL = regular file, '5' = directory).
        header[156] = typeFlag

        return header
    }

    private func tarBlock(padding contentCount: Int) -> Int {
        let blockSize = 512
        return (contentCount + blockSize - 1) / blockSize * blockSize
    }

    // MARK: - Valid archive

    func testExtractsSingleFileFromValidArchive() throws {
        let content = Data("hello tar world".utf8)
        var tar = Data()
        tar.append(makeTarHeader(name: "hello.txt", size: content.count, typeFlag: 0x30))
        var body = content
        body.append(Data(count: tarBlock(padding: content.count) - content.count))
        tar.append(body)

        try SherpaModelManager.extractTar(tar, to: tempDir, stripComponents: 0)

        let written = try Data(contentsOf: tempDir.appendingPathComponent("hello.txt"))
        XCTAssertEqual(written, content)
    }

    func testStripsLeadingPathComponents() throws {
        let content = Data("nested".utf8)
        var tar = Data()
        tar.append(makeTarHeader(name: "archive-root/inner/file.txt", size: content.count, typeFlag: 0x30))
        var body = content
        body.append(Data(count: tarBlock(padding: content.count) - content.count))
        tar.append(body)

        try SherpaModelManager.extractTar(tar, to: tempDir, stripComponents: 1)

        let written = try Data(contentsOf: tempDir.appendingPathComponent("inner/file.txt"))
        XCTAssertEqual(written, content)
    }

    // MARK: - Truncated archive (crash regression)

    /// Header declares a file body that never arrives — the archive is cut off
    /// immediately after the header block. Before the bounds-check fix this
    /// trapped (fatal error) instead of throwing.
    func testTruncatedArchiveThrowsInsteadOfCrashing() {
        let header = makeTarHeader(name: "big.bin", size: 1000, typeFlag: 0x30)

        XCTAssertThrowsError(try SherpaModelManager.extractTar(header, to: tempDir, stripComponents: 0)) { error in
            guard case SherpaError.modelDownloadFailed = error else {
                XCTFail("expected SherpaError.modelDownloadFailed, got \(error)")
                return
            }
        }
    }

    /// Same as above but the archive has *some* trailing data — just fewer bytes
    /// than the header's declared size promises.
    func testPartiallyTruncatedArchiveThrowsInsteadOfCrashing() {
        let header = makeTarHeader(name: "big.bin", size: 1000, typeFlag: 0x30)
        var tar = header
        tar.append(Data(count: 100)) // far short of the 1000 bytes promised

        XCTAssertThrowsError(try SherpaModelManager.extractTar(tar, to: tempDir, stripComponents: 0))
    }
}
