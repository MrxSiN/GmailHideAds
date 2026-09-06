# Gmail Hide Ads

An Xposed module that removes sponsored rows from the Gmail for Android
conversation list.

Built against the modern [libxposed API](https://github.com/libxposed/api)
(102), so it runs on [Vector](https://github.com/JingMatrix/Vector) and on any
other framework that implements that API. The legacy
`de.robv.android.xposed` API is not used anywhere.

## How it works

Gmail is minified on every release, so class and method names change constantly.
Nothing in this module depends on them. Both layers hook Android framework
methods, whose signatures are stable, and decide what to suppress from data that
Gmail cannot obfuscate: the content URI a query reads from, and the caption a
badge renders.

| Layer | Hook target | Suppresses |
| --- | --- | --- |
| `ad-query` | `ContentResolver.query` and `ContentProviderClient.query` | Rows loaded from Gmail's advertisement provider paths. The real cursor is wrapped so it keeps its schema and reports no rows — Gmail's ordinary "no ads available" path. |
| `ad-label` | `TextView.setText` | Server-rendered sponsored rows. The badge caption is matched against a per-locale vocabulary, and the conversation row that owns it is collapsed. |

The two layers are independent. If one fails to install, the other still runs,
and if both fail Gmail is left exactly as it was.

A collapsed row is remembered along with the badge that caused the collapse.
RecyclerView reuses the same views for organic mail seconds later, so the row is
restored as soon as that exact badge is rebound to something that is not an
advertisement.

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

Filter logcat for `GmailHideAds` to see which layers installed and what they
suppressed.

## Limitations

The badge vocabulary in `AdLabelVocabulary` covers the languages Gmail ships;
a locale that is missing there will not be matched by the `ad-label` layer.
Adding one is a single line.

## Licence

GPL-3.0. See [LICENSE](LICENSE).
