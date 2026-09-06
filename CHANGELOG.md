# Changelog

## v1.0.0

First release.

- `ad-query` layer: empties the cursors Gmail loads advertisement rows from,
  by wrapping the real result so it keeps its schema and reports no rows.
- `ad-label` layer: collapses the conversation row that owns a sponsored badge,
  matched against a per-locale caption vocabulary.
- Both layers hook Android framework methods rather than Gmail's own classes, so
  a Gmail update does not break them.
- Collapsed rows are restored when RecyclerView rebinds them to organic mail.
- Built on the modern libxposed API 102; no legacy `de.robv.android.xposed` use.
