package my.MrxSiN.gmailhideads.core;

import android.util.Log;

import java.lang.reflect.Executable;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import io.github.libxposed.api.XposedInterface;

/**
 * Process-wide access to the framework interface handed to the module entry.
 *
 * <p>The modern Xposed API exposes hooking, deoptimization and logging through
 * the {@link XposedInterface} instance attached to the module entry class
 * instead of the static {@code XposedBridge} of the legacy API. Every other
 * class in this module depends on this abstraction rather than on a concrete
 * framework, so the detectors and hook layers stay testable and free of
 * framework imports.</p>
 *
 * <p>Every hook carries a stable id. A hot-reloaded generation that installs a
 * hook with the same id on the same method replaces the old one in place, and
 * {@link #owns} tells which hooks of the previous generation were not taken
 * over.</p>
 */
public final class ModuleRuntime {

    private static final String TAG = "GmailHideAds";

    private static volatile XposedInterface api;

    private static final Set<String> HOOK_IDS = ConcurrentHashMap.newKeySet();

    private ModuleRuntime() {
    }

    public static void attach(XposedInterface framework) {
        api = framework;
    }

    public static void log(String message) {
        XposedInterface framework = api;
        if (framework == null) {
            Log.i(TAG, message);
            return;
        }
        framework.log(Log.INFO, TAG, message);
    }

    public static void log(String message, Throwable throwable) {
        XposedInterface framework = api;
        if (framework == null) {
            Log.e(TAG, message, throwable);
            return;
        }
        framework.log(Log.ERROR, TAG, message, throwable);
    }

    /**
     * Installs a hook under {@code id}, or returns {@code null} when the
     * framework interface is missing or the framework rejected the hook.
     */
    public static XposedInterface.HookHandle hook(
            Executable origin,
            String id,
            XposedInterface.Hooker hooker
    ) {
        XposedInterface framework = api;
        if (framework == null || origin == null) {
            return null;
        }
        XposedInterface.HookHandle handle = framework.hook(origin).setId(id).intercept(hooker);
        HOOK_IDS.add(id);
        return handle;
    }

    /** True when this generation installed a hook with that id. */
    public static boolean owns(String id) {
        return id != null && HOOK_IDS.contains(id);
    }

    /**
     * Forces ART to stop serving an already compiled copy of {@code executable}.
     *
     * <p>Both hook targets of this module are short framework methods that
     * larger callers inline. A hook on an inlined method is never reached,
     * because the caller keeps executing its own copy.</p>
     */
    public static boolean deoptimize(Executable executable) {
        XposedInterface framework = api;
        if (framework == null || executable == null) {
            return false;
        }
        try {
            return framework.deoptimize(executable);
        } catch (Throwable ignored) {
            return false;
        }
    }
}
