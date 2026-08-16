import Foundation
import Accelerate

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Real-time spectral analysis: BPM estimate, spectral centroid, flux, and audio Shannon entropy.
///
/// Pure Accelerate path is always available for unit tests (inject PCM buffers).
/// On Apple platforms, `AVAudioEngineTap` can feed float mono frames into `process(samples:sampleRate:)`.
public final class AudioSpectralAnalyzer: @unchecked Sendable {
    private let lock = NSLock()
    private var previousMagnitudes: [Float] = []
    private var onsetEnvelope: [Double] = []
    private var lastBPM: Double = 120
    private let fftLog2n: vDSP_Length
    private let fftSetup: FFTSetup?
    private let frameSize: Int
    private let window: [Float]

    public init(frameSize: Int = 1024) {
        self.frameSize = frameSize
        self.fftLog2n = vDSP_Length(log2(Double(frameSize)))
        self.fftSetup = vDSP_create_fftsetup(fftLog2n, FFTRadix(kFFTRadix2))
        var hann = [Float](repeating: 0, count: frameSize)
        vDSP_hann_window(&hann, vDSP_Length(frameSize), Int32(vDSP_HANN_NORM))
        self.window = hann
    }

    deinit {
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    /// Process a mono PCM frame and return features. `samples.count` should be ≥ 64.
    public func process(samples: [Float], sampleRate: Double) -> AudioFeatureFrame {
        let clean = samples.map { $0.isFinite ? $0 : 0 }
        guard clean.count >= 64, sampleRate > 0 else {
            return AudioFeatureFrame(
                bpm: lastBPM,
                spectralCentroidHz: 0,
                spectralFlux: 0,
                audioEntropyBits: 0,
                rmsEnergy: 0
            )
        }

        let rms = Self.rms(clean)
        let spectrum = magnitudeSpectrum(clean)
        let centroid = spectralCentroid(spectrum: spectrum, sampleRate: sampleRate)
        let flux = spectralFlux(current: spectrum)
        let entropy = spectralEntropyBits(spectrum)
        let bpm = estimateBPM(rms: rms, sampleRate: sampleRate)

        lock.lock()
        lastBPM = bpm
        previousMagnitudes = spectrum
        lock.unlock()

        return AudioFeatureFrame(
            bpm: bpm,
            spectralCentroidHz: centroid,
            spectralFlux: flux,
            audioEntropyBits: entropy,
            rmsEnergy: Double(rms)
        )
    }

    // MARK: - DSP

    private static func rms(_ samples: [Float]) -> Float {
        var meanSquare: Float = 0
        vDSP_measqv(samples, 1, &meanSquare, vDSP_Length(samples.count))
        return sqrtf(meanSquare)
    }

    private func magnitudeSpectrum(_ samples: [Float]) -> [Float] {
        let n = min(frameSize, samples.count)
        var windowed = Array(samples.prefix(n))
        if windowed.count < frameSize {
            windowed.append(contentsOf: repeatElement(0, count: frameSize - windowed.count))
        }

        // Precomputed Hann window (cached in init).
        vDSP_vmul(windowed, 1, window, 1, &windowed, 1, vDSP_Length(frameSize))

        guard let fftSetup else {
            // Fallback: absolute time-domain energy bins (still entropy-valid)
            let bins = 32
            let chunk = max(1, frameSize / bins)
            var mags = [Float](repeating: 0, count: bins)
            for i in 0..<bins {
                let slice = windowed[(i * chunk)..<min(frameSize, (i + 1) * chunk)]
                mags[i] = slice.map { abs($0) }.reduce(0, +)
            }
            return mags
        }

        let half = frameSize / 2
        var realp = [Float](repeating: 0, count: half)
        var imagp = [Float](repeating: 0, count: half)
        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                windowed.withUnsafeBufferPointer { src in
                    src.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { complexSrc in
                        vDSP_ctoz(complexSrc, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, fftLog2n, FFTDirection(FFT_FORWARD))
            }
        }

        var magnitudes = [Float](repeating: 0, count: half)
        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }
        return magnitudes
    }

