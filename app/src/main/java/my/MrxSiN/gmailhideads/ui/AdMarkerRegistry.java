package my.MrxSiN.gmailhideads.ui;

import android.view.View;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

/**
 * Remembers which label views currently read as advertising.
 *
 * <p>RecyclerView rebinds the same view for organic mail moments later, so a
 * marker is state that has to be cleared, not a one-off observation.</p>
 */
public final class AdMarkerRegistry {

    private static final Map<View, Boolean> MARKERS =
            Collections.synchronizedMap(new WeakHashMap<View, Boolean>());

    private AdMarkerRegistry() {
    }

    public static void mark(View labelView) {
        MARKERS.put(labelView, Boolean.TRUE);
    }

    public static void unmark(View labelView) {
        MARKERS.remove(labelView);
    }

    public static boolean isMarked(View labelView) {
        return MARKERS.containsKey(labelView);
    }

    /** True while any view below {@code root} still reads as advertising. */
    public static boolean subtreeHasMarker(View root) {
        return ViewTrees.anyInSubtree(root, new ViewTrees.Predicate() {
            @Override
            public boolean test(View view) {
                return isMarked(view);
            }
        });
    }
}
