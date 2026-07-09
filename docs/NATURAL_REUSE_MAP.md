# NATURaL → NaturalRemote reuse map

**Source:** `/Users/lp.more/Projects/NATURaL` · [LeBonhommePharma/NATURaL](https://github.com/LeBonhommePharma/NATURaL)  
**Consumer:** `/Users/lp.more/Projects/ClusterFuck` (`NaturalRemote`)

## Rule

Do **not** reimplement Shannon entropy, SCI scoring, FeedbackEngine orchestration, or SCI ring UI. Import `BonhommeCore` and call the shipped types.

## Inventory

| NATURaL path | Symbol / pattern | NaturalRemote consumer |
|---|---|---|
| `BonhommeCore/Package.swift` | SPM product `BonhommeCore` | `ClusterFuck/Package.swift` path dep `../NATURaL/BonhommeCore` |
| `.../Analysis/EntropyCalculator.swift` | `shannonEntropy`, `circularShannonEntropy`, `entropyToScore` | `DeltaHRVAnalyzer`, `DeltaHRVFlexAIDMapper`, `EigenMetalBridge`, spectral entropy parallels audio domain only |
| `.../Analysis/FeedbackEngine.swift` | `register`, `ingest`, `analyzeAll` | `RemoteControlLoop`, `ResearchKitBridge`, `PharmaControlSessionManager` |
| `.../Analysis/HRVAnalyzer.swift` | `SignalAnalyzer` for HRV → SCI | registered in control loop |
| `.../Analysis/HealthSignal.swift` | `HRVSignal`, `SurveySignal`, `DockingSignal`, `MedicationSignal` | ResearchKit + DrugKit + dose path |
| `.../Analysis/FlexAIDdSAnalyzer.swift` | `ThermodynamicConstants`, ΔS_config patterns | `DeltaHRVFlexAIDMapper`, `DrugKitEngine` |
| `.../Analysis/SignalAnalyzer.swift` | analyzer protocol | any new analyzers conform |
| `.../TVDisplay/SCIVisualizationView.swift` | `SCIVisualizationView(score:trend:)` | `RemoteSessionView` sigma tab |
| `.../TVDisplay/TVDisplayPayload.swift` | biofeedback snapshot shape | WCSession payloads (optional) |
| `BonhommeWatch/App/WatchSessionView.swift` | vertical `TabView` session topology | `RemoteSessionView` pages |
| `BonhommeWatch/App/WatchWorkoutManager.swift` | `HKWorkoutSession` + `FeedbackEngine` | `PharmaControlSessionManager` |
| `BonhommeWatch/App/WatchConnectivityBridge.swift` | WCSession activate / throttle | `Apps/.../RemoteWatchConnectivityBridge` |
| `BonhommeWatch/BonhommeWatch.entitlements` | HealthKit + App Groups | `Apps/BonhommeRemoteWatch/*.entitlements` |
| `BonhommeWatch/Info.plist` | HK usage + `workout-processing` | Remote watch Info.plist |
| `Bonhomme/Bonhomme.entitlements` | full iOS HK / WatchKit / groups | phone companion entitlements |
| `Bonhomme/Services/Music/MusicService.swift` | MusicKit `ApplicationMusicPlayer` | `AppleMusicController` |
| `Bonhomme/Services/HealthKit/*` | HR / HRV / medication | session + DrugKit inputs |
| `Bonhomme/Services/HealthKit/ResearchKitBridge.swift` | survey bridge | `ResearchKitBridge` |

## Do not reimplement

- Shannon histogram entropy (use `EntropyCalculator`)
- SCI ring drawing (use `SCIVisualizationView`)
- Feedback multi-buffer orchestration (use `FeedbackEngine`)
- `ThermodynamicConstants.entropyPenaltyKcal` (single source of truth)
- Pose/yoga catalog (out of scope for Remote)

## Sibling layout (required)

```
/Users/lp.more/Projects/
  NATURaL/                 # BonhommeCore + Xcode multi-target app
  ClusterFuck/             # NaturalRemote SPM + Remote app shells
```

GitHub NATURaL is the upstream of the path dependency; ClusterFuck does not vendor BonhommeCore sources.
