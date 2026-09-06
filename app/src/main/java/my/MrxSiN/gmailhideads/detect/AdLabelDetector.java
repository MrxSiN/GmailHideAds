package my.MrxSiN.gmailhideads.detect;

import java.util.Locale;

/**
 * Recognises the rendered badge of a sponsored conversation row.
 *
 * <p>Gmail obfuscates its classes on every release, so the badge caption is the
 * one ad signal that survives. The detector is deliberately strict: it matches
 * a whole caption, never a fragment, so that a message titled "Ad campaign
 * results" is left alone.</p>
 */
public final class AdLabelDetector implements AdDetector<CharSequence> {

    @Override
    public boolean isAd(CharSequence candidate) {
        String normalized = normalize(candidate);
        return normalized != null && AdLabelVocabulary.contains(normalized);
    }

    /**
     * Returns the caption reduced to its comparable form, or {@code null} when
     * the text cannot be a badge at all.
     */
    private static String normalize(CharSequence candidate) {
        if (candidate == null) {
            return null;
        }

        int length = candidate.length();
        if (length == 0 || length > AdLabelVocabulary.MAX_LABEL_LENGTH) {
            return null;
        }

        String trimmed = candidate.toString().trim();
        if (trimmed.isEmpty()) {
            return null;
        }

        return trimmed.toLowerCase(Locale.ROOT);
    }
}
