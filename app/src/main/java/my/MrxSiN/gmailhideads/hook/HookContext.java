package my.MrxSiN.gmailhideads.hook;

import android.content.Context;

/** Everything a hook layer is given at install time. */
public final class HookContext {

    private final ClassLoader hostClassLoader;
    private final Context appContext;

    public HookContext(ClassLoader hostClassLoader, Context appContext) {
        this.hostClassLoader = hostClassLoader;
        this.appContext = appContext;
    }

    public ClassLoader hostClassLoader() {
        return hostClassLoader;
    }

    /** The host application context, or {@code null} if it was unavailable. */
    public Context appContext() {
        return appContext;
    }
}
