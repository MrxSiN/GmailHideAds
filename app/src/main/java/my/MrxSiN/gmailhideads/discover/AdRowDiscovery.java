package my.MrxSiN.gmailhideads.discover;

import android.content.Context;
import android.content.SharedPreferences;

import org.luckypray.dexkit.DexKitBridge;
import org.luckypray.dexkit.query.FindClass;
import org.luckypray.dexkit.result.ClassData;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import my.MrxSiN.gmailhideads.BuildConfig;
import my.MrxSiN.gmailhideads.core.ModuleRuntime;
import my.MrxSiN.gmailhideads.detect.AdTeaserViewDetector;

/**
 * Lists Gmail's advertisement row classes once, at start-up.
 *
 * <p>DexKit only narrows the search to the ads package; which of those classes
 * is an ad row is decided by {@code row.bf} through the detector, exactly as
 * for a row met at runtime. The bridge is closed before this returns, so
 * DexKit never runs in steady state.</p>
 *
 * <p>A DexKit pass over Gmail's dex costs about 300 ms on the main thread, so
 * the names it found are kept in Gmail's preferences, keyed by the Gmail APK
 * path (new on every Gmail update) and this module's version code. Cached
 * names are judged by {@code row.bf} again on load.</p>
 */
public final class AdRowDiscovery {

    /** Search scope only: a wrong scope finds nothing and the caller falls back. */
    private static final String ADS_PACKAGE = "com.google.android.gm.ads";

    private static final String PREFERENCES = "gmailhideads_discovery";
    private static final String KEY_SOURCE = "source";
    private static final String KEY_ROWS = "rows";

    private AdRowDiscovery() {
    }

    public static List<Class<?>> find(Context context, AdTeaserViewDetector detector) {
        long started = System.nanoTime();
        ClassLoader loader = context.getClassLoader();
        String source = context.getApplicationInfo().sourceDir + "|" + BuildConfig.VERSION_CODE;
        SharedPreferences preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);

        if (source.equals(preferences.getString(KEY_SOURCE, null))) {
            List<Class<?>> rows = new ArrayList<>();
            try {
                for (String name : preferences.getStringSet(KEY_ROWS, Collections.emptySet())) {
                    Class<?> type = Class.forName(name, false, loader);
                    if (detector.isAdType(type)) {
                        rows.add(type);
                    }
                }
            } catch (Throwable stale) {
                rows.clear();
            }
            if (!rows.isEmpty()) {
                return logged(rows, "from cache", started);
            }
        }

        List<Class<?>> rows = search(loader, detector);
        if (!rows.isEmpty()) {
            Set<String> names = new HashSet<>();
            for (Class<?> row : rows) {
                names.add(row.getName());
            }
            preferences.edit().putString(KEY_SOURCE, source).putStringSet(KEY_ROWS, names).apply();
        }
        return logged(rows, "found by DexKit", started);
    }

    private static List<Class<?>> search(ClassLoader loader, AdTeaserViewDetector detector) {
        System.loadLibrary("dexkit");
        List<Class<?>> rows = new ArrayList<>();
        try (DexKitBridge bridge = DexKitBridge.create(loader, true)) {
            for (ClassData data : bridge.findClass(FindClass.create().searchPackages(ADS_PACKAGE))) {
                Class<?> type;
                try {
                    type = data.getInstance(loader);
                } catch (Throwable unresolved) {
                    continue;
                }
                if (detector.isAdType(type)) {
                    rows.add(type);
                }
            }
        }
        return rows;
    }

    private static List<Class<?>> logged(List<Class<?>> rows, String how, long started) {
        ModuleRuntime.log(rows.size() + " ad row class(es) " + how + " in "
                + (System.nanoTime() - started) / 1_000_000L + " ms");
        return rows;
    }
}
