package my.MrxSiN.gmailhideads.ui;

import android.view.View;

/**
 * Renders a view as a short string for the log.
 *
 * <p>The resource entry name is the useful half when it survives Gmail's
 * resource shrinking, and the class name is the fallback when it does not.</p>
 */
public final class ViewDescriptions {

    private ViewDescriptions() {
    }

    public static String describe(View view) {
        if (view == null) {
            return "null";
        }

        String type = view.getClass().getName();
        int id = view.getId();

        if (id == View.NO_ID) {
            return type + "#no-id";
        }

        try {
            return type + "#" + view.getResources().getResourceEntryName(id);
        } catch (Throwable ignored) {
            return type + "#0x" + Integer.toHexString(id);
        }
    }
}
