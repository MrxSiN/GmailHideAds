# bfcc: the Brainfuck compiler, in Brainfuck

bfcc turns the policy programs in `brainfuck/src` into the C that ships in
`libgmailbf`. It is itself a Brainfuck program
([`brainfuck/compiler/bfcc.bf`](../brainfuck/compiler/bfcc.bf)), it compiles
itself, and its output is byte-identical to the Python compiler it replaced
(`tools/bftool`), which stays in the repository as the reference the tests
compare against.

```text
tools/bftool (Python) ──compile bfcc.bf──► stage 0 C ──cc──► stage 1
stage 1 ──compile bfcc.bf──► stage 1 C (== stage 0 C) ──cc──► stage 2
stage 2 ──compile bfcc.bf──► stage 2 C (== stage 1 C: fixed point)
                              == tools/bfcc/bfcc.generated.c (committed)
stage 2 ──gen──► the committed policy C, memory map (unchanged)
```

## Files

| Path | What |
| --- | --- |
| `brainfuck/compiler/*.bfl` | the compiler's source: `lib` (numbers), `ir` (records, parser, loop optimizer, peephole), `prop` (value propagation, equality tests), `lint` (house-style checks), `emit` (C, memory map, job driver) |
| `brainfuck/compiler/bfcc.bf` | the compiler as Brainfuck, generated from the `.bfl` files |
| `tools/bfcc/bfcc.generated.c` | bfcc compiled by itself (the fixed point); what the normal build compiles |
| `tools/bfcc/bfcc_host.c`, `bfcc_main.c` | the host: files, command line, output streams, paged memory |
| `tools/bfcc/build.sh`, Gradle `buildBfcc` | build bfcc with the host C compiler (no Python) |
| `tools/bfcc/bflc.py` | authoring tool: `.bfl` → `bfcc.bf` |
| `tools/bfcc/selfhost.py` | the bootstrap chain above (CI) |
| `tools/bfcc/boot.py` | bootstrap helpers |
| `tests/compiler/test_bfcc.py` | bfcc against the Python compiler and the reference interpreter |

## Using it

```bash
tools/bfcc/build.sh                      # or ./gradlew :app:buildBfcc
build/bfcc/bfcc gen                      # regenerate (Gradle: generateBrainfuck)
build/bfcc/bfcc gen --check              # fail when stale (Gradle: checkBrainfuck, CI)
build/bfcc/bfcc compile X.bf NAME TAPE [--no-propagate] [--static] [-o X.c]
```

`gen` reads `brainfuck/programs.json` and the sources, lints them, compiles
them and writes `bf_programs.generated.c` and `MEMORY_MAP.md` exactly as
`tools/bftool/gen.py` did. It also copies `brainfuck/constants.txt` into
`bf_abi.h` and `BfAbi.java`; that is the one generated artifact the host
writes itself, because it involves no Brainfuck. `BFCC_STATS=1` prints loop
iterations, device traffic and run time.

After editing a `.bfl` file: `python tools/bfcc/bflc.py` regenerates
`bfcc.bf`, and `python tools/bfcc/selfhost.py --write` runs the chain and
commits the new fixed point to `bfcc.generated.c`.

## How it is written

Nobody writes a 5.8 MB program in raw Brainfuck. The compiler is written in
BFL, a small statically typed language in Python syntax, and `bflc`
translates it to Brainfuck the way an assembler translates mnemonics: every
decision of the compiler (what a character means, which loop is a transfer
loop, whether a value is known, which C to print) is Brainfuck code that
bflc generated from a BFL statement saying so. bflc is an authoring tool
like `lint.py` was; it runs when the compiler's source changes, never when
the compiler runs. The self-hosting chain starts from `bfcc.bf`, not from
BFL.

BFL has `u8` cells, fixed-size arrays and records of cells, constants,
`if`/`while`/`match`/`for`-over-constants, functions (recursion included) and
inline functions. There are no pointers into the tape: every variable has a
fixed cell.

### Program shape

`bfcc.bf` is one dispatch loop over 707 states, on a 1 200-cell tape:

```text
RUN = 1; NPC = main
while RUN:  PC = NPC; switch (PC) { case state: straight-line code; NPC = next }
```

Straight-line code, `if`s and loops without calls stay inside a state as
ordinary Brainfuck (loops compile to C `while`s); a call, a loop containing
one, `break` and `return` end a state. A call stores its arguments in the
device and its return state in the callee's cells; a recursive call first
stores the caller's frame on a memory stack. Every equality test is the same
idiom the policy sources use (`copy s→f via t; f -= v; e = 1; f[e[-] … f[-]]
e[… e[-]]`), so the dispatch and every `match` become C `switch`es when bfcc
compiles itself.

Cells come in three kinds, by address: every sixteenth cell is a copy
temporary; four in sixteen are zero between states (flags of the equality
tests, expression temporaries, the I/O cell); the rest hold values.
Functions' value cells are laid out like a static call stack (a function sits
above everything that can call it, so functions never active together share
cells), which keeps pointer travel, and so the size of `bfcc.bf`, down.

### The device

Brainfuck only has `,` and `.`. The host answers commands written with `.`
and read back with `,`; it moves bytes and never interprets them:

| Command | Effect |
| --- | --- |
| `GETC` | next job byte (or next byte from memory after `SOURCE`), 0 at the end |
| `PUTC b`, `PUTS … 0`, `SELECT k` | output to stream k (0: C file, 1: memory map) |
| `LOAD a n`, `STORE a n …` | up to 255 bytes of 32-bit paged memory (zero until written, 2 GiB limit) |
| `COPY s e d`, `DIFF s e o` | memmove; first address where two ranges differ |
| `SLURP a`, `SOURCE a`, `JOB` | job text to memory; read memory instead of the job; read the job again |
| `ARGW`/`ARGR`, `RETW`/`RETR` | a call's arguments and result |
| `DIAG b`, `EXIT code` | diagnostics; the result |

## The compiler

The algorithm is `tools/bftool/ir.py`'s, operation for operation, so the
output is the same C byte for byte (`MODE_ONE` prints one function,
`MODE_GEN` a whole generated file).

**Numbers.** Offsets are 8 decimal digits in ten's complement (±5·10⁷): the
compiler prints offsets far more often than it adds them, and ±1 is a carry
chain of equality tests. Addresses are 32-bit. An IR op is a 64-byte record:
kind, value, base, offset `a`, destination `b`, and the bounds of up to two
bodies.

| Memory (top address byte) | Holds |
| --- | --- |
| `01`–`1F` | arena: finished lists |
| `20`–`25` | lint: source, extracted commands, cell table and its hash chains, open loops |
| `30` | work area: lists being built, nested bodies above their parents |
| `38`, `39`, `3A`, `3B` | parser frames, transfer-loop scratch, program table, `switch` value sets |
| `3E` | recursion stack |
| `40`–`FF` | known-value states, two maps each |

**Parsing and loop optimization** (`ir.bfl`) are one streaming pass. A
scanner folds runs of `+`/`-` and pointer moves without leaving its loop.
Offsets inside a loop body are counted in the enclosing coordinates, so a
balanced loop needs no `_shift`; a body that turns out unbalanced is rebased.
When `]` is read, the body is classified exactly like `_optimize_loop`:
clear loop, transfer/multiply loop (one multiply-add per destination in
offset order), run-once loop (`if`), `while`, or `uloop`, and the result
joins its parent through `_peephole`'s rules (folding a run before the
peephole sees it gives the same list, since its merges are associative).

**Value propagation** (`prop.bfl`) is `_propagate`: copies, equality tests
(the `_match_copy`/`_match_ifeq` patterns, with `_touches`), add/set/multiply
folding, `if`s with known conditions, loops to a fixpoint (at most 8 rounds,
then the written cells are forgotten), and the final peephole. A known-value
state is two byte maps over the program's offset range (values, and
"unknown" flags); an unknown cell is always value 0, flag 1, so two states are
equal exactly when their bytes are. The map address of an offset is built
from its digits (no arithmetic), a copy is one `COPY`, a comparison one
`DIFF`, and a merge visits only the cells where `DIFF` finds a difference.

**Emission** (`emit.bfl`) is `emit_c`, `_emit_block` and `_switch_run`:
runs of three or more equality tests on one cell with distinct values, no
else and bodies that leave the cell alone become a `switch`; the tape-bound
check and static-program requirement are the same, with the same messages.

**Lint** (`lint.bfl`) is `lint.py`: the same rules, every error, the same
wording, in the same order. It reads the source twice from memory,
declarations first, and hands the commands to the parser.

## Verification

- `tests/compiler/test_bfcc.py`: the policies and `gen` output against the
  Python toolchain; 3 000+ random programs (runs up to 300, nested and moving
  loops, clear/transfer/multiply loops, copies, equality tests and switch
  runs, known values, pointer moves, I/O); malformed brackets, tape
  violations, unbalanced programs, oversized sources and 20 lint cases with
  their exact diagnostics; determinism; and bfcc's C for random programs run
  through the shipped engine against the reference interpreter (8-bit
  wrapping, EOF reads 0, tape faults, budget, output cap).
- `tools/bfcc/selfhost.py` (CI): the chain at the top of this page.
- CI builds bfcc from the committed seed with `cc` and runs `gen --check`
  with no Python involved, then runs the chain and the tests.
- The policy C is unchanged apart from the comment naming its generator, so
  the policy's run time and all its tests are unchanged.

## Performance

Median of 9 runs, Windows x86-64, MSVC `/O2`, measured when bfcc landed:

| | Python | bfcc | |
| --- | --- | --- | --- |
| policies: generate and check, whole process | 0.143 s | 0.077 s | 1.8× |
| policies: lint and compile, inside the process | 0.061 s | 0.059 s | 1.0× |
| compile `bfcc.bf` (5.8 MB of Brainfuck) | 13.9 s | 2.57 s | 5.4× |

The policies are small, so start-up decides: bfcc starts like any small
native program, Python does not. Inside the process the two are even on the
policies. bfcc's time goes mostly to device traffic (every record it reads
crosses `,` one byte at a time) and to the equality-test search, whose cost
is the same algorithm as Python's.

## Limits

- Sources up to 8 MiB, without NUL bytes; up to 255 programs; names and
  paths up to 100 bytes, cell names up to 47.
- `compile` tapes up to 499 999 cells; value propagation needs offsets
  within ±499 999 (larger ones can only occur in programs the tape check
  rejects).
- Value propagation holds two known-value states per enclosing loop and one
  per enclosing test: about 45 nested loops exhaust its 95 states, and such a
  program is rejected.
- Lint follows `str.splitlines`/`str.isspace` on ASCII; exotic Unicode line
  breaks and spaces count as ordinary characters.