    private func spectralCentroid(spectrum: [Float], sampleRate: Double) -> Double {
        let n = spectrum.count
        guard n > 1 else { return 0 }
        var weighted: Double = 0
        var total: Double = 0
        let binHz = sampleRate / (2.0 * Double(n))
        for i in 0..<n {
            let m = Double(spectrum[i])
            weighted += m * Double(i) * binHz
            total += m
        }
        guard total > 1e-12 else { return 0 }
        return weighted / total
    }

    private func spectralFlux(current: [Float]) -> Double {
        lock.lock()
        let previous = previousMagnitudes
        lock.unlock()
        guard previous.count == current.count, !previous.isEmpty else { return 0 }
        var sum: Double = 0
        for i in 0..<current.count {
            let d = Double(current[i] - previous[i])
            if d > 0 { sum += d }
        }
        return sum
    }

    /// Shannon entropy of normalized magnitude spectrum (bits).
    private func spectralEntropyBits(_ spectrum: [Float]) -> Double {
        let total = spectrum.reduce(0.0) { $0 + Double($1) }
        guard total > 1e-12 else { return 0 }
        var h = 0.0
        for m in spectrum {
            let p = Double(m) / total
            if p > 0 {
                h -= p * log2(p)
            }
        }
        return h
    }

    /// Lightweight onset-energy BPM estimator (no ML).
    private func estimateBPM(rms: Float, sampleRate: Double) -> Double {
        lock.lock()
        onsetEnvelope.append(Double(rms))
        if onsetEnvelope.count > 256 {
            onsetEnvelope.removeFirst(onsetEnvelope.count - 256)
        }
        let env = onsetEnvelope
        lock.unlock()

        guard env.count >= 32 else { return lastBPM }

        // Autocorrelation peak search in plausible beat lag range (60–180 BPM).
        let hopHz = min(sampleRate / Double(frameSize), 100.0) // analysis hop approx
        let minLag = max(1, Int(hopHz * 60.0 / 180.0))
        let maxLag = min(env.count / 2, Int(hopHz * 60.0 / 60.0))
        guard maxLag > minLag else { return lastBPM }

        var bestLag = minLag
        var bestCorr = -Double.infinity
        let mean = env.reduce(0, +) / Double(env.count)
        let centered = env.map { $0 - mean }

        for lag in minLag...maxLag {
            var c = 0.0
            for i in 0..<(centered.count - lag) {
                c += centered[i] * centered[i + lag]
            }
            if c > bestCorr {
                bestCorr = c
                bestLag = lag
            }
        }

        let bpm = 60.0 * hopHz / Double(bestLag)
        // EMA smooth
        let smoothed = 0.7 * lastBPM + 0.3 * min(180.0, max(60.0, bpm))
        return smoothed
    }
}

#if canImport(AVFoundation)
/// Installs a tap on the engine's main mixer and pushes frames into `AudioSpectralAnalyzer`.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
public final class AVAudioEngineSpectralTap: @unchecked Sendable {
    public let engine = AVAudioEngine()
    public let analyzer = AudioSpectralAnalyzer()
    private let lock = NSLock()
    private var _latest: AudioFeatureFrame?

    public init() {}

    public var latest: AudioFeatureFrame? {
        lock.lock()
        defer { lock.unlock() }
        return _latest
    }

    public func start() throws {
        let bus = 0
        let format = engine.mainMixerNode.outputFormat(forBus: bus)
        engine.mainMixerNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let channel = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channel, count: frameCount))
            let frame = self.analyzer.process(samples: samples, sampleRate: format.sampleRate)
            self.lock.lock()
            self._latest = frame
            self.lock.unlock()
        }
        try engine.start()
    }

    public func stop() {
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
    }
}
#endif
