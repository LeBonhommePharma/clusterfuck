# ClusterFuck / NATURaL Remote — App Store preparation

Repository preparation, not an uploaded release. Team **ZJLX84G8QV**, account **lp@thebonhomme.com** (same as NATURaL / Exergy).

This repo ships **two** product families. Do not invent tvOS or visionOS store records.

| Record | Bundle IDs | OS |
|--------|------------|----|
| ClusterFuck (codename) | `com.lebonhommepharma.clusterfuck` + `…watchkitapp` | iPhone, iPad (`TARGETED_DEVICE_FAMILY` 1,2), watchOS |
| ClusterFuck Mac | `com.lebonhommepharma.clusterfuck.mac` | macOS 14+ |
| NATURaL Remote (Session 0) | `com.natural.BonhommeRemote` + `…watchkitapp` | iPhone, iPad, watchOS |

## Identity

| Field | ClusterFuck | NATURaL Remote |
|-------|-------------|----------------|
| Display name | ClusterFuck | NATURaL Remote |
| Subtitle | Wrist Crooks control | Entropy docking remote |
| Category | Health & Fitness (secondary: Medical) | Health & Fitness |
| Pricing | Free | Free |
| Age | Complete the current content questionnaire; no rating claimed yet | Complete the current content questionnaire |
| Marketing | https://thebonhomme.com/ClusterFuck/ | https://thebonhomme.com/NATURaL-Remote/ |
| Privacy | https://thebonhomme.com/ClusterFuck/privacy/ | same policy family |
| App Group | `group.com.natural.BonhommeRemote` | `group.com.natural.BonhommeRemote` |

## App Privacy

The intended data flows include Health samples (HR / HRV) and local dose logs for app functionality. Live sampling, durable logging and export must be verified before these become store claims. On-device processing alone does not constitute collection under Apple’s privacy definition; audit configured third-party requests before final answers. Tracking is **off**. Tokens for Spotify / Alexa stay on the phone and are **not** written to WatchConnectivity application context.

Privacy manifests: `Apps/*/PrivacyInfo.xcprivacy`.

## Export compliance

`ITSAppUsesNonExemptEncryption` is `NO`. HTTPS to user-configured Alexa / Spotify / Sonos endpoints is exempt.

## Review notes (paste)

ClusterFuck is a wrist-oriented Crooks σ_irr remote for NATURaL. Demo dose logging is clearly a **non-clinical demo** (`DrugKitEngine.nonClinicalDemoMode`). HealthKit authorization may be skipped in simulator; the Crooks loop still runs on injected samples.

Watch supports independent operation and is embedded in its iOS companion. Mac has sandbox entitlements; signed behavior remains unverified.

Contact: lp@thebonhomme.com

## Remaining gates

See [TODO.md](TODO.md) for unresolved product functionality and [verification.md](verification.md) for actual verification. Local configuration is not yet a production-ready product.

## Account and publishing gates

1. Register identifiers and App Group on team ZJLX84G8QV.
2. App Store Connect records + screenshots (iPhone, iPad if universal, Watch, Mac).
3. TestFlight signed HealthKit / MusicKit / headphone motion.
4. Publish privacy URL on GitHub Pages, then lock it in Connect.
5. Alexa+ / Spotify client credentials are **not** in this repo.

Local check:

```sh
python3 scripts/validate-submission.py
python3 scripts/test_contracts.py
```
