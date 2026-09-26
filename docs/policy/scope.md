# scope.bf — the package and process the module belongs in

Normative specification of `brainfuck/src/scope.bf` (program id 1), asked by
`GmailHideAdsModule.onPackageReady` before anything is installed.

## OP_SCOPE (0x20)

Request payload:

```text
u8 packagePresent   0 when the package name is null
chunks of name-alphabet codes of the package name ("" when null), 0 ends
u8 processPresent   0 when the process name is null
chunks of name-alphabet codes of the process name ("" when null), 0 ends
```

The name alphabet is the one of [row](row.md).

Response payload (1 byte): 1 when the module belongs here, else 0.

Rule:

1. The package must be present and equal to `com.google.android.gm`.
2. The process may be absent, empty or equal to `com.google.android.gm`.
   Gmail runs several processes and binds ads only in the main one. An empty
   process name means the framework did not report one; the module then stays
   active rather than disabling itself.

Implementation: one machine `E` per name. In state *k* < 21 the next code must
be the *k*-th character of `com.google.android.gm`, else `E` becomes 22; state
21 also moves to 22 on any further character. At the end a name equals the
package name when `E == 21` and is empty when `E == 0`.

A failed request answers no, so a module whose library did not load installs
nothing.
