# Gmail Hide Ads v1.0.0

First release.

Removes sponsored rows from the Gmail for Android conversation list by matching
the ad row classes Gmail's layouts name — the one part of its ad surface that
minification cannot rename — and collapsing the row before it is measured.

The hook is on `ViewGroup.addView`, an Android framework method, so a Gmail
update does not move it. No per-locale word list, and ordinary mail whose
subject reads like a badge is left alone.

Requires an Xposed framework implementing libxposed API 101 or newer, such as
Vector. Enable the module, add Gmail to its scope, then force-stop and reopen
Gmail.

Verified against Gmail 2026.08.17.974752392 on Android 17 with Vector 2.2.
