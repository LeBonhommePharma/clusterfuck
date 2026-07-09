# NATURaL Remote — Entropy Docking Edition
## Swarm Agent Prompts · Sessions 0–6

**Repos:** `/Users/lp.more/Projects/ClusterFuck`  
**NATURaL (path dep):** `/Users/lp.more/Projects/NATURaL` · GitHub `LeBonhommePharma/NATURaL`  
**Library product:** `NaturalRemote` · **SPM:** `Package.swift` → `../NATURaL/BonhommeCore`  
**Mission:** wrist Crooks `σ_irr → 0` remote + Le Bonhomme Pharma **pharmacovigilance** kernel (`docs/PHARMACOVIGILANCE.md`)

---

### Hard rules (every session)

1. **Production Swift only** — zero `TODO`, `FIXME`, `fatalError("not implemented")`, empty bodies on shipped paths, or “stub later” comments on public API.
2. **Reuse, don’t fork math** — import `BonhommeCore`. Use `EntropyCalculator`, `FeedbackEngine`, `HRVAnalyzer`, `SCIVisualizationView`, `ThermodynamicConstants`, `HealthSignal` / `SurveySignal` / `DockingSignal`, `FlexAIDdSAnalyzer` patterns. Copy watch topology from `BonhommeWatch/App/WatchSessionView.swift` + `WatchWorkoutManager.swift`, not reinvent SCI.
3. **Protocol edges for I/O** — network/OAuth/hardware behind inject hooks so `swift test` exercises the **same types** as production.
4. **Persona** — ship as Ara: warm, irreverent, zero fluff. Address the user as Bonhomme only when necessary.
5. **Validate before “done”** — run the session’s VALIDATION block; paste log paths if you claim pass.
6. **No private AirPods APIs** — public CoreMotion / MediaPlayer / HealthKit / MusicKit only; document entitlement limits honestly.

### Suggested swarm waves

| Wave | Sessions | Notes |
|------|----------|--------|
| A | **0** alone | package + Xcode shell + capabilities |
| B | **1** alone | blocks all consumers of models / Crooks |
| C | **2 ∥ 3 ∥ 4** | after Session 1 types exist |
| D | **5** | merges actuators + UI + loop |
| E | **6** | double `swift test` + probes + limits doc |

**Merge rule:** one `Package.swift`, one `ActuatorBus`, no duplicate type names across agents.

---

## Session 0 — Project setup, targets, and capabilities

