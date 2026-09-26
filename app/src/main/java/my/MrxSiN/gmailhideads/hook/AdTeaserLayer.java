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
 * Collapses every advertisement row as it is added to the conversation list.
 *
 * <p>{@code addView(View, int, LayoutParams)} is the overload the other four
 * public {@code addView} signatures funnel into, and it is the moment the row
 * first has its layout parameters, so the row can be zeroed before it is ever
 * measured. Hooking the framework rather than Gmail's list adapter keeps the
 * layer working across Gmail releases.</p>
 */
public final class AdTeaserLayer {

    private AdTeaserLayer() {
    }

    public static void install() throws Throwable {
        Method addView = ViewGroup.class.getDeclaredMethod(
                "addView", View.class, int.class, ViewGroup.LayoutParams.class);

        // The shorter addView overloads are small enough for ART to inline, so
        // without this the hook can be bypassed by an already compiled caller.
        ModuleRuntime.deoptimize(addView);

        if (ModuleRuntime.hook(addView, new AddViewHooker(new AdTeaserViewDetector())) == null) {
            throw new IllegalStateException("ViewGroup.addView hook rejected");
        }
    }

    private static final class AddViewHooker implements XposedInterface.Hooker {

        private final AtomicLong collapsed = new AtomicLong();
        private final AdTeaserViewDetector detector;

        AddViewHooker(AdTeaserViewDetector detector) {
            this.detector = detector;
        }

        @Override
        public Object intercept(XposedInterface.Chain chain) throws Throwable {
            List<Object> args = chain.getArgs();

            if (args.size() >= 3 && args.get(0) instanceof View) {
                View child = (View) args.get(0);

                if (detector.isAd(child)) {
                    Object rawParams = args.get(2);
                    AdRowCollapser.collapse(
                            child,
                            rawParams instanceof ViewGroup.LayoutParams
                                    ? (ViewGroup.LayoutParams) rawParams
                                    : child.getLayoutParams()
                    );
                    // The view id survives Gmail's resource shrinking, so this
                    // line is what makes a bug report actionable after a rename.
                    ModuleRuntime.log("Collapsed advertisement row #" + collapsed.incrementAndGet()
                            + ": " + ViewDescriptions.describe(child) + " (" + GmailPolicy.summary() + ")");
                }
            }

            return chain.proceed();
        }
    }
}
