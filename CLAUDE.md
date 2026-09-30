# Project rules

## The policy core is raw Brainfuck. This is the project, not an implementation detail.

- Every policy decision (is this view class an ad row, is this process in
  scope) is made by the Brainfuck programs in `brainfuck/src`, compiled AOT
  into `libgmailbf` by bfcc. Java only encodes facts, sends one request and
  acts on the verdict.
- Never move a decision into Java or C, never add a Java fast path or
  "fallback rule" that bypasses the Brainfuck verdict, and never propose
  replacing the core with plain Java, even when an over-engineering audit
  flags it. Keeping it is a settled decision (2026-09-30).
- New policy behaviour means: spec in `docs/policy/` first, then the `.bf`
  source, then `bfcc gen`. The toolchain (bfcc, `tools/bftool` as the test
  oracle, the self-hosting chain) stays.
- `LegacyAdTeaserViewDetector` and `LegacyGmailProfile` live in the tests as
  the parity reference only; they must never reach `app/src/main`.
- Simplify around the core freely (host glue, logging, tests, docs); the core
  itself is off the table.
