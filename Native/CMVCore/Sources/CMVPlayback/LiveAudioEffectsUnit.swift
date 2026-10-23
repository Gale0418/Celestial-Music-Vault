import AVFoundation
import AudioToolbox
import Synchronization
import CMVDomain

/// The custom live part of the effects graph. The Audio Unit owns its delay
/// state on the render thread; control writes are atomic and never allocate,
/// lock, hop to an actor, or touch the player's sample rate.
final class CMVLiveAudioEffectsUnit: AUAudioUnit {
    static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: 0x434D5646, // "CMVF"
        componentManufacturer: 0x434D5631, // "CMV1"
        // kAudioComponentFlag_SandboxSafe is 2 in AudioToolbox's public API.
        componentFlags: 2,
        componentFlagsMask: 0
    )

    private var inputBus: AUAudioUnitBus
    private var outputBus: AUAudioUnitBus
    private var inputBusArray: AUAudioUnitBusArray!
    private var outputBusArray: AUAudioUnitBusArray!
    private var renderSampleRate: Double = 48_000
    private var delayLeft = UnsafeMutablePointer<Float>?.none
    private var delayRight = UnsafeMutablePointer<Float>?.none
    private var delayCapacity = 0
    private var writeIndex = 0

    private let widthBits = Atomic<UInt64>(Double(1).bitPattern)
    private let orbitBits = Atomic<UInt64>(Double(0).bitPattern)
    private let cassetteBits = Atomic<UInt64>(Double(0).bitPattern)
    private let cassetteDelayBits = Atomic<UInt64>(Double(0.012).bitPattern)

    // These values are touched only by the render callback after resources
    // are allocated. They provide click-free parameter slew at block edges.
    private var currentWidth: Float = 1
    private var currentOrbit: Float = 0
    private var currentCassette: Float = 0
    private var orbitPhase: Double = 0
    private var cassettePhase: Double = 0

    @MainActor private static var didRegister = false

    @MainActor static func makeAVAudioUnit() -> AVAudioUnitEffect {
        if !didRegister {
            AUAudioUnit.registerSubclass(
                self,
                as: Self.componentDescription,
                name: "CMV: Live Effects",
                version: 1
            )
            didRegister = true
        }
        return AVAudioUnitEffect(audioComponentDescription: Self.componentDescription)
    }

    override init(componentDescription: AudioComponentDescription,
                  options: AudioComponentInstantiationOptions = []) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2) else {
            throw NSError(domain: "CMVLiveAudioEffectsUnit", code: 1)
        }
        inputBus = try AUAudioUnitBus(format: format)
        outputBus = try AUAudioUnitBus(format: format)
        try super.init(componentDescription: componentDescription, options: options)
        inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        inputBus.shouldAllocateBuffer = false
        outputBus.shouldAllocateBuffer = false
    }

    override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    override var outputBusses: AUAudioUnitBusArray { outputBusArray }

    /// Changes the graph format before render resources are allocated. The
    /// music player keeps its historical 48 kHz format; video renderers use
    /// this hook for the source track's 44.1/48 kHz PCM format.
    func setProcessingFormat(_ format: AVAudioFormat) throws {
        guard format.channelCount == 2,
              format.commonFormat == .pcmFormatFloat32,
              !format.isInterleaved,
              format.sampleRate.isFinite,
              format.sampleRate > 0 else {
            throw NSError(domain: "CMVLiveAudioEffectsUnit", code: 3)
        }
        guard !renderResourcesAllocated else {
            throw NSError(domain: "CMVLiveAudioEffectsUnit", code: 4)
        }
        try inputBus.setFormat(format)
        try outputBus.setFormat(format)
    }

    func update(settings: AudioEffectsSettings) {
        let validated = settings.validated
        let parameters = validated.effectiveParameters.validated
        let intensity = validated.intensity
        let orbit = validated.preset == .orbit ? intensity : 0
        let cassette = validated.preset == .cassette ? intensity : 0
        let width = 1 + (parameters.width - 1) * intensity
        store(width: width, orbit: orbit, cassette: cassette, cassetteDelay: parameters.delay / 1_000)
    }

    private func store(width: Double, orbit: Double, cassette: Double, cassetteDelay: Double) {
        widthBits.store(width.bitPattern, ordering: .relaxed)
        orbitBits.store(orbit.bitPattern, ordering: .relaxed)
        cassetteBits.store(cassette.bitPattern, ordering: .relaxed)
        cassetteDelayBits.store(cassetteDelay.bitPattern, ordering: .relaxed)
    }

    override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        guard inputBus.format.channelCount == 2,
              inputBus.format.commonFormat == .pcmFormatFloat32,
              !inputBus.format.isInterleaved else {
            throw NSError(domain: "CMVLiveAudioEffectsUnit", code: 2)
        }
        renderSampleRate = max(8_000, inputBus.format.sampleRate)
        delayCapacity = max(2, Int(min(0.5, 2) * renderSampleRate) + 2)
        delayLeft = .allocate(capacity: delayCapacity)
        delayRight = .allocate(capacity: delayCapacity)
        delayLeft?.initialize(repeating: 0, count: delayCapacity)
        delayRight?.initialize(repeating: 0, count: delayCapacity)
        writeIndex = 0
        currentWidth = 1
        currentOrbit = 0
        currentCassette = 0
        orbitPhase = 0
        cassettePhase = 0
    }

    override func deallocateRenderResources() {
        delayLeft?.deinitialize(count: delayCapacity)
        delayRight?.deinitialize(count: delayCapacity)
        delayLeft?.deallocate()
        delayRight?.deallocate()
        delayLeft = nil
        delayRight = nil
        delayCapacity = 0
        super.deallocateRenderResources()
    }

    override var internalRenderBlock: AUInternalRenderBlock {
        { [unowned(unsafe) self] flags, timestamp, frameCount, _, outputData, _, pullInput in
            guard let pullInput else { return kAudio_ParamError }
            let status = pullInput(flags, timestamp, frameCount, 0, outputData)
            guard status == noErr else { return status }
            return self.render(outputData, frameCount: Int(frameCount))
        }
    }

    private func render(_ outputData: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) -> AUAudioUnitStatus {
        guard frameCount >= 0, delayCapacity > 1,
              let leftDelay = delayLeft, let rightDelay = delayRight else { return kAudio_ParamError }
        let buffers = UnsafeMutableAudioBufferListPointer(outputData)
        guard buffers.count > 0, buffers.allSatisfy({ $0.mData != nil }) else { return kAudio_ParamError }
        let targetWidth = Float(Self.value(widthBits)).clamped(to: 0...2)
        let targetOrbit = Float(Self.value(orbitBits)).clamped(to: 0...1)
        let targetCassette = Float(Self.value(cassetteBits)).clamped(to: 0...1)
        let targetDelay = Float(Self.value(cassetteDelayBits)).clamped(to: 0...0.5)
        let slew = 1 / max(1, Float(renderSampleRate) * 0.025)
        let channelCount = Int(buffers[0].mNumberChannels)
        guard channelCount > 0 else { return noErr }

        for frame in 0..<frameCount {
            currentWidth += (targetWidth - currentWidth) * slew
            currentOrbit += (targetOrbit - currentOrbit) * slew
            currentCassette += (targetCassette - currentCassette) * slew
            let sample = readStereo(buffers, frame: frame, channelCount: channelCount)
            let preCassetteLeft = sample.left
            let preCassetteRight = sample.right
            let mid = (preCassetteLeft + preCassetteRight) * 0.5
            let side = (preCassetteLeft - preCassetteRight) * 0.5 * currentWidth
            var left = mid + side
            var right = mid - side
            let orbitPan = Float(sin(orbitPhase)) * currentOrbit
            orbitPhase.formTruncatingRemainder(dividingBy: 2 * Double.pi)
            orbitPhase += 2 * Double.pi / (42 * renderSampleRate)
            if currentOrbit > 0.0001 {
                // Balance the existing stereo signal: downmixing to `mid`
                // here would erase anti-phase material at full intensity.
                left *= sqrt(max(0, 1 - orbitPan))
                right *= sqrt(max(0, 1 + orbitPan))
            }
            let delay = Double(targetDelay) + sin(cassettePhase) * 0.0015 * Double(currentCassette)
            cassettePhase.formTruncatingRemainder(dividingBy: 2 * Double.pi)
            cassettePhase += 2 * Double.pi * 4.7 / renderSampleRate
            let delayed = readDelay(leftDelay, rightDelay, index: writeIndex, delay: delay * renderSampleRate)
            leftDelay[writeIndex] = preCassetteLeft
            rightDelay[writeIndex] = preCassetteRight
            left += (delayed.left - left) * currentCassette * 0.35
            right += (delayed.right - right) * currentCassette * 0.35
            writeIndex += 1
            if writeIndex == delayCapacity { writeIndex = 0 }
            writeStereo(buffers, frame: frame, channelCount: channelCount, left: left, right: right)
        }
        return noErr
    }

    private static func value(_ atomic: borrowing Atomic<UInt64>) -> Double {
        Double(bitPattern: atomic.load(ordering: .relaxed))
    }

    private func readStereo(_ buffers: UnsafeMutableAudioBufferListPointer, frame: Int, channelCount: Int) -> (left: Float, right: Float) {
        if buffers.count >= 2 {
            guard let leftData = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightData = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return (0, 0) }
            let left = leftData[frame]
            let right = rightData[frame]
            return (left, right)
        }
        guard let values = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return (0, 0) }
        let left = values[frame * channelCount]
        let right = channelCount > 1 ? values[frame * channelCount + 1] : left
        return (left, right)
    }

    private func writeStereo(_ buffers: UnsafeMutableAudioBufferListPointer, frame: Int,
                             channelCount: Int, left: Float, right: Float) {
        if buffers.count >= 2 {
            guard let leftData = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightData = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return }
            leftData[frame] = left
            rightData[frame] = right
        } else {
            guard let values = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return }
            values[frame * channelCount] = left
            if channelCount > 1 { values[frame * channelCount + 1] = right }
        }
    }

    private func readDelay(_ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>,
                           index: Int, delay: Double) -> (left: Float, right: Float) {
        let bounded = min(Double(delayCapacity - 1), max(0, delay))
        let position = Double(index) - bounded
        let base = Int(floor(position)).positiveModulo(delayCapacity)
        let next = (base + 1) % delayCapacity
        let fraction = Float(position - floor(position))
        return (
            left[base] * (1 - fraction) + left[next] * fraction,
            right[base] * (1 - fraction) + right[next] * fraction
        )
    }
}

private extension Int {
    func positiveModulo(_ divisor: Int) -> Int {
        let value = self % divisor
        return value >= 0 ? value : value + divisor
    }
}

private extension BinaryFloatingPoint {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
