# NATURaL Remote — Entropy Docking Edition

Wrist-oriented **Crooks σ_irr minimization** control stack: multi-service music, **Alexa + Alexa+** (AI Action / Smart Home v3 / skill proxy), AirPods H1/H2 surfaces, Foundation Model routing, HealthKit/DrugKit, DeltaHRV ↔ FlexAID∆S hybrid, reusing **NATURaL BonhommeCore** (`EntropyCalculator`, `FeedbackEngine`, `HRVAnalyzer`, `SCIVisualizationView`).

Alexa+ details: [`docs/ALEXA_PLUS.md`](docs/ALEXA_PLUS.md).

## Build & test

```bash
cd /Users/lp.more/Projects/ClusterFuck
swift test
```

Requires sibling checkout: `../NATURaL/BonhommeCore`.

## Layout

```
Sources/NaturalRemote/
  Core/           CrooksMath, CrooksCycleController, models, ActuatorBus
  Music/          Apple Music, Spotify, Sonos, DI.fm, AVAudio spectral
  AirPods/        Max H1 + Pro H2
  Analysis/       DeltaHRV, FlexAID hybrid, EigenMetalBridge, ANE predictor
  Actuators/      Alexa, Foundation Models
  DrugKit/        DrugKitEngine
  Session/        RemoteControlLoop, PharmaControlSessionManager, RemoteSessionView
docs/
  SESSION_PROMPTS.md   Swarm agent prompts (Sessions 0–6)
  IMPLEMENTATION_ROADMAP.md
  CAPABILITIES.md
```

## Docs

- Swarm prompts: [`docs/SESSION_PROMPTS.md`](docs/SESSION_PROMPTS.md)
- Roadmap: [`docs/IMPLEMENTATION_ROADMAP.md`](docs/IMPLEMENTATION_ROADMAP.md)
