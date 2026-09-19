# Verification — 19 September 2026

Current verified implementation: **98c9ed07961e9b57b1429956eefef16666965680**.

[CI run 35469911750](https://github.com/LeBonhommePharma/clusterfuck/actions/runs/35469911750) completed successfully on 19 September 2026: Linux contracts, macOS Swift package build, **68 XCTest cases with zero failures**, standalone Health/HUD assertions, and unsigned Debug app builds for **iOS/iPadOS with embedded watchOS** and **native macOS**. Xcode result bundles are attached to that run.

This verifies compilation and automated tests. It does **not** establish physical sensor behavior, rendered accessibility/layout acceptance, Release distribution archives, signing/profile validity, App Store processing, or submission readiness. No upload or submission was performed. Full Xcode remains uninstalled locally; app builds ran on GitHub's macOS runner.

| Check | Result |
|---|---|
| `python3 scripts/validate-submission.py` | PASS: all icon slot dimensions, plist privacy structure, actual Xcode targets/team, version expansion, bundled resources and both Watch embeddings |
| `python3 scripts/test_contracts.py` | PASS: existing source contracts; not runtime tests |
| `swiftc -frontend -parse Sources/NaturalRemote/Session/RemoteSessionView.swift Sources/NaturalRemote/Theme/ClusterFuckTheme.swift Tests/NaturalRemoteTests/AppSessionFacadeTests.swift` | PASS: Swift syntax only, not type checking/linking |
| `git diff --check` | PASS |
| `xcodegen generate --spec project.yml` and `--spec clusterfuck.project.yml` | PASS: both project files regenerated from one configuration |
| `swift test --scratch-path /private/tmp/clusterfuck-release-spm` | BLOCKED: after approved sandbox retry, dependency asset processing requires actool from full Xcode; Xcode is uninstalled. Log: `/private/tmp/clusterfuck-swift-tests.log` |
| App builds | PASS in remote CI 35469911750: unsigned Debug iOS/iPadOS + embedded Watch and native Mac |
| Full XCTest | PASS in remote CI 35469911750: 68 tests, zero failures, including 3 injected Health observation/lifecycle tests |
| Screenshots / native runtime / signing | NOT VERIFIED: actual device tests, signed Release archives and final screenshots remain required |

The new XCTest `testMusicFailureReachesVisibleErrorState` injects a Spotify transport failure and requires a visible error and cleared busy state. It passed with the full XCTest suite in CI run 35469911750.

Remaining functional limitations are listed explicitly in TODO.md. No simulator, physical-device, signing, or production integration result is inferred from source-string checks.

## HUD provenance refinement

- Reviewed local/remote branch history before editing. The only additional SCI branch commit (`a488578`) is equivalent to the already merged `fa01a33`; no unmerged live sensor implementation was found in those refs.
- Added per-signal unavailable/simulated/measured provenance. Current production paths do not claim measured input; sensor integration remains open.
- Session start alone leaves metrics unavailable. Synthetic inputs and demo doses remain visibly identified, including accessibility copy; local light targets are unconfirmed requests.
- Stop clears displayed evidence; ordered actor refresh replaces the detached snapshot task. Pending snapshot results cannot restore stopped-session values.
- Added dependency-free runtime assertions in `scripts/test-hud-evidence.swift`, plus XCTest integration cases for start, demo, dose and restart behavior. The full XCTest suite subsequently passed using Xcode on the CI runner (35469911750).
- Fixed a separate accessibility trap: non-finite closure values no longer convert directly to Int in the sigma gauge.

Executed the standalone evidence test with the installed Command Line Tools:

```sh
swiftc -module-cache-path /private/tmp/clusterfuck-hud-module-cache Sources/NaturalRemote/Session/RemoteHUDEvidence.swift scripts/test-hud-evidence.swift -o /private/tmp/clusterfuck-hud-evidence
/private/tmp/clusterfuck-hud-evidence
```

Result: **PASS — 12 runtime assertions** (numeric validity, unavailable masking, genuine zero, demo precedence, waiting/idle/measured labels). Source syntax parsing, Python contracts, project validator and `git diff --check` also pass after these edits. This does not exercise SwiftUI or actual sensor connections.

## HealthKit observation implementation

Added a cancellable anchored-query stream for saved heart-rate/SDNN samples and heartbeat series. Actual contiguous inter-beat intervals supply RMSSD and SDNN; read-access denial remains indistinguishable from absent data as required by HealthKit privacy. The HUD labels recent health readings as measured and sigma as a model estimate; absent/stale intervals leave SCI unavailable. Readings expire after two minutes, out-of-order/invalid samples are rejected, and stop cancels observations. This is foreground observation of saved Health data, not a claim of continuous wrist/background acquisition.

Standalone compiled health assertions PASS: finite values, genuine zeros, stale/future/out-of-order rejection, interval gaps, analytical RMSSD/SDNN and deleted/error-state clearing. Injected-source XCTest covers permission/no-data, real interval delivery, expiry, failure, deletion and cancellation; all three injected observation tests passed in CI run 35469911750.

Fixed Ubuntu CI's confirmed `FileNotFoundError: plutil` from run [35468939018](https://github.com/LeBonhommePharma/clusterfuck/actions/runs/35468939018). Portable project parsing matches Apple's plutil output exactly for both committed projects; all previous project checks remain enforced. That run's macOS package build and XCTest passed. CI now also compiles the iOS/watchOS and native Mac app hosts.

API references: [read authorization privacy](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data), [anchored queries](https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery), [heartbeat query and gaps](https://developer.apple.com/documentation/healthkit/hkheartbeatseriesquery/init(heartbeatseries:datahandler:)).

The new real app-build gate exposed two existing platform-specific UI errors: watchOS cannot use UIKit dynamic UIColor providers; iOS cannot use List's nonoptional-selection overload. The Watch now uses its approved dark palette, and sidebar selection uses a supported optional binding. Run [35469617630](https://github.com/LeBonhommePharma/clusterfuck/actions/runs/35469617630) confirmed the latter via preserved xcresult diagnostics. All package tests and Linux contracts passed before these app-host gates. CI retains all targets/architectures and result bundles; final app compilation passed for both app-host steps on corrected head 98c9ed0 in run 35469911750. The app targets also use the valid Swift 5 language mode instead of an invalid 5.9 language-mode setting; the package tools version remains unchanged.