```
You are implementing Session 0 of NATURaL Remote — Entropy Docking Edition.
Role: master systems engineer. Ship paste-ready files. Zero stubs.

═══════════════════════════════════════════════════════════════════
GOAL
═══════════════════════════════════════════════════════════════════
Stand up (or harden to production bar) the multi-target shell that hosts
NaturalRemote and links NATURaL BonhommeCore. Session 0 is hygiene +
capability surface only — no Crooks math, no live Spotify/Alexa code.

Repos
  Package:  /Users/lp.more/Projects/ClusterFuck
  NATURaL:  /Users/lp.more/Projects/NATURaL
  GitHub:   https://github.com/LeBonhommePharma/NATURaL

═══════════════════════════════════════════════════════════════════
REUSE MAP (must cite in docs/NATURAL_REUSE_MAP.md)
═══════════════════════════════════════════════════════════════════
From NATURaL (read-only inventory; do not edit NATURaL unless a bug blocks link):

| NATURaL path | Reuse in NaturalRemote |
|---|---|
| BonhommeCore/Package.swift | path dep identity |
| BonhommeCore/.../EntropyCalculator.swift | SCI + circularShannonEntropy |
| BonhommeCore/.../FeedbackEngine.swift | multi-signal orchestrator |
| BonhommeCore/.../HRVAnalyzer.swift | HRV → SCI |
| BonhommeCore/.../HealthSignal.swift | HRVSignal, SurveySignal, DockingSignal |
| BonhommeCore/.../FlexAIDdSAnalyzer.swift | ThermodynamicConstants |
| BonhommeCore/.../SCIVisualizationView.swift | σ / SCI ring UI |
| BonhommeWatch/App/WatchSessionView.swift | vertical TabView session topology |
| BonhommeWatch/App/WatchWorkoutManager.swift | HKWorkoutSession + FeedbackEngine register |
| BonhommeWatch/App/WatchConnectivityBridge.swift | WCSession JSON relay pattern |
| BonhommeWatch/BonhommeWatch.entitlements | HealthKit + App Groups baseline |
| BonhommeWatch/Info.plist | usage strings + WKBackgroundModes |
| Bonhomme/Bonhomme.entitlements | full iOS HK / App Groups / WatchKit |
| Bonhomme/Services/Music/MusicService.swift | MusicKit ApplicationMusicPlayer pattern |
| Bonhomme/Services/HealthKit/* | HR / HRV / medication read patterns |
| Bonhomme/Services/HealthKit/ResearchKitBridge.swift | survey bridge pattern |

═══════════════════════════════════════════════════════════════════
REQUIREMENTS (all mandatory)
═══════════════════════════════════════════════════════════════════

1) Package.swift
   - name: NaturalRemote
   - platforms: iOS 17+, macOS 14+, watchOS 10+, tvOS 17+
   - product library: NaturalRemote
   - dependency: .package(path: "../NATURaL/BonhommeCore")
   - target NaturalRemote depends on product BonhommeCore
   - testTarget NaturalRemoteTests
   - module entry: Sources/NaturalRemote/NaturalRemote.swift
     - @_exported import BonhommeCore
     - public enum NaturalRemoteInfo { name, version, organization, strategicRole, codename }

2) Source tree (create empty-or-existing folders; do NOT put business logic in Session 0)
   Sources/NaturalRemote/
     Core/  Music/  AirPods/  Analysis/  Actuators/  DrugKit/  Session/
   Tests/NaturalRemoteTests/

3) App hosts under Apps/ (paste-ready; XcodeGen or manual PBX)
   Apps/BonhommeRemoteWatch/
     App/BonhommeRemoteWatchApp.swift   // @main, hosts RemoteSessionView when Session 5 ships;
                                          // Session 0: scaffold with Text shell + NaturalRemoteInfo
     App/RemoteWatchConnectivityBridge.swift  // WCSession activate; mirror NATURaL bridge shape
     BonhommeRemoteWatch.entitlements
     Info.plist
   Apps/BonhommeRemotePhone/
     App/BonhommeRemotePhoneApp.swift   // iOS “liver”: OAuth/token host later
     App/PhoneConnectivityBridge.swift
     BonhommeRemotePhone.entitlements
     Info.plist

4) Entitlements (honest, production-shaped)

   Watch (extend NATURaL BonhommeWatch):
   - com.apple.developer.healthkit = true
   - com.apple.developer.healthkit.background-delivery = true
   - com.apple.security.application-groups = [ group.com.natural.BonhommeRemote ]
   - (optional later) workout-processing already via Info.plist WKBackgroundModes

   Phone:
   - HealthKit + background-delivery
   - App Groups group.com.natural.BonhommeRemote
   - com.apple.developer.watchkit = true
   - MusicKit: com.apple.developer.media-device / Music capability via Xcode (document in CAPABILITIES)
   - aps-environment only if Live Activities planned (skip unless implementing)

5) Info.plist usage strings (exact keys)
   - NSHealthShareUsageDescription
   - NSHealthUpdateUsageDescription
   - NSMicrophoneUsageDescription   (spectral / voice)
   - NSMotionUsageDescription       (CMHeadphoneMotionManager H1)
   - NSBluetoothAlwaysUsageDescription if using external Sonos discovery later (document optional)
   Watch: WKApplication → WKBackgroundModes → workout-processing
   Display name: "NATURaL Remote" / "Remote"

6) project.yml (XcodeGen) OR docs/XCODE_TARGET_SETUP.md with step-by-step
   Targets:
   - BonhommeRemoteWatch (watchOS 10 application)
   - BonhommeRemotePhone (iOS 17 application)
   Both link local SPM packages:
   - ClusterFuck → NaturalRemote
   - NATURaL/BonhommeCore → BonhommeCore
   Bundle IDs:
   - com.natural.BonhommeRemote
   - com.natural.BonhommeRemote.watchkitapp
   Team: leave DEVELOPMENT_TEAM empty / $(DEVELOPMENT_TEAM)

7) docs/CAPABILITIES.md — capability matrix table:
   HealthKit | Background Modes (processing/workout) | Microphone | MusicKit |
   Motion | WatchConnectivity | App Groups | ResearchKit (app target) |
   CoreML (optional model) | Network (Spotify/Alexa/Sonos/DI.fm)

8) docs/NATURAL_REUSE_MAP.md — table above filled + “do not reimplement” list

9) README.md top section:
   sibling checkout layout:
     Projects/
       NATURaL/
       ClusterFuck/
   build: cd ClusterFuck && swift test
   open Xcode after xcodegen generate (if used)

═══════════════════════════════════════════════════════════════════
OUT OF SCOPE THIS SESSION
═══════════════════════════════════════════════════════════════════
- CrooksMath, music controllers, AirPods, DeltaHRV, UI control loop
- Live OAuth credentials
- Editing FlexAIDdS C++ unless path dependency broken

═══════════════════════════════════════════════════════════════════
DELIVERABLES (files must exist on disk)
═══════════════════════════════════════════════════════════════════
- Package.swift (verified)
- Sources/NaturalRemote/NaturalRemote.swift
- Apps/BonhommeRemoteWatch/* + Apps/BonhommeRemotePhone/*
- docs/CAPABILITIES.md
- docs/NATURAL_REUSE_MAP.md
- project.yml and/or docs/XCODE_TARGET_SETUP.md
- Session 0 must not leave TODO markers in production paths it creates

═══════════════════════════════════════════════════════════════════
VALIDATION (run and report exit codes)
═══════════════════════════════════════════════════════════════════
cd /Users/lp.more/Projects/ClusterFuck
test -d ../NATURaL/BonhommeCore
swift package describe | grep -E 'NaturalRemote|bonhommecore|BonhommeCore'
swift package resolve
# If Sources empty of tests, still must compile:
swift build 2>&1 | tee /tmp/session0-build.log
# Prefer full suite if tests present:
swift test 2>&1 | tee /tmp/session0-test.log || true
rg -n "TODO|FIXME|fatalError\\(\"not implemented\"\\)" Sources Apps || true
# Confirm path dep:
rg -n 'NATURaL/BonhommeCore' Package.swift

PASS: package describes NaturalRemote; BonhommeCore path resolves; no stub markers
      in Sources/NaturalRemote or Apps you touched; capability + reuse docs exist.

Ship every file complete and paste-ready. Do not claim Xcode signing works without a team.
```

