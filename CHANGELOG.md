# Changelog

## v1.0.0

First release.

- Collapses Gmail's advertisement rows by matching the six
  `*AdTeaserItemView` classes in `com.google.android.gm.ads.adteaser`, which
  Gmail's own layouts name and R8 therefore cannot rename.
- Hooks `ViewGroup.addView`, an Android framework method, so a Gmail update
  does not move the hook point. The row is zeroed and marked `GONE` before it
  is measured.
- Verified on Gmail 2026.08.17.974752392 with Vector 2.2 (libxposed API 102):
  the layer installs, Gmail renders normally, and no ordinary mail is touched.
- Built on the modern libxposed API 102; no legacy `de.robv.android.xposed` use.
