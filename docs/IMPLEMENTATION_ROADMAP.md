# ClusterFuck Remote — Implementation Roadmap

**Source thread:** [Spotify Alexa Apple Models WatchOS Integration](https://grok.com/share/bGVnYWN5_1a2635a1-1585-456d-b591-2a6e98567892)  
**Working title:** watchOS “clusterfuck” remote (NATURaL Remote ∆S)  
**Ultimate control goal:** Crooks’ irreversible entropy production minimization (`σ_irr → 0`)  
**Scaffold:** reuse [NATURaL](https://github.com/LeBonhommePharma/NATURaL) watchOS + BonhommeCore (≈70–90% copy/adapt)

This document is the **general structure** of the implementation roadmap distilled from the conversation. It is intentionally phase-ordered, dependency-aware, and verification-gated. Code sketches in the thread are design references; this roadmap is the plan skeleton for production work.

---

## 0. North star

**Org trajectory:** `ClusterFuck` / NATURaL Remote is positioned to become **Le Bonhomme Pharma’s main pharmacovigilance tool** — continuous exposure–outcome–intervention capture under thermodynamic control. See `docs/PHARMACOVIGILANCE.md`.

Build a **wrist-native psychopharm command hub** (and PV sensor node) that:

| Ligand (input / actuator) | Role |
|---|---|
| **Spotify** | Sensory amplifier / playlist + tempo control |
| **Alexa** | Environment titrator (lights, routines, breathe) |
| **Apple Foundation Models** | On-device trip-sitter / structured tool router |
| **HealthKit** | Continuous biomarkers (plasma-assay analogue) |
| **ResearchKit** | Subjective scales / dose–effect logs |
| **DrugKit** | Dose log + entropy / PCCI engine (FlexAID∆S-inspired) |
| **DeltaHRV + FlexAID mapper** | Observed vs predicted autonomic response |
| **EigenMetalBridge + ANE** | GPU / Neural Engine acceleration of collapse metrics |
| **CrooksCycleController** | Closed-loop `σ_irr` minimization across all scales |

**Thermodynamic framing (do not dilute):**

- APIs / signals = flexible ligands  
- watchOS UI = binding pocket (NATURaL `SessionView` scaffold)  
- Shannon Collapse / CCI / PCCI = configurational entropy term for multi-API microstates  
- Forward cycle = heating / exploration / high entropy  
- Reverse cycle = cooling / binding / grounding  
- **Score:** `σ_irr = ⟨W_fwd⟩ + ⟨W_rev⟩ − 2ΔG` → drive toward closure  

**Non-goals for early phases:** perfect Alexa public remote API (proxy required); full FlexAID∆S molecular GA on-watch; cloud-only inference as default path.

---

## 1. System architecture (fixed layers)

```
┌─────────────────────────────────────────────────────────────┐
│  watchOS UI  (BonhommeRemoteWatch)                          │
│  Tabs: Spotify | Alexa | AI Oracle | Dose & Log | σ gauge   │
└───────────────────────────┬─────────────────────────────────┘
                            │ local signals + mic + haptics
┌───────────────────────────▼─────────────────────────────────┐
│  Control plane                                              │
│  CrooksCycleController  ← ultimate optimizer                │
│  FoundationModelOrchestrator  ← voice → RemoteCommand       │
│  PharmaControlSessionManager  ← session + HKWorkoutSession  │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│  Analysis plane (BonhommeCore)                              │
│  FeedbackEngine + HealthSignal conformers                   │
│  EntropyCalculator / PCCI / SCI                             │
│  DeltaHRVAnalyzer → DeltaHRVFlexAIDMapper (Core ML / ANE)   │
│  DrugKitEngine                                              │
│  EigenMetalBridge (optional fast path)                      │
└───────────────────────────┬─────────────────────────────────┘
                            │ WCSession JSON commands / state
┌───────────────────────────▼─────────────────────────────────┐
│  iPhone companion (“liver”)                                 │
│  OAuth (Spotify), Alexa Lambda/webhook proxy, token refresh │
│  Heavy REST, CareKit/FHIR sync, Private Cloud Compute FM    │
└─────────────────────────────────────────────────────────────┘
```

**Role split**

| Node | Responsibility |
|---|---|
| **watchOS** | UI, on-device FM (when available), entropy collapse, haptics, session |
| **iPhone** | Auth, long-lived tokens, heavy REST, CareKit/FHIR, FM cloud fallback |
| **Optional C++/Metal** | Sub-ms PCCI / vector fusion |
| **Optional ANE / Core ML** | Surrogate ΔHRV ↔ FlexAID∆S prediction |

---

## 2. Metrics hierarchy (name them once, keep them precise)

| Symbol / name | Meaning | Primary producers |
|---|---|---|
| **SCI** | Shannon Collapse Index (existing NATURaL metric) | `EntropyCalculator` |
| **CCI** | Control Coherence Index across API states | multi-API signal fusion |
| **PCCI** | Pharma-Control Coherence Index (HRV + drug + music + voice success) | `DrugKitEngine` / EigenMetal |
| **ΔHRV** | Time-windowed HRV change (e.g. ΔRMSSD) | `DeltaHRVAnalyzer` |
| **ΔS_config / FlexAID∆S** | Configurational / docking-style entropy estimate | DrugKit + optional surrogate |
| **σ_irr** | Irreversible entropy production (Crooks loop score) | `CrooksCycleController` |

**Rule:** UI may show one primary gauge (reuse SCI visualization), but logs must retain the specific quantity that was computed.

---

## 3. Module map (target tree)

Fork NATURaL → extend; new watch target **BonhommeRemoteWatch**.

```
BonhommeCore/
├── Analysis/
│   ├── FeedbackEngine.swift              # reuse
│   ├── HealthSignal.swift                # reuse + new conformers
│   ├── SignalAnalyzer.swift              # reuse
│   ├── EntropyCalculator.swift           # reuse → CCI/PCCI hooks
│   ├── HRVAnalyzer.swift                 # reuse
│   ├── DrugResponseAnalyzer.swift        # reuse
│   ├── MedicationAnalyzer.swift          # reuse
│   ├── PharmacokineticProfile.swift      # reuse
│   ├── DeltaHRVAnalyzer.swift            # NEW
│   └── DeltaHRVFlexAIDMapper.swift       # NEW (Core ML surrogate)
├── DrugKit/
│   └── DrugKitEngine.swift               # NEW (official module)
├── Services/
│   ├── Music/ → MultiPlayerService       # extend (MusicKit → Spotify)
│   ├── HealthKit/                        # reuse + watch queries
│   └── CareKit/ + ResearchKit            # extend surveys
├── SpotifyRemote.swift                   # NEW
├── AlexaProxy.swift                      # NEW
├── FoundationModelOrchestrator.swift     # NEW (brain for routing)
├── EigenMetalBridge.swift                # NEW (optional)
└── CrooksCycleController.swift           # NEW (ultimate control)

EigenMetalBridge/  (optional SPM / C++ side)
├── PharmaRemoteKernel.hpp
├── PharmaRemoteKernel.cpp
└── entropyCollapseKernel.metal

BonhommeRemoteWatch/  (duplicate BonhommeWatch)
├── App/WatchApp.swift
├── RemoteControlView.swift               # from SessionView/HomeView
├── PharmaControlSessionManager.swift     # from WorkoutManager
└── (panels: Spotify, Alexa, AIOracle, DoseLog, SigmaGauge)

iPhone companion (existing NATURaL host)
└── WCSession auth/proxy handlers for Spotify + Alexa + FHIR sync
```

---

## 4. Implementation phases

Each phase ends with an explicit **exit gate**. Do not start the next phase until the gate passes.

### Phase 0 — Scaffold & hygiene

**Intent:** Stand up the empty product shell without science or third-party APIs.

| Work | Detail |
|---|---|
| 0.1 | Fork / submodule policy for NATURaL; create `BonhommeRemoteWatch` target |
| 0.2 | Embed `BonhommeCore` SPM; capabilities: HealthKit, Background Modes, Microphone |
| 0.3 | Info.plist usage strings (Health, mic, motion as needed) |
| 0.4 | `WatchApp` → `RemoteControlView` skeleton (tabs only, no real actions) |
| 0.5 | WCSession round-trip smoke test (watch ↔ phone dummy JSON) |

**Exit gate**

- `xcodebuild` for `BonhommeRemoteWatch` simulator succeeds  
- Tab shell renders; WCSession message logged both sides  

---

### Phase 1 — NATURaL reuse spine (Session + entropy)

**Intent:** 80% of UX and collapse math live before any external API.

| Work | Reuse / change |
|---|---|
| 1.1 | Port `SessionView` / `HomeView` → `RemoteControlView` vertical/tab pager |
| 1.2 | `WorkoutManager` → `PharmaControlSessionManager` (keep `HKWorkoutSession` option) |
| 1.3 | Wire `FeedbackEngine` + `EntropyCalculator` + gauge overlay |
| 1.4 | Define `RemoteStateSnapshot` (from `BiofeedbackSnapshot` pattern) |
| 1.5 | Battery policy: heavy work on phone; watch only when needed |

**Exit gate**

- Continuous session starts/stops; SCI/CCI gauge updates from synthetic or HK signals  
- No stubs in session lifecycle paths  

---

### Phase 2 — Spotify remote (first actuator)

**Intent:** One production actuator end-to-end.

| Work | Detail |
|---|---|
| 2.1 | Choose stack: SPTAppRemote and/or Swift Spotify package + Web API fallback |
| 2.2 | Phone: OAuth (`ASWebAuthenticationSession`) + token refresh |
| 2.3 | Watch: `SpotifyRemote` commands via WCSession (`play/pause/next/queue/volume`) |
| 2.4 | Signal: `SpotifySignal` → FeedbackEngine (valence / BPM for later PCCI) |
| 2.5 | UI: Spotify panel + haptic confirmations |

**Exit gate**

- Authenticated control of real Spotify Connect playback from watch  
- State sync after disconnect/reconnect  

**Constraints:** No full watchOS Spotify SDK; phone is mandatory for auth/REST.

---

### Phase 3 — Alexa / Alexa+ control planes (second actuator)

**Intent:** Environment control across classic and **Alexa+** generative planes.

| Work | Ranked approach |
|---|---|
| 3.1 | **Alexa+ (`alexaPlus`):** AI Action / Web Action / Multi-Agent style envelopes — `AlexaPlusAction(expert, utterance, slots)` → BFF or partner gateway |
| 3.2 | **Smart Home Skill API v3:** BrightnessController, PowerController, SceneController, ModeController directives |
| 3.3 | **Skill proxy:** Alexa for Apps / custom skill → Lambda → device |
| 3.4 | `AlexaAPIMode.auto` prefers Alexa+ when `alexaPlusEndpoint` is set, else v3, else proxy |
| 3.5 | Phone holds LWA/session tokens; watch sends structured `RemoteCommand` only |
| 3.6 | Deep / natural routines: breathe, dim lights, neutral ambient (utterance on Alexa+, directive on v3) |
| 3.7 | `AlexaSignal` / lights% into FeedbackEngine + Crooks `alexaEntropyHint` |

See `docs/ALEXA_PLUS.md` for POST shapes and Amazon SDK references.

**Exit gate**

- At least one Echo (or HA) routine fires from watch button + from structured command  
- Alexa+ path records expert+utterance offline without credentials; live path when BFF configured  
- Failure modes surface in UI (auth/proxy down)  

---

### Phase 4 — Apple Foundation Models orchestrator

**Intent:** On-device (or PCC fallback) structured routing of voice → multi-service actions.

| Work | Detail |
|---|---|
| 4.1 | `FoundationModelOrchestrator` + `LanguageModelSession` |
| 4.2 | `@Generable` / structured `RemoteCommand { service, action, params }` |
| 4.3 | Tools: `playSpotify`, `invokeAlexa`, `logDrug`, `computePCCI` |
| 4.4 | Prompt context: SCI/PCCI + Spotify state + last dose summary |
| 4.5 | Gate inference: mic tap or high entropy only (battery) |

**Exit gate**

- Spoken “chill music + dim lights” yields structured commands that execute Phase 2–3 paths  
- Offline/on-device path documented; cloud fallback explicit  

---

### Phase 5 — HealthKit + ResearchKit + DrugKit

**Intent:** Pharmacokinetic telemetry backbone (psychopharm command hub).

| Work | Detail |
|---|---|
| 5.1 | HealthKit: HR/HRV, medication writes, mindful sessions, background delivery |
| 5.2 | ResearchKit: wrist “Current State Log” / effect-rating ordered tasks |
| 5.3 | `DrugKitEngine`: `DrugLog`, analyze → PCCI, HealthKit + FHIR-oriented write |
| 5.4 | Dose & Log tab; PokeDrug-style quick selector reuse |
| 5.5 | Collapse policy: high PCCI → simplify UI + haptics; low → survey + grounding |

**Full-stack happy path (thread definition)**

1. Watch: “Log dose”  
2. HealthKit write + ResearchKit intensity  
3. DrugKit ΔS / PCCI  
4. Foundation Model contextual suggestion  
5. Spotify grounding + Alexa environment + UI simplify  
6. Phone: CareKit / FHIR cohort sync  

**Exit gate**

- Logged dose appears in Health; PCCI updates; at least one auto-actuator fires on threshold  
- Reproducible unit test / console: `predictInteraction(substance:)` returns concrete output  

---

### Phase 6 — DeltaHRV analyzer

**Intent:** Explicit ΔHRV as first-class canary signal (not buried inside generic HRV).

| Work | Detail |
|---|---|
| 6.1 | `DeltaHRVAnalyzer` (actor/shared), windowed ΔRMSSD (and siblings as needed) |
| 6.2 | Register with `FeedbackEngine` |
| 6.3 | Hook `PharmaControlSessionManager.start` + `DrugKitEngine.analyze` |
| 6.4 | `runTest()` console verification path |

**Exit gate**

- Live session produces ΔHRV samples; thresholds trigger documented side effects  

---

### Phase 7 — Hardware acceleration (optional, ordered)

Do **7A** and **7B** only after Phase 5–6 metrics are correct on CPU.

#### 7A — EigenMetalBridge

| Step | Artifact |
|---|---|
| 1 | SPM / package deps for Eigen + Metal shim |
| 2 | `PharmaRemoteKernel` C++: `computePCCI(VectorXd)` |
| 3 | Metal `entropyCollapseKernel` for batch |
| 4 | `EigenMetalBridge.swift` `@objc` bridge |
| 5 | One-line swap inside `DrugKitEngine.analyze` |

**Exit gate:** benchmark harness shows speedup vs scalar path; numeric parity within tolerance.

#### 7B — Apple Neural Engine / Core ML surrogate

| Step | Artifact |
|---|---|
| 1 | Train tiny regression: HRV (+ FlexAID features) → predicted Δ / PCCI shift |
| 2 | Export `.mlpackage` → Xcode → `.mlmodelc`, ANE-preferred config |
| 3 | `ANEPharmaPredictor` / mapper load path |
| 4 | Deviation flag → grounding actions |

**Exit gate:** ANE path runs on device; CPU fallback if model missing; deviation policy tested.

---

### Phase 8 — DeltaHRV ↔ FlexAID∆S hybrid model

**Intent:** Translational core for validation / publication — observed vs predicted autonomic response.

| Work | Detail |
|---|---|
| 8.1 | `DeltaHRVFlexAIDMapper` inputs: observed Δ, FlexAID-style ΔS, dose, baseline SCI, substance ID |
| 8.2 | Output: predicted Δ, deviation, action (`grounding_alert` \| `coherent_continue`) |
| 8.3 | Wire: after `DeltaHRVAnalyzer.processSamples` → `DrugKitEngine.analyzeWithFlexAID` |
| 8.4 | Dataset logging for thesis/cohort (paired predictions vs observations) |

**Exit gate**

- End-to-end path without stubs; grounding path fires on high deviation  
- Export schema defined for paired dataset  

**Scientific guardrail:** This is a **surrogate / ensemble estimate** path inspired by FlexAID∆S, not a claim of full molecular docking free energy on the watch.

---

### Phase 9 — Crooks’ `σ_irr` minimization loop (ultimate control goal)

**Intent:** Unify every prior phase under one optimizer.

| Work | Detail |
|---|---|
| 9.1 | `CrooksCycleController` actor: phases `.forward` / `.reverse`, `workFwd`, `workRev`, `deltaG`, `sigmaIrr` |
| 9.2 | `updateWithDeltaHRV(delta, flexAIDDeltaS, spotifyBPM, alexaState)` each sensor tick |
| 9.3 | `minimizeSigma()` orchestrates Spotify + Alexa + FM + ΔHRV reinforce |
| 9.4 | Phase flip near closure; cycle logging + ResearchKit/FHIR export |
| 9.5 | UI: live `σ_irr` + closure % (reuse SCI visualization skin) |
| 9.6 | FM prompts include “suggest action to reduce σ_irr” |

**Exit gate**

- Continuous loop runs in a session without crashing or runaway actuators  
- Every significant action is scored by estimated σ_irr reduction  
- Cycle completion writes paired validation record (FlexAID estimate + ΔHRV + final σ_irr + self-report)  

---

### Phase 10 — Hardening, reproducibility, ship

| Work | Detail |
|---|---|
| 10.1 | Strip remaining stubs/TODOs; production error surfaces |
| 10.2 | Instruments / battery profiling template |
| 10.3 | TestFlight checklist; privacy nutrition labels |
| 10.4 | Reproducibility package: model hashes, git SHA, device OS, capability matrix |
| 10.5 | Cohort export pipeline (FHIR / CloudKit) for book/thesis |

**Exit gate**

- Clean build; critical path tests green; documented demo script for TestFlight  

---

## 5. Dependency graph (build order)

```text
Phase 0 Scaffold
    └─► Phase 1 NATURaL spine
            ├─► Phase 2 Spotify ──────────────┐
            ├─► Phase 3 Alexa ────────────────┤
            └─► Phase 5 Health/Research/DrugKit
                    ├─► Phase 6 DeltaHRV
                    │       └─► Phase 8 FlexAID hybrid ──┐
                    └─► Phase 4 Foundation Models ───────┤
                                                         │
Phase 7A/7B (optional accel) ── accelerates 5–8 metrics  │
                                                         ▼
                                              Phase 9 Crooks σ_irr
                                                         │
                                                         ▼
                                              Phase 10 Harden & ship
```

**Parallelizable after Phase 1:** Spotify (2) ∥ Alexa (3) ∥ DrugKit shell (5.3)  
**Serial critical path to control goal:** 1 → 5 → 6 → 8 → 9  

---

## 6. Cross-cutting rules

1. **Production-grade only:** no “TODO later” in shipped paths; optional features behind flags, not empty stubs.  
2. **Phone does heavy I/O; watch does collapse + UI.**  
3. **Harm-reduction framing** for dose logging and auto-actions (grounding, simplify UI, export for clinician) — not moralizing.  
4. **Entropy language stays precise:** CF/SCI/PCCI/σ_irr are not interchangeable in logs or papers.  
5. **FlexAID∆S on-watch** is surrogate/mapping unless a full docking pipeline is explicitly in scope and verified.  
6. **Verify with actual runs** (simulator + device) before claiming a phase complete.  
7. **Reuse before rewrite:** NATURaL modules first; new files only at the seams listed above.

---

## 7. Verification matrix (summary)

| Phase | Minimal verification |
|---|---|
| 0 | Watch target builds; WCSession ping |
| 1 | Session + entropy gauge with live/synthetic signal |
| 2 | Real Spotify control + state sync |
| 3 | Real Alexa/HA routine from watch |
| 4 | Voice → structured multi-service execute |
| 5 | Dose log → HK + PCCI + actuator side effect |
| 6 | ΔHRV series + threshold action |
| 7A | PCCI numeric parity + latency bench |
| 7B | Core ML predict on ANE + fallback |
| 8 | Observed vs predicted + grounding_alert path |
| 9 | σ_irr loop drives actuators; cycle export |
| 10 | TestFlight demo script green |

---

## 8. Open decisions (resolve before locking phases)

Captured from the thread; pick explicitly in Phase 0–2 design notes:

1. Spotify package: official SPTAppRemote vs community Swift API vs both  
2. Alexa path: **Alexa+** (AI Action BFF) vs Smart Home v3 vs skill proxy vs Home Assistant  

3. Minimum watchOS / Apple Intelligence device matrix for on-device FM  
4. Whether EigenMetalBridge and ANE are **required** for v1 or post-MVP  
5. Substance catalog source of truth (PokeDrug chart / 84-substance list) and privacy scope  
6. Legal / App Store framing for psychopharm logging (medical device risk, research vs consumer)  

---

## 9. One-line phase slogan sheet

| Phase | Slogan |
|---|---|
| 0 | Empty pocket, correct fold |
| 1 | NATURaL spine, entropy gauge |
| 2 | First ligand: Spotify |
| 3 | Second ligand: Alexa (proxy) |
| 4 | FM as trip-sitter router |
| 5 | Dose + PCCI backbone |
| 6 | ΔHRV canary |
| 7 | Hardware docking (Metal / ANE) |
| 8 | Observed vs FlexAID-style predicted |
| 9 | Crooks demon: minimize σ_irr |
| 10 | Ship the closed loop |

---

## 10. Next concrete action

**Start Phase 0** in this repo:

1. Import or vendor the NATURaL watch + core packages this fork will extend  
2. Create `BonhommeRemoteWatch` + `BonhommeCore` package layout matching §3  
3. Land empty `RemoteControlView` + WCSession smoke test  
4. Open Phase 0 exit-gate checklist as issues or a `docs/PHASE0_CHECKLIST.md`

When Phase 0 is green, proceed **Phase 1 only** — do not skip ahead to Crooks or FlexAID mappers until the spine and at least one actuator exist.

---

*Roadmap structure derived from the shared Grok thread (2026-07-08). Update this file when phase scope changes; keep scientific terminology and control-goal language intact.*