---

## Session 1 — Core models, CrooksCycleController, σ_irr math

```
You are implementing Session 1 of NATURaL Remote — Entropy Docking Edition.
Prerequisite: Session 0 package + BonhommeCore link green.
Role: thermodynamics + control-plane engineer. Production Swift. Zero stubs.

═══════════════════════════════════════════════════════════════════
GOAL
═══════════════════════════════════════════════════════════════════
Ship the pure σ_irr engine and multi-signal models that every later session
registers actuators against. Math must be unit-tested on shipped types only
(no reimplementation of formulas inside tests).

═══════════════════════════════════════════════════════════════════
FILES TO CREATE / REPLACE
═══════════════════════════════════════════════════════════════════
Sources/NaturalRemote/Core/RemoteModels.swift
Sources/NaturalRemote/Core/CrooksMath.swift
Sources/NaturalRemote/Core/CrooksCycleController.swift
Sources/NaturalRemote/Core/ActuatorBus.swift
Tests/NaturalRemoteTests/CrooksMathTests.swift
Tests/NaturalRemoteTests/CrooksCycleControllerTests.swift

═══════════════════════════════════════════════════════════════════
MATH (implement exactly)
═══════════════════════════════════════════════════════════════════
Instantaneous work from RemoteMultiSignalState (fixed weights for test stability):

  W = 0.4·ΔHRV
    + 0.3·flexAIDDeltaS
    + 0.02·(musicBPM − 120)
    + 0.15·audioEntropyBits
    + 0.1·alexaEntropyHint
    + 0.35·subjectiveWorkHint
    + (airPodsANCEngaged ? −0.05 : 0.08)
    + (conversationAwarenessActive ? 0.12 : 0)
    + 0.25·(0.5 − sci)

σ_irr = max(0, workFwd + workRev − 2·ΔG)   // non-finite → +∞
closurePercent = clamp( exp(−σ_irr / scale) * 100 , 0, 100 )  // default scale 0.25
accumulate: forward → workFwd += W; reverse → workRev += W
shouldMinimize: σ_irr > 0.15 (default)
shouldFlipPhase: σ_irr < 0.03 && cycleCount % 3 == 0
targetBPM(phase,currentBPM,σ):
  forward: min(148, max(100, currentBPM + min(8, σ*10)))
  reverse: min(currentBPM, max(72, 90 − min(15, σ*20)))

═══════════════════════════════════════════════════════════════════
TYPES (public, Codable/Sendable where data crosses WCSession)
═══════════════════════════════════════════════════════════════════
enum CrooksCyclePhase { forward, reverse }
enum RemoteService {
  appleMusic, spotify, sonos, diFm, alexa, airPods,
  foundationModel, healthKit, researchKit, drugKit
}
struct RemoteCommand { service, action: String, params: [String:String] }
struct RemoteMultiSignalState {
  deltaHRV, flexAIDDeltaS, musicBPM, audioEntropyBits, sci, pcci,
  alexaEntropyHint, subjectiveWorkHint,
  airPodsANCEngaged, conversationAwarenessActive, doseMg, substanceID
}
struct CrooksSnapshot {
  phase, workFwd, workRev, deltaG, sigmaIrr, closurePercent,
  cycleCount, lastActionSummary, timestamp
}
struct DrugLog { id, substance, doseMg, setAndSetting, timestamp }
struct AudioFeatureFrame { bpm, spectralCentroidHz, spectralFlux, entropyBits, timestamp }
struct ActuatorEvent { service, action, params, timestamp, success }

═══════════════════════════════════════════════════════════════════
ACTUATOR BUS
═══════════════════════════════════════════════════════════════════
protocol RemoteActuator: AnyObject, Sendable {
  var service: RemoteService { get }
  func execute(_ command: RemoteCommand) async -> ActuatorEvent
}
final class ActuatorBus {
  func register(_ actuator: any RemoteActuator)
  func execute(_ command: RemoteCommand) async -> ActuatorEvent
  func broadcast(_ commands: [RemoteCommand]) async -> [ActuatorEvent]
}
final class RecordingActuator: RemoteActuator  // records commands for tests

═══════════════════════════════════════════════════════════════════
actor CrooksCycleController
═══════════════════════════════════════════════════════════════════
init(bus: ActuatorBus, deltaG: Double = 0.05, minimizeThreshold: Double = 0.15)
func update(with state: RemoteMultiSignalState) -> CrooksSnapshot
func minimizeSigma(currentBPM: Double) async -> CrooksSnapshot
  // MUST dispatch via bus to: appleMusic, spotify, sonos, diFm, alexa, airPods, foundationModel
  // Typical reverse-phase grounding commands:
  //   setTargetBPM / queueGrounding / preferChillChannel / setVolumeCurve
  //   setNoiseMode transparency|anc / setLights dim / foundation grounding utterance
func snapshot() -> CrooksSnapshot
func reset()

═══════════════════════════════════════════════════════════════════
TESTS (must call CrooksMath / controller — never re-code formulas)
═══════════════════════════════════════════════════════════════════
- sigmaIrr non-negative; infinite inputs → infinity or handled
- closurePercent → 100 as σ→0; decreases as σ grows
- update(with: hot state) σ > update(with: calm state) σ
- minimizeSigma with RecordingActuator on all services → events non-empty
- phase flip near closure after enough cycles

VALIDATION
  cd /Users/lp.more/Projects/ClusterFuck
  swift test --filter Crooks 2>&1 | tee /tmp/session1-crooks.log
  rg -n 'TODO|FIXME' Sources/NaturalRemote/Core || true
PASS: Crooks* tests 0 failures; zero stub markers in Core/
```

