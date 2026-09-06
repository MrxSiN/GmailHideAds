package my.MrxSiN.gmailhideads.detect;

import android.net.Uri;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Recognises the content URIs Gmail reads its advertisement rows from.
 *
 * <p>Gmail exposes ads as their own provider path next to the mailbox paths,
 * for example {@code content://com.google.android.gm/<account>/ads}. Matching is
 * done on whole path segments so that ordinary mail paths such as
 * {@code /threads} or {@code /unread} cannot match by accident.</p>
 */
public final class AdUriDetector implements AdDetector<Uri> {

    private static final Set<String> AD_SEGMENTS = Collections.unmodifiableSet(
            new HashSet<>(Arrays.asList(
                    "ads",
                    "adteaser",
                    "adteasers",
                    "advertisement",
                    "advertisements",
                    "sponsored"
            )));

    private static final String AD_AUTHORITY_SUFFIX = ".ads";

    /**
     * Segment matching is limited to Gmail's own providers. Without this guard
     * an unrelated system provider that happens to expose an "ads" path would
     * also be emptied.
     */
    private static final String GMAIL_AUTHORITY_PREFIX = "com.google.android.gm";
    private static final String GMAIL_LEGACY_AUTHORITY = "gmail-ls";

    @Override
    public boolean isAd(Uri candidate) {
        if (candidate == null) {
            return false;
        }

        String authority = candidate.getAuthority();
        if (authority == null) {
            return false;
        }

        String lowerAuthority = authority.toLowerCase(Locale.ROOT);
        if (lowerAuthority.endsWith(AD_AUTHORITY_SUFFIX)) {
            return true;
        }

        if (!lowerAuthority.startsWith(GMAIL_AUTHORITY_PREFIX)
                && !lowerAuthority.equals(GMAIL_LEGACY_AUTHORITY)) {
            return false;
        }

        List<String> segments = candidate.getPathSegments();
        for (int index = 0; index < segments.size(); index++) {
            if (AD_SEGMENTS.contains(segments.get(index).toLowerCase(Locale.ROOT))) {
                return true;
            }
        }

        return false;
    }
}
