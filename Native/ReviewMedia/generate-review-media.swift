import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct TrackSpec {
    let fileName: String
    let title: String
    let bpm: Double
    let rootMIDI: Double
    let duration: Double
}

let tracks = [
    TrackSpec(fileName: "01-cobalt-echoes.wav", title: "Cobalt Echoes", bpm: 92, rootMIDI: 48, duration: 20),
    TrackSpec(fileName: "02-amber-circuit.wav", title: "Amber Circuit", bpm: 108, rootMIDI: 52, duration: 19),
    TrackSpec(fileName: "03-violet-tide.wav", title: "Violet Tide", bpm: 124, rootMIDI: 45, duration: 21),
    TrackSpec(fileName: "04-silver-orbit.wav", title: "Silver Orbit", bpm: 76, rootMIDI: 55, duration: 18)
]

let outputDirectory: URL = {
    if let index = CommandLine.arguments.firstIndex(of: "--output"), index + 1 < CommandLine.arguments.count {
        return URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
    }
    return URL(fileURLWithPath: "/tmp/cmv-owned-review-media", isDirectory: true)
}()

func fail(_ message: String) -> Never {
    fputs("generate-review-media: \(message)\n", stderr)
    exit(1)
}

func writeAll(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: .atomic)
}

func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
}

func midiFrequency(_ midi: Double) -> Double {
    440 * pow(2, (midi - 69) / 12)
}

func makeWAV(_ spec: TrackSpec, at url: URL) throws {
    let sampleRate = 44_100
    let channels = 2
    let frames = Int(spec.duration * Double(sampleRate))
    var pcm = Data(capacity: frames * channels * MemoryLayout<Int16>.size)
    let notes = [0.0, 3.0, 7.0, 12.0, 7.0, 3.0]
    let secondsPerStep = 60.0 / spec.bpm / 2.0

    for frame in 0..<frames {
        let time = Double(frame) / Double(sampleRate)
        let step = Int(time / secondsPerStep)
        let note = midiFrequency(spec.rootMIDI + notes[step % notes.count])
        let octave = note * 2
        let phase = 2 * Double.pi * note * time
        let harmonicPhase = 2 * Double.pi * octave * time
        let local = time.truncatingRemainder(dividingBy: secondsPerStep)
        let attack = min(1, local / 0.012)
        let release = min(1, (secondsPerStep - local) / 0.045)
        let envelope = min(attack, release)
        let pulse = sin(phase) * 0.72 + sin(harmonicPhase) * 0.18
        let tremolo = 0.86 + 0.14 * sin(2 * Double.pi * 0.5 * time)
        let sample = Int16(max(-0.92, min(0.92, pulse * envelope * tremolo)) * Double(Int16.max))
        appendLE(sample, to: &pcm)
        appendLE(sample, to: &pcm)
    }

    var wav = Data(capacity: 44 + pcm.count)
    wav.append(contentsOf: Data("RIFF".utf8))
    appendLE(UInt32(36 + pcm.count), to: &wav)
    wav.append(contentsOf: Data("WAVEfmt ".utf8))
    appendLE(UInt32(16), to: &wav)
    appendLE(UInt16(1), to: &wav)
    appendLE(UInt16(channels), to: &wav)
    appendLE(UInt32(sampleRate), to: &wav)
    appendLE(UInt32(sampleRate * channels * 2), to: &wav)
    appendLE(UInt16(channels * 2), to: &wav)
    appendLE(UInt16(16), to: &wav)
    wav.append(contentsOf: Data("data".utf8))
    appendLE(UInt32(pcm.count), to: &wav)
    wav.append(pcm)
    try writeAll(wav, to: url)
}

