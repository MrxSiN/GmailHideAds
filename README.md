# Gmail Hide Ads

An Xposed module that removes sponsored rows from the Gmail for Android
conversation list.

Built against the modern [libxposed API](https://github.com/libxposed/api)
(102), so it runs on [Vector](https://github.com/JingMatrix/Vector) and on any
other framework that implements that API. The legacy
`de.robv.android.xposed` API is not used anywhere.

## How it works

Gmail is minified on every release, so almost nothing in it keeps a stable
name. Its advertisement rows are the exception: each one is inflated from a
layout that names its root class in XML, so R8 cannot rename them. In Gmail
2026.08 that set is, all in `com.google.android.gm.ads.adteaser`:

`BasicAdTeaserItemView`, `VideoAdTeaserItemView`,
`ImageCarouselAdTeaserItemView`, `RichButtonChipAdTeaserItemView`,
`AppInstallButtonChipAdTeaserItemView`, `EuSingleImageAdTeaserItemView`.

The module hooks `ViewGroup.addView(View, int, LayoutParams)` — the overload the
other four public `addView` signatures funnel into — and when the view being
added is one of those classes it zeroes the row's height and marks it `GONE`
before the row is ever measured. The hook is on the Android framework, not on
Gmail, so a Gmail update does not move the hook point.

Matching the class instead of the rendered "Ad" badge means the rule needs no
per-locale word list and cannot mistake a message whose subject happens to read
"Ad" for an advertisement.

There is no restore path, because none is needed: Gmail gives an advertisement
its own RecyclerView item type, so a row of one of these classes is never
rebound to ordinary mail.

## Build

```
./gradlew assembleRelease
```

The release build is signed only when all four of `ANDROID_KEYSTORE_PATH`,
`ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_PASSWORD`
are set; otherwise it is produced unsigned. No credential is stored in this
repository.

## Release

CI builds every branch. Pushing a `vX.Y.Z` tag that matches `appVersion` in
`app/build.gradle.kts` builds, signs, verifies and publishes the APK to a GitHub
release. The workflow needs four repository secrets: `SIGNING_KEY` (the keystore,
base64-encoded), `ALIAS`, `STORE_PASSWORD` and `KEY_PASSWORD`.

## Install

1. Install the APK.
2. Enable **Gmail Hide Ads** in your Xposed manager.
3. Confirm Gmail is in the module's scope.
4. Force-stop Gmail and reopen it.

Filter logcat for `GmailHideAds` to see the framework it loaded on, the Gmail
version it detected, and every row it removed:

```bash
adb logcat -s GmailHideAds:V
```

Gmail only serves these ads in the **Promotions** and **Social** tabs. With the
Promotions tab switched off in Gmail's settings there is nothing for the module
to remove.

## Verified against

Gmail `2026.08.17.974752392.Release` (65972134) on Android 17, Vector 2.2
(API 102). The ad row class names above were read out of that build's layouts;
if a later Gmail renames them, the log line for a collapsed row names the view
that matched, which is what a bug report needs.

## Licence

GPL-3.0. See [LICENSE](LICENSE).
