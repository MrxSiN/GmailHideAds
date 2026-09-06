package my.MrxSiN.gmailhideads.hook;

import android.content.ContentProviderClient;
import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.CancellationSignal;

import java.lang.reflect.Method;

import io.github.libxposed.api.XposedInterface;

import my.MrxSiN.gmailhideads.core.ModuleRuntime;
import my.MrxSiN.gmailhideads.core.ModuleStats;
import my.MrxSiN.gmailhideads.data.EmptyCursor;
import my.MrxSiN.gmailhideads.detect.AdDetector;

/**
 * Empties the cursors Gmail loads its advertisement rows from.
 *
 * <p>This layer hooks the framework rather than Gmail. Every public
 * {@code query} overload funnels into the {@link Bundle} variant hooked here,
 * and framework signatures do not change with a Gmail release, so the layer
 * survives the obfuscation and the redesigns that break name-based hooks.</p>
 *
 * <p>Gmail already handles an ad query that returns nothing; that is the
 * ordinary "no ads available" path.</p>
 */
public final class AdQueryLayer implements HookLayer {

    private final AdDetector<Uri> detector;

    public AdQueryLayer(AdDetector<Uri> detector) {
        this.detector = detector;
    }

    @Override
    public String id() {
        return "ad-query";
    }

    @Override
    public void install(HookContext context) throws Throwable {
        XposedInterface.Hooker hooker = new QueryHooker(detector);

        Method resolverQuery = ContentResolver.class.getDeclaredMethod(
                "query", Uri.class, String[].class, Bundle.class,
                CancellationSignal.class);
        Method clientQuery = ContentProviderClient.class.getDeclaredMethod(
                "query", Uri.class, String[].class, Bundle.class,
                CancellationSignal.class);

        // Both targets are short delegating methods that ART inlines into
        // their callers; without this the hooks would never be reached.
        ModuleRuntime.deoptimize(resolverQuery);
        ModuleRuntime.deoptimize(clientQuery);

        if (ModuleRuntime.hook(resolverQuery, hooker) == null) {
            throw new IllegalStateException("ContentResolver.query hook rejected");
        }
        if (ModuleRuntime.hook(clientQuery, hooker) == null) {
            throw new IllegalStateException("ContentProviderClient.query hook rejected");
        }
    }

    /** Wraps an advertisement result so it reports its schema but no rows. */
    private static final class QueryHooker implements XposedInterface.Hooker {

        private final AdDetector<Uri> detector;

        QueryHooker(AdDetector<Uri> detector) {
            this.detector = detector;
        }

        @Override
        public Object intercept(XposedInterface.Chain chain) throws Throwable {
            Object result = chain.proceed();

            if (!(result instanceof Cursor)) {
                return result;
            }

            Object rawUri = chain.getArgs().isEmpty() ? null : chain.getArg(0);
            if (!(rawUri instanceof Uri)) {
                return result;
            }

            Uri uri = (Uri) rawUri;
            if (!detector.isAd(uri)) {
                return result;
            }

            ModuleStats.recordBlockedQuery(uri.toString());
            return new EmptyCursor((Cursor) result);
        }
    }
}