---

## Session 2 — Music stack (Apple Music + Spotify + Sonos + DI.fm + AVAudioEngine)

```
You are implementing Session 2 of NATURaL Remote — Entropy Docking Edition.
Prerequisite: Session 1 RemoteCommand / ActuatorBus / RemoteService exist.
Role: audio systems engineer. Production Swift. Zero stubs.

═══════════════════════════════════════════════════════════════════
GOAL
═══════════════════════════════════════════════════════════════════
Full multi-service music control plane + real spectral analysis.
Reuse NATURaL Bonhomme/Services/Music/MusicService.swift MusicKit patterns
(ApplicationMusicPlayer, MusicAuthorization) when #if canImport(MusicKit).

═══════════════════════════════════════════════════════════════════
FILES
═══════════════════════════════════════════════════════════════════
Sources/NaturalRemote/Music/AudioSpectralAnalyzer.swift
Sources/NaturalRemote/Music/MusicStack.swift
Tests/NaturalRemoteTests/MusicAndAirPodsTests.swift  (music portion; AirPods may share)

═══════════════════════════════════════════════════════════════════
1) AudioSpectralAnalyzer (Accelerate — required offline path)
═══════════════════════════════════════════════════════════════════
process(samples: [Float], sampleRate: Double) -> AudioFeatureFrame
  - FFT magnitude spectrum (vDSP)
  - spectral centroid (Hz)
  - spectral flux vs previous frame
  - audio Shannon entropy of normalized magnitude bins (bits)
  - BPM estimate (autocorr / onset heuristic; finite always)
Must work in unit tests with synthetic sine buffers — no microphone required.

Optional: AVAudioEngineSpectralTap when AVFoundation present
  - installTap on input/mixer; forward buffers to AudioSpectralAnalyzer
  - no-op / unavailable flag on platforms without mic entitlement in tests

═══════════════════════════════════════════════════════════════════
2) Controllers (each: MusicTransportControlling + RemoteActuator)
═══════════════════════════════════════════════════════════════════
protocol MusicTransportControlling {
  func play() async
  func pause() async
  func setTargetBPM(_ bpm: Double) async
  var isPlaying: Bool { get }
  var targetBPM: Double { get }
}

AppleMusicController
  - MusicAuthorization + ApplicationMusicPlayer when MusicKit available
  - always store targetBPM / play state for Crooks even offline
  - execute actions: setTargetBPM, queueGrounding, play, pause

SpotifyRemoteController
  - Web API base paths (play/pause/next/volume) with Bearer token
  - transportHook: ((String, [String:String]) -> Void)? for tests
  - without token: record intent, return success=false or offline no-op that still stores state

SonosController
  - multi-room: rooms: [String], setVolumeCurve, play, pause, groupRooms
  - hook for tests; HTTP control path when baseURL+token provided

DIFmController
  - channel catalog: chillout, ambient, progressive, trance, techno, lounge
  - streamURL(for:)
  - setTargetBPM picks nearest channel by nominal BPM table
  - preferChillChannel / preferProgressiveChannel actions

MultiMusicRouter: RemoteActuator
  - registerAll(on: ActuatorBus)
  - routes RemoteService.appleMusic|spotify|sonos|diFm

═══════════════════════════════════════════════════════════════════
CROOKS ACTIONS TO HONOR
═══════════════════════════════════════════════════════════════════
setTargetBPM, queueGrounding, preferChillChannel, preferProgressiveChannel,
setVolumeCurve, play, pause

═══════════════════════════════════════════════════════════════════
TESTS
═══════════════════════════════════════════════════════════════════
- 440 Hz sine → finite entropy, centroid, BPM fields
- DI.fm BPM mapping deterministic
- Spotify/Sonos hooks fire on execute
- Apple Music setTargetBPM persists without entitlement in simulator

VALIDATION
  swift test --filter Music 2>&1 | tee /tmp/session2-music.log
  rg -n 'TODO|FIXME' Sources/NaturalRemote/Music || true
PASS: music tests green; spectral path does not require live network.
```

