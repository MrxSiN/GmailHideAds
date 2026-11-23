# row.bf — Gmail ad row classes

Normative specification of `brainfuck/src/row.bf` (program id 0), used by
`AdTeaserViewDetector` for every view class `ViewGroup.addView` meets for the
first time. The verdict is cached per class in Java, so the program runs once
per class, not once per row.

## OP_AD_ROW (0x10)

Request payload:

```text
u8 n (0..255): the view class first, then each superclass up to java.lang.Object
per class:
  chunks of name-alphabet codes of Class.getName(), 0 ends
```

A chain longer than 255 classes is not sent; the request fails and the view
is kept.

Name alphabet (case sensitive, `NC_*`): 0 any other char (including every
non-ASCII char), 1 `.`, 2–19 the letters `c o m g l e a n d r i s t w A T I V`
and 20–21 the letters `p b`, which together are every letter of
`com.google.android.gm.ads.`, `com.google.android.apps.gmail.libraries.ads.`
and `AdTeaserItemView`.

Response payload (1 byte): 1 when some class in the chain is an ad row, else 0.

Rule: a class is an ad row when its name **starts with** one of the ads
packages

- `com.google.android.gm.ads.` (Gmail up to 2026.10),
- `com.google.android.apps.gmail.libraries.ads.` (Gmail 2026.11.09 and later,
  same class names),

**and ends with** `AdTeaserItemView`. The shortest such name is
`com.google.android.gm.ads.AdTeaserItemView` (42 chars): a prefix and the
suffix cannot overlap, because each prefix ends in `.` and the suffix holds
none.

Implementation, per class:

- `PS` walks a trie of the two prefixes. States 0–25 follow
  `com.google.android.gm.ads.`: in state *k* the next code must be its *k*-th
  character, else `PS` becomes 27 (dead). State 19 (after
  `com.google.android.`) also takes `a` to state 28, and states 28–51 follow
  `pps.gmail.libraries.ads.` the same way, the last one going to 26. States 26
  (matched) and 27 stay put.
- `SS` is the length of the longest start of `AdTeaserItemView` that ends the
  name so far. On a mismatch it restarts at 1 for `A`, else 0; the suffix holds
  its first character `A` only once, so no other fallback state exists.
- At the end of the name, `PS == 26` and `SS == 16` sets the verdict.

Both machines see every character, so the result equals Java's
`(startsWith(gmAds) || startsWith(appsAds)) && endsWith(suffix)` for every
string, which
`PolicyParityTest` checks against the frozen v1.0.0 detector, including every
BMP character in six positions.
