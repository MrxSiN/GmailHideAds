# Policy fixtures

Exact binary request/response pairs for `brainfuck/src/row.bf` and `scope.bf`
(ABI in `brainfuck/constants.txt`). The expected `.response` bytes were
produced by the frozen v1.0.0 rules (`LegacyAdTeaserViewDetector`,
`LegacyGmailProfile`) and each was checked against the BBC-built program; the
two `*-bad-*` pairs capture the programs' own status replies.

Run from `cmd` with the pinned BBC (`TOOLCHAIN_PIN.json`); every line must pass:

```text
bbc compile windows-x86_64 row.exe < brainfuck\src\row.bf
bbc compile windows-x86_64 scope.exe < brainfuck\src\scope.bf
for %f in (tests\policy\row-*.request) do @(row.exe < %f > out.bin & fc /b out.bin %~dpnf.response >nul || echo FAIL %f)
for %f in (tests\policy\scope-*.request) do @(scope.exe < %f > out.bin & fc /b out.bin %~dpnf.response >nul || echo FAIL %f)
```

A fixture-driven XAX runner replaces these commands with the XAX module
(migration to Brainfuck + XAX only, see AGENTS.md).