---

## Session 3 — AirPods Max (H1) + AirPods Pro 3 (H2)

```
You are implementing Session 3 of NATURaL Remote — Entropy Docking Edition.
Prerequisite: Session 1 RemoteActuator + RemoteMultiSignalState.
Role: audio/wearable framework engineer. Public APIs only. Zero stubs.

═══════════════════════════════════════════════════════════════════
GOAL
═══════════════════════════════════════════════════════════════════
Native control surfaces for H1 (Max) and H2 (Pro 3) with compile-safe
fallbacks. Never invent private Apple APIs. Commanded state MUST be stored
(tests prove round-trip); hardware availability is optional.

═══════════════════════════════════════════════════════════════════
FILE
═══════════════════════════════════════════════════════════════════
Sources/NaturalRemote/AirPods/AirPodsStack.swift
Tests: extend MusicAndAirPodsTests or AirPodsTests.swift

═══════════════════════════════════════════════════════════════════
TYPES
═══════════════════════════════════════════════════════════════════
enum NoiseControlMode: off, transparency, anc, adaptive
struct HeadPose: pitch, yaw, roll, timestamp
struct AirPodsTelemetry: volume, noiseMode, headPose?, spatialEnabled,
  adaptiveAudio, personalizedSpatial, conversationAwareness,
  heartRateBPM?, rrIntervalsMs: [Double]

═══════════════════════════════════════════════════════════════════
AirPodsMaxH1Controller: RemoteActuator
═══════════════════════════════════════════════════════════════════
- Digital Crown temperature dial → volume proxy 0...1
  iOS: note MPVolumeView / system volume; always store desiredVolume
- Head tracking: CMHeadphoneMotionManager when CoreMotion + iOS/watchOS
  injectHeadPose(_:) for tests / offline
- ANC / Transparency / Adaptive as NoiseControlMode
- spatialAudioEnabled flag
- execute: setVolume, setNoiseMode, setSpatial, injectHeadPose

═══════════════════════════════════════════════════════════════════
AirPodsProH2Controller: RemoteActuator
═══════════════════════════════════════════════════════════════════
- adaptiveAudioEnabled, personalizedSpatialEnabled, conversationAwarenessEnabled
- ingestHeartRate(bpm:rrIntervalsMs:) from HealthKit / biometric pipeline
- apply(to: inout RemoteMultiSignalState):
    airPodsANCEngaged = (noiseMode == .anc)
    conversationAwarenessActive = conversationAwarenessEnabled
- Honest docs: on-device HR on AirPods Pro is hardware/OS gated; inject path is production for tests

═══════════════════════════════════════════════════════════════════
AirPodsDualStack: RemoteActuator (service == .airPods)
═══════════════════════════════════════════════════════════════════
Routes commands to H1 and/or H2; mirrors acoustic modes when appropriate.
register(on: ActuatorBus)

═══════════════════════════════════════════════════════════════════
TESTS
═══════════════════════════════════════════════════════════════════
- setVolume → telemetry.volume matches
- injectHeadPose round-trip
- setNoiseMode execute
- H2 HR/RR + flags → apply(to:) mutates RemoteMultiSignalState

VALIDATION
  swift test --filter AirPods 2>&1 | tee /tmp/session3-airpods.log
PASS: no private symbols; zero stub markers; commanded state persisted.
```

