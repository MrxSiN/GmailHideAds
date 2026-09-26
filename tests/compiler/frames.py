"""Python mirror of the host request encoding (PolicyFrame.java) and of the
v1.0.0 Java rules, for the randomized program tests. Parity with the frozen
legacy Java policy itself is PolicyParityTest."""

import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tools"))

from bftool import gen  # noqa: E402

C = gen.abi_constants()

AD_PREFIX = "com.google.android.gm.ads."
AD_SUFFIX = "AdTeaserItemView"
TARGET = "com.google.android.gm"

NAME_LETTERS = {".": "NC_DOT", "c": "NC_C", "o": "NC_O", "m": "NC_M", "g": "NC_G", "l": "NC_L",
                "e": "NC_E", "a": "NC_A", "n": "NC_N", "d": "NC_D", "r": "NC_R", "i": "NC_I",
                "s": "NC_S", "t": "NC_T", "w": "NC_W", "A": "NC_UP_A", "T": "NC_UP_T",
                "I": "NC_UP_I", "V": "NC_UP_V"}


def name_code(ch):
    name = NAME_LETTERS.get(ch)
    return C[name] if name else C["NC_OTHER"]


def chunks(codes):
    out = bytearray()
    for i in range(0, len(codes), 255):
        part = codes[i:i + 255]
        out.append(len(part))
        out += bytes(part)
    out.append(0)
    return bytes(out)


def name_text(value):
    return chunks([name_code(c) for c in value])


def frame(op, payload, request_id=0x1234, major=C["ABI_MAJOR"]):
    return struct.pack("<BBBBHH", major, C["ABI_MINOR"], op, 0, len(payload) & 0xFFFF, request_id) + payload


def ad_row(names):
    """OP_AD_ROW: the view class name first, then each superclass name."""
    return frame(C["OP_AD_ROW"], bytes([len(names)]) + b"".join(name_text(n) for n in names))


def scope(package, process):
    payload = bytearray()
    for value in (package, process):
        payload.append(0 if value is None else 1)
        payload += name_text(value or "")
    return frame(C["OP_SCOPE"], bytes(payload))


def parse(out, op, length, request_id=0x1234):
    assert len(out) == 8 + length, (len(out), length)
    major, minor, rop, status, n, rid = struct.unpack_from("<BBBBHH", out)
    assert (major, rop, status, n, rid) == (C["ABI_MAJOR"], op | C["RESPONSE_BIT"], 0, length, request_id), out[:8]
    return out[8:]


def legacy_ad_row(names):
    return int(any(n.startswith(AD_PREFIX) and n.endswith(AD_SUFFIX) for n in names))


def legacy_scope(package, process):
    return int(package == TARGET and (process is None or process == "" or process == TARGET))