func makeCover(at url: URL) throws {
    let width = 1024
    let height = 1024
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("could not create cover context")
    }
    context.setFillColor(CGColor(red: 0.025, green: 0.035, blue: 0.09, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let center = CGPoint(x: 512, y: 512)
    for index in 0..<18 {
        let radius = CGFloat(70 + index * 24)
        let hue = CGFloat(index) / 18.0
        context.setStrokeColor(CGColor(red: 0.15 + hue * 0.35, green: 0.35 + (1 - hue) * 0.3, blue: 0.85, alpha: 0.2))
        context.setLineWidth(index % 3 == 0 ? 5 : 2)
        context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
    context.setStrokeColor(CGColor(red: 0.3, green: 0.85, blue: 1, alpha: 0.9))
    context.setLineWidth(8)
    for index in 0..<12 {
        let angle = CGFloat(index) * .pi / 6
        context.move(to: center)
        context.addLine(to: CGPoint(x: center.x + cos(angle) * 390, y: center.y + sin(angle) * 390))
    }
    context.strokePath()
    guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fail("could not create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("could not finalize cover PNG") }
}

func makePixelBuffer(width: Int, height: Int, frame: Int) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ]
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer)
    guard let pixelBuffer else { return nil }
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(pixelBuffer),
          let context = CGContext(data: base, width: width, height: height, bitsPerComponent: 8,
                                   bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
    let phase = CGFloat(frame % 240) / 240.0
    context.setFillColor(CGColor(red: 0.02 + phase * 0.08, green: 0.04, blue: 0.12 + (1 - phase) * 0.16, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setStrokeColor(CGColor(red: 0.25, green: 0.8, blue: 1, alpha: 0.85))
    context.setLineWidth(4)
    context.move(to: CGPoint(x: 0, y: CGFloat(height) * 0.62))
    for x in stride(from: 0, through: width, by: 8) {
        let y = CGFloat(height) * 0.62 + sin(CGFloat(x) * 0.055 + phase * 6.28) * CGFloat(height) * (0.05 + phase * 0.03)
        context.addLine(to: CGPoint(x: CGFloat(x), y: y))
    }
    context.strokePath()
    return pixelBuffer
}

func makeVideoMovie(at url: URL) throws {
    let width = 640
    let height = 360
    let frameRate = 24
    let durationSeconds = 12
    guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { fail("could not create MOV writer") }
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 900_000]
    ])
    videoInput.expectsMediaDataInRealTime = true
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height
    ])
    guard writer.canAdd(videoInput) else { fail("writer rejected video input") }
    writer.add(videoInput)
    guard writer.startWriting() else { fail("MOV writer failed to start") }
    writer.startSession(atSourceTime: .zero)
    let videoDone = DispatchSemaphore(value: 0)
    let videoQueue = DispatchQueue(label: "cmv.review-media.video")
    let totalFrames = frameRate * durationSeconds
    var nextFrame = 0
    videoInput.requestMediaDataWhenReady(on: videoQueue) {
        while videoInput.isReadyForMoreMediaData && nextFrame < totalFrames {
            guard let buffer = makePixelBuffer(width: width, height: height, frame: nextFrame),
                  adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(nextFrame), timescale: CMTimeScale(frameRate))) else {
                writer.cancelWriting()
                videoDone.signal()
                return
            }
            nextFrame += 1
        }
        if nextFrame == totalFrames {
            videoInput.markAsFinished()
            videoDone.signal()
        }
    }
    guard videoDone.wait(timeout: .now() + 60) == .success else {
        writer.cancelWriting()
        fail("video writer did not finish 288 frames within 60 seconds")
    }
    guard nextFrame == totalFrames else { fail("video append failed before all frames were written") }
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting { semaphore.signal() }
    semaphore.wait()
    guard writer.status == .completed else { fail("MOV writer failed: \(writer.error?.localizedDescription ?? "unknown")") }
}

func makeMovie(videoURL: URL, audioURL: URL, at url: URL) throws {
    let videoAsset = AVURLAsset(url: videoURL)
    let audioAsset = AVURLAsset(url: audioURL)
    guard let sourceVideo = videoAsset.tracks(withMediaType: .video).first,
          let sourceAudio = audioAsset.tracks(withMediaType: .audio).first else { fail("source fixture tracks missing") }
    let composition = AVMutableComposition()
    guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
          let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { fail("could not create composition tracks") }
    let range = CMTimeRange(start: .zero, duration: CMTime(seconds: 12, preferredTimescale: 600))
    try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
    try audioTrack.insertTimeRange(range, of: sourceAudio, at: .zero)
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { fail("could not create MOV exporter") }
    exporter.outputURL = url
    exporter.outputFileType = .mov
    let semaphore = DispatchSemaphore(value: 0)
    exporter.exportAsynchronously { semaphore.signal() }
    semaphore.wait()
    guard exporter.status == .completed else { fail("MOV export failed: \(exporter.error?.localizedDescription ?? "unknown")") }
}

func sha256(_ url: URL) throws -> String {
    let digest = SHA256.hash(data: try Data(contentsOf: url))
    return digest.map { String(format: "%02x", $0) }.joined()
}

struct MediaReadback {
    let duration: Double
    let videoCodecs: [String]
    let videoFrameRate: Double?
    let audioCodecs: [String]
    let audioChannels: Int?
    let audioSampleRate: Double?
}

func fourCC(_ value: FourCharCode) -> String {
    String(bytes: [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)], encoding: .ascii) ?? "unknown"
}

