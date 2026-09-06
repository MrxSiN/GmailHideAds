#!/usr/bin/env sh
#
# Fails the build when the module's structural invariants are broken. These are
# the mistakes a compiler cannot catch: a missing Xposed descriptor, a legacy
# API creeping back in, a hard-coded credential, or a version that no longer
# agrees with itself.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC="$ROOT/app/src/main/java/my/MrxSiN/gmailhideads"
XPOSED_META="$ROOT/app/src/main/resources/META-INF/xposed"
APP_GRADLE="$ROOT/app/build.gradle.kts"
MANIFEST="$ROOT/app/src/main/AndroidManifest.xml"
DETECTOR="$SRC/detect/AdTeaserViewDetector.java"
LAYER="$SRC/hook/AdTeaserLayer.java"

fail() {
  echo "check-project: $1" >&2
  exit 1
}

# --- every source file the module is assembled from -------------------------
for file in \
  "$APP_GRADLE" \
  "$MANIFEST" \
  "$ROOT/.github/workflows/android.yml" \
  "$XPOSED_META/java_init.list" \
  "$XPOSED_META/module.prop" \
  "$XPOSED_META/scope.list" \
  "$SRC/GmailHideAdsModule.java" \
  "$SRC/config/GmailProfile.java" \
  "$SRC/core/ModuleRuntime.java" \
  "$SRC/core/ModuleStats.java" \
  "$SRC/detect/AdDetector.java" \
  "$DETECTOR" \
  "$LAYER" \
  "$SRC/hook/HookContext.java" \
  "$SRC/hook/HookLayer.java" \
  "$SRC/hook/HookPipeline.java" \
  "$SRC/ui/AdRowCollapser.java" \
  "$SRC/ui/ViewDescriptions.java" ; do
  test -f "$file" || fail "missing $file"
done

# --- modern Xposed API only -------------------------------------------------
grep -q '^my.MrxSiN.gmailhideads.GmailHideAdsModule$' "$XPOSED_META/java_init.list" \
  || fail "java_init.list does not name the entry class"
grep -q '^com.google.android.gm$' "$XPOSED_META/scope.list" \
  || fail "scope.list does not name Gmail"
grep -q '^minApiVersion=101$' "$XPOSED_META/module.prop" || fail "unexpected minApiVersion"
grep -q '^targetApiVersion=102$' "$XPOSED_META/module.prop" || fail "unexpected targetApiVersion"
grep -q 'compileOnly("io.github.libxposed:api:102.0.0")' "$APP_GRADLE" \
  || fail "the modern Xposed API dependency is missing"
grep -q 'merges += "META-INF/xposed/\*"' "$APP_GRADLE" \
  || fail "META-INF/xposed must be merged into the APK"
grep -q 'extends XposedModule' "$SRC/GmailHideAdsModule.java" \
  || fail "the entry class must extend XposedModule"

test ! -f "$ROOT/app/src/main/assets/xposed_init" \
  || fail "the legacy assets entry point must not exist"
! grep -rq 'de.robv.android.xposed' "$ROOT/app/src/main/java" \
  || fail "the legacy Xposed API must not be referenced"
! grep -q 'xposedmodule\|xposedminversion\|xposedscope' "$MANIFEST" \
  || fail "legacy manifest metadata must not be present"

# --- no credential may live in the repository -------------------------------
! grep -q 'storePassword = "' "$APP_GRADLE" || fail "hard-coded store password"
! grep -q 'keyPassword = "' "$APP_GRADLE" || fail "hard-coded key password"
grep -q 'ANDROID_KEYSTORE_PATH' "$APP_GRADLE" \
  || fail "release signing must come from the environment"
test ! -f "$ROOT/app/release.keystore" || fail "a keystore is checked in"

# --- detection must stay on the signals verified against a real Gmail -------
# Verified against Gmail 2026.08.17.974752392: the six ad row classes are the
# only part of the ad surface R8 may not rename, because the layouts name them.
grep -q '"com.google.android.gm.ads."' "$DETECTOR" \
  || fail "the detector no longer matches Gmail's ads package"
grep -q '"AdTeaserItemView"' "$DETECTOR" \
  || fail "the detector no longer matches Gmail's ad row classes"
grep -q 'getSuperclass' "$DETECTOR" \
  || fail "the detector must match subclasses of an ad row"
grep -q 'ViewGroup.class.getDeclaredMethod' "$LAYER" \
  || fail "the teaser layer no longer targets the framework"
grep -q 'ModuleRuntime.deoptimize' "$LAYER" \
  || fail "the addView target must be deoptimized or the hook is inlined away"

# Caption matching was removed on purpose: it needed a per-locale word list and
# collapsed ordinary mail whose subject read like a badge.
! grep -rq 'AdLabelVocabulary\|AdLabelDetector' "$SRC" \
  || fail "caption matching must not come back"

# --- version agreement ------------------------------------------------------
VERSION=$(sed -n 's/^val appVersion = "\([^"]*\)"/\1/p' "$APP_GRADLE")
test -n "$VERSION" || fail "appVersion is not readable from app/build.gradle.kts"
grep -q "MODULE_VERSION = \"$VERSION\"" "$SRC/GmailHideAdsModule.java" \
  || fail "MODULE_VERSION does not match appVersion $VERSION"
# The changelog heading is "## <version> — <date>", matching the sibling
# modules. The version is escaped so its dots are not treated as wildcards.
CHANGELOG_HEADING=$(printf '%s' "$VERSION" | sed 's/\./\\./g')
grep -qE "^## $CHANGELOG_HEADING( |\$)" "$ROOT/CHANGELOG.md" \
  || fail "CHANGELOG.md has no entry for $VERSION"

grep -q "^# Gmail Hide Ads v$VERSION\$" "$ROOT/RELEASE_NOTES.md" \
  || fail "RELEASE_NOTES.md does not open with the v$VERSION heading"

echo "check-project: all structural checks passed for v$VERSION."
