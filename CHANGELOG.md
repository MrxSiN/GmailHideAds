# Changelog

## Unreleased

- Rewrote the README in the house style of the sibling modules, and added
  `branding/gmail-hide-ads-icon.png` to match.
- Reported the keystore verification result as workflow annotations rather than
  stderr alone. GitHub runs the step under `set -eo pipefail`, so a failing
  decode aborted before its own message was reached, and job logs cannot be read
  without an authenticated request.
- Verified the signing keystore immediately after decoding it, so a bad secret
  fails the job in seconds and names itself, instead of surfacing ninety seconds
  later inside a Gradle stack trace as `keystore password was incorrect`.
- Stripped whitespace before base64-decoding the keystore secret. A base64
  keystore copied out of a Windows text file carries CR characters, and GNU
  `base64` rejects those outright rather than ignoring them, silently leaving a
  truncated keystore behind.

## 1.0.0 — 2026-09-06

First release.

- Removes sponsored conversation rows from the Gmail inbox by matching the six
  `*AdTeaserItemView` classes in `com.google.android.gm.ads.adteaser`. Gmail's
  own layouts name these classes, so R8 cannot rename them, which makes them the
  one part of the ad surface that survives minification intact.
- Hooks `ViewGroup.addView(View, int, ViewGroup.LayoutParams)`, the overload the
  other four public `addView` signatures funnel into and the first moment a row
  has its layout parameters. Hooking the Android framework rather than a Gmail
  class means a Gmail update does not move the hook point.
- Zeroes the row's layout height as well as setting it `GONE`. `GONE` alone stops
  the row drawing, but a RecyclerView layout manager still measures its attached
  children, so the height must be zero for the row to occupy no space.
- Deoptimizes the hook target through `XposedInterface.deoptimize`. The shorter
  `addView` overloads are small enough for ART to inline, and an already compiled
  caller would otherwise bypass the hook.
- Classifies a view by walking its superclasses, so a Gmail release that
  subclasses one of these rows is still recognized, and caches the verdict per
  class because `addView` is a hot path.
- Waits for `Application.attach()` before installing, so Gmail has supplied its
  real application context first, and installs through a pipeline that isolates
  a failing layer rather than letting it take Gmail down.
- Logs the class and view id of every removed row, which is what a bug report
  needs when a later Gmail renames something.
- Built against the modern libxposed API `102.0.0` as implemented by
  [Vector](https://github.com/JingMatrix/Vector), with the entry point declared
  through `META-INF/xposed/java_init.list` and a static scope of
  `com.google.android.gm`. The legacy `de.robv.android.xposed` API is not used.
- Reads release signing credentials from the environment, so no credential is
  stored in the repository.

### Not shipped, and why

Two approaches were built first, measured against Gmail
`2026.08.17.974752392.Release`, and removed:

- A content-provider layer that emptied the cursor Gmail loaded advertisements
  from. Modern Gmail has no ad provider — there is no ad content URI anywhere in
  its DEX — so the layer hooked `ContentResolver.query` and
  `ContentProviderClient.query` on every Gmail query and could never fire.
- A badge-caption layer that matched the rendered "Ad" label against a
  per-locale word list. It collapsed five rows in a mailbox that was serving no
  advertisements at all, and it needed maintaining in every language Gmail
  ships. Gmail's English badge is the string resource `string/ad`, whose value is
  `Ad`, which an ordinary subject line can also be.

Matching the view class carries the same information as the caption, needs no
word list, and cannot mistake a message for an advertisement.
