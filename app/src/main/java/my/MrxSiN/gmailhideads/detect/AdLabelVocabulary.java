package my.MrxSiN.gmailhideads.detect;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/**
 * The words Gmail prints on a sponsored conversation row, in the languages
 * Gmail ships.
 *
 * <p>This class holds knowledge, not behaviour: it is the single place to edit
 * when a locale is missing.</p>
 */
public final class AdLabelVocabulary {

    /**
     * Every entry must be a complete badge caption, because matching is exact.
     * A substring rule would collapse ordinary mail whose subject merely
     * contains one of these words.
     */
    private static final Set<String> LABELS = Collections.unmodifiableSet(
            new HashSet<>(Arrays.asList(
                    // English
                    "ad", "ads", "sponsored", "sponsored message",
                    // Western Europe
                    "anuncio", "anúncio", "patrocinado", "publicidad",
                    "annonce", "sponsorisé", "publicité",
                    "anzeige", "gesponsert", "werbung",
                    "annuncio", "sponsorizzato", "pubblicità",
                    "advertentie", "gesponsord",
                    "annons", "annonse", "mainos", "reklame",
                    // Central and Eastern Europe
                    "reklama", "reklam", "reclamă", "anunț",
                    "hirdetés", "szponzorált",
                    "διαφήμιση", "χορηγούμενο",
                    "реклама", "спонсоровано",
                    // Middle East
                    "إعلان", "إعلان ممول", "مُموَّل",
                    "מודעה", "ממומן",
                    // Asia
                    "広告", "スポンサー", "スポンサー広告",
                    "광고", "스폰서", "스폰서 광고",
                    "广告", "赞助商广告", "廣告", "贊助商廣告",
                    "โฆษณา", "ได้รับการสนับสนุน",
                    "quảng cáo", "được tài trợ",
                    "iklan", "bersponsor",
                    "विज्ञापन", "प्रायोजित"
            )));

    /**
     * A badge is short. The bound keeps the exact-match lookup off the hot path
     * for ordinary subject lines and mail bodies.
     */
    public static final int MAX_LABEL_LENGTH = 24;

    private AdLabelVocabulary() {
    }

    public static boolean contains(String normalizedLabel) {
        return LABELS.contains(normalizedLabel);
    }
}
