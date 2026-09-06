package my.MrxSiN.gmailhideads.ui;

import android.view.View;

import java.lang.ref.WeakReference;
import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

/**
 * The layout state of every collapsed row, and the label view that caused each
 * collapse.
 *
 * <p>Recording the cause matters: a sponsored row keeps binding its sender,
 * subject and timestamp after the badge has already collapsed it, and any of
 * those later bindings would otherwise restore the advertisement.</p>
 */
public final class HiddenViewRegistry {

    public static final int UNSET_HEIGHT = Integer.MIN_VALUE;

    private static final Map<View, SavedState> HIDDEN =
            Collections.synchronizedMap(new WeakHashMap<View, SavedState>());

    private HiddenViewRegistry() {
    }

    public static void rememberIfAbsent(
            View row,
            int originalVisibility,
            int originalHeight,
            View markerView
    ) {
        synchronized (HIDDEN) {
            if (!HIDDEN.containsKey(row)) {
                HIDDEN.put(row, new SavedState(
                        originalVisibility, originalHeight, markerView));
            }
        }
    }

    public static SavedState get(View row) {
        return HIDDEN.get(row);
    }

    public static void forget(View row) {
        HIDDEN.remove(row);
    }

    public static final class SavedState {

        public final int originalVisibility;
        public final int originalHeight;

        private final WeakReference<View> markerView;

        SavedState(int originalVisibility, int originalHeight, View markerView) {
            this.originalVisibility = originalVisibility;
            this.originalHeight = originalHeight;
            this.markerView = new WeakReference<>(markerView);
        }

        public boolean wasHiddenBy(View view) {
            return markerView.get() == view;
        }
    }
}
