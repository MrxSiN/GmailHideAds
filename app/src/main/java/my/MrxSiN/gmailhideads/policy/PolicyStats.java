package my.MrxSiN.gmailhideads.policy;

import java.util.concurrent.atomic.AtomicLong;

import my.MrxSiN.gmailhideads.core.ModuleRuntime;

/**
 * Brainfuck policy counters. Failures are rare, so each one is counted and the
 * first few (then every power of two) are logged; production pays for one
 * counter increment per request.
 */
final class PolicyStats {

    static final String UNAVAILABLE = "library-unavailable";
    static final String OVERFLOW = "request-too-large";
    static final String NATIVE = "native-error";
    static final String MALFORMED = "malformed-response";

    private static final AtomicLong CALLS = new AtomicLong();
    private static final AtomicLong FAILURES = new AtomicLong();
    private static final AtomicLong MALFORMED_RESPONSES = new AtomicLong();

    private PolicyStats() {
    }

    static void ok() {
        CALLS.incrementAndGet();
    }

    /** Counts and (rate-limited) logs a failed request; always false, for fail-open returns. */
    static boolean failed(int opcode, String kind) {
        CALLS.incrementAndGet();
        long count = FAILURES.incrementAndGet();
        if (kind.equals(MALFORMED)) {
            MALFORMED_RESPONSES.incrementAndGet();
        }
        if (count <= 3 || Long.bitCount(count) == 1) {
            ModuleRuntime.log("Brainfuck policy request failed open: op=0x" + Integer.toHexString(opcode)
                    + ", kind=" + kind + ", count=" + count
                    + (kind.equals(UNAVAILABLE) ? ", reason=" + GmailPolicy.failure() : ""));
        }
        return false;
    }

    static long failures() {
        return FAILURES.get();
    }

    static String summary() {
        return "bfCalls=" + CALLS.get()
                + ", bfFailures=" + FAILURES.get()
                + ", malformed=" + MALFORMED_RESPONSES.get();
    }
}
