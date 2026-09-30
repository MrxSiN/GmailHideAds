"""bfcc, the Brainfuck compiler written in Brainfuck, against the Python
compiler (tools/bftool/ir.py, the oracle) and the reference interpreter.

bfcc is built from the committed tools/bfcc/bfcc.generated.c. Its C must be
byte-identical to ir.emit_c(ir.compile_bf(...)) for every program; the
runtime tests also execute that C through the shipped engine and compare it
with the reference interpreter. The self-hosting chain itself is
tools/bfcc/selfhost.py (CI).
"""

import os
import random
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))

from bftool import gen, hostcc, ir, lint, ref, replay  # noqa: E402

ROOT = gen.ROOT
BFCC = os.path.join(ROOT, "tools", "bfcc")
CPP = os.path.join(ROOT, "app", "src", "main", "cpp")
MODE_ONE, MODE_MANY, MODE_GEN = 1, 2, 3
PROPAGATE, STATIC = 1, 2


# ---------------------------------------------------------------- programs

def random_program(rng, depth=0):
    """Legal but otherwise arbitrary code: runs, moves, I/O, loops that may
    move the pointer, comments."""
    parts = []
    for _ in range(rng.randint(1, 8)):
        r = rng.random()
        if r < 0.3:
            parts.append(rng.choice("+-") * rng.randint(1, 300 if rng.random() < 0.05 else 4))
        elif r < 0.5:
            k = rng.randint(1, 3)
            parts.append(">" * k + rng.choice("+-") * rng.randint(1, 3) + "<" * k)
        elif r < 0.55:
            parts.append(rng.choice(["<", ">", ">>", "<<<", ">" * 40, "<" * 40]))
        elif r < 0.6:
            parts.append(",")
        elif r < 0.65:
            parts.append(".")
        elif r < 0.72:
            parts.append(rng.choice(["[-]", "[+]", "[->+<]", "[->>+++<<]", "[-<+>>-<]", "[>]", "[<]",
                                     "[[-]>]", "[->+>+<<]>>[-<<+>>]<<"]))
        elif r < 0.75:
            parts.append(" comment\n")
        elif depth < 3:
            body = random_program(rng, depth + 1)
            parts.append(rng.choice(["[->", "[", "[-"]) + body + rng.choice(["<]", "]", "[-]]"]))
    return "".join(parts)


def at(c, code):
    return ">" * c + code + "<" * c


def copy_ifeq(s, f, e, t, n, then, other):
    """The equality idiom of the policy sources (and of bfcc itself)."""
    code = at(s, "[-" + "<" * s + at(f, "+") + at(t, "+") + ">" * s + "]")
    code += at(t, "[-" + "<" * t + at(s, "+") + ">" * t + "]")
    code += at(f, "+" * n) + at(e, "+")
    code += at(f, "[" + "<" * f + at(e, "[-]") + other + at(f, "[-]") + ">" * f + "]")
    code += at(e, "[" + "<" * e + then + at(e, "[-]") + ">" * e + "]")
    return code


def static_program(rng, depth=0):
    """Balanced code with equality tests (switch candidates), copies, clear
    and multiply loops and constants for value propagation."""
    parts = []
    for _ in range(rng.randint(1, 6)):
        r = rng.random()
        if r < 0.25:
            parts.append(at(rng.randint(0, 7), rng.choice("+-") * rng.randint(1, 5)))
        elif r < 0.32:
            parts.append(at(rng.randint(0, 7), ","))
        elif r < 0.4:
            parts.append(at(rng.randint(0, 7), "."))
        elif r < 0.48:
            parts.append(at(rng.randint(0, 3), "[-]") + at(rng.randint(4, 7), "[-" + "<" * 3 + "+" * 3 + ">" * 3 + "]"))
        elif r < 0.62 and depth < 3:
            # A run of tests on one cell: a C switch when it has three or more.
            s = rng.randint(0, 3)
            values = rng.sample(range(256), rng.randint(1, 5))
            for v in values:
                parts.append(copy_ifeq(s, 8 + depth * 3, 9 + depth * 3, 10 + depth * 3, (-v) & 255,
                                       static_program(rng, depth + 1), ""))
        elif r < 0.8 and depth < 3:
            then = static_program(rng, depth + 1)
            other = static_program(rng, depth + 1) if rng.random() < 0.5 else ""
            parts.append(copy_ifeq(rng.randint(0, 3), 8 + depth * 3, 9 + depth * 3, 10 + depth * 3,
                                   rng.randint(0, 255), then, other))
        elif depth < 3:
            c = rng.randint(0, 3)
            parts.append(at(c, "[-" + "<" * c + static_program(rng, depth + 1) + ">" * c + "]"))
    return "".join(parts)


