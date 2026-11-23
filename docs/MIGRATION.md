# Migration to Brainfuck + XAX only

Goal: the repository holds only Brainfuck, XAX stores and declarative files
(fixtures, metadata, docs). Toolchains are pinned in `TOOLCHAIN_PIN.json`.

| Step | State |
| --- | --- |
| 1. Policy programs built by BBC, checked by binary fixtures (`tests/policy`) | done |
| 2. libxposed module as an XAX store (`android-libxposed`, JVM general target): scope check, `Application.attach` guard, `onFinishInflate` hook, hot reload | blocked upstream |
| 3. Ad-row class discovery in XAX (replaces DexKit) | after 2 |
| 4. Delete bfcc, `tools/`, the C engine, the Java sources, Gradle and the Python tests; amend `AGENTS.md` | after 3 |

## Blockers (checked 2026-11-23 against XAX release 0040, BBC `12f0d64`)

- **Calling the policy from the module.** The module's code runs on XAX's JVM
  general target, which has no heap views, so a BBC program cannot run there
  as imported. The supported way is a native library the module ships with
  `static native` declarations, which needs a BBC/XAX shared object with a
  JNI export taking `byte[]` in and out:
  [MrxSiN/XAX#51](https://github.com/MrxSiN/XAX/issues/51) (with #47).
- **Creating the module store natively.** `xaxc edit` cannot create an
  `android-libxposed` store or replace its module carrier; only the Python
  `xax_construct` can: [MrxSiN/XAX#135](https://github.com/MrxSiN/XAX/issues/135)
  (design ADR-416).

Already available upstream: Hooker callbacks with `Chain.proceed()` and
`getArgs()` (MrxSiN/XAX#50), lifecycle entries (`onModuleLoaded`, ADR-411),
bounded hot reload, and native libraries plus `static native` declarations in
the module carrier.

Until step 4 the existing Gradle build, C engine and Java glue stay and keep
shipping; nothing new is added in those languages.
