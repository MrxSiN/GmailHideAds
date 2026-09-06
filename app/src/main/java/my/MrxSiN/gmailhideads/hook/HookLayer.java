package my.MrxSiN.gmailhideads.hook;

/**
 * One independent way of suppressing advertising.
 *
 * <p>A layer knows how to install itself and nothing else. Adding coverage for
 * a new Gmail surface means adding a layer and registering it, never editing
 * an existing one.</p>
 */
public interface HookLayer {

    /** Short name used in logs. */
    String id();

    void install(HookContext context) throws Throwable;
}
