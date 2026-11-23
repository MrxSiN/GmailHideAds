# Gmail Hide Ads v2.1.1

## Ads are hidden again on Gmail 2026.11

Gmail `2026.11.09` moved its ad row classes from `com.google.android.gm.ads` to `com.google.android.apps.gmail.libraries.ads`, keeping their names. 2.1.0 found none of them there, fell back to the `addView` hook, and let every ad through.

### Fixed

- `row.bf` accepts both ad packages: a class is an ad row when its name starts with `com.google.android.gm.ads.` or `com.google.android.apps.gmail.libraries.ads.` and ends with `AdTeaserItemView` (`docs/policy/row.md`). The prefix machine became a trie that branches after `com.google.android.`; the name alphabet gained `p` and `b` (`NC_P`, `NC_B`, appended).
- DexKit discovery searches both packages.

### Also in this release

- bfcc, the Brainfuck compiler written in Brainfuck, generates and checks the policy files; its output is byte-identical to the Python compiler's, so the shipped policy code is unchanged by it (`docs/BFCC.md`).

### Verified

- On a Pixel 8 Pro (Android 17, Vector 2.2, API 102) with Gmail `2026.11.09.1019722178.Release`: DexKit found and `row.bf` accepted 6 ad row classes in 310 ms, 2 ms from the cache on the next start; the inflate layer installed; a live `ImageCarouselAdTeaserItemView` ad in Promotions was collapsed with no gap left (`bfFailures=0`).
- Toolchain and program tests (26), BBC-built policy fixtures, the bfcc self-hosting chain, `bfcc gen --check`, and the JVM parity, robustness and benchmark suites (16) pass.

Older Gmail builds with the `com.google.android.gm.ads` package were covered by the parity tests only, not re-run on a device. LSPatch, 32-bit and x86 devices were not run for this release.

### Version metadata

- Version name: `2.1.1`
- Android version code: `5`
- Git tag: `v2.1.1`
- APK filename: `GmailHideAds-v2.1.1.apk`

### Updating

Install the v2.1.1 APK over 2.1.0. With Gmail running, Vector hot reloads it; otherwise force-stop and reopen Gmail. Confirm the framework log reports `ad row class(es) found by DexKit` with a non-zero count and `Layer installed: ad-teaser inflate`.
