"""The self-hosting chain of bfcc, the Brainfuck compiler written in
Brainfuck (brainfuck/compiler/bfcc.bf):

  0. bfcc.bf is current with its sources (brainfuck/compiler/*.bfl)
  1. stage 0: the Python compiler (tools/bftool/ir.py) compiles bfcc.bf
  2. stage 1: stage 0's C, built with the host C compiler
  3. stage 1 compiles bfcc.bf; the result must equal stage 0's C
  4. stage 2: stage 1's C, built; stage 2 compiles bfcc.bf again and the
     result must equal stage 1's (the fixed point)
  5. the fixed point must equal the committed tools/bfcc/bfcc.generated.c
  6. stage 2 regenerates the policy programs: they must equal the
     committed app/src/main/cpp/generated files

    python tools/bfcc/selfhost.py [--write] [--build DIR]

--write updates bfcc.bf and bfcc.generated.c instead of failing on them.
"""

import argparse
import filecmp
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)

import bflc  # noqa: E402
import boot  # noqa: E402

ROOT = bflc.ROOT
SEED = os.path.join(HERE, "bfcc.generated.c")
TAPE = 65536    # bfcc's own tape bound (every static program below it compiles alike)


def step(msg):
    print("selfhost: " + msg, flush=True)


def fail(msg):
    print("selfhost: FAILED: " + msg, file=sys.stderr)
    sys.exit(1)


def compile_with(exe, src, out):
    t = time.time()
    r = subprocess.run([exe, "compile", src, "bfcc", str(TAPE), "--static", "-o", out])
    if r.returncode != 0:
        fail("%s could not compile %s" % (exe, src))
    return time.time() - t


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--build", default=os.path.join(ROOT, "build", "bfcc"))
    args = ap.parse_args(argv)
    os.makedirs(args.build, exist_ok=True)
    exe = ".exe" if os.name == "nt" else ""
    b = lambda name: os.path.join(args.build, name)  # noqa: E731

    text, prog = bflc.build_compiler()
    if args.write:
        with open(bflc.OUTPUT, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    with open(bflc.OUTPUT, encoding="utf-8", newline="") as f:
        if f.read() != text:
            fail("brainfuck/compiler/bfcc.bf is stale; run python tools/bfcc/bflc.py")
    step("bfcc.bf: %d commands, %d cells, %d states" % (
        sum(text.count(c) for c in "+-<>[].,"), prog.tape_cells, len(prog.states)))

    t = time.time()
    c0, _ = boot.python_compile(text, "bfcc", tape=TAPE)
    with open(b("stage0.c"), "w", encoding="utf-8", newline="\n") as f:
        f.write(c0)
    step("stage 0: Python compiler, %.1f s" % (time.time() - t))

    t = time.time()
    boot.build(b("stage0.c"), "bfcc", TAPE, b("stage1" + exe))
    step("stage 1 built, %.1f s" % (time.time() - t))
    step("stage 1 compiles bfcc.bf: %.2f s" % compile_with(b("stage1" + exe), bflc.OUTPUT, b("stage1.c")))
    if not filecmp.cmp(b("stage0.c"), b("stage1.c"), shallow=False):
        fail("stage 1 output differs from stage 0 (the Python compiler)")
    step("stage 1 output == stage 0 output")

    boot.build(b("stage1.c"), "bfcc", TAPE, b("stage2" + exe))
    step("stage 2 compiles bfcc.bf: %.2f s" % compile_with(b("stage2" + exe), bflc.OUTPUT, b("stage2.c")))
    if not filecmp.cmp(b("stage1.c"), b("stage2.c"), shallow=False):
        fail("stage 2 output differs from stage 1: no fixed point")
    step("stage 2 output == stage 1 output (fixed point)")

    if args.write:
        shutil.copyfile(b("stage2.c"), SEED)
    if not filecmp.cmp(b("stage2.c"), SEED, shallow=False):
        fail("tools/bfcc/bfcc.generated.c is not the fixed point; run selfhost.py --write")
    step("fixed point == tools/bfcc/bfcc.generated.c")

    r = subprocess.run([b("stage2" + exe), "gen", "--check", "--root", ROOT])
    if r.returncode != 0:
        fail("stage 2 does not reproduce the committed generated files")
    step("stage 2 reproduces the policy programs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
