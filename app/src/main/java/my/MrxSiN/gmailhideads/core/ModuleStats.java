package my.MrxSiN.gmailhideads.core;

import java.util.concurrent.atomic.AtomicLong;

/** Counters for what each hook layer actually suppressed. */
public final class ModuleStats {

    private static final AtomicLong BLOCKED_QUERIES = new AtomicLong();
    private static final AtomicLong COLLAPSED_ROWS = new AtomicLong();
    private static final AtomicLong RESTORED_ROWS = new AtomicLong();

    private ModuleStats() {
    }

    public static void recordBlockedQuery(String uri) {
        ModuleRuntime.log("Emptied advertisement cursor #"
                + BLOCKED_QUERIES.incrementAndGet() + " for " + uri);
    }

    public static void recordCollapsedRow(String description) {
        ModuleRuntime.log("Collapsed sponsored row #"
                + COLLAPSED_ROWS.incrementAndGet() + ": " + description);
    }

    public static void recordRestoredRow(String description) {
        ModuleRuntime.log("Restored recycled row #"
                + RESTORED_ROWS.incrementAndGet() + ": " + description);
    }
}
