<div align="center">

# <img src="branding/gmail-hide-ads-icon.png" width="36" height="36"> Gmail Hide Ads

### A focused Xposed module for removing sponsored rows from the Gmail Android app

[![Android](https://img.shields.io/badge/Android-Vector-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/JingMatrix/Vector)
[![API](https://img.shields.io/badge/libxposed%20API-102-brightgreen?style=for-the-badge)](https://github.com/libxposed/api)
[![Target](https://img.shields.io/badge/Target-Gmail-EA4335?style=for-the-badge&logo=gmail&logoColor=white)](https://mail.google.com/)
[![JDK](https://img.shields.io/badge/JDK-17%2B-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)](https://openjdk.org/)

</div>

<p align="center"><img src="branding/gmail-hide-ads-icon.png" width="160" alt="Gmail Hide Ads app icon"></p>

## ✨ Features

- Removes sponsored conversation rows from the Gmail inbox before they are measured.
- Identifies an advertisement by its view class, which Gmail's own layouts name and minification cannot rename.
- Needs no per-locale word list, and never mistakes a message whose subject reads "Ad" for an advertisement.
- Waits for `Application.attach()` so Gmail's final application context is ready before the hook is installed.
- Hooks an Android framework method rather than a Gmail class, so a Gmail update does not move the hook point.
- Deoptimizes the hook target so ART cannot serve an inlined copy past the hook.
- Classifies each view class once and caches the result, keeping a hot framework path cheap.
- Fails open: if the layer cannot install, Gmail is left exactly as it was.
- Carries no native library and no DEX-search dependency.
- Limits its scope to the official Gmail Android package.

## 🎯 Scope

The module hooks only:

```text
com.google.android.gm
```

Do not enable additional applications in the module scope.

## 🔍 How it works

Gmail is minified on every release, so almost nothing inside it keeps a stable name. Its advertisement rows are the exception, and that exception is what this module is built on:

1. The module entry class extends `io.github.libxposed.api.XposedModule` and installs a lightweight `Application.attach()` guard from `onPackageReady()` rather than hooking immediately.
2. Once Gmail supplies its real application context, the single hook layer is installed through a pipeline that isolates failures, so a layer that cannot install is logged and skipped instead of taking Gmail down with it.
3. Every Gmail ad row is inflated from a layout that names its root class in XML. R8 cannot rename a class that a layout refers to by name, so these six survive minification intact:

```text
com.google.android.gm.ads.adteaser.BasicAdTeaserItemView
com.google.android.gm.ads.adteaser.VideoAdTeaserItemView
com.google.android.gm.ads.adteaser.ImageCarouselAdTeaserItemView
com.google.android.gm.ads.adteaser.RichButtonChipAdTeaserItemView
com.google.android.gm.ads.adteaser.AppInstallButtonChipAdTeaserItemView
com.google.android.gm.ads.adteaser.EuSingleImageAdTeaserItemView
```

4. The module hooks `ViewGroup.addView(View, int, ViewGroup.LayoutParams)`, the overload that the other four public `addView` signatures funnel into, and the first moment a row has its layout parameters.
5. A view is classified by walking its superclasses for a name under `com.google.android.gm.ads.` ending in `AdTeaserItemView`, so a release that subclasses one of these is still recognized. The verdict is cached per class, because `addView` is a hot path.
6. A matching row has its layout height zeroed and its visibility set to `GONE` before it is ever measured. Both are required: `GONE` stops the row drawing, but a RecyclerView layout manager still measures its attached children, so the height must be zero for the row to occupy no space.
7. The hook target is deoptimized through `XposedInterface.deoptimize`. The shorter `addView` overloads are small enough for ART to inline, and without deoptimization an already compiled caller can bypass the hook.

There is no restore path, and none is needed. Gmail gives an advertisement its own RecyclerView item type, so a row of one of these classes is never rebound to ordinary mail.

Matching the class rather than the rendered badge is a deliberate choice. Gmail's English badge is the string resource `string/ad`, whose value is simply `Ad`; matching that text needed a word list in every language Gmail ships, and it collapsed ordinary mail during testing. The class name carries the same information and cannot be mistaken.

Gmail serves these advertisements in the **Promotions** and **Social** tabs. With the Promotions tab switched off in Gmail's settings, Gmail delivers none and the module has nothing to remove.

## ✅ Requirements

### Runtime

- A framework implementing the modern Xposed API, version 101 or newer. The legacy `de.robv.android.xposed` API is not used, so frameworks that only implement it cannot load this module. Two supported options:
  - **Rooted:** [Vector](https://github.com/JingMatrix/Vector) on Android 8.1 or newer, with Magisk or KernelSU and Zygisk enabled.
  - **Rootless:** [LSPatch](https://github.com/JingMatrix/LSPatch), which embeds Vector into a patched Gmail APK and loads modern libxposed modules through the same runtime. Use the `JingMatrix` fork; the archived `LSPosed/LSPatch` build predates the modern API and cannot load this module.
- The official Gmail application (`com.google.android.gm`).
- The **Gmail Hide Ads** APK installed and enabled in the framework manager, or baked into the patched APK in LSPatch integrated mode.

### Build environment

- Android Studio with JDK 17 or newer, **or** a standalone JDK 17+ setup.
- Gradle 9.6.1 when building without an existing wrapper.
- Android SDK Platform 36.
- Git or a downloaded copy of the project source.

## 🛠️ Build

From the project directory, build the release APK with the included wrapper:

#### Linux / macOS

```bash
./gradlew :app:assembleRelease
```

#### Windows PowerShell

```powershell
.\gradlew.bat :app:assembleRelease
```

The generated APK will be located under:

```text
app/build/outputs/apk/release/
```

The release build is signed only when `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_PASSWORD` are all set in the environment; otherwise it is produced unsigned. No credential is stored in this repository.

## 📦 Installation

1. Build and install the release APK, or download it from the [latest release](https://github.com/MrxSiN/GmailHideAds/releases/latest).
2. Open the framework manager. With LSPatch, patch Gmail in manager mode and select the module there, or patch it in integrated mode with the module embedded.
3. Enable **Gmail Hide Ads**.
4. The module declares a static scope of `com.google.android.gm` in `META-INF/xposed/scope.list`, so no scope selection is required.
5. Force-stop Gmail once after installing or updating the module, then reopen it.
6. Review the framework logs for entries beginning with:

```text
GmailHideAds
```

A working start-up logs the framework, the detected Gmail build, and the installed layer:

```text
Gmail Hide Ads v1.0.0: loading in com.google.android.gm, framework=Vector 2.2, api=102
Host: 2026.08.17.974752392.Release (65972134)
Layer installed: ad-teaser
Active layers: 1/1
```

Each removal is logged with the class and view id that matched, which is what a bug report needs if a later Gmail renames something:

```text
Collapsed advertisement row #1: com.google.android.gm.ads.adteaser.BasicAdTeaserItemView#basic_ad_teaser_item
```

## 🧪 Validation status

The release version is `1.0.0` (`versionCode 1`). The ad row class names were read out of the compiled layouts of Gmail `2026.08.17.974752392.Release` (`65972134`) and confirmed present and unrenamed in its DEX.

The module was measured on a Pixel 8 Pro running Android 17 with Vector 2.2 (libxposed API 102). The layer installs, and a real sponsored row was collapsed in the Promotions tab, logged as `BasicAdTeaserItemView#basic_ad_teaser_item`, leaving the list with no advertisement and no empty gap. Gmail rendered normally throughout Primary, Promotions, Social, Updates and Forums under repeated scrolling, with no crash and no ordinary mail collapsed. The signed release APK was verified to carry the project signing certificate and was then confirmed to load and install its layer from the published artifact.

One caveat is worth stating plainly: Gmail delivers these advertisements intermittently, so a side-by-side capture of the same row with the module disabled was not obtained. The evidence is the logged removal of a genuine ad row instance, not a paired screenshot.

The included GitHub Actions workflow builds on every push, pull request, and manual run. A `v*` tag additionally builds, signs, verifies and attaches the release APK to the GitHub Release when the four signing secrets are configured. Pull-request builds remain unsigned, because signing secrets are not exposed to pull-request code.

## 🩺 Troubleshooting

| Problem | Suggested action |
| --- | --- |
| No advertisement is ever removed | This is expected when no advertisement is being served. Gmail shows these only in the Promotions and Social tabs; if the Promotions tab is switched off in Gmail's settings, there is nothing to remove. |
| Sponsored rows still appear | Confirm the module is enabled and that the log reports `Active layers: 1/1`. If the layer installed but nothing is collapsed, Gmail has probably renamed its ad row classes. |
| No module log entries at all | Verify the module is enabled and Gmail is in scope, then force-stop Gmail once. The framework must implement libxposed API 101 or newer. |
| `ViewGroup.addView hook rejected` | The framework refused the hook. Check that it reports API 101 or newer in the start-up line. |
| Layer installs but rows are not collapsed after a Gmail update | Capture the `Collapsed advertisement row` lines, or their absence, along with the `Host:` line naming the Gmail build, and report them. |
| An advertisement briefly reappears while scrolling fast | RecyclerView can re-attach a cached row through a path that bypasses `addView`. Report the Gmail version if this is reproducible. |

## 🙏 Credits

This project depends on and benefits from the following open-source work:

| Project | Contribution |
| --- | --- |
| [Vector](https://github.com/JingMatrix/Vector) by JingMatrix | Provides the ART hooking framework, and the method deoptimization used to reach inlined framework methods. Licensed under GPL-3.0. |
| [LSPatch](https://github.com/JingMatrix/LSPatch) by JingMatrix | Embeds Vector into a patched APK, which is how this module runs without root. Licensed under GPL-3.0. |
| [libxposed API](https://github.com/libxposed/api) | The modern Xposed module API this module compiles against. Licensed under Apache-2.0. |

## ⚠️ Disclaimer

This project is not affiliated with, endorsed by, or sponsored by Google LLC.
"Gmail" is a trademark of Google LLC and is used only to name the application
this module targets. The module modifies Gmail's behaviour in memory on the
user's own device; it does not redistribute or patch the Gmail APK, and it
transmits nothing off the device. It is provided for educational and personal
use. App updates may break the hook without notice.
