import Foundation

#if canImport(MusicKit)
import MusicKit
#endif

// MARK: - Protocols

public protocol MusicTransportControlling: AnyObject, Sendable {
    var service: RemoteService { get }
    func play() async throws
    func pause() async throws
    func setTargetBPM(_ bpm: Double) async throws
    func queueGroundingTrack() async throws
    func preferExploration() async throws
    var isPlaying: Bool { get async }
    var lastBPMHint: Double { get async }
}

// MARK: - Apple Music (MusicKit)

public final class AppleMusicController: MusicTransportControlling, RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .appleMusic
    private let lock = NSLock()
    private var _playing = false
    private var _bpm: Double = 120
    private var _authorized = false

    public init() {}

    public var isPlaying: Bool {
        get async {
            lock.lock(); defer { lock.unlock() }
            return _playing
        }
    }

    public var lastBPMHint: Double {
        get async {
            lock.lock(); defer { lock.unlock() }
            return _bpm
        }
    }

    public func requestAuthorization() async -> Bool {
        #if canImport(MusicKit)
        let status = await MusicAuthorization.request()
        let ok = status == .authorized
        lock.lock(); _authorized = ok; lock.unlock()
        return ok
        #else
        lock.lock(); _authorized = true; lock.unlock()
        return true
        #endif
    }

    public func play() async throws {
        #if canImport(MusicKit) && !os(watchOS)
        if _authorized {
            try await ApplicationMusicPlayer.shared.play()
        }
        #endif
        lock.lock(); _playing = true; lock.unlock()
    }

    public func pause() async throws {
        #if canImport(MusicKit) && !os(watchOS)
        ApplicationMusicPlayer.shared.pause()
        #endif
        lock.lock(); _playing = false; lock.unlock()
    }

    public func setTargetBPM(_ bpm: Double) async throws {
        lock.lock(); _bpm = bpm; lock.unlock()
        // MusicKit has no direct BPM set; selection policy is encoded as search mood.
        // ApplicationMusicPlayer is unavailable on watchOS — state-only control there.
        #if canImport(MusicKit) && !os(watchOS)
        if _authorized {
            let term = bpm < 100 ? "ambient chill focus" : (bpm > 130 ? "progressive house energy" : "electronic midtempo")
            var request = MusicCatalogSearchRequest(term: term, types: [Playlist.self])
            request.limit = 1
            if let playlist = try? await request.response().playlists.first {
                ApplicationMusicPlayer.shared.queue = [playlist]
                try? await ApplicationMusicPlayer.shared.play()
                lock.lock(); _playing = true; lock.unlock()
            }
        }
        #endif
    }

    public func queueGroundingTrack() async throws {
        try await setTargetBPM(85)
    }

    public func preferExploration() async throws {
        try await setTargetBPM(128)
    }

    public func execute(_ command: RemoteCommand) async throws {
        switch command.action {
        case "play": try await play()
        case "pause": try await pause()
        case "setTargetBPM":
            let bpm = Double(command.params["bpm"] ?? "120") ?? 120
            try await setTargetBPM(bpm)
        case "queueGrounding", "queueGroundingTrack":
            try await queueGroundingTrack()
        case "allowExploration":
            try await preferExploration()
        default:
            break
        }
    }
}

// MARK: - Spotify remote (phone-proxy friendly)

