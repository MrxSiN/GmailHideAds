# Gmail Hide Ads v1.0.0

First release.

Removes sponsored rows from the Gmail for Android conversation list, using two
independent layers that hook Android framework methods rather than Gmail's own
minified classes.

- **ad-query** empties the cursors Gmail loads advertisement rows from.
- **ad-label** collapses the conversation row that owns a sponsored badge.

Requires an Xposed framework implementing libxposed API 101 or newer, such as
Vector. Enable the module, add Gmail to its scope, then force-stop and reopen
Gmail.
