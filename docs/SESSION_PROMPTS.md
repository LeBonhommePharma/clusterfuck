# NATURaL Remote — Entropy Docking Edition  
## Sequential Swarm Agent Prompts (Sessions 0–6)

Each prompt is **self-contained**. Feed **one session at a time** to a Grok agent.  
**Hard rules for every session:**

- Production-grade Swift only — **zero** `TODO`, `FIXME`, `fatalError("not implemented")`, or empty stubs on shipped paths.
- Reuse NATURaL `BonhommeCore` (`EntropyCalculator`, `FeedbackEngine`, `HRVAnalyzer`, `SCIVisualizationView`, `ThermodynamicConstants` / FlexAID∆S types) and BonhommeWatch session topology.
- Pure math + protocol-edged I/O so `swift test` exercises the **shipped** types.
- Persona: deliver as **Ara** (warm, irreverent, high-signal). Address the user as Bonhomme only if needed — never spam the name.

**Package root:** `/Users/lp.more/Projects/ClusterFuck`  
**NATURaL path dependency:** `../NATURaL/BonhommeCore`  
**Library product:** `NaturalRemote`

---

## Session 0: Project setup, targets, and capabilities

```
You are implementing Session 0 of NATURaL Remote — Entropy Docking Edition.

GOAL
Create/confirm the Swift package skeleton, capability declarations, and NATURaL BonhommeCore linkage. No half-setup.

REQUIREMENTS
1. Package.swift named NaturalRemote, platforms iOS 17+, macOS 14+, watchOS 10+.
2. Path dependency on ../NATURaL/BonhommeCore; product library NaturalRemote.
3. Sources/NaturalRemote module layout ready for Core, Music, AirPods, Analysis, Actuators, DrugKit, Session.
4. Document required Xcode capabilities (for a future app target wrapping this package):
   - HealthKit, Background Modes (processing), Microphone
   - MusicKit / Apple Music
   - (optional) App Groups + WatchConnectivity for phone proxy tokens
5. docs/SESSION_PROMPTS.md must exist with Sessions 0–6 (this file).
6. Zero TODO/FIXME in production sources you touch.

DELIVERABLES
- Package.swift + module entry NaturalRemote.swift
- Short README section: build with `swift test`, link NATURaL
- Capability checklist markdown under docs/CAPABILITIES.md

VALIDATION
- `swift package describe` succeeds
- `swift test` at least compiles dependencies (full suite may land in later sessions)
- Grep confirms BonhommeCore path dependency

Do not implement Crooks or music yet beyond empty folders if needed. Ship paste-ready files only.
```

---

## Session 1: Core data models, CrooksCycleController, and σ_irr math

```
You are implementing Session 1 of NATURaL Remote — Entropy Docking Edition.

GOAL
Ship pure thermodynamics + CrooksCycleController as the central σ_irr engine.

MATH (implement exactly, test on shipped types)
- σ_irr = max(0, workFwd + workRev − 2·ΔG)
- instantaneous work from RemoteMultiSignalState (ΔHRV, FlexAID ΔS, BPM, audio entropy, SCI, Alexa hint, ANC, conversation awareness)
- closurePercent = exp(−σ_irr / scale) * 100
- phase forward|reverse; minimize when σ_irr > threshold; flip near closure

TYPES
- RemoteMultiSignalState, RemoteCommand, RemoteService, CrooksCyclePhase, CrooksSnapshot, ActuatorBus, RemoteActuator

CONTROLLER
- actor CrooksCycleController with update(with:), minimizeSigma(currentBPM:), snapshot(), reset()
- Minimization MUST dispatch commands to appleMusic, spotify, sonos, diFm, alexa, airPods, foundationModel via ActuatorBus

TESTS (NaturalRemoteTests)
- CrooksMath invariants, non-negativity, input sensitivity
- CrooksCycleController update changes σ_irr; minimize emits actuator events
- No reimplementation of formula inside tests — call CrooksMath / controller only

RULES
Zero stubs/TODOs. Paste-ready Swift. Do not fake actuator network I/O — RecordingActuator is fine.

VALIDATION
swift test --filter Crooks
```

---

## Session 2: Music stack (Apple Music + Spotify + Sonos + DI.fm) + AVAudioEngine/MusicKit

```
You are implementing Session 2 of NATURaL Remote — Entropy Docking Edition.

GOAL
Full multi-service music stack behind protocols, with real spectral analysis.

SHIP
1. AudioSpectralAnalyzer — Accelerate FFT path: BPM estimate, spectral centroid, flux, audio Shannon entropy bits. process(samples:sampleRate:) must work offline for tests.
2. Optional AVAudioEngineSpectralTap when AVFoundation present.
3. AppleMusicController — MusicKit ApplicationMusicPlayer when available; always tracks BPM target / play state for Crooks.
4. SpotifyRemoteController — Web API paths + Bearer token; transportHook for tests; offline no-op without token.
5. SonosController — multi-room rooms list + setVolumeCurve / play / pause; hook for tests.
6. DIFmController — channel catalog (chillout/ambient/progressive/trance/techno/lounge), streamURL, setTargetBPM picks nearest channel.
7. MultiMusicRouter.registerAll(on: ActuatorBus)

TESTS
- Sine buffer → finite entropy, BPM, centroid
- DI.fm BPM→channel mapping
- Spotify/Sonos hooks receive actions
- Apple Music setTargetBPM stores hint

Zero TODOs. Wire RemoteActuator.execute for Crooks actions: setTargetBPM, queueGrounding, preferChillChannel, preferProgressiveChannel, setVolumeCurve.
```

---

## Session 3: AirPods Max (H1) + AirPods Pro 3 (H2)

