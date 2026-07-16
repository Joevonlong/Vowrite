import XCTest
@testable import VowriteKit

/// Tests for `SoundFeedback.wavData` — the pure RIFF/WAV header byte-layout
/// math (no audio session or playback involved). Verifies every field against
/// the canonical 44-byte PCM WAV header format for a known sample count.
final class SoundFeedbackWavHeaderTests: XCTestCase {

    private func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        let bytes = Array(data[data.startIndex + offset ..< data.startIndex + offset + 4])
        return UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
    }

    private func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
        let bytes = Array(data[data.startIndex + offset ..< data.startIndex + offset + 2])
        return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    }

    private func readASCII(_ data: Data, at offset: Int, length: Int) -> String {
        let bytes = Array(data[data.startIndex + offset ..< data.startIndex + offset + length])
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    func testWavHeaderFieldsForKnownSampleCount() {
        let samples: [Int16] = Array(stride(from: Int16(0), to: Int16(10), by: 1)) // 10 samples
        let sampleRate: UInt32 = 44100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16

        let wav = SoundFeedback.wavData(
            samples: samples, sampleRate: sampleRate, channels: channels, bitsPerSample: bitsPerSample
        )

        let blockAlign = channels * (bitsPerSample / 8) // 2
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8) // 88200
        let dataSize = UInt32(samples.count) * UInt32(blockAlign) // 20

        // RIFF chunk descriptor
        XCTAssertEqual(readASCII(wav, at: 0, length: 4), "RIFF")
        XCTAssertEqual(readUInt32LE(wav, at: 4), 36 + dataSize) // ChunkSize
        XCTAssertEqual(readASCII(wav, at: 8, length: 4), "WAVE")

        // fmt subchunk
        XCTAssertEqual(readASCII(wav, at: 12, length: 4), "fmt ")
        XCTAssertEqual(readUInt32LE(wav, at: 16), 16) // Subchunk1Size (PCM)
        XCTAssertEqual(readUInt16LE(wav, at: 20), 1) // AudioFormat == PCM
        XCTAssertEqual(readUInt16LE(wav, at: 22), channels)
        XCTAssertEqual(readUInt32LE(wav, at: 24), sampleRate)
        XCTAssertEqual(readUInt32LE(wav, at: 28), byteRate)
        XCTAssertEqual(readUInt16LE(wav, at: 32), blockAlign)
        XCTAssertEqual(readUInt16LE(wav, at: 34), bitsPerSample)

        // data subchunk
        XCTAssertEqual(readASCII(wav, at: 36, length: 4), "data")
        XCTAssertEqual(readUInt32LE(wav, at: 40), dataSize)

        // Total file size: 44-byte header + sample payload.
        XCTAssertEqual(wav.count, 44 + Int(dataSize))

        // Sample payload itself round-trips exactly (little-endian Int16).
        for (index, sample) in samples.enumerated() {
            let byteOffset = 44 + index * 2
            let lo = wav[wav.startIndex + byteOffset]
            let hi = wav[wav.startIndex + byteOffset + 1]
            let readBack = Int16(bitPattern: UInt16(lo) | (UInt16(hi) << 8))
            XCTAssertEqual(readBack, sample)
        }
    }

    func testWavHeaderForEmptySampleArray() {
        let wav = SoundFeedback.wavData(samples: [], sampleRate: 44100, channels: 1, bitsPerSample: 16)

        XCTAssertEqual(wav.count, 44) // header only, no payload
        XCTAssertEqual(readUInt32LE(wav, at: 4), 36) // ChunkSize with zero data
        XCTAssertEqual(readUInt32LE(wav, at: 40), 0) // Subchunk2Size (data) is zero
    }

    /// Production always calls `wavData` with `channels: 1` (see `generateTone`) —
    /// the sample-writing loop appends exactly one 16-bit value per array element
    /// regardless of the `channels` header field, so `channels > 1` would produce
    /// a header/data-size mismatch (dead code path, never exercised at runtime).
    /// This test covers the actually-used mono path at a different sample rate.
    func testWavHeaderForMonoAtDifferentSampleRate() {
        let samples: [Int16] = [100, -100, 200, -200, 300]
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16

        let wav = SoundFeedback.wavData(
            samples: samples, sampleRate: sampleRate, channels: channels, bitsPerSample: bitsPerSample
        )

        let blockAlign = channels * (bitsPerSample / 8) // 2
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8) // 32000
        let dataSize = UInt32(samples.count) * UInt32(blockAlign) // 10

        XCTAssertEqual(readUInt16LE(wav, at: 22), 1)
        XCTAssertEqual(readUInt32LE(wav, at: 28), byteRate)
        XCTAssertEqual(readUInt16LE(wav, at: 32), blockAlign)
        XCTAssertEqual(readUInt32LE(wav, at: 40), dataSize)
        XCTAssertEqual(wav.count, 44 + Int(dataSize))
    }
}
