package my.MrxSiN.gmailhideads.policy;

import com.google.android.gm.ads.adteaser.AdTeaserRows;

import org.junit.BeforeClass;
import org.junit.Test;

import java.util.Arrays;
import java.util.Locale;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.IntSupplier;

import my.MrxSiN.gmailhideads.legacy.LegacyAdTeaserViewDetector;
import my.MrxSiN.gmailhideads.legacy.LegacyGmailProfile;

/**
 * Microbenchmarks, legacy Java policy against the Brainfuck policy through
 * JNI: p50/p95/p99 per call. The detector caches one verdict per class, so a
 * policy request runs once per view class and the hot path is the cache
 * lookup. Host numbers only indicate relative cost.
 */
public class PolicyBenchmarkTest {

    private static final int WARMUP = 20000;
    private static final int SAMPLES = 20000;

    private static volatile int sink;

    @BeforeClass
    public static void load() {
        HostCore.ensure();
    }

    private static String measure(String name, IntSupplier call) {
        for (int index = 0; index < WARMUP; index++) {
            sink += call.getAsInt();
        }
        long[] nanos = new long[SAMPLES];
        for (int index = 0; index < SAMPLES; index++) {
            long started = System.nanoTime();
            sink += call.getAsInt();
            nanos[index] = System.nanoTime() - started;
        }
        Arrays.sort(nanos);
        return String.format(Locale.ROOT, "%-34s p50 %6.2f  p95 %6.2f  p99 %6.2f us", name,
                nanos[SAMPLES / 2] / 1000.0, nanos[SAMPLES * 95 / 100] / 1000.0, nanos[SAMPLES * 99 / 100] / 1000.0);
    }

    @Test
    public void compare() {
        // A deep ordinary row: the common case, every superclass name is sent.
        Class<?> ordinary = java.util.concurrent.ConcurrentHashMap.class;
        Class<?> ad = AdTeaserRows.DERIVED[0];
        ConcurrentHashMap<Class<?>, Boolean> cache = new ConcurrentHashMap<>();
        cache.put(ad, Boolean.TRUE);
        StringBuilder out = new StringBuilder("PolicyBenchmarkTest\n");
        out.append(measure("legacy ordinary class", () -> LegacyAdTeaserViewDetector.describesAdRow(ordinary) ? 1 : 0)).append('\n');
        out.append(measure("brainfuck ordinary class", () -> GmailPolicy.adRow(ordinary))).append('\n');
        out.append(measure("legacy derived ad row", () -> LegacyAdTeaserViewDetector.describesAdRow(ad) ? 1 : 0)).append('\n');
        out.append(measure("brainfuck derived ad row", () -> GmailPolicy.adRow(ad))).append('\n');
        out.append(measure("legacy scope", () -> LegacyGmailProfile.isTargetPackage("com.google.android.gm")
                && LegacyGmailProfile.isTargetProcess("com.google.android.gm") ? 1 : 0)).append('\n');
        out.append(measure("brainfuck scope", () -> GmailPolicy.inScope("com.google.android.gm",
                "com.google.android.gm") ? 1 : 0)).append('\n');
        out.append(measure("cached verdict (the addView path)", () -> cache.get(ad) ? 1 : 0)).append('\n');
        System.out.println(out);
    }
}
