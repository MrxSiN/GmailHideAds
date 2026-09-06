package my.MrxSiN.gmailhideads.detect;

/**
 * Decides whether one candidate of a single kind is advertising.
 *
 * <p>Each hook layer depends on this abstraction only, so a new signal is added
 * by writing a new implementation rather than by editing an existing layer.</p>
 *
 * @param <T> the kind of candidate this detector understands
 */
public interface AdDetector<T> {

    boolean isAd(T candidate);
}
