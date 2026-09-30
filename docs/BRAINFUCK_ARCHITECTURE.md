# Brainfuck policy architecture

GmailHideAds uses Brainfuck for its decision policy, while Android/Xposed
integration remains Java/native. Brainfuck decides; Java and C carry out the
decision.

The toolchain and conventions are taken from
[TwitterHideAds](https://github.com/MrxSiN/TwitterHideAds) `v3.0.0`, which took
them from [ThreadsHideAds](https://github.com/MrxSiN/ThreadsHideAds) `v2.0.0`
(`main` `358373d`): the source checker (`lint.py`), the optimizer and C emitter
(`ir.py`), the reference interpreter, the generator, the host compiler driver
and replay harness, the stateless stack-only runtime and the `.bf` house style
(`%cell` declarations, `@checkpoints`, `~N` run assertions, the equality-test
idiom). Each copied file names its origin; the changes are listed at the end.

```text
Gmail / Android
    |
libxposed hook (Application.attach guard, each ad row's onFinishInflate;
                ViewGroup.addView as the fallback)
    |
Java host: class names, per-class cache, deoptimization, row collapsing
    |
normalized primitive facts (one small code per character), one frame
    |
JNI: NativePolicy.nativeRun  (@FastNative, direct buffers, one call)
    |
AOT-compiled Brainfuck policy (libgmailbf.so)
    |
yes / no
    |
Java host performs the actual view operation
```

## Why Brainfuck, and where

The goal is a real, auditable policy layer. Gmail's policy is small, pure and
deterministic, which is exactly what a byte-in, byte-out Brainfuck program can
own; everything with side effects stays out.

| In Brainfuck | Program | Spec |
| --- | --- | --- |
| ad row rule: the ads package prefix `com.google.android.gm.ads.` and the `AdTeaserItemView` suffix | `row.bf` | [row](policy/row.md) |
| superclass rule: any class in the chain decides | `row.bf` | [row](policy/row.md) |
| package rule: only `com.google.android.gm` | `scope.bf` | [scope](policy/scope.md) |
| process rule: absent, empty or the main process | `scope.bf` | [scope](policy/scope.md) |

| Stays in Java or C | Why |
| --- | --- |
| hooks, `Application.attach` guard, deoptimization, hot reload | framework API calls |
| listing the ads package with DexKit, and caching the names it found | DexKit native calls and Gmail's preferences; `row.bf` still judges every class |
| walking `getSuperclass()`, `Class.getName()` | reflection; reduced to name codes before the call |
| text → name codes (one table lookup per char) | cheapest normalization |
| per-class verdict cache | Java state on the `addView` hot path |
| zeroing the row height, `GONE`, logging | view operations and I/O |
| reading the Gmail version for the log | `PackageManager` |

## ABI (version 1.0)

`brainfuck/constants.txt` is the single source of every number; the generator
exports it to `policy/BfAbi.java` and `cpp/generated/bf_abi.h`.

Frame (request and response):

| Offset | Size | Request | Response |
| --- | --- | --- | --- |
| 0 | 1 | ABI major (1) | ABI major |
| 1 | 1 | ABI minor (0) | ABI minor |
| 2 | 1 | opcode | opcode \| 0x80 |
| 3 | 1 | flags (0) | status: 0 ok, 1 bad version, 2 bad opcode |
| 4 | 2 | payload length LE (informative, mod 65536) | payload length LE |
| 6 | 2 | request id LE | request id echoed |

Programs parse the payload by opcode layout, so a short request simply reads
zeros. Opcodes: `row.bf` 0x10, `scope.bf` 0x20; layouts are in the policy
specs. Text is sent as chunks (`u8 k`, k codes, …, `u8 0`) in the name
alphabet.

The host validates every response: runtime status, length exactly
`8 + expected`, major version, opcode echo, status 0, request id, and the
verdict range (0 or 1). Anything else is a failure.

## Runtime and memory semantics

- Cells are unsigned 8-bit and wrap on `+`/`-` (identical on every ABI: the
  generated C uses `uint8_t`).
- Tape: fixed per program (`programs.json`: 32 cells each), zeroed before every
  request, allocated on the calling thread's C stack (`BF_TAPE_MAX` 256). The
  generator only accepts programs whose loops are balanced, so every cell
  address is a compile-time constant checked against the tape size; the
  pointer cannot leave the tape.
- `,` reads the next request byte and yields 0 at the end of the request (EOF
  = 0). Every loop in the programs terminates on a zero, so truncated or
  garbage input ends them.
- `.` appends to the response buffer (1024 bytes); overflow is an error.
- Request size limit 1 MiB (`RUNTIME_IN_CAP`); the host fails open above it.
- Execution budget: every `while` iteration of the generated C charges one
  tick; the budget is `65536 + 64 × request bytes`. Exhausting it returns
  `BF_ERR_LIMIT`. The program tests assert real requests use under a quarter of
  their budget.
- No allocation, no global mutable state, no locks in native code. The program
  table is immutable.

## Build pipeline (AOT)

```text
brainfuck/src/*.bf ── bfcc, the Brainfuck compiler written in Brainfuck (docs/BFCC.md):
       │  lint (comments free of commands, @checkpoints, ~N runs, tape bounds)
       │  parse → IR → optimize: runs, clear/transfer/multiply loops, run-once
       │  loops, value and copy propagation, equality tests → if / C switch
       ▼
app/src/main/cpp/generated/bf_programs.generated.c  (+ MEMORY_MAP.md; bf_abi.h and
       │                                              BfAbi.java copied from constants.txt)
       ▼
NDK clang -O2 -flto, -fvisibility=hidden, -fstack-protector-strong, _FORTIFY_SOURCE=2,
RELRO + BIND_NOW, non-executable stack, --gc-sections, --icf=all  ──►  libgmailbf.so
```

bfcc is built from the committed `tools/bfcc/bfcc.generated.c` (bfcc compiled
by itself) with the host C compiler, so generation needs no Python:
`./gradlew :app:generateBrainfuck` or `tools/bfcc/build.sh && build/bfcc/bfcc
gen`. `bfcc gen --check` (Gradle `checkBrainfuck`, part of `check`, run by CI
and before every host test build) fails when the files are stale. The Python
toolchain (`tools/bftool`) stays as the reference the tests compare against:
bfcc's output is byte-identical to it. Generated files are committed, so
`./gradlew :app:assembleRelease` needs neither. Generation is deterministic
(byte-identical output, LF line endings enforced by `.gitattributes`). The
library exports only the two JNI entry points.

Program sizes: row 18 748 BF commands (237 IR ops), scope 18 192 (242 IR ops);
the arm64 library is 10 KB. Every state machine compiles to one C `switch`.

## Threading

`nativeRun` keeps all state on the caller's stack. Java encodes into a
per-thread `PolicyFrame` (heap byte array staged into a direct buffer, and a
direct response buffer). Encoding reads only class names and strings and never
calls back into Gmail, so a frame is never re-entered. Concurrency is tested
with 8 threads × 5 000 requests against the legacy results.

## Failure behaviour (fail open)

| Failure | Result |
| --- | --- |
| library missing or ABI mismatch | `fail-open mode active` is logged; `OP_SCOPE` answers no, so nothing is installed |
| request over 1 MiB, more than 255 classes in a chain | request not sent; the view is kept |
| native error, budget exhausted, bad version/opcode, malformed response | request fails; the view is kept |
| a failed `OP_AD_ROW` | not cached, so the next view of that class asks again |

Failures are counted and logged at counts 1, 2, 3, 4, 8, 16, …

## Performance

Measured with `PolicyBenchmarkTest`, 20 000 warm-up and 20 000 timed calls
each, frozen v1.0.0 Java policy against Brainfuck through JNI.

Pixel 8 Pro, Android 17, release build, non-debuggable instrumentation process
(`-PbenchmarkRelease`):

| Case | Legacy p50 / p95 / p99 | Brainfuck p50 / p95 / p99 |
| --- | --- | --- |
| ordinary class, 3 names (`ConcurrentHashMap` chain) | 0.20 / 0.20 / 0.24 µs | 0.90 / 1.14 / 1.18 µs |
| derived ad row, 4 names | 0.24 / 0.29 / 0.29 µs | 1.34 / 1.42 / 1.43 µs |
| scope | 0.41 / 0.41 / 0.45 µs | 0.81 / 0.90 / 0.94 µs |
| cached verdict (every `addView`) | 0.12 / 0.12 / 0.12 µs | same |

Unlike TwitterHideAds, the Java this replaces was already two string
comparisons, so a Brainfuck request costs about 1 µs more than the old check.
That cost is paid once per view class: the detector caches the verdict, and
every `addView` after the first only reads the cache, which is unchanged. The
scope request runs once per package load.

Host JVM (Windows x86-64, MSVC `/O2` host build; indicative only): ordinary
class 0.6 µs vs 0.1 µs legacy, scope 0.5 µs vs 0.05 µs.

## Parity and testing

`app/src/test/java/my/MrxSiN/gmailhideads/legacy/` is the frozen v1.0.0 Java
policy (`AdTeaserViewDetector` and `GmailProfile` at `2f978ff`). Totals of the
current suite:

| Suite | Cases |
| --- | --- |
| `PolicyParityTest` (old Java result = new Brainfuck result) | 634 229 comparisons, on the JVM and on the Pixel 8 Pro |
| of which: every BMP char in six class-name contexts and three scope contexts | 589 824 |
| `tests/compiler` (Python: reference interpreter vs IR vs AOT C, known vectors, random names, scope, malformed frames, truncations, budget) | about 46 000 requests, 13 tests |
| `tests/compiler/test_bfcc.py` (bfcc vs the Python compiler: policies, `gen`, lint diagnostics, 3 000+ random programs, switches, errors; bfcc's C vs the reference interpreter) | 13 tests |
| `tools/bfcc/selfhost.py` (CI): Python → stage 0 → stage 1 → stage 2 fixed point == committed seed | byte-identical |
| `PolicyRobustnessTest`: random bytes to both programs, truncations, determinism | 20 000 + every prefix + 2 000 |
| concurrency: 8 threads × 5 000 requests | 40 000 |

Parity covers real classes and their superclass chains (the six Gmail row
names, a renamed subclass, a nested class, the shortest accepted name,
look-alikes in and out of the ads package, JDK, array, primitive, anonymous
and lambda classes), randomized and mutated names, names from 0 to 1 100
characters around the 255-code chunk border, a row at every position of chains
up to 255 classes, and the scope table. The whole JVM suite also runs on
devices: `./gradlew :app:connectedDebugAndroidTest` (16 tests pass on arm64).

`-PparityCases=N` scales the randomized counts (CI uses 40 000).

## Supported ABIs

| ABI | Built | Tested |
| --- | --- | --- |
| arm64-v8a | yes | full suite on Pixel 8 Pro (Android 17) |
| x86-64 host (JVM tests, MSVC or cc) | test build | full suite, CI (Linux) and Windows |
| armeabi-v7a, x86, x86_64 | yes | experimental: same generated C, not run on a device |

## Observability

Every collapsed row is logged with the policy counters (`bfCalls`,
`bfFailures`, `malformed`). Debug builds, or release builds made with
`-PpolicyTiming`, add average and maximum request time.

## Changing a policy safely

1. Edit the normative spec in `docs/policy/` first.
2. Edit the `.bf` source. Keep the house idioms: named cells with `%cell`,
   a `@CELL` checkpoint after moves, `~N` after long runs, the equality test
   `copy s→f via t; f -= v; e = 1; f[ e[-] … f[-] ] e[ … e[-] ]` with `f` below
   `t`, and every scratch cell back at zero. `bfcc gen` checks pointer
   positions statically before it compiles anything.
3. New numbers go into `brainfuck/constants.txt` (append only; a layout change
   bumps `ABI_MAJOR`).
4. `./gradlew :app:generateBrainfuck` (or `build/bfcc/bfcc gen`), then
   `python -m unittest discover -s tests/compiler` and `./gradlew
   testDebugUnitTest`.
5. A deliberate behaviour change must update the parity test to state the new
   rule; the legacy oracle itself is never edited.

## Changes from the TwitterHideAds toolchain

- `gen.py`: output paths, `BfAbi` in the `policy` package. Since bfcc it is
  the reference implementation; the generated files name bfcc.
- bfcc (`brainfuck/compiler`, `tools/bfcc`): the compiler of `ir.py`, `lint.py`
  and the memory map of `gen.py`, rewritten in Brainfuck and self-hosting.
- Runtime and JNI glue: renamed to `libgmailbf` and
  `my.MrxSiN.gmailhideads.policy.NativePolicy`; otherwise unchanged.
- `PolicyFrame`: one name alphabet, no reference table and no re-entry frame,
  because encoding never calls back into the host.
