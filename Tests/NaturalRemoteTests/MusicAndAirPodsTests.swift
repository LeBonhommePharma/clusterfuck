import XCTest
@testable import NaturalRemote

final class MusicAndAirPodsTests: XCTestCase {
    func testSpectralAnalyzerEntropyAndBPMFinite() {
        let analyzer = AudioSpectralAnalyzer(frameSize: 512)
        // 440 Hz-ish sine at 16 kHz
        let sr = 16000.0
        var samples = [Float]()
        samples.reserveCapacity(512)
        for n in 0..<512 {
            samples.append(Float(sin(2.0 * Double.pi * 440.0 * Double(n) / sr)))
        }
        let frame = analyzer.process(samples: samples, sampleRate: sr)
        XCTAssertTrue(frame.audioEntropyBits.isFinite)
        XCTAssertGreaterThanOrEqual(frame.audioEntropyBits, 0)
        XCTAssertTrue(frame.bpm.isFinite)
        XCTAssertGreaterThan(frame.rmsEnergy, 0)
        XCTAssertTrue(frame.spectralCentroidHz.isFinite)
    }

    func testDIFmChannelSelectionByBPM() async throws {
        let di = DIFmController()
        try await di.setTargetBPM(82)
        XCTAssertEqual(di.currentChannelId, "chillout")
        try await di.setTargetBPM(136)
        XCTAssertTrue(["trance", "techno", "progressive"].contains(di.currentChannelId))
        XCTAssertNotNil(di.streamURL(for: di.currentChannelId))
    }

    func testSpotifyHookReceivesActions() async throws {
        let spotify = SpotifyRemoteController()
        var seen: [String] = []
        spotify.transportHook = { action, _ in seen.append(action) }
        try await spotify.queueGroundingTrack()
        XCTAssertTrue(seen.contains("queueGrounding") || seen.contains("setTargetBPM"))
    }

    func testSonosRoomsAndVolumeCurve() async throws {
        let sonos = SonosController()
        sonos.setRooms(["Kitchen", "Den"])
        XCTAssertEqual(sonos.rooms.count, 2)
        var actions: [String] = []
        sonos.transportHook = { action, _ in actions.append(action) }
        try await sonos.execute(RemoteCommand(service: .sonos, action: "setVolumeCurve", params: ["mode": "dim"]))
        XCTAssertEqual(actions, ["setVolumeCurve"])
    }

    func testAirPodsH1VolumeAndPose() async throws {
        let h1 = AirPodsMaxH1Controller()
        h1.setCrownVolume(0.75)
        XCTAssertEqual(h1.currentTelemetry().volume, 0.75, accuracy: 1e-6)
        h1.setNoiseMode(.noiseCancellation)
        XCTAssertEqual(h1.currentTelemetry().noiseMode, .noiseCancellation)
        h1.injectHeadPose(HeadPose(pitch: 0.1, roll: 0.2, yaw: -0.3))
        XCTAssertEqual(h1.currentTelemetry().headPose?.yaw ?? 0, -0.3, accuracy: 1e-9)
        try await h1.execute(RemoteCommand(service: .airPods, action: "transparency"))
        XCTAssertEqual(h1.currentTelemetry().noiseMode, .transparency)
    }

    func testAirPodsH2BiometricsAndFlags() async throws {
        let h2 = AirPodsProH2Controller()
        h2.setAdaptiveAudio(true)
        h2.setPersonalizedSpatial(true)
        h2.setConversationAwareness(true)
        h2.ingestHeartRate(bpm: 72, rrIntervalsMs: [800, 810, 790, 805])
        let t = h2.currentTelemetry()
        XCTAssertEqual(t.chipGeneration, "H2")
        XCTAssertTrue(t.adaptiveAudioActive)
        XCTAssertTrue(t.personalizedSpatialEnabled)
        XCTAssertTrue(t.conversationAwarenessActive)
        XCTAssertEqual(t.heartRateBPM ?? 0, 72, accuracy: 1e-9)
        XCTAssertEqual(t.rrIntervalsMs.count, 4)
        var state = RemoteMultiSignalState()
        h2.apply(to: &state)
        XCTAssertTrue(state.conversationAwarenessActive)
    }

    func testAppleMusicActuatorActions() async throws {
        let am = AppleMusicController()
        try await am.setTargetBPM(88)
        let bpm = await am.lastBPMHint
        XCTAssertEqual(bpm, 88, accuracy: 1e-9)
    }
}