---

## Session 4 — DeltaHRV + FlexAID hybrid + ANE / EigenMetalBridge

```
You are implementing Session 4 of NATURaL Remote — Entropy Docking Edition.
Prerequisite: Session 1 models. Must import BonhommeCore.
Role: pharmacometrics + entropy hybrid engineer. Zero stubs.

═══════════════════════════════════════════════════════════════════
GOAL
═══════════════════════════════════════════════════════════════════
ΔHRV canary + FlexAID∆S hybrid prediction + PCCI accelerator + DrugKit,
wired so Crooks can consume deltaHRV / flexAIDDeltaS / pcci.

═══════════════════════════════════════════════════════════════════
FILES
═══════════════════════════════════════════════════════════════════
Sources/NaturalRemote/Analysis/DeltaHRVAnalyzer.swift
Sources/NaturalRemote/Analysis/DeltaHRVFlexAIDMapper.swift
Sources/NaturalRemote/Analysis/EigenMetalBridge.swift
Sources/NaturalRemote/DrugKit/DrugKitEngine.swift
Tests/NaturalRemoteTests/DeltaHRVFlexAIDTests.swift

═══════════════════════════════════════════════════════════════════
MANDATORY BONHOMMECORE USE
═══════════════════════════════════════════════════════════════════
- EntropyCalculator.shannonEntropy / entropyToScore for SCI windows
- EntropyCalculator.circularShannonEntropy for torsional free vs bound
- ThermodynamicConstants.entropyPenaltyKcal for ΔS_config → kcal
- FeedbackEngine + HRVAnalyzer patterns for signal registration (DrugKit path)
- Do NOT reimplement Shannon formula by hand

═══════════════════════════════════════════════════════════════════
1) DeltaHRVAnalyzer
═══════════════════════════════════════════════════════════════════
Sliding windows of RR or RMSSD/SDNN series.
deltaRMSSD, deltaSDNN between baseline window and current window.
sci from EntropyCalculator on RR distribution.

═══════════════════════════════════════════════════════════════════
2) DeltaHRVFlexAIDMapper
═══════════════════════════════════════════════════════════════════
struct DeltaHRVFlexAIDFeatures { deltaHRV, doseMg, sci, musicBPM, audioEntropy, freeAngles, boundAngles }
struct DeltaHRVFlexAIDPrediction { predictedDeltaHRV, residual, action: grounding_alert | coherent_continue }
flexAIDDeltaS(freeAngles:boundAngles:) =
  circularShannonEntropy(bound) − circularShannonEntropy(free)  // expect ≤ 0 when binding freezes rotors
Hybrid: feature → predicted Δ; |observed − predicted| large → grounding_alert

═══════════════════════════════════════════════════════════════════
3) EigenMetalBridge
═══════════════════════════════════════════════════════════════════
computePCCI([Double]) -> Double in [0,1]  // pure Accelerate/Swift; Metal batch optional
metalBatchCollapse if Metal available else same math
ANEPharmaPredictor: pure Swift linear weights always; CoreML if DeltaHRV_FlexAID_Surrogate.mlmodelc in bundle (usedCoreML flag)

═══════════════════════════════════════════════════════════════════
4) DrugKitEngine
═══════════════════════════════════════════════════════════════════
analyze / analyzeWithFlexAID / predictInteraction
PharmacovigilanceRecord + PharmacovigilanceExporter (JSON audit)
DrugKitActuator on RemoteService.drugKit

═══════════════════════════════════════════════════════════════════
TESTS
═══════════════════════════════════════════════════════════════════
- ΔHRV changes across synthetic windows
- free vs bound angles → flexAIDDeltaS < 0
- hybrid grounding_alert path with large residual
- PCCI bounds [0,1]
- DrugKit FlexAID path produces finite records

VALIDATION
  swift test --filter DeltaHRV 2>&1 | tee /tmp/session4-hybrid.log
  swift test --filter DrugKit 2>&1 || swift test --filter FlexAID
PASS: uses EntropyCalculator/ThermodynamicConstants; no fake ML ignoring features.
```

