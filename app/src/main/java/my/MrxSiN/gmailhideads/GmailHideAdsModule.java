package my.MrxSiN.gmailhideads;

import android.content.Context;

import java.lang.reflect.Method;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

import io.github.libxposed.api.XposedModule;

import my.MrxSiN.gmailhideads.config.GmailProfile;
import my.MrxSiN.gmailhideads.core.ModuleRuntime;
import my.MrxSiN.gmailhideads.detect.AdLabelDetector;
import my.MrxSiN.gmailhideads.detect.AdUriDetector;
import my.MrxSiN.gmailhideads.hook.AdLabelLayer;
import my.MrxSiN.gmailhideads.hook.AdQueryLayer;
import my.MrxSiN.gmailhideads.hook.HookContext;
import my.MrxSiN.gmailhideads.hook.HookPipeline;

/**
 * Modern Xposed API entry point, scoped to Gmail.
 *
 * <p>The entry owns lifecycle only. It decides when the host is ready and hands
 * the work to {@link HookPipeline}; what counts as an ad and how a row is
 * suppressed are decided elsewhere.</p>
 */
public final class GmailHideAdsModule extends XposedModule {

    private static final String MODULE_VERSION = "1.0.0";

    private static final AtomicBoolean ATTACH_GUARD_INSTALLED = new AtomicBoolean(false);
    private static final AtomicBoolean BOOTSTRAPPED = new AtomicBoolean(false);

    private volatile String processName = "";
    private volatile ClassLoader hostClassLoader;

    @Override
    public void onModuleLoaded(ModuleLoadedParam param) {
        ModuleRuntime.attach(this);
        processName = param.getProcessName();
    }

    @Override
    public void onPackageReady(PackageReadyParam param) {
        if (!GmailProfile.isTargetPackage(param.getPackageName())
                || !GmailProfile.isTargetProcess(processName)) {
            return;
        }
        if (!ATTACH_GUARD_INSTALLED.compareAndSet(false, true)) {
            return;
        }

        hostClassLoader = param.getClassLoader();
        ModuleRuntime.log("Gmail Hide Ads v" + MODULE_VERSION
                + ": loading in " + processName
                + ", framework=" + getFrameworkName()
                + " " + getFrameworkVersion()
                + ", api=" + getApiVersion());

        installAttachGuard(hostClassLoader);
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
        ModuleRuntime.log("Host: " + GmailProfile.describeHostVersion(appContext));

        HookPipeline pipeline = new HookPipeline(
                new AdQueryLayer(new AdUriDetector()),
                new AdLabelLayer(new AdLabelDetector())
        );

        pipeline.installAll(new HookContext(hostClassLoader, appContext));
    }
}
