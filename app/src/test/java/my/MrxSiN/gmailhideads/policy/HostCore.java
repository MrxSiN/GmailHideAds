package my.MrxSiN.gmailhideads.policy;

/**
 * Loads libgmailbf: on the JVM the host build (Gradle task buildHostCore: the
 * same AOT C, runtime and JNI glue the APK ships, compiled by the host
 * compiler); on a device the APK's own library.
 */
public final class HostCore {

    private static boolean loaded;

    private HostCore() {
    }

    public static synchronized void ensure() {
        if (loaded) {
            return;
        }
        String path = System.getProperty("gmailbf.hostlib");
        if (path == null) {
            if (!GmailPolicy.load()) {
                throw new IllegalStateException("libgmailbf unavailable: " + GmailPolicy.failure());
            }
            loaded = true;
            return;
        }
        System.load(path);
        if (!GmailPolicy.verify()) {
            throw new IllegalStateException("host core rejected: " + GmailPolicy.failure());
        }
        loaded = true;
    }

    public static int parityCases() {
        return Integer.getInteger("gmailbf.parityCases", 20000);
    }

    /** Raw OP_AD_ROW over class names (view class first): 1, 0, or -1 on failure. */
    static int adRow(CharSequence... names) {
        ensure();
        PolicyFrame frame = PolicyFrame.begin(BfAbi.OP_AD_ROW);
        frame.u8(names.length);
        for (CharSequence name : names) {
            frame.nameText(name);
        }
        return frame.send(BfAbi.PROG_ROW, 1) ? frame.verdict(0) : -1;
    }
}
