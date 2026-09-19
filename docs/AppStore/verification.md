# Verification — 19 September 2026

These receipts cover source/configuration only and do not establish App Store readiness.

| Check | Result |
|---|---|
| `python3 scripts/validate-submission.py` | PASS: all icon slot dimensions, plist privacy structure, actual Xcode targets/team, version expansion, bundled resources and both Watch embeddings |
| `python3 scripts/test_contracts.py` | PASS: existing source contracts; not runtime tests |
| `swiftc -frontend -parse Sources/NaturalRemote/Session/RemoteSessionView.swift Sources/NaturalRemote/Theme/ClusterFuckTheme.swift Tests/NaturalRemoteTests/AppSessionFacadeTests.swift` | PASS: Swift syntax only, not type checking/linking |
| `git diff --check` | PASS |
| `xcodegen generate --spec project.yml` and `--spec clusterfuck.project.yml` | PASS: both project files regenerated from one configuration |
| `swift test --scratch-path /private/tmp/clusterfuck-release-spm` | BLOCKED: after approved sandbox retry, dependency asset processing requires actool from full Xcode; Xcode is uninstalled. Log: `/private/tmp/clusterfuck-swift-tests.log` |
| App builds / screenshots / native runtime | NOT RUN: full Xcode unavailable |

The new XCTest `testMusicFailureReachesVisibleErrorState` injects a Spotify transport failure and requires a visible error and cleared busy state. It has been syntax checked but not executed.

Remaining functional limitations are listed explicitly in TODO.md. No simulator, physical-device, signing, or production integration result is inferred from source-string checks.

## HUD provenance refinement

- Reviewed local/remote branch history before editing. The only additional SCI branch commit (`a488578`) is equivalent to the already merged `fa01a33`; no unmerged live sensor implementation was found in those refs.
- Added per-signal unavailable/simulated/measured provenance. Current production paths do not claim measured input; sensor integration remains open.
- Session start alone leaves metrics unavailable. Synthetic inputs and demo doses remain visibly identified, including accessibility copy; local light targets are unconfirmed requests.
- Stop clears displayed evidence; ordered actor refresh replaces the detached snapshot task. Pending snapshot results cannot restore stopped-session values.
- Added dependency-free runtime assertions in `scripts/test-hud-evidence.swift`, plus XCTest integration cases for start, demo, dose and restart behavior. The full XCTest suite still requires Xcode.
- Fixed a separate accessibility trap: non-finite closure values no longer convert directly to Int in the sigma gauge.

Executed the standalone evidence test with the installed Command Line Tools:

```sh
swiftc -module-cache-path /private/tmp/clusterfuck-hud-module-cache Sources/NaturalRemote/Session/RemoteHUDEvidence.swift scripts/test-hud-evidence.swift -o /private/tmp/clusterfuck-hud-evidence
/private/tmp/clusterfuck-hud-evidence
```

Result: **PASS — 12 runtime assertions** (numeric validity, unavailable masking, genuine zero, demo precedence, waiting/idle/measured labels). Source syntax parsing, Python contracts, project validator and `git diff --check` also pass after these edits. This does not exercise SwiftUI or actual sensor connections.

## HealthKit observation implementation

Added a cancellable anchored-query stream for saved heart-rate/SDNN samples and heartbeat series. Actual contiguous inter-beat intervals supply RMSSD and SDNN; read-access denial remains indistinguishable from absent data as required by HealthKit privacy. The HUD labels recent health readings as measured and sigma as a model estimate; absent/stale intervals leave SCI unavailable. Readings expire after two minutes, out-of-order/invalid samples are rejected, and stop cancels observations. This is foreground observation of saved Health data, not a claim of continuous wrist/background acquisition.

Standalone compiled health assertions PASS: finite values, genuine zeros, stale/future/out-of-order rejection, interval gaps, analytical RMSSD/SDNN and deleted/error-state clearing. Injected-source XCTest covers permission/no-data, real interval delivery, expiry, failure, deletion and cancellation; remote CI results are required before claiming those tests pass.

Fixed Ubuntu CI's confirmed `FileNotFoundError: plutil` from run [35468939018](https://github.com/LeBonhommePharma/clusterfuck/actions/runs/35468939018). Portable project parsing matches Apple's plutil output exactly for both committed projects; all previous project checks remain enforced. That run's macOS package build and XCTest passed. CI now also compiles the iOS/watchOS and native Mac app hosts.

API references: [read authorization privacy](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data), [anchored queries](https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery), [heartbeat query and gaps](https://developer.apple.com/documentation/healthkit/hkheartbeatseriesquery/init(heartbeatseries:datahandler:)).