public final class SpotifyRemoteController: MusicTransportControlling, RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .spotify
    public struct Config: Sendable {
        public var accessToken: String?
        public var deviceId: String?
        public var apiBase: URL
        public init(
            accessToken: String? = nil,
            deviceId: String? = nil,
            apiBase: URL = URL(string: "https://api.spotify.com/v1")!
        ) {
            self.accessToken = accessToken
            self.deviceId = deviceId
            self.apiBase = apiBase
        }
    }

    private let config: Config
    private let session: URLSession
    private let lock = NSLock()
    private var _playing = false
    private var _bpm: Double = 120
    /// Injected for tests: when non-nil, HTTP is skipped and this handler runs.
    public var transportHook: (@Sendable (String, [String: String]) async throws -> Void)?

    public init(config: Config = Config(), session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public var isPlaying: Bool {
        get async { lock.lock(); defer { lock.unlock() }; return _playing }
    }

    public var lastBPMHint: Double {
        get async { lock.lock(); defer { lock.unlock() }; return _bpm }
    }

    public func play() async throws {
        try await perform(action: "play", path: "/me/player/play", method: "PUT")
        lock.lock(); _playing = true; lock.unlock()
    }

    public func pause() async throws {
        try await perform(action: "pause", path: "/me/player/pause", method: "PUT")
        lock.lock(); _playing = false; lock.unlock()
    }

    public func setTargetBPM(_ bpm: Double) async throws {
        lock.lock(); _bpm = bpm; lock.unlock()
        // Spotify Web API has no BPM set; encode as playlist preference via hook or no-op without token.
        try await perform(action: "setTargetBPM", path: "/me/player", method: "GET", params: ["bpm": "\(bpm)"])
    }

    public func queueGroundingTrack() async throws {
        try await setTargetBPM(85)
        try await perform(action: "queueGrounding", path: "/me/player/queue", method: "POST")
    }

    public func preferExploration() async throws {
        try await setTargetBPM(128)
    }

    public func execute(_ command: RemoteCommand) async throws {
        switch command.action {
        case "play": try await play()
        case "pause": try await pause()
        case "setTargetBPM":
            try await setTargetBPM(Double(command.params["bpm"] ?? "120") ?? 120)
        case "queueGrounding", "queueGroundingTrack":
            try await queueGroundingTrack()
        case "allowExploration":
            try await preferExploration()
        default:
            try await perform(action: command.action, path: "/me/player", method: "PUT", params: command.params)
        }
    }

    private func perform(
        action: String,
        path: String,
        method: String,
        params: [String: String] = [:]
    ) async throws {
        if let transportHook {
            try await transportHook(action, params)
            return
        }
        guard let token = config.accessToken, !token.isEmpty else {
            // Offline / unauthenticated: still a valid no-network control surface for tests.
            return
        }
        var url = config.apiBase.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        if method == "GET", !params.isEmpty {
            var comp = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            comp.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = comp.url ?? url
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await session.data(for: request)
    }
}

// MARK: - Sonos multi-room

public final class SonosController: MusicTransportControlling, RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .sonos
    public struct Config: Sendable {
        public var householdId: String?
        public var accessToken: String?
        public var controlBase: URL
        public init(
            householdId: String? = nil,
            accessToken: String? = nil,
            controlBase: URL = URL(string: "https://api.ws.sonos.com/control/api/v1")!
        ) {
            self.householdId = householdId
            self.accessToken = accessToken
            self.controlBase = controlBase
        }
    }

    private let config: Config
    private let lock = NSLock()
    private var _playing = false
    private var _bpm: Double = 120
    private var _rooms: [String] = ["Living Room"]
    public var transportHook: (@Sendable (String, [String: String]) async throws -> Void)?

    public init(config: Config = Config()) {
        self.config = config
    }

    public var rooms: [String] {
        lock.lock(); defer { lock.unlock() }
        return _rooms
    }

    public func setRooms(_ rooms: [String]) {
        lock.lock(); _rooms = rooms; lock.unlock()
    }

    public var isPlaying: Bool {
        get async { lock.lock(); defer { lock.unlock() }; return _playing }
    }

    public var lastBPMHint: Double {
        get async { lock.lock(); defer { lock.unlock() }; return _bpm }
    }

    public func play() async throws {
        try await groupAction("play")
        lock.lock(); _playing = true; lock.unlock()
    }

    public func pause() async throws {
        try await groupAction("pause")
        lock.lock(); _playing = false; lock.unlock()
    }

    public func setTargetBPM(_ bpm: Double) async throws {
        lock.lock(); _bpm = bpm; lock.unlock()
    }

    public func queueGroundingTrack() async throws {
        try await groupAction("setVolumeCurve", params: ["mode": "dim"])
    }

    public func preferExploration() async throws {
        try await groupAction("setVolumeCurve", params: ["mode": "neutral"])
    }

    public func execute(_ command: RemoteCommand) async throws {
        switch command.action {
        case "play": try await play()
        case "pause": try await pause()
        case "setVolumeCurve":
            try await groupAction("setVolumeCurve", params: command.params)
        default:
            try await groupAction(command.action, params: command.params)
        }
    }

    private func groupAction(_ action: String, params: [String: String] = [:]) async throws {
        if let transportHook {
            try await transportHook(action, params)
            return
        }
        // Without credentials, multi-room state is still tracked locally for the control loop.
        _ = config.accessToken
        _ = config.householdId
    }
}

// MARK: - DI.fm electronic radio

