# NATURaL Remote — Entropy Docking Edition

**Repo codename:** `ClusterFuck` · **Org trajectory:** candidate **main pharmacovigilance tool for Le Bonhomme Pharma**.

Wrist-oriented **Crooks σ_irr minimization** control stack: multi-service music, **Alexa + Alexa+** (AI Action / Smart Home v3 / skill proxy), AirPods H1/H2 surfaces, Foundation Model routing, HealthKit/DrugKit, DeltaHRV ↔ FlexAID∆S hybrid, reusing **NATURaL BonhommeCore** (`EntropyCalculator`, `FeedbackEngine`, `HRVAnalyzer`, `SCIVisualizationView`).

This is not “just a media remote.” Dose logs, ΔHRV, hybrid predictions, actuator events, and σ_irr trajectories are first-class **pharmacovigilance signals** — exposure, outcome, intervention, audit. See [`docs/PHARMACOVIGILANCE.md`](docs/PHARMACOVIGILANCE.md).

## Sibling layout (required)

```
/Users/lp.more/Projects/
  NATURaL/          # https://github.com/LeBonhommePharma/NATURaL
  ClusterFuck/      # this repo — path dep ../NATURaL/BonhommeCore
  ShannonUI/Exergy/ # remaining-quota tracker (sibling; not this remote)
```

## Build & test (SPM kernel)

```bash
cd /Users/lp.more/Projects/ClusterFuck
swift package describe
swift test
python3 scripts/test_contracts.py
python3 scripts/validate-submission.py
```

## App hosts (Session 0)

```bash
# Optional XcodeGen
brew install xcodegen
xcodegen generate
open BonhommeRemote.xcodeproj
```

| Target | Path | Bundle ID |
|---|---|---|
| Watch | `Apps/BonhommeRemoteWatch` | `com.natural.BonhommeRemote.watchkitapp` |
| Phone | `Apps/BonhommeRemotePhone` | `com.natural.BonhommeRemote` |
| ClusterFuck | `Apps/ClusterFuck` + `Apps/Shared` | `com.lebonhommepharma.clusterfuck` |
| ClusterFuck Watch | `Apps/ClusterFuckWatch` | `com.lebonhommepharma.clusterfuck.watchkitapp` |
| ClusterFuck Mac | `Apps/ClusterFuck` (MacInfo) | `com.lebonhommepharma.clusterfuck.mac` |

App Store prep: [`docs/AppStore/README.md`](docs/AppStore/README.md) · design tokens: [`design-system/clusterfuck/MASTER.md`](design-system/clusterfuck/MASTER.md)

Details: [`docs/XCODE_TARGET_SETUP.md`](docs/XCODE_TARGET_SETUP.md) · [`docs/CAPABILITIES.md`](docs/CAPABILITIES.md)

## Layout

```
Sources/NaturalRemote/
  Core/           CrooksMath, CrooksCycleController, models, ActuatorBus
  Music/          Apple Music, Spotify, Sonos, DI.fm, AVAudio spectral
  AirPods/        Max H1 + Pro H2
  Analysis/       DeltaHRV, FlexAID hybrid, EigenMetalBridge, ANE predictor
  Actuators/      Alexa, Foundation Models, ResearchKit
  DrugKit/        DrugKitEngine + PV export
  Session/        RemoteControlLoop, PharmaControlSessionManager, RemoteSessionView
Apps/
  BonhommeRemoteWatch/   watchOS shell + WCSession
  BonhommeRemotePhone/   iOS liver + WCSession
docs/
  SESSION_PROMPTS.md     Swarm agent prompts (Sessions 0–6) ← start here
  NATURAL_REUSE_MAP.md   NATURaL symbol inventory
  IMPLEMENTATION_ROADMAP.md
  CAPABILITIES.md
  PHARMACOVIGILANCE.md
  ALEXA_PLUS.md
```

## Swarm prompts

Feed **one session at a time** from [`docs/SESSION_PROMPTS.md`](docs/SESSION_PROMPTS.md):

0. Project setup, targets, capabilities  
1. Core models + Crooks σ_irr  
2. Music stack  
3. AirPods H1/H2  
4. DeltaHRV + FlexAID + ANE  
5. UI + control loop  
6. Validation harness  

## Docs

- **Pharmacovigilance mission:** [`docs/PHARMACOVIGILANCE.md`](docs/PHARMACOVIGILANCE.md)
- **NATURaL reuse:** [`docs/NATURAL_REUSE_MAP.md`](docs/NATURAL_REUSE_MAP.md)
- Swarm prompts: [`docs/SESSION_PROMPTS.md`](docs/SESSION_PROMPTS.md)
- Roadmap: [`docs/IMPLEMENTATION_ROADMAP.md`](docs/IMPLEMENTATION_ROADMAP.md)
- Alexa+: [`docs/ALEXA_PLUS.md`](docs/ALEXA_PLUS.md)
