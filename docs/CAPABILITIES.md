# Xcode / runtime capabilities — NATURaL Remote

When wrapping `NaturalRemote` in app targets (`Apps/BonhommeRemoteWatch`, `Apps/BonhommeRemotePhone`):

| Capability | Target | Why |
|---|---|---|
| **HealthKit** | Watch + Phone | HR / HRV / medication for DrugKit + ΔHRV; optional `HKWorkoutSession` |
| **HealthKit background delivery** | Watch + Phone | Continuous samples during session |
| **Background Modes → processing / workout-processing** | Watch (`WKBackgroundModes`) | Session continuity on wrist |
| **Microphone** | Phone (primary), Watch if available | `AVAudioEngine` spectral tap / voice → Foundation Model |
| **MusicKit / Apple Music** | Phone + Watch (where supported) | `ApplicationMusicPlayer` + catalog search |
| **Motion** | Phone + Watch | `CMHeadphoneMotionManager` head tracking (H1) |
| **WatchConnectivity** | Both | Phone = OAuth/token liver; Watch = control + sensors |
| **App Groups** | Both | `group.com.natural.BonhommeRemote` shared token/session store |
| **ResearchKit** | Phone app target (optional link) | Dose-effect / current-state surveys → `ResearchKitBridge` |
| **Network (client)** | Phone primarily | Spotify Web API, Alexa BFF, Sonos LAN/cloud, DI.fm streams |
| **Core ML** | Phone / Watch (optional) | `DeltaHRV_FlexAID_Surrogate.mlmodelc` if bundled; pure Swift weights always work |

### Bundle identifiers (Session 0 defaults)

| Target | Bundle ID |
|---|---|
| BonhommeRemotePhone | `com.natural.BonhommeRemote` |
| BonhommeRemoteWatch | `com.natural.BonhommeRemote.watchkitapp` |

### Info.plist usage strings

| Key | Suggested copy |
|---|---|
| `NSHealthShareUsageDescription` | NATURaL Remote reads heart rate and HRV to minimize irreversible entropy production (σ_irr) and support pharmacovigilance logging. |
| `NSHealthUpdateUsageDescription` | NATURaL Remote may save workout-style control sessions and mindfulness intervals to Apple Health. |
| `NSMicrophoneUsageDescription` | NATURaL Remote analyzes ambient/music audio entropy and optional voice commands on-device. |
| `NSMotionUsageDescription` | NATURaL Remote uses headphone motion for AirPods Max spatial / head-pose control. |
| `NSBluetoothAlwaysUsageDescription` | Optional: Sonos / accessory discovery (enable only if shipping LAN discovery). |

### Entitlements baseline

**Watch** (`Apps/BonhommeRemoteWatch/BonhommeRemoteWatch.entitlements`):

- `com.apple.developer.healthkit`
- `com.apple.developer.healthkit.background-delivery`
- `com.apple.security.application-groups` → `group.com.natural.BonhommeRemote`

**Phone** (`Apps/BonhommeRemotePhone/BonhommeRemotePhone.entitlements`):

- HealthKit + background-delivery
- App Groups (same group)
- `com.apple.developer.watchkit`

MusicKit capability is toggled in Xcode Signing & Capabilities (not always a raw entitlements key across SDK versions).

### Signing notes

| Path | Paid team? |
|---|---|
| `swift test` of pure logic | **No** |
| Device HealthKit, MusicKit, headphone biometrics | **Yes** — signed app + entitlements |
| Live Spotify / Alexa+ | Developer accounts + BFF tokens (not in-repo secrets) |

### NATURaL parity

Mirror patterns from:

- `NATURaL/BonhommeWatch/BonhommeWatch.entitlements`
- `NATURaL/Bonhomme/Bonhomme.entitlements`
- `NATURaL/BonhommeWatch/Info.plist` (`WKBackgroundModes` → `workout-processing`)