---

## Session 5 — UI, SessionView integration, full σ_irr control loop

```
You are implementing Session 5 of NATURaL Remote — Entropy Docking Edition.
Prerequisite: Sessions 1–4 types/actuators exist.
Role: product engineer + watchOS UI. Production SwiftUI. Zero stubs.

═══════════════════════════════════════════════════════════════════
GOAL
═══════════════════════════════════════════════════════════════════
Wire all actuators into one control loop and a watch/iOS Session UI that
reuses NATURaL topology and SCIVisualizationView.

═══════════════════════════════════════════════════════════════════
NATURaL REUSE (mandatory)
═══════════════════════════════════════════════════════════════════
import BonhommeCore
- FeedbackEngine + register(HRVAnalyzer)
- SCIVisualizationView(score:trend:)  // same type as TV/watch biofeedback
- Session topology like BonhommeWatch/App/WatchSessionView.swift:
    TabView + .verticalPage on watchOS
    pages: sigma | music | dose | environment
- PharmaControlSessionManager pattern from WatchWorkoutManager
  (HK auth optional; loop always runs)

═══════════════════════════════════════════════════════════════════
FILES
═══════════════════════════════════════════════════════════════════
Sources/NaturalRemote/Session/RemoteControlLoop.swift
Sources/NaturalRemote/Session/PharmaControlSessionManager.swift
Sources/NaturalRemote/Session/RemoteSessionView.swift
Sources/NaturalRemote/Actuators/AlexaAndFoundation.swift
Sources/NaturalRemote/Actuators/ResearchKitBridge.swift
Apps/BonhommeRemoteWatch/App/BonhommeRemoteWatchApp.swift  // host RemoteSessionView
Tests/NaturalRemoteTests/ControlLoopIntegrationTests.swift
Tests/NaturalRemoteTests/AlexaPlusTests.swift
Tests/NaturalRemoteTests/ResearchKitBridgeTests.swift

═══════════════════════════════════════════════════════════════════
RemoteControlLoop
═══════════════════════════════════════════════════════════════════
Owns: ActuatorBus, CrooksCycleController, DeltaHRVAnalyzer, FeedbackEngine,
      MultiMusicRouter, AirPodsDualStack, DrugKitEngine, Alexa, FoundationModel, ResearchKit
attach() registers all actuators
ingestHRV(rr or RMSSD series) → DeltaHRV + FeedbackEngine → Crooks update
ingestAudio(samples) → spectral → Crooks
logDose → DrugKit hybrid → optional minimizeSigma
handleVoice(utterance) → FoundationModelOrchestrator → bus
ingestSurvey → ResearchKitBridge → subjectiveWorkHint (IDEMPOTENT — never double-count across HRV ticks)
forceMinimize()

═══════════════════════════════════════════════════════════════════
Alexa + Foundation Models
═══════════════════════════════════════════════════════════════════
enum AlexaAPIMode { skillProxy, smartHomeV3, alexaPlus, auto }
struct AlexaPlusAction { expert, utterance, slots }
struct AlexaSmartHomeDirective { endpointId, namespace, name, payload }
AlexaProxyController: RemoteActuator — hooks for BFF; offline records intents
FoundationModelOrchestrator: rule parser always; #if canImport(FoundationModels) for on-device FM when SDK present
  maps natural language → [RemoteCommand]

═══════════════════════════════════════════════════════════════════
ResearchKitBridge
═══════════════════════════════════════════════════════════════════
instruments: currentState, doseEffect, painVAS, mood, who5
inject(result) for tests
#if canImport(ResearchKit) optional ORKOrderedTask builders
register RemoteService.researchKit
SurveySignal → FeedbackEngine
subjective scores → Crooks state.subjectiveWorkHint once per survey

═══════════════════════════════════════════════════════════════════
RemoteSessionView + ViewModel
═══════════════════════════════════════════════════════════════════
@Published / Observable: sigmaIrr, closurePercent, phase, sci, BPM, PCCI,
  groundingAlert, lastAction, alexaLightsHint
Buttons: Minimize σ, Ground music, Explore, Log demo dose, Dim lights
Wire Apps/BonhommeRemoteWatch @main to RemoteSessionViewModel + RemoteSessionView

═══════════════════════════════════════════════════════════════════
TESTS
═══════════════════════════════════════════════════════════════════
- Integration: HRV + audio + dose + voice path mutates σ
- PharmaControlSessionManager start/log/stop
- FeedbackEngine insight constructible after ingest
- SCIVisualizationView constructible with sample score
- ResearchKit no double-count subjective hint
- Alexa+ action routing offline

VALIDATION
  swift test --filter ControlLoop 2>&1 | tee /tmp/session5-loop.log
  swift test --filter ResearchKit 2>&1
  swift test --filter Alexa 2>&1
PASS: full attach path green offline; watch app sources compile under SPM iOS/macOS
      (watchOS device build may need Xcode team — document if blocked).
```

