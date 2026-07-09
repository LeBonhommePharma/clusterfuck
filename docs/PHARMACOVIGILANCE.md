# Pharmacovigilance positioning — Le Bonhomme Pharma

**Critical product north star:** `ClusterFuck` / **NATURaL Remote — Entropy Docking Edition** is engineered so it can become **Le Bonhomme Pharma’s main pharmacovigilance (PV) tool** — not a toy remote that happens to log doses.

Treat every architecture and feature decision as if this stack will eventually:

1. Collect **set/setting + dose + physiologic response** (ΔHRV, SCI/PCCI, σ_irr trajectory).  
2. Compare **observed vs predicted** response (DeltaHRV ↔ FlexAID∆S hybrid).  
3. Drive **harm-reduction actuators** (music tempo, Alexa+/environment, AirPods ANC) when deviation or σ_irr rises.  
4. Export **auditable, reproducible paired records** for internal PV review, cohort studies, and clinician handoff (FHIR-oriented fields, timestamps, model versions).  
5. Prefer **on-device / privacy-preserving** sensing with phone-side token and export control.

## What “main PV tool” means here

| PV need | Remote surface |
|--------|----------------|
| Exposure logging | `DrugLog` + DrugKitEngine + ResearchKit state surveys |
| Outcome signals | ΔHRV, SCI, PCCI, audio entropy, AirPods HR/R-R when available |
| Expected vs observed | `DeltaHRVFlexAIDMapper` / `analyzeWithFlexAID` deviation + `grounding_alert` |
| Intervention | Crooks `minimizeSigma` → music / Alexa+ / AirPods |
| Causality context | set/setting, substance ID, dose, ambient state vector |
| Audit trail | `ActuatorEvent` bus + Crooks snapshots + PV export records |
| Reproducibility | git SHA, model weights layout, entropy constants from BonhommeCore |

## Design rules (non-negotiable for PV path)

- **No stubbed logging on the PV path.** If a dose is accepted, it must persist in-process and be exportable.  
- **Precise thermodynamics language** in exports (σ_irr, SCI, ΔS_config estimate — never claim full molecular ΔG on-watch).  
- **Harm-reduction first** when deviation or σ_irr exceeds thresholds (grounding playlist, dim/breathe via Alexa+, ANC).  
- **Phone = liver** for credentials and bulk export; **watch = sensor + control**.  
- **Alexa+** is preferred for natural-language environment control when configured (`docs/ALEXA_PLUS.md`), still fully offline-recordable for tests and dry-runs.  
- Future cohort / regulatory packages should reuse the same paired schema — do not invent a parallel “research only” log format.

## Primary types for PV export

See `PharmacovigilanceRecord` / `PharmacovigilanceExporter` in `DrugKitEngine.swift`.

Minimum fields per event:

- `timestamp`, `substance`, `doseMg`, `setAndSetting`  
- `observedDeltaHRV`, `predictedDeltaHRV`, `deviation`, `action`  
- `sci`, `pcci`, `sigmaIrr`, `crooksPhase`, `closurePercent`  
- `musicBPM`, `audioEntropyBits`, `alexaLightsPercent`, `airPodsNoiseMode`  
- `flexAIDDeltaS`, `sourceBuild` (app/package version)

## Roadmap implication

Sessions 0–6 deliver the **control + sensing kernel**. The PV mission means subsequent work prioritizes:

1. Durable storage (SwiftData / encrypted store) of `PharmacovigilanceRecord`  
2. FHIR `MedicationStatement` + observation pairing  
3. Cohort CSV/JSON export for Le Bonhomme Pharma internal review  
4. Validation dashboards (observed vs FlexAID-style predicted over time)

Until those land, the in-memory exporter + unit tests remain the **contract** every feature must honor.
