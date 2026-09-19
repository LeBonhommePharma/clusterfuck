# App Store TODO — ClusterFuck 1.0

Updated 19 September 2026. Owner: LP / Le Bonhomme Pharma.

Source preparation is in progress. [CI run 35469911750](https://github.com/LeBonhommePharma/clusterfuck/actions/runs/35469911750) verifies implementation head **98c9ed0**: 68 XCTest cases and unsigned Debug app builds for iOS/iPadOS, embedded watchOS, and native macOS all passed. Physical-device acceptance, signed Release archives, account setup, uploads and submission remain incomplete.

## Completed source preparation

- [x] Preserve Cursor's committed HUD/SCI/accessibility work.
- [x] Use team ZJLX84G8QV in the shared XcodeGen configuration.
- [x] Regenerate both Xcode projects from the shared configuration; include shared UI in the NATURaL Remote phone target.
- [x] Embed ClusterFuck Watch in the phone app and declare the correct companion IDs for both product families.
- [x] Synchronize all bundle versions with MARKETING_VERSION / CURRENT_PROJECT_VERSION.
- [x] Export existing Mac icon artwork at each catalog slot's actual pixel size.
- [x] Bundle icons/privacy manifests in every app target; validate actual project files.
- [x] Remove unused iOS background-processing declaration (no BGTask handler exists).
- [x] Keep compact pages scrollable, use the Mac sidebar, and ensure mint CTA text has contrast in both appearances.
- [x] Start sessions only after user action; show actual command failures as alerts.
- [x] Python source/configuration contracts, Swift syntax parsing, and whitespace checks pass (see verification.md).

## Product work still required

- [x] Implement cancellable HealthKit observation for saved heart-rate, SDNN and heartbeat-series samples. Only contiguous real beat intervals feed RMSSD/SCI control; permission success and scalar HR/SDNN do not invent intervals.
- [ ] Verify actual HealthKit collection/updates and permissions on paired hardware; foreground observation of saved samples does not guarantee continuous wrist acquisition.
- [ ] Implement and verify supported integration setup/authentication. The default controllers include local simulation/no-op paths; currently no end-user credentials/configuration UI proves Spotify, Alexa, Sonos or Apple Music operation.
- [x] Gate HUD metrics on per-signal provenance; synthetic readings/doses are labeled Demo, missing signals remain unavailable after start, and light command targets are explicitly unconfirmed.
- [ ] Validate the provenance UI on all platforms and verify measured HealthKit adapter behavior, expiration and sensor loss; external actuator confirmation remains unavailable.
- [ ] Verify actual audio/headphone capture and supported controls on hardware. Do not claim system ANC or playback changes from locally updated variables.
- [ ] Complete durable dose history, export/deletion UX if those features are included in the release description; current in-memory demo is insufficient evidence.
- [ ] Localize user-facing app copy and permission descriptions for the intended release languages.
- [ ] Resolve public App Store naming with LP. ClusterFuck is retained as requested; all-audiences metadata requirement is a review risk, not an approved name.
- [ ] Decide whether NATURaL Remote is a separately submitted product or an internal host; avoid duplicate store listings for the same functionality.

## Xcode/device verification (Xcode currently uninstalled)

- [x] Run Swift XCTest including surfaced-command-failure and injected Health observation regressions: 68 tests, zero failures in CI 35469911750.
- [x] Compile unsigned Debug iOS/iPadOS + embedded watchOS and native macOS app hosts in CI 35469911750.
- [ ] Build Release iOS/iPadOS, watchOS and native macOS from the regenerated projects.
- [ ] Exercise first launch, consent denial/revocation, start/stop, network errors and sensor loss on actual devices.
- [ ] Validate VoiceOver, largest text, smallest Watch, iPad resizing/orientation, keyboard navigation and Reduce Motion in the rendered app.
- [ ] Inspect signed embedded Watch bundle, profiles, entitlements, privacy report and archive with Organizer.
- [ ] Capture final screenshots from the actual app for iPhone, iPad, Watch and Mac.

## Publishing and account gates

- [ ] Register exact identifiers and required capabilities on ZJLX84G8QV; obtain distribution profiles.
- [ ] Publish and verify https://thebonhomme.com/ClusterFuck/ and its support/privacy pages. The local privacy document is a draft.
- [ ] Audit real release data flows before final App Privacy answers/manifests; on-device processing alone is not Apple's definition of collected data.
- [ ] Complete App Store Connect metadata, category, age-rating questionnaire, contacts, availability, encryption answers and accessibility declarations using verified behavior.
- [ ] Validate signed archives and upload/TestFlight test on every submitted platform.
- [ ] LP reviews final build, screenshots and metadata before submission.

Apple references: [metadata guidelines](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata), [privacy details](https://developer.apple.com/app-store/app-privacy-details/).
