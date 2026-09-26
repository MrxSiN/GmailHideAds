package my.MrxSiN.gmailhideads.hook;

import android.view.View;
import android.view.ViewGroup;

import java.lang.reflect.Method;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

import io.github.libxposed.api.XposedInterface;

import my.MrxSiN.gmailhideads.core.ModuleRuntime;
import my.MrxSiN.gmailhideads.detect.AdTeaserViewDetector;
import my.MrxSiN.gmailhideads.policy.GmailPolicy;
import my.MrxSiN.gmailhideads.ui.AdRowCollapser;
import my.MrxSiN.gmailhideads.ui.ViewDescriptions;

/**
 * Collapses every advertisement row before it is ever measured.
 *
 * <p>Primary: each ad row class found at start-up declares its own
 * {@code onFinishInflate}, which runs after the inflater gave the row its
 * layout parameters and before the list binds or measures it, so only those
 * methods are hooked; the row is collapsed there and again each time it is
 * attached. Fallback, when discovery found nothing or a class could
 * not be hooked: {@code ViewGroup.addView(View, int, LayoutParams)}, the
 * overload the other public {@code addView} signatures funnel into.</p>
 */
public final class AdTeaserLayer {

    private static final AtomicLong COLLAPSED = new AtomicLong();

    /**
     * Gmail's bind sets the row's visibility after inflation; attaching comes
     * after the bind and before the first measure, so the row is collapsed
     * again there.
     */
    private static final View.OnAttachStateChangeListener RECOLLAPSE = new View.OnAttachStateChangeListener() {
        @Override
        public void onViewAttachedToWindow(View row) {
            AdRowCollapser.collapse(row, row.getLayoutParams());
        }

        @Override
        public void onViewDetachedFromWindow(View row) {
        }
    };

    private AdTeaserLayer() {
    }

    /**
     * Hooks {@code onFinishInflate} of every row class, or nothing: false when
     * any class declares no such method or its hook was rejected.
     */
    public static boolean installInflate(List<Class<?>> rows, AdTeaserViewDetector detector) {
        XposedInterface.Hooker hooker = chain -> {
            Object result = chain.proceed();
            Object row = chain.getThisObject();
            if (row instanceof View && detector.isAd((View) row)) {
                View view = (View) row;
                suppress(view, view.getLayoutParams());
                view.addOnAttachStateChangeListener(RECOLLAPSE);
            }
            return result;
        };
        for (Class<?> row : rows) {
            try {
                if (ModuleRuntime.hook(row.getDeclaredMethod("onFinishInflate"),
                        "inflate:" + row.getName(), hooker) == null) {
                    return false;
                }
            } catch (NoSuchMethodException missing) {
                ModuleRuntime.log("Ad row without its own onFinishInflate: " + row.getName());
                return false;
            }
        }
        return !rows.isEmpty();
    }

    public static void installAddView(AdTeaserViewDetector detector) throws Throwable {
        Method addView = ViewGroup.class.getDeclaredMethod(
                "addView", View.class, int.class, ViewGroup.LayoutParams.class);

        // The shorter addView overloads are small enough for ART to inline, so
        // without this the hook can be bypassed by an already compiled caller.
        ModuleRuntime.deoptimize(addView);

        XposedInterface.Hooker hooker = chain -> {
            List<Object> args = chain.getArgs();
            if (args.size() >= 3 && args.get(0) instanceof View && detector.isAd((View) args.get(0))) {
                View child = (View) args.get(0);
                Object params = args.get(2);
                suppress(child, params instanceof ViewGroup.LayoutParams
                        ? (ViewGroup.LayoutParams) params
                        : child.getLayoutParams());
            }
            return chain.proceed();
        };
        if (ModuleRuntime.hook(addView, "addView", hooker) == null) {
            throw new IllegalStateException("ViewGroup.addView hook rejected");
        }
    }

    private static void suppress(View row, ViewGroup.LayoutParams params) {
        AdRowCollapser.collapse(row, params);
        // The view id survives Gmail's resource shrinking, so this line is
        // what makes a bug report actionable after a rename.
        ModuleRuntime.log("Collapsed advertisement row #" + COLLAPSED.incrementAndGet()
                + ": " + ViewDescriptions.describe(row) + " (" + GmailPolicy.summary() + ")");
    }
}
