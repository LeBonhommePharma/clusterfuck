# One bundle identifier per app

**Decided by LP on 2026-09-21.** Applies to ClusterFuck, Exergy, and RIVE if it
becomes a native app. **Does not apply to NATURaL** — see "Grandfathered".

## The decision

ClusterFuck ships under a single identifier, `com.lebonhommepharma.clusterfuck`,
on every platform. One App Store Connect record, one SKU, one listing.

| Target | Platform | Identifier | Record |
|---|---|---|---|
| ClusterFuck | iOS / iPadOS | `com.lebonhommepharma.clusterfuck` | the record |
| ClusterFuckMac | macOS | `com.lebonhommepharma.clusterfuck` | same record, added as a platform |
| ClusterFuckWatch | watchOS | `…clusterfuck.watchkitapp` | embedded — not a record |

`ClusterFuckMac` previously declared `com.lebonhommepharma.clusterfuck.mac`,
which forced a second record and a second full listing.

The watch app keeps a sub-identifier because Apple requires that of embedded
apps. A sub-identifier is not a second listing; it is a component of the one
above it.

## BonhommeRemote is untouched, and separate on purpose

`com.natural.BonhommeRemote` (+ `.watchkitapp`) keeps its own identifier and its
own record. It has no Mac target, so it is already exactly one record, and
whether it is a distinct product or an internal host is still open — see
[TODO.md](TODO.md), "Decide whether NATURaL Remote is a separately submitted
product or an internal host". This decision does not settle that question and
does not merge the two.

## Why

- **Consolidated ratings and review counts.** Separate records split the same
  audience, and each starts from zero.
- **Cross-platform purchase.** Bought once, available everywhere. Universal
  purchase activates once App Review approves a second platform.
- **One submission per update, not two.** Every record is its own screenshot set
  at every device size, description, keyword set, age rating, privacy nutrition
  label, support URL and privacy policy URL — and its own review cycle, with a
  round trip on every rejection.

Across the portfolio the choice was eleven listings against seven.

## What Apple actually requires

Verified against App Store Connect Help on 2026-09-21, not from memory:

> "If you want to offer an app with multiple platforms as a single purchase,
> create it as a single record in App Store Connect. All platforms will share
> the same bundle ID, but you'll add platform-specific information separately."

> "A macOS, tvOS, visionOS app, or any combination of creating these platforms,
> uses the same Apple ID (an app identifier), SKU, and bundle ID as the iOS app."

> "Watch-only apps are considered part of the iOS platform in App Store Connect."

Platforms can be added to an existing record later — "In the sidebar, click Add
Platform" — **provided the identifiers already match**. That is the part that is
not reversible after shipping, and the reason this was settled before first
submission rather than after.

Sources: [Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app),
[Add platforms](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/)

## Grandfathered: NATURaL

NATURaL registered distinct per-platform identifiers — `com.natural.BonhommeTV`,
`com.natural.BonhommeVision`, `com.natural.Bonhomme.mac` — and its records are
live with a permanent SKU. It keeps them. Changing them now would cost real work
and buy nothing, because the records already exist and cannot be merged.

Do not "fix" NATURaL to match this document. The inconsistency is deliberate.

## watchOS: embedded, and why

`ClusterFuckWatch` and `BonhommeRemoteWatch` are both embedded in their phone
targets (`embed: true`) and always have been, so each rides in one archive under
one listing. No change was needed.

A standalone watch record was considered and rejected: watchOS is not a
selectable platform in App Store Connect, so a standalone watch app means a
watch-*only* app with no iOS version at all.

`WKRunsIndependentlyOfCompanionApp: YES` is set on both and is **orthogonal to
the listing count** — it governs whether the watch app can run without the phone
app installed, not whether it gets its own record.

## Enforcement

`scripts/validate-submission.py` now asserts the exact identifier set declared by
`project.yml`, anchored to whole lines and counted.

The previous form asked whether `"com.lebonhommepharma.clusterfuck"` appeared
anywhere in the file. The `watchkitapp` line satisfies that on its own, so the
main app's identifier could have been deleted or mistyped and a sibling would
have covered for it. Both mutations are now refused, and the Mac host's
identifier is counted at 2 — one for iOS, one for macOS — so the shared id is
the asserted contract rather than an accident that happens to pass.