def terminating_program(rng, depth=0):
    """Code whose every loop decrements its own cell (test_ir's generator)."""
    parts = []
    for _ in range(rng.randint(1, 8)):
        r = rng.random()
        if r < 0.35:
            parts.append(rng.choice("+-") * rng.randint(1, 4))
        elif r < 0.55:
            k = rng.randint(1, 3)
            parts.append(">" * k + rng.choice("+-") * rng.randint(1, 3) + "<" * k)
        elif r < 0.62:
            parts.append(",")
        elif r < 0.7:
            parts.append(".")
        elif depth < 3:
            parts.append("[->" + terminating_program(rng, depth + 1) + "<]")
    return "".join(parts)


# ---------------------------------------------------------------- running bfcc

class Bfcc:
    exe = None

    @classmethod
    def build(cls, directory):
        exe = os.path.join(directory, "bfcc.exe" if os.name == "nt" else "bfcc")
        cls.exe = hostcc.build([os.path.join(BFCC, "bfcc_host.c"), os.path.join(BFCC, "bfcc_main.c")],
                               exe, include_dirs=[BFCC])

    @classmethod
    def run(cls, job):
        with tempfile.TemporaryDirectory() as d:
            jp, op = os.path.join(d, "job"), os.path.join(d, "out")
            with open(jp, "wb") as f:
                f.write(job)
            r = subprocess.run([cls.exe, "run", jp, "-o", op], capture_output=True)
            with open(op, "rb") as f:
                return r.returncode, f.read().decode("utf-8"), r.stderr.decode("utf-8")

    @classmethod
    def many(cls, programs):
        """programs: (name, code, tape, flags); returns the concatenated C."""
        job = bytearray([MODE_MANY, len(programs)])
        for name, code, tape, flags in programs:
            job += str(tape).encode() + b"\0" + name.encode() + b"\0" + bytes([flags]) + code.encode() + b"\0"
        return cls.run(bytes(job))

    @classmethod
    def one(cls, code, name="demo", tape=64, flags=PROPAGATE):
        job = bytes([MODE_ONE]) + str(tape).encode() + b"\0" + name.encode() + b"\0" + bytes([flags])
        return cls.run(job + code.encode("utf-8") + b"\0")


def python_c(name, code, tape, flags):
    ops = ir.compile_bf(code, zero_from=0 if flags & PROPAGATE else None)
    if flags & STATIC and not ir.is_static(ops):
        raise SystemExit("%s: generated BF must keep every loop balanced" % name)
    return ir.emit_c(ops, name, tape)


def python_accepts(p):
    try:
        python_c(*p)
        return True
    except (ValueError, ref.BfError, SystemExit):
        return False


class BfccTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        try:
            hostcc.compiler()
        except hostcc.NoCompiler as e:
            raise unittest.SkipTest(str(e))
        cls.dir = tempfile.mkdtemp()
        Bfcc.build(cls.dir)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.dir, ignore_errors=True)

    def assert_same(self, programs):
        programs = [p for p in programs if python_accepts(p)]
        for i in range(0, len(programs), 250):
            batch = programs[i:i + 250]
            code, out, err = Bfcc.many(batch)
            expected = "".join(python_c(*p) for p in batch)
            if code != 0 or out != expected:
                for p in batch:
                    code, out, err = Bfcc.one(p[1], p[0], p[2], p[3])
                    self.assertEqual((0, python_c(*p)), (code, out), (p, err))
                self.fail("batch differs")

    # ------------------------------------------------------------ the same C

    def test_policy_programs(self):
        for entry in gen.load_manifest()["programs"]:
            code = gen.program_code(entry["name"])
            self.assert_same([(entry["name"], code, entry["tape"], PROPAGATE | STATIC)])

    def test_gen_matches_the_python_generator(self):
        """bfcc gen: lint, compile, memory map, ABI constants."""
        expected = gen.generate()
        root = tempfile.mkdtemp()
        try:
            shutil.copytree(os.path.join(ROOT, "brainfuck"), os.path.join(root, "brainfuck"))
            for path in expected:
                os.makedirs(os.path.dirname(os.path.join(root, os.path.relpath(path, ROOT))), exist_ok=True)
            r = subprocess.run([Bfcc.exe, "gen", "--root", root], capture_output=True)
            self.assertEqual(0, r.returncode, r.stderr)
            for path, text in expected.items():
                with open(os.path.join(root, os.path.relpath(path, ROOT)), encoding="utf-8", newline="") as f:
                    self.assertEqual(text, f.read(), path)
        finally:
            shutil.rmtree(root)
        r = subprocess.run([Bfcc.exe, "gen", "--check", "--root", ROOT], capture_output=True)
        self.assertEqual(0, r.returncode, r.stdout + r.stderr)

    def test_edge_programs(self):
        cases = ["", "+", "-", "+" * 1000, "-" * 257, ">" * 1000 + "<" * 999, "<" * 5, ",", ".", ",.,.",
                 "[]", "[-]", "[+]", "[[]]", "+[->+<]", "+[->++>+++<<]", "+[-<+>]", "[->+<-]",
                 ">[<+>[-]]", "+[>]", "+[<]", "+[>+<[-]]", "+[[-]>]", ",[.,]", "+[->[-]+<]",
                 "+++[>+++[>++<-]<-]>>.", "[.>]", ">" * 30 + "[<<]"]
        programs = [("e%d" % i, c, 64, f) for i, c in enumerate(cases) for f in (0, PROPAGATE)]
        self.assert_same(programs)

    def test_random_programs(self):
        rng = random.Random(20260930)
        programs = []
        for i in range(1500):
            programs.append(("p%d" % i, ">" * 20 + random_program(rng), 4096, rng.choice([0, PROPAGATE])))
            programs.append(("s%d" % i, static_program(rng), 64, rng.choice([0, PROPAGATE, PROPAGATE | STATIC])))
        self.assert_same(programs)

    def test_switches_and_equality_runs(self):
        rng = random.Random(5)
        programs, switches = [], 0
        for i in range(200):
            s = rng.randint(0, 3)
            values = rng.sample(range(256), rng.randint(3, 9))
            code = "".join(copy_ifeq(s, 8, 9, 10, (-v) & 255, at(rng.randint(4, 7), "+" * rng.randint(1, 3)), "")
                           for v in values)
            programs.append(("w%d" % i, at(s, ",") + code, 64, PROPAGATE))
            switches += python_c(*programs[-1]).count("switch")
        self.assertGreater(switches, 150)
        self.assert_same(programs)

    def test_known_values_fold(self):
        code = "+++" + copy_ifeq(0, 8, 9, 10, 253, at(4, "+"), at(5, "+")) + at(4, ".") + at(5, ".")
        c = python_c("k", code, 64, PROPAGATE)
        self.assertNotIn("if", c)
        self.assert_same([("k", code, 64, PROPAGATE)])

    # ------------------------------------------------------------ errors

    def test_malformed_brackets(self):
        for code in ["]", "[", "+[", "[]]", "[[]", ">]<", "[[[-]]", "+]["]:
            try:
                ops = ir.compile_bf(code, zero_from=0)
                ir.emit_c(ops, "demo", 64)
                expected = None
            except ref.BfError as e:
                expected = str(e)
            status, out, err = Bfcc.one(code)
            self.assertEqual(1, status, code)
            self.assertEqual(expected + "\n", err, code)

    def test_tape_violations(self):
        for code, tape in [(">" * 64 + "+", 64), ("<+", 64), (">" * 10 + ".", 10), ("+[->>+<<]", 2)]:
            with self.assertRaises(ValueError) as cm:
                ir.emit_c(ir.compile_bf(code, zero_from=0), "demo", tape)
            status, out, err = Bfcc.one(code, tape=tape)
            self.assertEqual((1, str(cm.exception) + "\n"), (status, err), code)

    def test_unbalanced_rejected_when_static_required(self):
        status, _, err = Bfcc.one("+[>]", flags=PROPAGATE | STATIC)
        self.assertEqual(1, status)
        self.assertIn("generated BF must keep every loop balanced", err)

    def test_oversized_source(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "big.bf")
            with open(path, "w") as f:
                f.write("+" * (8 * 1024 * 1024 + 1))
            r = subprocess.run([Bfcc.exe, "compile", path, "big", "64"], capture_output=True)
            self.assertEqual(1, r.returncode)
            self.assertIn(b"sources are limited", r.stderr)

    def test_lint_diagnostics(self):
        cases = [
            "+ # has + and . and ]\n",
            "# %cell A 0\n# %cell B 1 2\n>@B >@B:1 @A\n",
            "# %cell A 0\n@Z\n",
            "# %cell A 3 2\n@A:2\n",
            "# %cell A 0\n@A:\n",
            "@\n@-\n~\n~x\n",
            "+++ ~3 ++ ~3\n>> ~2 ~2\n",
            "]\n[[\n]\n[\n",
            "[>]\n",
            ">>>>>>>> >>\n",
            "<\n",
            "# %cell A 0\n# %cell A 1\n",
            "x y\n",
            "+\r\n+\r+\n# %cell Q 1\r\n>@Q\n",
            "\u00e9+'\\\n",
            "@12 >@1 @0:1\n",
            "# %cell LONGNAME_x9 5   scratch 7\n>>>>> @LONGNAME_x9\n",
            "#%cell  T\t3\n>>>@T\n",
            "+~0\n",
            "\x01\n",
        ]
        for text in cases:
            try:
                lint.lint(text, 8, "src/x.bf")
                expected = (0, "")
            except lint.LintError as e:
                expected = (1, str(e) + "\n")
            self.assertEqual(expected, self.lint_with_bfcc(text, 8), repr(text))

    def lint_with_bfcc(self, text, tape):
        root = tempfile.mkdtemp()
        try:
            for d in ("brainfuck/src", "brainfuck/generated", "app/src/main/cpp/generated",
                      "app/src/main/java/my/MrxSiN/gmailhideads/policy"):
                os.makedirs(os.path.join(root, d))
            shutil.copy(os.path.join(ROOT, "brainfuck", "constants.txt"), os.path.join(root, "brainfuck"))
            with open(os.path.join(root, "brainfuck", "programs.json"), "w") as f:
                f.write('{"programs": [{"id": 0, "name": "x", "source": "src/x.bf", "tape": %d}]}' % tape)
            with open(os.path.join(root, "brainfuck", "src", "x.bf"), "wb") as f:
                f.write(text.encode("utf-8"))
            r = subprocess.run([Bfcc.exe, "gen", "--root", root], capture_output=True)
            return (0 if r.returncode == 0 else 1), r.stderr.decode("utf-8")
        finally:
            shutil.rmtree(root)

    # ------------------------------------------------------------ determinism

    def test_deterministic(self):
        rng = random.Random(3)
        programs = [("d%d" % i, static_program(rng), 64, PROPAGATE) for i in range(100)]
        programs = [p for p in programs if python_accepts(p)]
        self.assertEqual(Bfcc.many(programs), Bfcc.many(programs))

    # ------------------------------------------------------------ run time

    def test_generated_code_runs_like_the_reference(self):
        """reference interpreter == bfcc's C, run through the shipped engine
        (8-bit wrapping, EOF reads 0, output, tape faults, loop budget)."""
        rng = random.Random(77)
        programs = []
        for i in range(120):
            if i % 3 == 0:
                code = static_program(rng)
            elif i % 3 == 1:
                code = ">" * 8 + terminating_program(rng)
            else:
                code = ">" * 4 + random_program(rng)
            if python_accepts(("r%d" % i, code, 64, PROPAGATE)):
                programs.append(("r%d" % i, code, 64, PROPAGATE))
        status, functions, err = Bfcc.many(programs)
        self.assertEqual(0, status, err)
        with tempfile.TemporaryDirectory() as d:
            c_path = os.path.join(d, "programs.c")
            with open(c_path, "w", encoding="utf-8", newline="\n") as f:
                f.write('#include "bf_runtime.h"\n\n' + functions + "const bf_program_info bf_programs[] = {\n")
                for name, _, tape, _ in programs:
                    f.write('    {"%s", bf_prog_%s, %d},\n' % (name, name, tape))
                f.write("};\nconst int bf_program_count = %d;\n" % len(programs))
            exe = replay.build_harness(c_path, os.path.join(d, "replay.exe" if os.name == "nt" else "replay"))
            cases = []
            for pid, p in enumerate(programs):
                for _ in range(3):
                    cases.append((pid, bytes(rng.randrange(256) for _ in range(rng.randint(0, 12)))))
            results = replay.run_aot(exe, cases)
        compared = 0
        for (pid, data), (status, out, ticks) in zip(cases, results):
            name, code, tape, _ = programs[pid]
            try:
                expected = ref.run(code, data, tape=bytearray(tape), max_steps=2_000_000)
            except ref.BfError as e:
                if "step limit" in str(e):
                    continue
                self.assertEqual(1, status, (code, data))   # BF_ERR_TAPE
                continue
            if status == 3:
                continue  # the per-request loop budget ran out first
            if len(expected) > gen.abi_constants()["RUNTIME_OUT_CAP"]:
                self.assertEqual(2, status, (code, data))   # BF_ERR_OUTPUT
                continue
            self.assertEqual((0, expected), (status, out), (code, data))
            compared += 1
        self.assertGreater(compared, 200)


if __name__ == "__main__":
    unittest.main()