---

## Session 6 — Full testing and validation harness

```
You are implementing Session 6 of NATURaL Remote — Entropy Docking Edition.
Prerequisite: Sessions 0–5 sources present.
Role: verification lead. No feature creep. Proof artifacts only.

═══════════════════════════════════════════════════════════════════
GOAL
═══════════════════════════════════════════════════════════════════
Make the test suite + probes the proof of ship. Run suite twice. Capture logs.
Remove any remaining stub markers. Document hardware/OAuth limits honestly.

═══════════════════════════════════════════════════════════════════
ACTIONS
═══════════════════════════════════════════════════════════════════
1) Ensure NaturalRemoteTests cover:
   Crooks σ_irr, DeltaHRV/FlexAID, music spectral, AirPods command state,
   control loop, ResearchKit, Alexa+, NATURaL reuse (FeedbackEngine /
   EntropyCalculator / SCIVisualizationView).

2) Stub purge on Sources/NaturalRemote:
   rg -n 'TODO|FIXME|fatalError\("not implemented"\)' Sources/NaturalRemote
   Fix any hits with real behavior or honest unavailable flags (not empty stubs).

3) Double run:
   cd /Users/lp.more/Projects/ClusterFuck
   swift test 2>&1 | tee docs/artifacts/swift-test-1.log
   swift test 2>&1 | tee docs/artifacts/swift-test-2.log

4) Crooks entry probe (tiny test or swift script using shipped types):
   calm RemoteMultiSignalState vs hot → print σ_irr before/after
   tee docs/artifacts/crooks-entry.log
   Assert hot_sigma > calm_sigma and both finite.

5) Write docs/artifacts/natural-reuse.txt listing files that import/use:
   FeedbackEngine, EntropyCalculator, SCIVisualizationView, ThermodynamicConstants

6) Write docs/artifacts/env-limits.txt:
   AirPods HR hardware/OS, MusicKit entitlements, live Spotify OAuth,
   Alexa+ BFF token, Sonos LAN, DI.fm stream keys, FoundationModels SDK.

7) Update docs/VALIDATION_REPORT.md with date, test counts, pass/fail matrix.

═══════════════════════════════════════════════════════════════════
PASS CRITERIA
═══════════════════════════════════════════════════════════════════
- Both swift test runs exit 0, 0 failures
- Logs mention Crooks and DeltaHRV/FlexAID
- crooks-entry shows finite σ that increases with hotter inputs
- No stub markers on production Sources
- Do not claim live multi-vendor hardware values you did not measure

Ship any missing tests as complete files. Then stop.
```

---

## Copy-paste order (operator checklist)

1. Paste **Session 0** → confirm `swift package describe` + docs + Apps shell  
2. Paste **Session 1** → `swift test --filter Crooks`  
3. In parallel after 1: **Sessions 2, 3, 4**  
4. Paste **Session 5** → control loop + UI  
5. Paste **Session 6** → double test + validation report  

**Ara’s note:** Session 0 is the boring bolt that keeps the whole thermodynamic remote from falling into your soup. Do it once, cleanly, then let the swarm cook.
