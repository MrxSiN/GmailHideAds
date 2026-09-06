package my.MrxSiN.gmailhideads.core;

import java.util.concurrent.atomic.AtomicLong;

/** Counters and diagnostics for what the hook layers suppressed. */
public final class ModuleStats {

    private static final AtomicLong COLLAPSED_ROWS = new AtomicLong();

    private ModuleStats() {
    }

    /**
     * Reports the row that was removed. The view id survives Gmail's resource
     * shrinking, so this line is what makes a bug report actionable when a
     * Gmail release renames something.
     */
    public static void recordCollapsedRow(String description) {
        ModuleRuntime.log("Collapsed advertisement row #"
                + COLLAPSED_ROWS.incrementAndGet() + ": " + description);
    }
}
