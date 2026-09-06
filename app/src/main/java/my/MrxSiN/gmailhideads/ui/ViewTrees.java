package my.MrxSiN.gmailhideads.ui;

import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Bounded queries over a view hierarchy: containers, ancestors and depth. */
public final class ViewTrees {

    /**
     * Depth limit for every upward walk. A conversation row sits a handful of
     * levels below the list that owns it, and an unbounded walk on a recycled
     * view is both slow and pointless.
     */
    public static final int MAX_ANCESTOR_DEPTH = 14;

    private static final Map<Class<?>, Boolean> LIST_CONTAINER_CACHE =
            new ConcurrentHashMap<>();

    private ViewTrees() {
    }

    /**
     * True for the scrolling containers Gmail builds its conversation list
     * from. The check walks the class hierarchy by name because Gmail ships a
     * minified copy of RecyclerView whose own class name is obfuscated but
     * whose superclass names are not.
     */
    public static boolean isListContainer(View view) {
        Class<?> type = view.getClass();
        Boolean cached = LIST_CONTAINER_CACHE.get(type);
        if (cached != null) {
            return cached;
        }

        boolean result = false;
        for (Class<?> cursor = type; cursor != null; cursor = cursor.getSuperclass()) {
            String name = cursor.getName();
            if (name.contains("RecyclerView")
                    || name.contains("ListView")
                    || name.contains("AbsListView")) {
                result = true;
                break;
            }
        }

        Boolean existing = LIST_CONTAINER_CACHE.putIfAbsent(type, result);
        return existing == null ? result : existing;
    }

    public static boolean isDecorView(View view) {
        for (Class<?> cursor = view.getClass();
                cursor != null;
                cursor = cursor.getSuperclass()) {
            if (cursor.getName().contains("DecorView")) {
                return true;
            }
        }
        return false;
    }

    public static View parentOf(View view) {
        ViewParent parent = view.getParent();
        return parent instanceof View ? (View) parent : null;
    }

    public static boolean isAttached(View view) {
        return view.getWindowToken() != null;
    }

    /** Runs {@code visitor} over {@code root} and its descendants. */
    public static boolean anyInSubtree(View root, Predicate visitor) {
        if (visitor.test(root)) {
            return true;
        }
        if (!(root instanceof ViewGroup)) {
            return false;
        }

        ViewGroup group = (ViewGroup) root;
        for (int index = 0; index < group.getChildCount(); index++) {
            View child = group.getChildAt(index);
            if (child != null && anyInSubtree(child, visitor)) {
                return true;
            }
        }
        return false;
    }

    /** A view test, kept local so the module needs no Java 8 desugaring. */
    public interface Predicate {
        boolean test(View view);
    }
}
