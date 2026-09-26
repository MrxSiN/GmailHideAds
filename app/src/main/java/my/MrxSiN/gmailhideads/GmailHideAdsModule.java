package my.MrxSiN.gmailhideads;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.os.Build;

import java.lang.reflect.Method;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

import io.github.libxposed.api.XposedModule;

import my.MrxSiN.gmailhideads.core.ModuleRuntime;
import my.MrxSiN.gmailhideads.hook.AdTeaserLayer;
import my.MrxSiN.gmailhideads.policy.GmailPolicy;

/**
 * Modern Xposed API entry point, scoped to Gmail.
 *
 * <p>The entry owns lifecycle only. It decides when the host is ready and hands
 * the work to {@link AdTeaserLayer}; whether a package and process are in scope
 * and what counts as an advertisement are decided by the Brainfuck policy in
 * {@link GmailPolicy}, and how a row is suppressed is decided elsewhere.</p>
 */
public final class GmailHideAdsModule extends XposedModule {

    private static final String MODULE_VERSION = BuildConfig.VERSION_NAME;
    private static final String TARGET_PACKAGE = "com.google.android.gm";

    private static final AtomicBoolean ATTACH_GUARD_INSTALLED = new AtomicBoolean(false);
    private static final AtomicBoolean BOOTSTRAPPED = new AtomicBoolean(false);

    private volatile String processName = "";

    @Override
    public void onModuleLoaded(ModuleLoadedParam param) {
        ModuleRuntime.attach(this);
        processName = param.getProcessName();
        if (!GmailPolicy.load()) {
            ModuleRuntime.log("Brainfuck policy core unavailable; fail-open mode active: "
                    + GmailPolicy.failure());
        }
    }

    @Override
    public void onPackageReady(PackageReadyParam param) {
        // Gmail runs several processes and ads are bound only in the main one.
        // A library that failed to load answers no, so nothing is installed.
        if (!GmailPolicy.inScope(param.getPackageName(), processName)) {
            return;
        }
        if (!ATTACH_GUARD_INSTALLED.compareAndSet(false, true)) {
            return;
        }

        ModuleRuntime.log("Gmail Hide Ads v" + MODULE_VERSION
                + ": loading in " + processName
                + ", framework=" + getFrameworkName()
                + " " + getFrameworkVersion()
                + ", api=" + getApiVersion()
                + ", policyCore=brainfuck-aot abi=" + GmailPolicy.abi());

        installAttachGuard(param.getClassLoader());
    }

    /**
     * Waits for {@code Application.attach()} rather than installing from the
     * package callback, so that Gmail has supplied its real application context
     * before any layer is installed.
     */
    private void installAttachGuard(ClassLoader classLoader) {
        try {
            Class<?> applicationClass =
                    Class.forName("android.app.Application", false, classLoader);
            Method attach = applicationClass.getDeclaredMethod("attach", Context.class);

            ModuleRuntime.hook(attach, chain -> {
                List<Object> args = chain.getArgs();
                Object result = chain.proceed();
                bootstrap(args.isEmpty() ? null : args.get(0));
                return result;
            });

            ModuleRuntime.log("Application attach guard installed");
        } catch (Throwable throwable) {
            ModuleRuntime.log(
                    "Unable to install application attach guard; Gmail is left untouched",
                    throwable);
        }
    }

    private void bootstrap(Object rawContext) {
        if (!BOOTSTRAPPED.compareAndSet(false, true)) {
            return;
        }

        Context appContext = rawContext instanceof Context ? (Context) rawContext : null;
        ModuleRuntime.log("Host: " + describeHostVersion(appContext));

        // A layer that fails is logged and skipped; Gmail keeps working.
        try {
            AdTeaserLayer.install();
            ModuleRuntime.log("Layer installed: ad-teaser");
        } catch (Throwable throwable) {
            ModuleRuntime.log("Layer failed, skipping: ad-teaser", throwable);
        }
    }

    /**
     * The installed Gmail version, for the log line that makes a bug report
     * useful. Never throws: an unknown version is not a reason to abort.
     */
    @SuppressWarnings("deprecation")
    private static String describeHostVersion(Context context) {
        if (context == null) {
            return "unknown (no application context)";
        }
        try {
            PackageInfo info = context.getPackageManager().getPackageInfo(TARGET_PACKAGE, 0);
            long versionCode = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
                    ? info.getLongVersionCode()
                    : info.versionCode;
            return info.versionName + " (" + versionCode + ")";
        } catch (Throwable throwable) {
            return "unknown (" + throwable.getClass().getSimpleName() + ")";
        }
    }
}