func verify(_ url: URL, expectedVideo: Bool, expectedAudio: Bool) throws -> MediaReadback {
    let asset = AVURLAsset(url: url)
    let duration = asset.duration.seconds
    guard duration.isFinite, duration > 0 else { fail("invalid duration for \(url.lastPathComponent)") }
    let videoTracks = asset.tracks(withMediaType: .video)
    let audioTracks = asset.tracks(withMediaType: .audio)
    if expectedVideo { guard !videoTracks.isEmpty else { fail("missing video track") } }
    if expectedAudio { guard !audioTracks.isEmpty else { fail("missing audio track") } }
    let videoCodecs = videoTracks.flatMap { track in
        track.formatDescriptions.compactMap { description -> String? in
            return fourCC(CMFormatDescriptionGetMediaSubType(description as! CMFormatDescription))
        }
    }
    let audioCodecs = audioTracks.flatMap { track in
        track.formatDescriptions.compactMap { description -> String? in
            return fourCC(CMFormatDescriptionGetMediaSubType(description as! CMFormatDescription))
        }
    }
    let videoFrameRate = videoTracks.first.map { Double($0.nominalFrameRate) }
    var audioChannels: Int?
    var audioSampleRate: Double?
    if let description = audioTracks.first?.formatDescriptions.first,
       let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description as! CMAudioFormatDescription)?.pointee {
        audioChannels = Int(asbd.mChannelsPerFrame)
        audioSampleRate = asbd.mSampleRate
    }
    if expectedVideo {
        guard videoCodecs.contains(where: { $0 == "avc1" || $0 == "avc3" }) else { fail("video codec is not H.264: \(videoCodecs)") }
        guard let videoFrameRate, videoFrameRate >= 23.9 else { fail("video frame rate is below 24fps") }
    }
    if expectedAudio { guard !audioCodecs.isEmpty else { fail("audio codec could not be read") } }
    return MediaReadback(duration: duration, videoCodecs: videoCodecs, videoFrameRate: videoFrameRate, audioCodecs: audioCodecs, audioChannels: audioChannels, audioSampleRate: audioSampleRate)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for spec in tracks { try makeWAV(spec, at: outputDirectory.appendingPathComponent(spec.fileName)) }
let coverURL = outputDirectory.appendingPathComponent("review-cover.png")
try makeCover(at: coverURL)
let audioFixtureURL = outputDirectory.appendingPathComponent("eof-pip-fixture-audio.wav")
try makeWAV(TrackSpec(fileName: audioFixtureURL.lastPathComponent, title: "EOF PiP Fixture", bpm: 110, rootMIDI: 50, duration: 12), at: audioFixtureURL)
let videoFixtureURL = outputDirectory.appendingPathComponent("eof-pip-fixture-video.mov")
try makeVideoMovie(at: videoFixtureURL)
let movieURL = outputDirectory.appendingPathComponent("eof-pip-fixture.mov")
try makeMovie(videoURL: videoFixtureURL, audioURL: audioFixtureURL, at: movieURL)
try FileManager.default.removeItem(at: videoFixtureURL)
try FileManager.default.removeItem(at: audioFixtureURL)

var entries: [[String: Any]] = []
for spec in tracks {
    let url = outputDirectory.appendingPathComponent(spec.fileName)
    let readback = try verify(url, expectedVideo: false, expectedAudio: true)
    guard readback.audioChannels == 2, readback.audioSampleRate == 44_100 else { fail("WAV audio format is not stereo 44.1kHz") }
    entries.append(["file": spec.fileName, "title": spec.title, "kind": "original-generated-instrumental", "durationSeconds": readback.duration, "audioCodecs": readback.audioCodecs, "audioChannels": readback.audioChannels!, "audioSampleRate": readback.audioSampleRate!, "sha256": try sha256(url)])
}
let movieReadback = try verify(movieURL, expectedVideo: true, expectedAudio: true)
guard movieReadback.audioCodecs.contains(where: { $0 == "mp4a" || $0 == "aac " }) else { fail("MOV audio codec is not AAC: \(movieReadback.audioCodecs)") }
guard movieReadback.audioChannels == 2, movieReadback.audioSampleRate == 44_100 else { fail("MOV audio format is not stereo 44.1kHz") }
let imageSource = CGImageSourceCreateWithURL(coverURL as CFURL, nil)
guard let imageSource, let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
      let imageWidth = properties[kCGImagePropertyPixelWidth] as? Int, let imageHeight = properties[kCGImagePropertyPixelHeight] as? Int,
      imageWidth == 1024, imageHeight == 1024 else { fail("cover PNG dimensions are not 1024x1024") }
entries.append(["file": movieURL.lastPathComponent, "kind": "H.264-video-plus-AAC-audio-fixture", "durationSeconds": movieReadback.duration, "videoCodecs": movieReadback.videoCodecs, "videoFrameRate": movieReadback.videoFrameRate!, "videoFrameCount": 288, "audioCodecs": movieReadback.audioCodecs, "audioChannels": movieReadback.audioChannels!, "audioSampleRate": movieReadback.audioSampleRate!, "sha256": try sha256(movieURL)])
entries.append(["file": coverURL.lastPathComponent, "kind": "self-generated-CoreGraphics-PNG", "width": imageWidth, "height": imageHeight, "sha256": try sha256(coverURL)])

let manifest: [String: Any] = [
    "schemaVersion": "1.0",
    "generatedBy": "Native/ReviewMedia/generate-review-media.swift",
    "rights": "WindSheep project original generated fixture; no external music, text, or imagery.",
    "verification": "AVAsset duration, track codecs, frame rate, audio channels/sample rate, and PNG dimensions were read back after generation; this does not claim human listening or Store review approval.",
    "artifacts": entries
]
let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
try writeAll(manifestData, to: outputDirectory.appendingPathComponent("manifest.json"))
print("generated and verified \(entries.count) artifacts at \(outputDirectory.path)")
