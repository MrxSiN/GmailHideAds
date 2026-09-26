# Changelog

All notable changes to Gmail Hide Ads are documented here.

## 2.0.0 - 2026-09-26

- Move the decision policy into Brainfuck, compiled ahead of time to native code (`libgmailbf.so`): the ad row class rule (the `com.google.android.gm.ads.` prefix, the `AdTeaserItemView` suffix and the superclass walk) in `row.bf`, and the package and process scope rule in `scope.bf`. Hooks, reflection, the per-class cache and row collapsing stay in Java. See `docs/BRAINFUCK_ARCHITECTURE.md` and the normative specs in `docs/policy/`.
- Adopt the TwitterHideAds `v3.0.0` Brainfuck toolchain (source checker, IR optimizer, C emitter, reference interpreter, replay harness), with a per-request loop budget and a stack-only, stateless runtime behind one `@FastNative` JNI call.
- Keep the 1.0.0 Java policy as a frozen test oracle; the parity suite compares old and new results on 634 229 cases per run, including every BMP character in nine contexts, plus randomized, malformed-frame, truncation and concurrency tests, on the JVM and on arm64.
- A Brainfuck request costs about 1 µs on a Pixel 8 Pro, against 0.2 µs for the two string comparisons it replaces, and runs once per view class; every `addView` after the first reads the per-class cache, which is unchanged at 0.12 µs.
- Fail open on any policy failure: a missing library or ABI mismatch answers the scope check with no, so nothing is installed; an oversized, malformed or budget-exhausted request keeps the row and is not cached.
- Add the policy counters (calls, failures, malformed responses) to the collapsed-row log line, with request timing in debug or `-PpolicyTiming` builds.
- CI: a test job checks the generated Brainfuck output and runs the Python toolchain tests and the parity suite before the build; the build verifies that `libgmailbf.so` ships for every ABI; the release body is `docs/releases/<tag>.md`.
- New launcher icon: a broken shield struck through from bottom left to top right over the Gmail M, the M kept clear of the strike, drawn as one vector that is also the themed icon (`docs/icon.svg`). The envelope icon and the raster branding image are removed.
- Rewrite the README in the ThreadsHideAds layout, and add release notes for every version in `docs/releases/`.
- Read the module version from `BuildConfig` and remove the unused ProGuard rules file (minification is off).
- Remove abstractions with a single user: the hook layer interface, pipeline and context, the detector interface, `ModuleStats` and `GmailProfile`. The entry installs the one `addView` layer directly and still logs and skips it if it fails.
- Fix two `NewApi` lint errors: the launcher theme used `Theme.DeviceDefault.DayNight`, which needs API 29; it now uses `Theme.DeviceDefault.Light` and, in `values-night`, `Theme.DeviceDefault`.
- Increased Android `versionCode` from `2` to `3`.

Also in this release (previously unreleased):

- Move the application id from `my.MrxSiN.gmailhideads` to `io.github.mrxsin.gmailhideads` (`versionCode` `1` to `2`). Android treats it as a new app: uninstall 1.0.0 and enable the new module in the framework manager.
- Drop the deprecated `android.useAndroidX=false` Gradle flag.
- Verify the signing keystore immediately after decoding it and report the result as workflow annotations, so a bad secret fails the job in seconds and names itself instead of surfacing later inside a Gradle stack trace as `keystore password was incorrect`.
- Strip whitespace before base64-decoding the keystore secret. A base64 keystore copied out of a Windows text file carries CR characters, which GNU `base64` rejects, silently leaving a truncated keystore behind.

## 1.0.0 - 2026-09-06

- First release: removes sponsored conversation rows from the Gmail inbox by matching the six `*AdTeaserItemView` classes in `com.google.android.gm.ads.adteaser`. Gmail's own layouts name these classes, so R8 cannot rename them, which makes them the one part of the ad surface that survives minification intact.
- Hook `ViewGroup.addView(View, int, ViewGroup.LayoutParams)`, the overload the other four public `addView` signatures funnel into and the first moment a row has its layout parameters. Hooking the Android framework rather than a Gmail class means a Gmail update does not move the hook point.
- Zero the row's layout height as well as setting it `GONE`: `GONE` alone stops the row drawing, but a RecyclerView layout manager still measures its attached children.
- Deoptimize the hook target through `XposedInterface.deoptimize`; the shorter `addView` overloads are small enough for ART to inline, and an already compiled caller would otherwise bypass the hook.
- Classify a view by walking its superclasses, so a Gmail release that subclasses one of these rows is still recognized, and cache the verdict per class because `addView` is a hot path.
- Wait for `Application.attach()` before installing, and install through a pipeline that isolates a failing layer rather than letting it take Gmail down.
- Log the class and view id of every removed row.
- Built against the modern libxposed API `102.0.0` as implemented by [Vector](https://github.com/JingMatrix/Vector), with the entry point declared through `META-INF/xposed/java_init.list` and a static scope of `com.google.android.gm`.
- Read release signing credentials from the environment, so no credential is stored in the repository.
- Not shipped: a content-provider layer that emptied the cursor Gmail loaded ads from (modern Gmail has no ad provider, so it hooked every query and could never fire), and a badge-caption layer matching the rendered "Ad" label against a per-locale word list (it collapsed five ordinary rows in a mailbox serving no ads). Matching the view class carries the same information, needs no word list and cannot mistake a message for an advertisement.
- Validated on device against Gmail `2026.08.17.974752392.Release` under Vector 2.2.
