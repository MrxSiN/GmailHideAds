package com.google.android.gm.ads;

/** Test fixtures: names at the edges of the ad row rule. */
public final class LookAlikes {

    /** The shortest name the rule accepts: the package prefix and the suffix, nothing between. */
    public static final Class<?> SHORTEST = AdTeaserItemView.class;

    /** Right package, the suffix is not at the end. */
    public static final Class<?> HOLDER = AdTeaserItemViewHolder.class;

    private LookAlikes() {
    }
}

class AdTeaserItemView {
}

class AdTeaserItemViewHolder {
}