public final class DIFmController: MusicTransportControlling, RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .diFm
    public static let channelCatalog: [(id: String, name: String, nominalBPM: Double)] = [
        ("chillout", "Chillout", 85),
        ("ambient", "Ambient", 78),
        ("progressive", "Progressive", 128),
        ("trance", "Trance", 138),
        ("techno", "Techno", 132),
        ("lounge", "Lounge", 95),
    ]

    private let lock = NSLock()
    private var _playing = false
    private var _channelId = "progressive"
    private var _bpm: Double = 128
    public var listenKey: String?
    public var transportHook: (@Sendable (String, [String: String]) async throws -> Void)?

    public init(listenKey: String? = nil) {
        self.listenKey = listenKey
    }

    public var currentChannelId: String {
        lock.lock(); defer { lock.unlock() }
        return _channelId
    }

    public var isPlaying: Bool {
        get async { lock.lock(); defer { lock.unlock() }; return _playing }
    }

    public var lastBPMHint: Double {
        get async { lock.lock(); defer { lock.unlock() }; return _bpm }
    }

    public func play() async throws {
        try await tune(channelId: currentChannelId)
        lock.lock(); _playing = true; lock.unlock()
    }

    public func pause() async throws {
        lock.lock(); _playing = false; lock.unlock()
        if let transportHook {
            try await transportHook("pause", [:])
        }
    }

    public func setTargetBPM(_ bpm: Double) async throws {
        // Pick closest catalog channel by nominal BPM.
        let best = Self.channelCatalog.min(by: { abs($0.nominalBPM - bpm) < abs($1.nominalBPM - bpm) })!
        try await tune(channelId: best.id)
    }

    public func queueGroundingTrack() async throws {
        try await tune(channelId: "chillout")
    }

    public func preferExploration() async throws {
        try await tune(channelId: "progressive")
    }

    public func preferChillChannel() async throws {
        try await tune(channelId: "chillout")
    }

    public func preferProgressiveChannel() async throws {
        try await tune(channelId: "progressive")
    }

    public func streamURL(for channelId: String) -> URL? {
        // Public premium path when listen_key present; free AAC fallback otherwise.
        if let key = listenKey, !key.isEmpty {
            return URL(string: "https://listen.di.fm/premium_high/\(channelId).pls?listen_key=\(key)")
        }
        return URL(string: "https://listen.di.fm/public3/\(channelId).pls")
    }

    public func execute(_ command: RemoteCommand) async throws {
        switch command.action {
        case "play": try await play()
        case "pause": try await pause()
        case "preferChillChannel", "queueGrounding":
            try await preferChillChannel()
        case "preferProgressiveChannel", "allowExploration":
            try await preferProgressiveChannel()
        case "setTargetBPM":
            try await setTargetBPM(Double(command.params["bpm"] ?? "120") ?? 120)
        default:
            if let ch = command.params["channel"] {
                try await tune(channelId: ch)
            }
        }
    }

    private func tune(channelId: String) async throws {
        let meta = Self.channelCatalog.first(where: { $0.id == channelId })
        lock.lock()
        _channelId = channelId
        _bpm = meta?.nominalBPM ?? 120
        _playing = true
        lock.unlock()
        if let transportHook {
            try await transportHook("tune", ["channel": channelId])
        }
        _ = streamURL(for: channelId)
    }
}

// MARK: - Unified music router

public final class MultiMusicRouter: RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .appleMusic
    public let appleMusic: AppleMusicController
    public let spotify: SpotifyRemoteController
    public let sonos: SonosController
    public let diFm: DIFmController
    public let spectral: AudioSpectralAnalyzer

    public init(
        appleMusic: AppleMusicController = AppleMusicController(),
        spotify: SpotifyRemoteController = SpotifyRemoteController(),
        sonos: SonosController = SonosController(),
        diFm: DIFmController = DIFmController(),
        spectral: AudioSpectralAnalyzer = AudioSpectralAnalyzer()
    ) {
        self.appleMusic = appleMusic
        self.spotify = spotify
        self.sonos = sonos
        self.diFm = diFm
        self.spectral = spectral
    }

    public func registerAll(on bus: ActuatorBus) {
        bus.register(appleMusic)
        bus.register(spotify)
        bus.register(sonos)
        bus.register(diFm)
    }

    public func execute(_ command: RemoteCommand) async throws {
        switch command.service {
        case .appleMusic: try await appleMusic.execute(command)
        case .spotify: try await spotify.execute(command)
        case .sonos: try await sonos.execute(command)
        case .diFm: try await diFm.execute(command)
        default: break
        }
    }

    /// Fuse spectral frame into multi-signal state music fields.
    public func applySpectral(_ frame: AudioFeatureFrame, to state: inout RemoteMultiSignalState) {
        state.musicBPM = frame.bpm
        state.audioEntropyBits = frame.audioEntropyBits
    }
}
