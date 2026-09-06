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
  "$SRC/data/EmptyCursor.java" \
  "$SRC/detect/AdDetector.java" \
  "$SRC/detect/AdLabelDetector.java" \
  "$SRC/detect/AdLabelVocabulary.java" \
  "$SRC/detect/AdUriDetector.java" \
  "$SRC/hook/AdLabelLayer.java" \
  "$SRC/hook/AdQueryLayer.java" \
  "$SRC/hook/HookContext.java" \
  "$SRC/hook/HookLayer.java" \
  "$SRC/hook/HookPipeline.java" \
  "$SRC/ui/AdMarkerRegistry.java" \
  "$SRC/ui/HiddenViewRegistry.java" \
  "$SRC/ui/ListItemCollapser.java" \
  "$SRC/ui/ViewTrees.java" ; do
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

# --- the module must stay hooked to framework methods, not obfuscated ones ---
grep -q 'ContentResolver.class.getDeclaredMethod' "$SRC/hook/AdQueryLayer.java" \
  || fail "the query layer no longer targets the framework"
grep -q 'TextView.class.getDeclaredMethod' "$SRC/hook/AdLabelLayer.java" \
  || fail "the label layer no longer targets the framework"
grep -q 'ModuleRuntime.deoptimize' "$SRC/hook/AdQueryLayer.java" \
  || fail "the query targets must be deoptimized or the hooks are inlined away"
grep -q 'ModuleRuntime.deoptimize' "$SRC/hook/AdLabelLayer.java" \
  || fail "the label target must be deoptimized or the hook is inlined away"

# --- version agreement ------------------------------------------------------
VERSION=$(sed -n 's/^val appVersion = "\([^"]*\)"/\1/p' "$APP_GRADLE")
test -n "$VERSION" || fail "appVersion is not readable from app/build.gradle.kts"
grep -q "MODULE_VERSION = \"$VERSION\"" "$SRC/GmailHideAdsModule.java" \
  || fail "MODULE_VERSION does not match appVersion $VERSION"
grep -q "^## v$VERSION" "$ROOT/CHANGELOG.md" \
  || fail "CHANGELOG.md has no entry for v$VERSION"

echo "check-project: all structural checks passed for v$VERSION."
