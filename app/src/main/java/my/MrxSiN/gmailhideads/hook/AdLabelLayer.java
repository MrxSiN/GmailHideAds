package my.MrxSiN.gmailhideads.hook;

import android.widget.TextView;

import java.lang.reflect.Method;

import io.github.libxposed.api.XposedInterface;

import my.MrxSiN.gmailhideads.core.ModuleRuntime;
import my.MrxSiN.gmailhideads.detect.AdDetector;
import my.MrxSiN.gmailhideads.ui.AdMarkerRegistry;
import my.MrxSiN.gmailhideads.ui.ListItemCollapser;

/**
 * Collapses conversation rows whose badge renders as advertising.
 *
 * <p>Server-rendered ads never touch the advertisement provider, so
 * {@link AdQueryLayer} alone cannot see them. What every sponsored row does do
 * is print its badge through {@link TextView}, the single overload that all
 * public {@code setText} calls funnel into.</p>
 */
public final class AdLabelLayer implements HookLayer {

    private final AdDetector<CharSequence> detector;

    public AdLabelLayer(AdDetector<CharSequence> detector) {
        this.detector = detector;
    }

    @Override
    public String id() {
        return "ad-label";
    }

    @Override
    public void install(HookContext context) throws Throwable {
        Method setText = TextView.class.getDeclaredMethod(
                "setText", CharSequence.class, TextView.BufferType.class);

        // setText(CharSequence, BufferType) is small enough for ART to inline
        // into setText(CharSequence), which would bypass the hook entirely.
        ModuleRuntime.deoptimize(setText);

        if (ModuleRuntime.hook(setText, new LabelHooker(detector)) == null) {
            throw new IllegalStateException("TextView.setText hook rejected");
        }
    }

    private static final class LabelHooker implements XposedInterface.Hooker {

        private final AdDetector<CharSequence> detector;

        LabelHooker(AdDetector<CharSequence> detector) {
            this.detector = detector;
        }

        @Override
        public Object intercept(XposedInterface.Chain chain) throws Throwable {
            // Let the text land first: the collapser measures the row, and a
            // row that has not yet been laid out cannot be identified.
            Object result = chain.proceed();

            Object self = chain.getThisObject();
            if (!(self instanceof TextView)) {
                return result;
            }

            Object rawText = chain.getArgs().isEmpty() ? null : chain.getArg(0);
            CharSequence text = rawText instanceof CharSequence
                    ? (CharSequence) rawText
                    : null;

            TextView label = (TextView) self;

            if (detector.isAd(text)) {
                AdMarkerRegistry.mark(label);
                ListItemCollapser.collapseRowOf(label);
            } else {
                AdMarkerRegistry.unmark(label);
                ListItemCollapser.restoreRowMarkedBy(label);
            }

            return result;
        }
    }
}
