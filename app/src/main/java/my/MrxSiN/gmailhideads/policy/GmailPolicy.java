package my.MrxSiN.gmailhideads.policy;

/**
 * The module's decisions, made by the Brainfuck programs in libgmailbf
 * (docs/BRAINFUCK_ARCHITECTURE.md). Java only reduces what it read to name
 * codes, sends one request and reports the answer; every failure is reported
 * as "no", so Gmail is left untouched.
 */
public final class GmailPolicy {

    /** {@link #adRow} could not get an answer; the caller must not cache it. */
    public static final int FAILED = -1;

    private GmailPolicy() {
    }

    /** Loads libgmailbf once per process. */
    public static boolean load() {
        return NativePolicy.load();
    }

    /** Why {@link #load} failed, or {@code null}. */
    public static String failure() {
        return NativePolicy.failure();
    }

    public static String abi() {
        return BfAbi.ABI_MAJOR + "." + BfAbi.ABI_MINOR;
    }

    /** Request counters for the log. */
    public static String summary() {
        return PolicyStats.summary();
    }

    /**
     * {@code row.bf}, OP_AD_ROW (docs/policy/row.md): 1 when {@code type} or
     * one of its superclasses is a Gmail ad row, 0 when not, {@link #FAILED}
     * when the request failed.
     */
    public static int adRow(Class<?> type) {
        PolicyFrame frame = PolicyFrame.begin(BfAbi.OP_AD_ROW);
        int countAt = frame.position();
        frame.u8(0);
        int count = 0;
        for (Class<?> cursor = type; cursor != null; cursor = cursor.getSuperclass()) {
            if (count == BfAbi.MAX_NAMES) {
                frame.overflow();
                break;
            }
            frame.nameText(cursor.getName());
            count++;
        }
        frame.patch(countAt, count);
        return frame.send(BfAbi.PROG_ROW, 1) ? frame.verdict(0) : FAILED;
    }

    /**
     * {@code scope.bf}, OP_SCOPE (docs/policy/scope.md): whether the module
     * belongs in this package and process. A failed request answers no.
     */
    public static boolean inScope(String packageName, String processName) {
        PolicyFrame frame = PolicyFrame.begin(BfAbi.OP_SCOPE);
        frame.bool(packageName != null);
        frame.nameText(packageName == null ? "" : packageName);
        frame.bool(processName != null);
        frame.nameText(processName == null ? "" : processName);
        return frame.send(BfAbi.PROG_SCOPE, 1) && frame.verdict(0) == BfAbi.V_YES;
    }
}
