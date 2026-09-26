package my.MrxSiN.gmailhideads.legacy;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;

/**
 * Frozen v1.0.0 policy (config/GmailProfile at 2f978ff), kept as the test
 * oracle for scope.bf. Never edit.
 *
 * <p>The single description of which host this module belongs in.</p>
 */
public final class LegacyGmailProfile {

    public static final String TARGET_PACKAGE = "com.google.android.gm";

    private LegacyGmailProfile() {
    }

    public static boolean isTargetPackage(String packageName) {
        return TARGET_PACKAGE.equals(packageName);
    }

    /**
     * Gmail runs several processes. Ads are only ever bound in the main one, so
     * the remaining processes are left untouched.
     *
     * <p>An empty process name means the framework did not report one; the
     * module then stays active rather than disabling itself.</p>
     */
    public static boolean isTargetProcess(String processName) {
        return processName == null
                || processName.isEmpty()
                || TARGET_PACKAGE.equals(processName);
    }

    /**
     * The installed Gmail version, for the log line that makes a bug report
     * useful. Never throws: an unknown version is not a reason to abort.
     */
    @SuppressWarnings("deprecation")
    public static String describeHostVersion(Context context) {
        if (context == null) {
            return "unknown (no application context)";
        }

        try {
            PackageManager packages = context.getPackageManager();
            PackageInfo info = packages.getPackageInfo(TARGET_PACKAGE, 0);
            long versionCode = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
                    ? info.getLongVersionCode()
                    : info.versionCode;
            return info.versionName + " (" + versionCode + ")";
        } catch (Throwable throwable) {
            return "unknown (" + throwable.getClass().getSimpleName() + ")";
        }
    }
}
