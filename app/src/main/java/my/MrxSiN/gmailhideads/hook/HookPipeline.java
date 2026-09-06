package my.MrxSiN.gmailhideads.hook;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import my.MrxSiN.gmailhideads.core.ModuleRuntime;

/**
 * Installs the configured layers and keeps them independent of each other.
 *
 * <p>A layer that fails is logged and skipped. Gmail keeps working with the
 * layers that did install, and with none of them if all fail.</p>
 */
public final class HookPipeline {

    private final List<HookLayer> layers;

    public HookPipeline(HookLayer... layers) {
        this.layers = Collections.unmodifiableList(Arrays.asList(layers));
    }

    public void installAll(HookContext context) {
        int installed = 0;

        for (int index = 0; index < layers.size(); index++) {
            HookLayer layer = layers.get(index);
            try {
                layer.install(context);
                installed++;
                ModuleRuntime.log("Layer installed: " + layer.id());
            } catch (Throwable throwable) {
                ModuleRuntime.log("Layer failed, skipping: " + layer.id(), throwable);
            }
        }

        ModuleRuntime.log("Active layers: " + installed + "/" + layers.size());
    }
}
