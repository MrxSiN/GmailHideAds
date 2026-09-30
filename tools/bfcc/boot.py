"""Bootstrap helpers: compile a Brainfuck program with the Python reference
compiler (tools/bftool/ir.py) and build C for the bfcc device (bfcc_host.c)
into a host executable.

    python tools/bfcc/boot.py BF_FILE NAME OUT_EXE [--c OUT_C]

Used by the self-hosting chain (selfhost.py) and to try BFL programs. The
normal path builds bfcc from the committed tools/bfcc/bfcc.generated.c and
needs no Python.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

from bftool import hostcc, ir, ref  # noqa: E402


def python_compile(code, name, tape=None):
    """(C text, tape) of a static Brainfuck program, compiled exactly as
    tools/bftool/gen.py compiles the policy programs. The tape defaults to
    the highest cell used plus one."""
    code = ref.strip(code)
    ops = ir.compile_bf(code, zero_from=0)
    if not ir.is_static(ops):
        raise SystemExit("%s: every loop must be balanced" % name)
    if tape is None:
        tape = ir.offset_range(ops)[1] + 1
    return ir.emit_c(ops, name, tape), tape


def build(c_path, name, tape, exe, profile=False):
    """Builds the device host around the program C at c_path. With profile
    (the tape addresses of the program counter cells, from bflc --map), the
    host counts loop iterations and device bytes per dispatch state
    (written to bfcc.profile)."""
    # One translation unit names the program, so no quoting reaches the
    # compiler's command line.
    unit = os.path.splitext(os.path.abspath(exe))[0] + ".unit.c"
    with open(unit, "w", encoding="utf-8", newline="\n") as f:
        if profile:
            f.write("#define BFCC_PC0 %d\n#define BFCC_PC1 %d\n" % profile)
            f.write("#define BFCC_PROFILE 1\n")
        f.write('#define BFCC_PROGRAM "%s"\n#define BFCC_ENTRY bf_prog_%s\n#define BFCC_TAPE %d\n'
                '#include "bfcc_host.c"\n' % (os.path.abspath(c_path).replace("\\", "/"), name, tape))
    return hostcc.build([unit, os.path.join(HERE, "bfcc_main.c")], exe, include_dirs=[HERE])


def main(argv):
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("bf")
    ap.add_argument("name")
    ap.add_argument("exe")
    ap.add_argument("--c")
    ap.add_argument("--profile", action="store_true")
    args = ap.parse_args(argv)
    with open(args.bf, encoding="utf-8") as f:
        code = f.read()
    text, tape = python_compile(code, args.name)
    c_path = args.c or os.path.splitext(args.exe)[0] + ".c"
    with open(c_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    build(c_path, args.name, tape, args.exe, args.profile)
    print("built %s (tape %d)" % (args.exe, tape))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
