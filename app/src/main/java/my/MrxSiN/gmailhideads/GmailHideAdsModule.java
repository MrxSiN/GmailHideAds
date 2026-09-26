package my.MrxSiN.gmailhideads;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.os.Build;

import java.lang.reflect.Method;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

import io.github.libxposed.api.XposedInterface;
import io.github.libxposed.api.XposedModule;

import my.MrxSiN.gmailhideads.core.ModuleRuntime;
import my.MrxSiN.gmailhideads.detect.AdTeaserViewDetector;
import my.MrxSiN.gmailhideads.discover.AdRowDiscovery;
import my.MrxSiN.gmailhideads.hook.AdTeaserLayer;
import my.MrxSiN.gmailhideads.policy.GmailPolicy;

/**
 * Modern Xposed API entry point, scoped to Gmail.
 *
 * <p>The entry owns lifecycle only. It decides when the host is ready and hands
 * the work to {@link AdTeaserLayer}; whether a package and process are in scope
 * and what counts as an advertisement are decided by the Brainfuck policy in
 * {@link GmailPolicy}, and how a row is suppressed is decided elsewhere.</p>
 *
 * <p>Hot reload ({@code autoHotReload} in module.prop): when a new build is
 * installed, the running generation hands over the class loader and the
 * application context ({@link #onHotReloading}); the new generation installs
 * its hooks again under the same ids, so they replace the old ones in place,
 * and takes the rest of the old hooks off ({@link #onHotReloaded}).</p>
 */
public final class GmailHideAdsModule extends XposedModule {

    private static final String MODULE_VERSION = BuildConfig.VERSION_NAME;
    private static final String TARGET_PACKAGE = "com.google.android.gm";

    private final AtomicBoolean attachGuardInstalled = new AtomicBoolean(false);
    private final AtomicBoolean bootstrapped = new AtomicBoolean(false);

    private volatile String processName = "";
    /** Gmail's class loader, once this generation is in scope. */
    private volatile ClassLoader classLoader;
    /** The application context, once Application.attach has run. */
    private volatile Context context;

    @Override
    public void onModuleLoaded(ModuleLoadedParam param) {
        start(param.getProcessName());
    }

    @Override
    public void onPackageReady(PackageReadyParam param) {
        // Gmail runs several processes and ads are bound only in the main one.
        // A library that failed to load answers no, so nothing is installed.
        if (!GmailPolicy.inScope(param.getPackageName(), processName)) {
            return;
        }
        if (!attachGuardInstalled.compareAndSet(false, true)) {
            return;
        }
        classLoader = param.getClassLoader();
        ModuleRuntime.log("Gmail Hide Ads v" + MODULE_VERSION
                + ": loading in " + processName
                + ", framework=" + getFrameworkName()
                + " " + getFrameworkVersion()
                + ", api=" + getApiVersion()
                + ", policyCore=brainfuck-aot abi=" + GmailPolicy.abi());

        installAttachGuard(classLoader);
    }

    @Override
    public boolean onHotReloading(HotReloadingParam param) {
        param.setSavedInstanceState(new Object[]{classLoader, context});
        ModuleRuntime.log("Hot reloading from v" + MODULE_VERSION);
        return true;
    }

    @Override
    public void onHotReloaded(HotReloadedParam param) {
        start(param.getProcessName());
        Object saved = param.getSavedInstanceState();
        if (saved instanceof Object[]) {
            ClassLoader loader = (ClassLoader) ((Object[]) saved)[0];
            Context attached = (Context) ((Object[]) saved)[1];
            if (loader != null) {
                classLoader = loader;
                if (attached != null) {
                    bootstrap(attached);
                } else if (attachGuardInstalled.compareAndSet(false, true)) {
                    installAttachGuard(loader);
                }
            }
        }
        int retired = 0;
        for (XposedInterface.HookHandle handle : param.getOldHookHandles()) {
            if (!ModuleRuntime.owns(handle.getId())) {
                handle.unhook();
                retired++;
            }
        }
        ModuleRuntime.log("Hot reloaded to v" + MODULE_VERSION + "; "
                + retired + " hook(s) of the previous generation taken off");
    }

    private void start(String process) {
        ModuleRuntime.attach(this);
        processName = process;
        if (!GmailPolicy.load()) {
            ModuleRuntime.log("Brainfuck policy core unavailable; fail-open mode active: "
                    + GmailPolicy.failure());
        }
    }

    /**
     * Waits for {@code Application.attach()} rather than installing from the
     * package callback, so that Gmail has supplied its real application context
     * before any layer is installed.
     */
    private void installAttachGuard(ClassLoader loader) {
        try {
            Class<?> applicationClass =
                    Class.forName("android.app.Application", false, loader);
            Method attach = applicationClass.getDeclaredMethod("attach", Context.class);

            ModuleRuntime.hook(attach, "attach", chain -> {
                List<Object> args = chain.getArgs();
                Object result = chain.proceed();
                Object raw = args.isEmpty() ? null : args.get(0);
                if (raw instanceof Context) {
                    bootstrap((Context) raw);
                }
                return result;
            });

            ModuleRuntime.log("Application attach guard installed");
        } catch (Throwable throwable) {
            ModuleRuntime.log(
                    "Unable to install application attach guard; Gmail is left untouched",
                    throwable);
        }
    }

    private void bootstrap(Context appContext) {
        if (!bootstrapped.compareAndSet(false, true)) {
            return;
        }
        context = appContext;
        ModuleRuntime.log("Host: " + describeHostVersion(appContext));

        // Discovery failing, or finding nothing hookable, falls back to the
        // broad layer; a layer that fails is logged and skipped.
        AdTeaserViewDetector detector = new AdTeaserViewDetector();
        try {
            if (AdTeaserLayer.installInflate(AdRowDiscovery.find(appContext, detector), detector)) {
                ModuleRuntime.log("Layer installed: ad-teaser inflate");
                return;
            }
            ModuleRuntime.log("No hookable ad row class; using the addView fallback");
        } catch (Throwable throwable) {
            ModuleRuntime.log("DexKit discovery failed; using the addView fallback", throwable);
        }
        try {
            AdTeaserLayer.installAddView(detector);
            ModuleRuntime.log("Layer installed: ad-teaser addView");
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
