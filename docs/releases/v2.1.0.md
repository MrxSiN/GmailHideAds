# Gmail Hide Ads v2.1.0

## DexKit discovery, narrow hooks and hot reload

This release changes how rows are caught, not which rows are removed.

### Changed

- Ad row classes are found once at start-up with DexKit: every class in `com.google.android.gm.ads` is judged by the same `row.bf` program that judges rows at runtime. The names found are cached per Gmail build, so later cold starts skip the scan (about 2 ms instead of about 300 ms on a Pixel 8 Pro).
- Only the ad rows are hooked: each one's own `onFinishInflate`, where the row is collapsed before it is ever measured, and collapsed again whenever it is attached, because Gmail's bind sets its visibility afterwards. The global `ViewGroup.addView` hook is now only the fallback when discovery finds nothing hookable.
- Hot reload: installing a new build while Gmail runs swaps the module in place, with no force-stop.
- Requires libxposed API 102 (`minApiVersion=102`).
- Adds DexKit `2.2.0` (LGPL-3.0-or-later).

### Verified

- On a Pixel 8 Pro (Android 17, Vector 2.2, API 102) with Gmail `2026.09.07.986350278.Release`: DexKit found and `row.bf` accepted all six ad row classes in 289 ms; the next cold start read them from the cache in 2 ms; installing this build over 2.0.0 hot reloaded into the running Gmail process (same PID), replaced the hooks and took the stale one off.
- `gradle check`: Brainfuck generation, toolchain tests, parity and robustness suites and lint pass.

Gmail served no advertisement during testing, so the collapse of a live ad row by the new hook has not yet been observed; the fallback `addView` path is the one validated on 1.0.0. LSPatch, 32-bit and x86 devices were not run for this release.

### Version metadata

- Version name: `2.1.0`
- Android version code: `4`
- Git tag: `v2.1.0`
- APK filename: `GmailHideAds-v2.1.0.apk`

### Updating

Install the v2.1.0 APK over 2.0.0. With Gmail running, Vector hot reloads it; otherwise force-stop and reopen Gmail. Confirm the framework log reports `Layer installed: ad-teaser inflate`.