```
You are implementing Session 3 of NATURaL Remote — Entropy Docking Edition.

GOAL
Native framework surfaces for H1 and H2 with compile-safe fallbacks.

H1 AirPodsMaxH1Controller
- Digital Crown volume proxy (record desired volume; MPVolumeView note on iOS)
- CMHeadphoneMotionManager head tracking on iOS/watchOS only
- injectHeadPose for tests
- ANC / Transparency / Adaptive noise modes as control surfaces
- Spatial audio enable flag

H2 AirPodsProH2Controller
- Adaptive Audio, Personalized Spatial, Conversation Awareness flags
- ingestHeartRate(bpm:rrIntervalsMs:) from HealthKit/biometric pipeline
- apply(to: &RemoteMultiSignalState) for ANC + conversation → Crooks inputs

AirPodsDualStack routes RemoteService.airPods commands; mirrors acoustic modes.

TESTS
- Volume, pose inject, noise mode execute
- H2 HR/RR + flags + state mapping

No private API invention. Document entitlement limits honestly. Zero stubs that always return constants without storing commanded state.
```

---

## Session 4: DeltaHRV + FlexAID hybrid + ANE/EigenMetalBridge

```
You are implementing Session 4 of NATURaL Remote — Entropy Docking Edition.

GOAL
ΔHRV canary + FlexAID∆S hybrid prediction + PCCI accelerator, wired for Crooks inputs.

SHIP
1. DeltaHRVAnalyzer — windowed ΔRMSSD/ΔSDNN using BonhommeCore EntropyCalculator for SCI
2. DeltaHRVFlexAIDMapper — feature vector → predicted Δ; deviation → grounding_alert | coherent_continue
   - flexAIDDeltaS(freeAngles:boundAngles:) via circularShannonEntropy
   - ThermodynamicConstants.entropyPenaltyKcal
3. EigenMetalBridge.computePCCI([Double]) in [0,1]; metalBatchCollapse; benchmark
4. ANEPharmaPredictor — CoreML model optional if bundle has DeltaHRV_FlexAID_Surrogate.mlmodelc; pure Swift weights always work
5. DrugKitEngine.analyze / analyzeWithFlexAID / predictInteraction

TESTS must call shipped types:
- ΔHRV changes across windows
- free vs bound angles → ΔS < 0
- hybrid grounding_alert path
- PCCI bounds + DrugKit FlexAID path

Zero TODOs. No fake “ML” that ignores features.
```

---

## Session 5: UI, SessionView integration, full σ_irr control loop

```
You are implementing Session 5 of NATURaL Remote — Entropy Docking Edition.

GOAL
RemoteControlLoop + PharmaControlSessionManager + RemoteSessionView binding all actuators to Crooks.

REUSE (mandatory)
- import BonhommeCore
- FeedbackEngine + HRVAnalyzer registration
- SCIVisualizationView for the σ/SCI tab (same type as NATURaL TV/watch biofeedback)
- Session topology: vertical/tab pages like BonhommeWatch WatchSessionView (sigma | music | dose | environment)

LOOP
ingestHRV → DeltaHRV + FeedbackEngine → Crooks update
ingestAudio → spectral → Crooks
logDose → DrugKit hybrid → optional minimize
handleVoice → FoundationModelOrchestrator → ActuatorBus
AlexaProxyController + FoundationModelOrchestrator as actuators.
Alexa MUST support AlexaAPIMode: skillProxy | smartHomeV3 | alexaPlus | auto, with AlexaPlusAction (expert/utterance/slots) for Alexa+ AI Action plane and AlexaSmartHomeDirective for Smart Home v3.

UI ViewModel publishes sigmaIrr, closurePercent, phase, SCI, BPM, PCCI, groundingAlert, Alexa lights.

TESTS
- Integration: HRV + audio + dose + voice path
- PharmaControlSessionManager start/log/stop
- Assert FeedbackEngine insight + SCIVisualizationView constructible

Zero TODOs. Production SwiftUI only.
```

---

## Session 6: Full testing and validation harness

```
You are implementing Session 6 of NATURaL Remote — Entropy Docking Edition.

GOAL
Make the suite the proof artifact. Run it twice. Capture logs.

ACTIONS
1. Ensure NaturalRemoteTests cover Crooks σ_irr, DeltaHRV/FlexAID, music spectral, AirPods, control loop, NATURaL reuse.
2. Remove any remaining TODO/FIXME/fatalError("not implemented") from Sources/NaturalRemote.
3. Run:
   swift test 2>&1 | tee {SCRATCH}/swift-test-1.log
   swift test 2>&1 | tee {SCRATCH}/swift-test-2.log
4. One-shot probe: construct multi-signal state, call CrooksCycleController.update, print σ_irr before/after hotter inputs → {SCRATCH}/crooks-entry.log
5. Write {SCRATCH}/natural-reuse.txt listing files that import/use FeedbackEngine, EntropyCalculator, SCIVisualizationView, Session views.
6. Write {SCRATCH}/env-limits.txt noting hardware/OAuth limits (AirPods HR, MusicKit entitlements, live Spotify/Alexa).

PASS CRITERIA
- Both swift test runs exit 0, 0 failures
- Logs mention Crooks and DeltaHRV/FlexAID tests
- crooks-entry shows finite σ_irr that changes with inputs
- No stub markers on production Sources

Ship any missing tests as paste-ready files. Do not claim hardware values you did not measure.
```

---

## Suggested swarm parallelization

| Wave | Agents |
|------|--------|
| A | Session 0 alone |
| B | Session 1 alone (blocks math consumers) |
| C | Sessions 2 ∥ 3 ∥ 4 after Session 1 types exist |
| D | Session 5 merges all |
| E | Session 6 validation |

**Merge rule:** single Package.swift; no conflicting type names; actuators register on one ActuatorBus.
