<div align="center">

<img src="docs/icon.svg" width="120" alt="Gmail Hide Ads">

# Gmail Hide Ads

**An Xposed module that removes sponsored rows from the Gmail Android app, with its ad policy written in Brainfuck. Yes, really.**

Sponsored rows are collapsed before Gmail measures them, not hidden after.

<br>

[![Release](https://img.shields.io/github/v/release/MrxSiN/GmailHideAds?include_prereleases&color=EA4335&label=release&style=for-the-badge)](https://github.com/MrxSiN/GmailHideAds/releases)
[![Downloads](https://img.shields.io/github/downloads/MrxSiN/GmailHideAds/total?color=3DDC84&logo=android&logoColor=fff&style=for-the-badge)](https://github.com/MrxSiN/GmailHideAds/releases)
[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?logo=android&logoColor=fff&style=for-the-badge)](#requirements)
[![libxposed](https://img.shields.io/badge/libxposed-API%20102-E8A33D?style=for-the-badge)](https://github.com/libxposed/api)

</div>

---

> [!NOTE]
> Gmail serves these advertisements only in the **Promotions** and **Social** tabs, and only
> intermittently. With the Promotions tab switched off in Gmail's settings, Gmail delivers none and
> the module has nothing to remove. See the [compatibility](#compatibility) table for what has
> actually been tested.

## Why Brainfuck?

Surely nobody would write the decision logic of an ad blocker in Brainfuck.

Brainfuck was selected for its rich ecosystem, mature package manager, excellent Android SDK
bindings, comprehensive type system, first-class coroutine support, and famously pleasant
debugging experience.

Just joking.

The real idea is the one [ThreadsHideAds](https://github.com/MrxSiN/ThreadsHideAds) proved out and
[TwitterHideAds](https://github.com/MrxSiN/TwitterHideAds) followed: **keep every decision about
Gmail out of the Android code.** Which class names mark an advertisement, whether a superclass
counts, which package and which process the module belongs in — that is the part that has to change
when Gmail changes, and it now lives in one place that cannot touch anything else.

Brainfuck enforces that boundary, because it literally cannot call Android, Xposed or JNI. It reads
bytes and writes bytes. Java reduces a view's class chain to one small code per character, sends it
in one request, and does exactly what the answer says. GmailHideAds uses Brainfuck for its
decision-policy core, while Android/Xposed integration remains Java/native.

The two programs are plain eight-command Brainfuck, compiled ahead of time to C and then to native
code with the NDK. There is no interpreter in the APK. A request takes about 1 µs on a Pixel 8 Pro and
runs once per view class; every later row of that class is answered from a cache. DexKit finds the
ad row classes once, so only those classes are hooked, and a new build hot reloads into a running
Gmail.

|  | |
|---|---|
| 🧹 **Collapsed before measure** | A sponsored row loses its height and its visibility the moment it is added to the list, so there is no gap and no flash of an ad. |
| 🏷️ **Matches the class, not the badge** | Gmail's own layouts name the six ad row classes, so minification cannot rename them. No per-locale word list, and a message whose subject reads "Ad" is never touched. |
| 🧠 **Policy in Brainfuck, compiled** | Every decision is Brainfuck, compiled ahead of time to native code. One native call per view class, no allocations. |
| 🛟 **Fails open** | If the library or a request fails, the row is kept, and if the scope check fails, nothing is installed at all. |
| 🎯 **Hooks only the ad rows** | DexKit lists Gmail's ads package once, `row.bf` picks the rows, and only their `onFinishInflate` is hooked. The names are cached per Gmail build, so a cold start pays about 2 ms. |
| 🔁 **No restart to update** | Vector hot reloads a new build into a running Gmail process. |
| 🧪 **Proven identical** | The 1.0.0 Java policy is kept as a test oracle; 634 229 comparisons per run, on the JVM and on an arm64 phone, check that old and new answers match. |

---

## What it removes

A row is an advertisement when its view class, or any superclass, is named
`com.google.android.gm.ads.…AdTeaserItemView`. Every Gmail ad row is inflated from a layout that
names its root class in XML, and R8 cannot rename a class a layout refers to by name, so all six
survive minification intact:

```text
com.google.android.gm.ads.adteaser.BasicAdTeaserItemView
com.google.android.gm.ads.adteaser.VideoAdTeaserItemView
com.google.android.gm.ads.adteaser.ImageCarouselAdTeaserItemView
com.google.android.gm.ads.adteaser.RichButtonChipAdTeaserItemView
com.google.android.gm.ads.adteaser.AppInstallButtonChipAdTeaserItemView
com.google.android.gm.ads.adteaser.EuSingleImageAdTeaserItemView
```

A Gmail release that subclasses one of these, under any name, is still caught. Ordinary mail is
never touched: Gmail gives an advertisement its own RecyclerView item type, so a row of one of these
classes is never rebound to a message, and there is nothing to restore.

<details>
<summary><b>🚫 What was tried and dropped</b></summary>
<br>

| Approach | Why it went |
|---|---|
| Emptying the cursor Gmail loads ads from | Modern Gmail has no ad provider; the layer hooked every query and could never fire. |
| Matching the rendered "Ad" badge | Gmail's English badge is `string/ad`, simply `Ad`. It needed a word list per language and collapsed ordinary mail in testing. |

</details>

---

## Status

**v2.1.0.** DexKit discovery of the ad row classes, hooks on those classes only, and hot reload.
On a Pixel 8 Pro the scan takes about 300 ms once per Gmail build and 2 ms from the cache after that.

**v2.0.0.** The decision policy moved from Java into two Brainfuck programs, compiled ahead of time.
The 1.0.0 Java policy was frozen as an oracle first, and the new programs answer identically over
634 229 randomized and exhaustive comparisons on the JVM and on an arm64 phone
([`docs/BRAINFUCK_ARCHITECTURE.md`](docs/BRAINFUCK_ARCHITECTURE.md)).

The release version is `2.1.0` (`versionCode 4`).

### Compatibility

Each row is one setup somebody has actually run. If you try another, please open a pull request
adding a row.

| Device | Android | Framework | Gmail | Module | Result | Tester | Date |
|---|---|---|---|---|---|---|---|
| Pixel 8 Pro | 17 | Vector 2.2 (API 102) | 2026.09.07.986350278 | 2.1.0 | DexKit found 6 row classes (289 ms, 2 ms cached); inflate layer installed; hot reload over 2.0.0 in the running process. No ad served, so no live collapse yet | @MrxSiN | 2026-09 |
| Pixel 8 Pro | 17 | — (instrumented tests) | — | 2.0.0 | 16 policy tests pass on arm64: 634 229 parity comparisons, robustness, concurrency | @MrxSiN | 2026-09 |
| Pixel 8 Pro | 17 | Vector 2.2 (API 102) | 2026.08.17.974752392 | 1.0.0 | Layer installed; a real sponsored row collapsed in Promotions, no gap; no ordinary mail touched | @MrxSiN | 2026-09 |

### Known limits

- **2.1.0 in Gmail**: discovery, the inflate hooks and hot reload run inside Gmail, but no ad was
  served while testing, so the new hook has not yet been seen collapsing a live row.
- Gmail serves ads intermittently, so no side-by-side capture of the same row with the module off
  exists; the 1.0.0 evidence is the logged removal of a genuine ad row.
- Vector hot reloads only when the `versionCode` changes; force-stop Gmail otherwise.
- 32-bit and x86 devices ship the native library but have not been run.

## Requirements

| | |
|---|---|
| **Android** | 8.0 (API 26) or newer |
| **App** | Gmail (`com.google.android.gm`) |
| **Framework** | [Vector](https://github.com/JingMatrix/Vector) or another libxposed API 102 framework, or [LSPatch](https://github.com/JingMatrix/LSPatch) |
| **Root** | Required by Vector; the module itself asks for none |

Built against the modern [libxposed API](https://github.com/libxposed/api)
(`io.github.libxposed:api`), not the legacy `de.robv.android.xposed` bridge.

## Install

```
1. Install the APK from Releases
2. Enable Gmail Hide Ads in Vector
3. Force-stop Gmail once, then open it
```

The module declares a **static scope** — Gmail only — so there is nothing to pick.

The framework log shows what happened, in lines tagged `GmailHideAds`. A working start-up looks like:

```text
Gmail Hide Ads v2.1.0: loading in com.google.android.gm, framework=Vector 2.2, api=102, policyCore=brainfuck-aot abi=1.0
Host: 2026.09.07.986350278.Release (66020097)
6 ad row class(es) from cache in 2 ms
Layer installed: ad-teaser inflate
Collapsed advertisement row #1: com.google.android.gm.ads.adteaser.BasicAdTeaserItemView#basic_ad_teaser_item (bfCalls=<n>, bfFailures=0, malformed=0)
```

<details>
<summary><b>Without root: LSPatch</b></summary>
<br>

The module has no root-only calls, so LSPatch can embed it into Gmail:

1. Install the LSPatch manager ([JingMatrix fork](https://github.com/JingMatrix/LSPatch); the
   archived `LSPosed/LSPatch` predates the modern API).
2. Patch Gmail with **Gmail Hide Ads**, in manager mode or embedded.
3. Uninstall the store copy of Gmail, then install the patched APK.

</details>

---

## How it works

```
Gmail / Android
  → libxposed hook (Application.attach guard, each ad row's onFinishInflate)
  → Java host (class chain, per-class cache, deoptimization)
  → normalized primitive facts: one small code per character of each class name
  → JNI (one call)
  → AOT-compiled Brainfuck policy (libgmailbf.so)
  → yes / no
  → Java host collapses the row
```

One rule decides where code goes: **if it needs Android, Java, Xposed or JNI, Java does it; if it
decides what to do with what Java read, Brainfuck decides.**

<details>
<summary><b>Starting at the right moment</b></summary>
<br>

- Loading into a Gmail process first asks `scope.bf` whether the module belongs there: the Gmail
  package, and the main process (or one the framework did not name). Then only a small
  `Application.attach()` guard is installed, so Gmail has its real application context before
  anything else.
- At attach, DexKit lists the classes in `com.google.android.gm.ads` and `row.bf` judges each one.
  The names found are kept in Gmail's preferences, keyed by the Gmail APK path and the module version
  code, so later cold starts skip the scan. DexKit is closed before the first row is drawn.
- Each ad row class declares its own `onFinishInflate`, which runs after the inflater gave the row
  its layout parameters and before the list measures it. Only those methods are hooked. Gmail's bind
  sets the row's visibility after inflation, so the row is collapsed again whenever it is attached.
- When discovery finds nothing, or a class cannot be hooked, the fallback hooks
  `ViewGroup.addView(View, int, ViewGroup.LayoutParams)`, the overload the other public `addView`
  signatures funnel into, and deoptimizes it so an inlined caller cannot bypass it.
- Hot reload: the running generation hands over Gmail's class loader and application context; the
  new one hooks again under the same ids, which replace the old hooks in place, and takes the rest
  off.
- A matching row has its height zeroed and its visibility set to `GONE`. Both are needed: `GONE`
  stops the drawing, but a RecyclerView layout manager still measures attached children.

</details>

<details>
<summary><b>The Brainfuck core</b></summary>
<br>

| Program | Decides |
|---|---|
| `row` | whether a class chain holds a name that starts with the ads package and ends with `AdTeaserItemView` |
| `scope` | whether the package is Gmail and the process is one the module belongs in |

Each program is a `.bf` file in `brainfuck/src/` with a normative specification in
[`docs/policy/`](docs/policy/). Comments may not contain a command character, `%cell` comments name
tape cells, `@cell` checkpoints assert where the data pointer is, and `~N` asserts the length of a
run. The compiler checks all of them and turns the programs into C (clear and transfer loops, value
propagation, equality tests become `switch`), every loop charges an execution budget, and the NDK
builds `libgmailbf.so`. The compiler, bfcc, is itself written in Brainfuck and compiles itself; see
[`docs/BFCC.md`](docs/BFCC.md). The tape lives on the caller's stack, so concurrent
calls share nothing. Frame format, opcodes and memory semantics are in
[`docs/BRAINFUCK_ARCHITECTURE.md`](docs/BRAINFUCK_ARCHITECTURE.md).

</details>

<details>
<summary><b>Staying fast</b></summary>
<br>

`addView` is a hot path, so the verdict is cached per view class and a policy request runs once per
class. On a Pixel 8 Pro (release build):

| Case | Java 1.0.0 | Brainfuck 2.0.0 |
|---|---|---|
| every `addView` (cached verdict) | 0.12 µs | 0.12 µs |
| first view of an ordinary class | 0.20 µs | 0.90 µs |
| first view of a derived ad row | 0.24 µs | 1.34 µs |
| scope, once per package load | 0.41 µs | 0.81 µs |

The old check was two string comparisons, so the uncached request is slower than it was; it is paid
once per class. Full percentiles are in
[`docs/BRAINFUCK_ARCHITECTURE.md`](docs/BRAINFUCK_ARCHITECTURE.md#performance).

</details>

---

## Build

```bash
./gradlew :app:generateBrainfuck                # bfcc: check brainfuck/src, regenerate C, ABI and memory map
python -m unittest discover -s tests/compiler   # optimizer, bfcc, AOT and randomized program tests
python tools/bfcc/selfhost.py                   # bfcc's self-hosting chain
./gradlew :app:testDebugUnitTest                # JVM parity against the frozen 1.0.0 policy
./gradlew :app:assembleRelease
```

The generated files are committed; the Gradle build checks them with `checkBrainfuck` (bfcc, built
from its committed C, no Python) and never edits them. `scripts/check-project.sh` runs the static
project checks.

You need JDK 17+, Android SDK 36 with NDK 28.2.13676358 and CMake 3.22.1, a host C compiler (MSVC
Build Tools on Windows, gcc or clang elsewhere) for bfcc and the JVM tests, and Python 3.10+ for the
tests.

The release build is signed only when `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_ALIAS`,
`ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_PASSWORD` are all set; otherwise it is produced
unsigned. No credential is stored in this repository.

CI builds bfcc with `cc` and checks the generated files with it, runs bfcc's self-hosting chain
and the Python and JVM tests, then builds the release APK and
checks that every native library ships in it, on every push and pull request. A `v*` tag signs the
APK, verifies its certificate and attaches it to the GitHub Release. Pull-request builds stay
unsigned, because signing secrets are not exposed to pull-request code.

## Design

```
brainfuck/src/      the two programs: every decision, word and limit
brainfuck/          programs.json, constants.txt (ABI numbers), generated memory map
brainfuck/compiler/ bfcc, the compiler, in Brainfuck (bfcc.bf) and in its source language
docs/policy/        the normative specification of each program
tools/bfcc/         bfcc's host, its self-compiled C, the bootstrap chain
tools/bftool/       the Python reference compiler and interpreter (tests and bootstrap only)
app/src/main/cpp/   runtime, JNI glue and the generated C
policy/             GmailPolicy, per-thread request encoding, response validation, counters
GmailHideAdsModule  libxposed entry, scope check, bootstrap and hot reload
discover/           DexKit listing of the ads package, and its per-build cache
hook/               the onFinishInflate layer, and the addView fallback
detect/, ui/        the per-class cache, row collapsing, log descriptions
```

The layering, ABI, parity method and measurements are in
[`docs/BRAINFUCK_ARCHITECTURE.md`](docs/BRAINFUCK_ARCHITECTURE.md).

## Troubleshooting

| Problem | Try |
|---|---|
| No advertisement is ever removed | Expected when none is served. Gmail shows them only in Promotions and Social, and none at all with the Promotions tab switched off. |
| `using the addView fallback` | DexKit found no hookable row class; the broad layer runs instead. Report the `Host:` line. |
| Sponsored rows still appear | Check the log for `Layer installed: ad-teaser`. If the layer installed and nothing is collapsed, Gmail has probably renamed its ad row classes. |
| No module log lines at all | Check the module is enabled, then force-stop Gmail once. The framework must implement libxposed API 102. |
| `Brainfuck policy core unavailable` | `libgmailbf.so` could not load for the device ABI; nothing is installed. Reinstall the module APK. |
| `Brainfuck policy request failed open` | A request was malformed or too large and the row was kept. Report the logged `op` and `kind`. |
| `ViewGroup.addView hook rejected` | The framework refused the hook. Check that it reports API 102 in the start-up line. |
| Broken after a Gmail update | Report the `Collapsed advertisement row` lines, or their absence, with the `Host:` line naming the Gmail build. |

## Credits

| Project | Contribution |
|---|---|
| [libxposed API](https://github.com/libxposed/api), [Vector](https://github.com/JingMatrix/Vector), [LSPatch](https://github.com/JingMatrix/LSPatch) | The hooking API, framework and deoptimization the module runs on, and rootless embedding. |
| [DexKit](https://github.com/LuckyPray/DexKit) | Dex search used to find the ad row classes (LGPL-3.0-or-later). |
| [ThreadsHideAds](https://github.com/MrxSiN/ThreadsHideAds), [TwitterHideAds](https://github.com/MrxSiN/TwitterHideAds) | The Brainfuck toolchain (source checker, optimizer, AOT C emitter, reference interpreter), runtime and conventions, adapted from TwitterHideAds `v3.0.0`. |

## Disclaimer

Not affiliated with, endorsed by or sponsored by Google LLC. "Gmail" is a trademark of Google LLC and
is used only to name the app this module targets. The module changes Gmail's behaviour in memory on
the user's own device; it does not redistribute or patch the Gmail APK, and it transmits nothing off
the device. Provided for educational and personal use. Gmail updates may break the hook without
notice.
