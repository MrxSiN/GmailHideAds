"""The shipped policy programs: reference interpreter vs IR vs host-compiled
AOT C, known vectors, randomized names, malformed frames and the execution
budget. Parity with the legacy Java policy is PolicyParityTest."""

import os
import random
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tools"))

import frames  # noqa: E402
from bftool import gen, hostcc, ir, ref, replay  # noqa: E402

C = frames.C
ROW, SCOPE = C["PROG_ROW"], C["PROG_SCOPE"]
TAPES = {p["id"]: p["tape"] for p in gen.load_manifest()["programs"]}
NAMES = {p["id"]: p["name"] for p in gen.load_manifest()["programs"]}

AD_ROWS = ["com.google.android.gm.ads.adteaser.BasicAdTeaserItemView",
           "com.google.android.gm.ads.adteaser.VideoAdTeaserItemView",
           "com.google.android.gm.ads.adteaser.ImageCarouselAdTeaserItemView",
           "com.google.android.gm.ads.adteaser.RichButtonChipAdTeaserItemView",
           "com.google.android.gm.ads.adteaser.AppInstallButtonChipAdTeaserItemView",
           "com.google.android.gm.ads.adteaser.EuSingleImageAdTeaserItemView"]
ORDINARY = ["android.view.View", "android.view.ViewGroup", "android.widget.FrameLayout",
            "java.lang.Object", "androidx.recyclerview.widget.RecyclerView",
            "com.google.android.gm.ads.AdTeaserItemViewHolder", "com.google.android.gm.AdTeaserItemView",
            "com.google.android.gm.ads", "com.google.android.gm.adsx.AdTeaserItemView",
            "Com.google.android.gm.ads.AdTeaserItemView", "com.google.android.gm.ads.AdteaserItemView",
            "com.google.android.gm.ads.adteaser.BasicAdTeaserItemView$1", "", "AdTeaserItemView"]
PIECES = [frames.AD_PREFIX, frames.AD_SUFFIX, "adteaser.", "Basic", "Video", "Ad", "AdTeaser",
          "com.google.android.gm", ".", "ads.", "View", "Item", "AAd", "x", "$1", "ﬀ", "é",
          "com.google.", "android.", "gm."]


def random_name(rng):
    r = rng.random()
    if r < 0.2:
        return rng.choice(AD_ROWS + ORDINARY)
    if r < 0.6:
        return "".join(rng.choice(PIECES) for _ in range(rng.randint(0, 6)))
    if r < 0.8:
        base = rng.choice(AD_ROWS)
        i = rng.randrange(len(base))
        op = rng.randrange(3)
        ch = rng.choice("AdTeaserItemViewcom.gl xZ")
        return base[:i] + ch + base[i:] if op == 0 else (base[:i] + ch + base[i + 1:] if op == 1 else base[:i] + base[i + 1:])
    return "".join(rng.choice("comgleandrisATItVw.xyZ$") for _ in range(rng.randint(0, 60)))


def random_scope_name(rng):
    r = rng.random()
    if r < 0.15:
        return None
    if r < 0.3:
        return ""
    if r < 0.5:
        return frames.TARGET
    base = rng.choice([frames.TARGET, frames.TARGET + ":sync", "com.google.android.gms", "com.google.android.g",
                       "com.google.android.gmail", "com.android.systemui"])
    if rng.random() < 0.5 and base:
        i = rng.randrange(len(base))
        base = base[:i] + rng.choice("comgl.adrix:") + base[i + 1:]
    return base


class ProgramsTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        try:
            hostcc.compiler()
        except hostcc.NoCompiler as e:
            raise unittest.SkipTest(str(e))
        cls.dir = tempfile.mkdtemp()
        exe = os.path.join(cls.dir, "replay.exe" if os.name == "nt" else "replay")
        cls.binary = replay.build_harness(gen.C_OUT, exe)
        cls.codes = {pid: gen.program_code(name) for pid, name in NAMES.items()}
        cls.ops = {pid: ir.compile_bf(code, zero_from=0) for pid, code in cls.codes.items()}

    def aot(self, cases):
        return replay.run_aot(self.binary, cases)

    def aot_ok(self, program, requests):
        results = self.aot([(program, r) for r in requests])
        for (status, _, ticks), req in zip(results, requests):
            self.assertEqual(0, status, req[:16])
            budget = C["BUDGET_BASE"] + len(req) * C["BUDGET_PER_BYTE"]
            self.assertLess(ticks, budget // 4, "a policy request should stay far below its budget")
        return [r[1] for r in results]

    # ------------------------------------------------------------ backends agree

    def test_reference_ir_and_aot_agree(self):
        rng = random.Random(7)
        requests = []
        for _ in range(40):
            requests.append((ROW, frames.ad_row([random_name(rng) for _ in range(rng.randint(0, 4))])))
            requests.append((SCOPE, frames.scope(random_scope_name(rng), random_scope_name(rng))))
        requests.append((ROW, frames.ad_row(AD_ROWS)))
        requests.append((ROW, frames.frame(0x7F, b"\x01")))
        requests.append((SCOPE, frames.frame(C["OP_SCOPE"], b"", major=2)))
        aot = self.aot(requests)
        for (program, req), (status, out, _) in zip(requests, aot):
            self.assertEqual(0, status)
            expected = ref.run(self.codes[program], req, tape=bytearray(TAPES[program]))
            self.assertEqual(expected, ir.execute(self.ops[program], req, tape_size=TAPES[program]))
            self.assertEqual(expected, out)

    # ------------------------------------------------------------ row.bf

    def test_known_rows(self):
        cases = [[n] for n in AD_ROWS + ORDINARY]
        cases += [["com.example.Sub", n, "android.view.ViewGroup", "java.lang.Object"] for n in AD_ROWS]
        cases += [[], ["android.view.View", "java.lang.Object"]]
        outs = self.aot_ok(ROW, [frames.ad_row(c) for c in cases])
        for c, out in zip(cases, outs):
            self.assertEqual([frames.legacy_ad_row(c)], list(frames.parse(out, C["OP_AD_ROW"], 1)), c)
        self.assertEqual(6, sum(frames.legacy_ad_row([n]) for n in AD_ROWS))

    def test_random_rows(self):
        rng = random.Random(8)
        cases = [[random_name(rng) for _ in range(rng.randint(0, 6))] for _ in range(20000)]
        cases += [[frames.AD_PREFIX + "x" * rng.randint(0, 600) + frames.AD_SUFFIX] for _ in range(50)]
        outs = self.aot_ok(ROW, [frames.ad_row(c) for c in cases])
        hits = 0
        for c, out in zip(cases, outs):
            expected = frames.legacy_ad_row(c)
            hits += expected
            self.assertEqual([expected], list(frames.parse(out, C["OP_AD_ROW"], 1)), c)
        self.assertGreater(hits, 1000)

    def test_max_class_count(self):
        names = ["java.lang.Object"] * 254 + [AD_ROWS[0]]
        out = self.aot_ok(ROW, [frames.ad_row(names)])[0]
        self.assertEqual([1], list(frames.parse(out, C["OP_AD_ROW"], 1)))

    # ------------------------------------------------------------ scope.bf

    def test_scope(self):
        rng = random.Random(9)
        values = [None, "", frames.TARGET, frames.TARGET + ":sync", "com.google.android.g", "x"]
        cases = [(p, q) for p in values for q in values]
        cases += [(random_scope_name(rng), random_scope_name(rng)) for _ in range(20000)]
        outs = self.aot_ok(SCOPE, [frames.scope(*c) for c in cases])
        for c, out in zip(cases, outs):
            self.assertEqual([frames.legacy_scope(*c)], list(frames.parse(out, C["OP_SCOPE"], 1)), c)

    # ------------------------------------------------------------ robustness

    def test_bad_version_and_opcode(self):
        for program in (ROW, SCOPE):
            out = self.aot([(program, frames.frame(C["OP_AD_ROW"], b"", major=2)),
                            (program, frames.frame(0x7F, b"\x01\x02"))])
            self.assertEqual(C["ST_BAD_VERSION"], out[0][1][3])
            self.assertEqual(C["ST_BAD_OPCODE"], out[1][1][3])
            self.assertEqual(8, len(out[1][1]))
        # Each program serves only its own opcode.
        wrong = self.aot([(ROW, frames.scope(frames.TARGET, None)), (SCOPE, frames.ad_row(AD_ROWS))])
        for _, out, _ in wrong:
            self.assertEqual(C["ST_BAD_OPCODE"], out[3])

    def test_malformed_frames_terminate(self):
        rng = random.Random(12)
        cases = []
        for _ in range(6000):
            program = rng.choice([ROW, SCOPE])
            op = rng.choice([0x10, 0x20, rng.randrange(256)])
            payload = bytes(rng.randrange(256) for _ in range(rng.randint(0, 600)))
            data = frames.frame(op, payload) if rng.random() < 0.8 else payload
            cases.append((program, data))
        for (program, data), (status, out, ticks) in zip(cases, self.aot(cases)):
            self.assertIn(status, (0, 3), data[:16])  # OK or budget exhausted, never a tape fault
            self.assertLessEqual(len(out), C["RUNTIME_OUT_CAP"])

    def test_truncated_requests_are_answered(self):
        for program, full in ((ROW, frames.ad_row(["android.view.View", AD_ROWS[0]])),
                              (SCOPE, frames.scope(frames.TARGET, frames.TARGET))):
            for status, out, _ in self.aot([(program, full[:n]) for n in range(len(full))]):
                self.assertEqual(0, status)

    def test_budget_scales_with_the_request(self):
        # 255 names of 1020 characters each: still answered inside the budget.
        name = (b"\xff" + bytes([C["NC_C"]]) * 255) * 4 + b"\0"
        req = frames.frame(C["OP_AD_ROW"], b"\xff" + name * 255)
        status, out, ticks = self.aot([(ROW, req)])[0]
        self.assertEqual(0, status)


if __name__ == "__main__":
    unittest.main()
