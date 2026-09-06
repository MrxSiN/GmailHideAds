package my.MrxSiN.gmailhideads.ui;

import android.util.DisplayMetrics;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

import my.MrxSiN.gmailhideads.core.ModuleStats;

/**
 * Collapses the conversation row that owns a rendered advertisement badge, and
 * restores it once the row is recycled for organic mail.
 *
 * <p>The deferred retry below exists for cold launch. Gmail binds the first
 * page of rows while they are still detached and unmeasured, so at that moment
 * neither the list container nor the size heuristic can identify the row.
 * Collapsing then would hide the badge alone and leave the advertisement on
 * screen. The collapser therefore waits for attach and for the first layout
 * pass, and only falls back to the badge itself once the hierarchy has had a
 * real chance to settle.</p>
 */
public final class ListItemCollapser {

    private static final int MAX_LAYOUT_RETRIES = 4;

    private static final float MIN_ROW_WIDTH_RATIO = 0.70f;
    private static final float MAX_ROW_HEIGHT_RATIO = 0.60f;
    private static final int MIN_ROW_HEIGHT_DP = 48;

    private static final Map<View, Boolean> PENDING_RETRIES =
            Collections.synchronizedMap(new WeakHashMap<View, Boolean>());

    private ListItemCollapser() {
    }

    public static void collapseRowOf(View labelView) {
        collapseRowOf(labelView, 0);
    }

    private static void collapseRowOf(final View labelView, final int attempt) {
        if (!AdMarkerRegistry.isMarked(labelView)) {
            // The badge was rebound to organic text while the retry was armed.
            return;
        }

        View row = findRow(labelView);

        if (row != null) {
            collapse(row, labelView);
            ModuleStats.recordCollapsedRow(row.getClass().getName());
            return;
        }

        if (attempt < MAX_LAYOUT_RETRIES
                && retryWhenHierarchyIsReady(labelView, attempt + 1)) {
            return;
        }

        // Last resort: hide the badge only, rather than risk hiding the screen.
        collapse(labelView, labelView);
        ModuleStats.recordCollapsedRow("badge-only fallback");
    }

    /**
     * Returns the row to collapse, or {@code null} while the hierarchy cannot
     * yet answer the question.
     */
    private static View findRow(View labelView) {
        DisplayMetrics metrics = labelView.getResources().getDisplayMetrics();
        int screenWidth = metrics.widthPixels;
        int screenHeight = metrics.heightPixels;
        int minimumHeight = (int) (MIN_ROW_HEIGHT_DP * metrics.density);

        View current = labelView;
        View fallback = null;

        for (int depth = 0; depth < ViewTrees.MAX_ANCESTOR_DEPTH; depth++) {
            View parent = ViewTrees.parentOf(current);
            if (parent == null) {
                break;
            }

            // current is the row itself once its parent is the list container.
            if (ViewTrees.isListContainer(parent) && current != labelView) {
                return current;
            }

            if (depth >= 2
                    && parent.getWidth() >= screenWidth * MIN_ROW_WIDTH_RATIO
                    && parent.getHeight() >= minimumHeight
                    && parent.getHeight() <= screenHeight * MAX_ROW_HEIGHT_RATIO) {
                fallback = parent;
            }

            if (parent == labelView.getRootView() || ViewTrees.isDecorView(parent)) {
                break;
            }

            current = parent;
        }

        return fallback;
    }

    /**
     * Arms a single deferred retry: on attach while the badge is still
     * detached, otherwise after the next layout pass.
     *
     * @return true when a retry was armed and the caller should stop.
     */
    private static boolean retryWhenHierarchyIsReady(
            final View labelView,
            final int nextAttempt
    ) {
        if (PENDING_RETRIES.put(labelView, Boolean.TRUE) != null) {
            // A retry for this badge is already armed.
            return true;
        }

        if (!ViewTrees.isAttached(labelView)) {
            labelView.addOnAttachStateChangeListener(
                    new View.OnAttachStateChangeListener() {
                        @Override
                        public void onViewAttachedToWindow(View view) {
                            view.removeOnAttachStateChangeListener(this);
                            PENDING_RETRIES.remove(view);
                            collapseRowOf(view, nextAttempt);
                        }

                        @Override
                        public void onViewDetachedFromWindow(View view) {
                        }
                    });
            return true;
        }

        ViewTreeObserver observer = labelView.getViewTreeObserver();
        if (!observer.isAlive()) {
            PENDING_RETRIES.remove(labelView);
            return false;
        }

        observer.addOnPreDrawListener(new ViewTreeObserver.OnPreDrawListener() {
            @Override
            public boolean onPreDraw() {
                ViewTreeObserver current = labelView.getViewTreeObserver();
                if (current.isAlive()) {
                    current.removeOnPreDrawListener(this);
                }
                PENDING_RETRIES.remove(labelView);
                collapseRowOf(labelView, nextAttempt);
                return true;
            }
        });

        return true;
    }

    private static void collapse(View row, View markerView) {
        ViewGroup.LayoutParams params = row.getLayoutParams();

        HiddenViewRegistry.rememberIfAbsent(
                row,
                row.getVisibility(),
                params == null ? HiddenViewRegistry.UNSET_HEIGHT : params.height,
                markerView
        );

        if (params != null && params.height != 0) {
            params.height = 0;
            row.setLayoutParams(params);
        }

        row.setVisibility(View.GONE);
        row.requestLayout();
    }

    /**
     * Restores a collapsed row once the badge that hid it is rebound to
     * organic text. Only the exact view that caused the collapse may undo it.
     */
    public static void restoreRowMarkedBy(View labelView) {
        View current = labelView;

        for (int depth = 0; depth < ViewTrees.MAX_ANCESTOR_DEPTH; depth++) {
            HiddenViewRegistry.SavedState saved = HiddenViewRegistry.get(current);

            if (saved != null) {
                if (!saved.wasHiddenBy(labelView)
                        || AdMarkerRegistry.subtreeHasMarker(current)) {
                    return;
                }
                restore(current, saved);
                return;
            }

            View parent = ViewTrees.parentOf(current);
            if (parent == null) {
                return;
            }
            current = parent;
        }
    }

    private static void restore(View row, HiddenViewRegistry.SavedState saved) {
        HiddenViewRegistry.forget(row);

        ViewGroup.LayoutParams params = row.getLayoutParams();
        if (params != null && saved.originalHeight != HiddenViewRegistry.UNSET_HEIGHT) {
            params.height = saved.originalHeight;
            row.setLayoutParams(params);
        }

        row.setVisibility(saved.originalVisibility);
        row.requestLayout();

        ModuleStats.recordRestoredRow(row.getClass().getName());
    }
}
