import AVFoundation
import XCTest
@testable import CMV

final class NativeAudioAnalyzerTests: XCTestCase {
    func testMultichannelPCMRemainsSupported() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVMultichannel-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let layout = try XCTUnwrap(AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_MPEG_7_1_A))
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channelLayout: layout))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88_200))
        buffer.frameLength = 88_200
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<8 {
            channels[channel].update(repeating: 0, count: Int(buffer.frameLength))
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let analyzer = NativeAudioAnalyzer()
        let trackID = UUID()
        // An idle cancellation must not poison this or a later request.
        await analyzer.cancel(trackID: trackID)
        let profile = try await analyzer.analyze(trackID: trackID, url: url)
        XCTAssertGreaterThan(profile.version, 0)
        XCTAssertTrue(profile.energy.isFinite)
        XCTAssertTrue(profile.brightness.isFinite)
        await analyzer.cancel(trackID: trackID)
        let repeated = try await analyzer.analyze(trackID: trackID, url: url)
        XCTAssertEqual(repeated.version, profile.version)
    }

    func testCancelledAnalysisStopsBeforeOpeningTheSource() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await NativeAudioAnalyzer().analyze(
                trackID: UUID(),
                url: FileManager.default.temporaryDirectory.appendingPathComponent("CMV-unavailable-\(UUID().uuidString).caf")
            )
        }
        do {
            _ = try await task.value
            XCTFail("取消的分析不應開啟來源或回傳結果")
        } catch is CancellationError {
            // Expected, rather than a file-open error.
        }
    }
}
