package my.MrxSiN.gmailhideads.detect;

import android.view.View;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import my.MrxSiN.gmailhideads.policy.GmailPolicy;

/**
 * Recognises the row views Gmail renders an advertisement into.
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
 *
 * <p>The rule itself (the class or one of its superclasses is under
 * {@code com.google.android.gm.ads.} and its name ends in
 * {@code AdTeaserItemView}) is decided by {@code brainfuck/src/row.bf}; this
 * class only caches the verdict per class.</p>
 */
public final class AdTeaserViewDetector {

    /** addView is a hot path; each class is classified once. */
    private static final Map<Class<?>, Boolean> CACHE = new ConcurrentHashMap<>();

    public boolean isAd(View candidate) {
        return candidate != null && isAdType(candidate.getClass());
    }

    public boolean isAdType(Class<?> type) {
        Boolean cached = CACHE.get(type);
        if (cached != null) {
            return cached;
        }

        int verdict = GmailPolicy.adRow(type);
        if (verdict == GmailPolicy.FAILED) {
            // Fail open, and uncached, so the next row of this class asks again.
            return false;
        }
        boolean result = verdict == 1;
        Boolean existing = CACHE.putIfAbsent(type, result);
        return existing == null ? result : existing;
    }
}
