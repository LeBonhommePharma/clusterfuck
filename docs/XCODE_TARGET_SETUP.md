# Xcode target setup — Session 0

## Preferred: XcodeGen

```bash
# Sibling layout required
ls ../NATURaL/BonhommeCore/Package.swift
cd /Users/lp.more/Projects/ClusterFuck
brew install xcodegen   # once
xcodegen generate       # → BonhommeRemote.xcodeproj
open BonhommeRemote.xcodeproj
```

### Schemes (after generate)

| Scheme | Platform | Sources |
|---|---|---|
| `BonhommeRemotePhone` | iOS | `Apps/BonhommeRemotePhone` (+ embeds watch) |
| `BonhommeRemoteWatch` | watchOS | `Apps/BonhommeRemoteWatch` |
| `ClusterFuck` | iOS | `Apps/ClusterFuck` + `Apps/Shared` |
| `ClusterFuckWatch` | watchOS | `Apps/ClusterFuckWatch` |
| `ClusterFuckMac` | macOS | `Apps/ClusterFuck` + `Apps/Shared` (`MacInfo.plist`, sandboxed) |

All four link SPM products **NaturalRemote** + **BonhommeCore**.

Set your **Team** under Signing. Enable capabilities in `docs/CAPABILITIES.md` if Xcode does not pick them up from entitlements alone (MusicKit especially).

## Manual (no XcodeGen)

1. File → New → Project → iOS App → `BonhommeRemotePhone`, bundle `com.natural.BonhommeRemote`.
2. File → New → Target → Watch App → `BonhommeRemoteWatch`, bundle `com.natural.BonhommeRemote.watchkitapp`.
3. File → Add Package Dependencies → Add Local…
   - `ClusterFuck` (this repo) → product **NaturalRemote**
   - `NATURaL/BonhommeCore` → product **BonhommeCore**
4. Replace generated sources with `Apps/BonhommeRemotePhone/**` and `Apps/BonhommeRemoteWatch/**`.
5. Point Info.plist and entitlements at the files under `Apps/`.
6. App Groups: `group.com.natural.BonhommeRemote` on both targets.
7. HealthKit on both; Background Modes (processing/audio) on phone; workout-processing on watch.

## SPM-only verification (no device)

```bash
cd /Users/lp.more/Projects/ClusterFuck
swift package describe
swift test
```

Device MusicKit / HealthKit / headphone motion require a signed app — not covered by `swift test`.
