# Xcode / runtime capabilities — NATURaL Remote

When wrapping `NaturalRemote` in an app target (iOS / watchOS):

| Capability | Why |
|---|---|
| HealthKit | HR / HRV / medication records for DrugKit + ΔHRV |
| ResearchKit (app target) | Dose-effect / current-state surveys → `ResearchKitBridge` (SPM works offline via inject) |
| Background Modes → processing | Continuous session samples |
| Microphone | AVAudioEngine spectral tap / voice |
| MusicKit | Apple Music playback |
| Motion (when prompted) | CMHeadphoneMotionManager head tracking (H1) |
| WatchConnectivity | Phone proxy for Spotify / Alexa / Alexa+ tokens |
| App Groups (optional) | Shared token store phone ↔ watch |

### Info.plist usage strings

- `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSMotionUsageDescription` (headphone motion)

### Signing notes

Local `swift test` of pure logic does **not** require a paid team. Device MusicKit, HealthKit, and headphone biometrics require a signed app + entitlements.
