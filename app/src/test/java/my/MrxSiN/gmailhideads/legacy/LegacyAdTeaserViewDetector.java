package my.MrxSiN.gmailhideads.legacy;

import android.view.View;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Frozen v1.0.0 policy (detect/AdTeaserViewDetector at 2f978ff), kept as the
 * test oracle for row.bf. Only {@link #matchesName} was split out of
 * {@link #describesAdRow} so names without a class can be compared. Never edit.
 *
 * <p>Recognises the row views Gmail renders an advertisement into.
 *
 * <p>Gmail minifies almost everything, but not these: every ad row is inflated
 * from a layout that names its root class in XML, so R8 must keep the name.
 * In Gmail 2026.08 the set is {@code BasicAdTeaserItemView},
 * {@code VideoAdTeaserItemView}, {@code ImageCarouselAdTeaserItemView},
 * {@code RichButtonChipAdTeaserItemView},
 * {@code AppInstallButtonChipAdTeaserItemView} and
 * {@code EuSingleImageAdTeaserItemView}, all in
 * {@code com.google.android.gm.ads.adteaser}.</p>
 *
 * <p>Matching the class rather than the rendered badge caption means the rule
 * needs no per-locale word list and cannot mistake a message whose subject
 * happens to read "Ad" for an advertisement.</p>
 */
public final class LegacyAdTeaserViewDetector {

    private static final String AD_PACKAGE_PREFIX = "com.google.android.gm.ads.";
    private static final String AD_ROW_SUFFIX = "AdTeaserItemView";

    /** addView is a hot path; each class is classified once. */
    private static final Map<Class<?>, Boolean> CACHE = new ConcurrentHashMap<>();

    public boolean isAd(View candidate) {
        if (candidate == null) {
            return false;
        }

        Class<?> type = candidate.getClass();
        Boolean cached = CACHE.get(type);
        if (cached != null) {
            return cached;
        }

        boolean result = describesAdRow(type);
        Boolean existing = CACHE.putIfAbsent(type, result);
        return existing == null ? result : existing;
    }

    /**
     * Walks the superclasses so that a Gmail release which subclasses one of
     * these views is still recognised.
     */
    public static boolean describesAdRow(Class<?> type) {
        for (Class<?> cursor = type; cursor != null; cursor = cursor.getSuperclass()) {
            String name = cursor.getName();
            if (matchesName(name)) {
                return true;
            }
        }
        return false;
    }

    public static boolean matchesName(String name) {
        return name.startsWith(AD_PACKAGE_PREFIX) && name.endsWith(AD_ROW_SUFFIX);
    }
}
