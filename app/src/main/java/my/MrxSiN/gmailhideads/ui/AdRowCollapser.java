package my.MrxSiN.gmailhideads.ui;

import android.view.View;
import android.view.ViewGroup;

/**
 * Removes an advertisement row from the layout.
 *
 * <p>There is no matching restore. Gmail gives an advertisement its own view
 * type, so a row of this class is never rebound to ordinary mail; once
 * collapsed it can stay collapsed for the life of the instance.</p>
 *
 * <p>Both steps are needed. {@code GONE} stops the row drawing, but a
 * RecyclerView layout manager still measures its attached children, so the
 * height has to be zeroed for the row to take no space.</p>
 */
public final class AdRowCollapser {

    private AdRowCollapser() {
    }

    public static void collapse(View row, ViewGroup.LayoutParams params) {
        if (params != null && params.height != 0) {
            params.height = 0;
        }

        if (row.getVisibility() != View.GONE) {
            row.setVisibility(View.GONE);
        }
    }
}
