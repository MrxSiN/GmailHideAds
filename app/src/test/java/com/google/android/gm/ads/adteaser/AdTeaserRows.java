package com.google.android.gm.ads.adteaser;

/**
 * Test fixtures named like the ad row classes of Gmail 2026.08.17. They are
 * plain classes: the policy reads class names and superclasses, never views.
 */
public final class AdTeaserRows {

    public static final Class<?>[] ROWS = {
            BasicAdTeaserItemView.class,
            VideoAdTeaserItemView.class,
            ImageCarouselAdTeaserItemView.class,
            RichButtonChipAdTeaserItemView.class,
            AppInstallButtonChipAdTeaserItemView.class,
            EuSingleImageAdTeaserItemView.class,
    };

    /** An ad row subclassed under an ordinary name, and a nested ad row. */
    public static final Class<?>[] DERIVED = {RenamedRow.class, Holder.NestedAdTeaserItemView.class};

    /** Same package, not a row. */
    public static final Class<?> BASE = AdTeaserItemBase.class;

    private AdTeaserRows() {
    }

    public static final class Holder {
        static class NestedAdTeaserItemView {
        }
    }
}

class AdTeaserItemBase {
}

class BasicAdTeaserItemView extends AdTeaserItemBase {
}

class VideoAdTeaserItemView extends AdTeaserItemBase {
}

class ImageCarouselAdTeaserItemView extends AdTeaserItemBase {
}

class RichButtonChipAdTeaserItemView extends AdTeaserItemBase {
}

class AppInstallButtonChipAdTeaserItemView extends AdTeaserItemBase {
}

class EuSingleImageAdTeaserItemView extends BasicAdTeaserItemView {
}

class RenamedRow extends VideoAdTeaserItemView {
}
