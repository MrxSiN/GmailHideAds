"""Compiler-generation benchmark: bfcc (native, the Brainfuck compiler)
against the Python compiler, on the policy programs and on bfcc itself.
Policy execution is unaffected: both produce the same C.

    python tools/bfcc/bench.py [BFCC_EXE] [--runs N]

BFCC_EXE defaults to build/bfcc/bfcc(.exe) (tools/bfcc/build.sh or Gradle
buildBfcc). Times are medians of N runs; "process" includes start-up.
"""

import argparse
import os
import statistics
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

from bftool import gen, ir, ref  # noqa: E402

ROOT = gen.ROOT


def median_time(fn, runs):
    times = []
    for _ in range(runs):
        t = time.perf_counter()
        fn()
        times.append(time.perf_counter() - t)
    return statistics.median(times)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("exe", nargs="?",
                    default=os.path.join(ROOT, "build", "bfcc", "bfcc.exe" if os.name == "nt" else "bfcc"))
    ap.add_argument("--runs", type=int, default=9)
    args = ap.parse_args(argv)
    exe, runs = os.path.abspath(args.exe), args.runs
    run = lambda *a: subprocess.run(list(a), check=True, capture_output=True, cwd=ROOT)  # noqa: E731

    rows = []
    rows.append(("policies: generate + check, process", median_time(
        lambda: run(sys.executable, "tools/bftool/gen.py", "--check"), runs),
        median_time(lambda: run(exe, "gen", "--check"), runs)))

    def python_policies():
        for p in gen.load_manifest()["programs"]:
            code, _, _ = gen.load_program(os.path.join(ROOT, "brainfuck", p["source"]), p)
            ir.emit_c(ir.compile_bf(code, zero_from=0), p["name"], p["tape"])

    def bfcc_inside():
        env = dict(os.environ, BFCC_STATS="1")
        r = subprocess.run([exe, "gen", "--check"], capture_output=True, cwd=ROOT, env=env)
        line = [l for l in r.stderr.decode().splitlines() if "loop iterations" in l][0]
        return float(line.split(",")[1].split()[0])

    inside = statistics.median(bfcc_inside() for _ in range(runs))
    rows.append(("policies: lint + compile, in process", median_time(python_policies, runs), inside))

    src = os.path.join(ROOT, "brainfuck", "compiler", "bfcc.bf")
    out = os.path.join(ROOT, "build", "bfcc", "bench.c")
    with open(src, encoding="utf-8") as f:
        text = f.read()

    def python_self():
        ir.emit_c(ir.compile_bf(ref.strip(text), zero_from=0), "bfcc", 65536)

    self_runs = max(1, runs // 3)
    rows.append(("bfcc.bf (%.1f MB): compile" % (len(text) / 1e6), median_time(python_self, self_runs),
                 median_time(lambda: run(exe, "compile", src, "bfcc", "65536", "--static", "-o", out),
                             self_runs)))

    print("%-44s %10s %10s %8s" % ("", "Python", "bfcc", "speed-up"))
    for name, py, bf in rows:
        print("%-44s %9.3fs %9.3fs %7.1fx" % (name, py, bf, py / bf))
    return 0


if __name__ == "__main__":
    sys.exit(main())
