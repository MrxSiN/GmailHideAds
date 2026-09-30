"""bflc: compiles BFL, the structured source language of the Brainfuck
compiler, into one balanced Brainfuck program.

BFL is a small, statically allocated language written in Python syntax
(parsed with the standard `ast` module, never executed). It exists so the
compiler's decisions can be written as readable functions and still end up
as plain Brainfuck: this tool is an authoring aid in the role of an
assembler, and nothing it does is part of compiling a user program.
docs/BFCC.md describes the language and the shape of the generated program.

Values are unsigned 8-bit cells. Aggregates (arrays `u8[N]` and classes) are
lists of cells with compile-time field and index selection. Every variable
has a fixed tape cell; there is no pointer arithmetic at run time.

Control flow compiles to a state machine: every function is a set of states,
a state is straight-line Brainfuck with inline `if`s and pure loops, and one
dispatch loop selects the state from a program counter. Calls store a return
state; recursive calls save the caller's frame through the memory device.
Every equality test uses the idiom tools/bftool/ir.py (and bfcc.bf itself)
recognises, so the dispatch and every `match` compile to C `switch`es.

Usage: python tools/bfcc/bflc.py SOURCE.bfl... -o OUT.bf [--map OUT.map]
"""

import ast
import os
import sys

# Memory device opcodes (tools/bfcc/bfcc_host.c).
(DEV_GETC, DEV_PUTC, DEV_LOAD, DEV_STORE, DEV_COPY, DEV_DIFF, DEV_EXIT, DEV_PUTS, DEV_DIAG,
 DEV_SLURP, DEV_SOURCE, DEV_JOB, DEV_SELECT, DEV_ARGW, DEV_ARGR, DEV_RETW, DEV_RETR) = range(1, 18)
STACK_BASE = 0x3E000000     # call stack for recursive frames, 256 bytes per frame
FRAME = 256
TSTRIDE = 16                # every 16th cell (15, 31, ...) is a copy temporary


class BflError(Exception):
    pass


# ---------------------------------------------------------------- types

class U8Ty:
    size = 1
    name = "u8"


U8 = U8Ty()


class ArrTy:
    def __init__(self, elem, n):
        self.elem, self.n, self.size = elem, n, elem.size * n
        self.name = "%s[%d]" % (elem.name, n)


class StructTy:
    def __init__(self, name):
        self.name, self.fields, self.size = name, {}, 0


class Loc:
    """A typed list of cells."""
    __slots__ = ("ty", "cells")

    def __init__(self, ty, cells):
        self.ty, self.cells = ty, list(cells)
        assert len(self.cells) == ty.size

    @property
    def cell(self):
        assert self.ty is U8
        return self.cells[0]


# ---------------------------------------------------------------- cell ops
#
# ("clr", c)  ("add", c, k)  ("mov", src, [(dst, k)...]) (src ends zero)
# ("in", c)  ("out", c)  ("outk", [k...])  ("ifeq", s, k, then, else)
# ("loop", c, body)  ("npc", state)  ("setret", func, state)  ("ret", func)
# ("save", func)  ("restore", func)  ("halt",)


def clr(c):
    return ("clr", c)


def add(c, k):
    return ("add", c, k & 255)


class Program:
    def __init__(self):
        self.consts = {}
        self.types = {"u8": U8}
        self.globals = {}
        self.funcs = {}
        self.states = []
        self.next_cell = 0
        self.cell_names = {}
        self.cell_owner = {}
        self.owner = None           # function whose region new cells join
        self.temps_free = []
        self.levels = []
        self.file = "<bfl>"

    def alloc(self, n=1, name="?"):
        """n virtual cells; layout() gives them tape addresses, grouping
        each function's cells so the Brainfuck pointer travels little."""
        out = []
        for _ in range(n):
            c = self.next_cell
            self.next_cell += 1
            self.cell_names[c] = name
            self.cell_owner[c] = self.owner
            out.append(c)
        return out

    def temp(self):
        return self.temps_free.pop() if self.temps_free else self.alloc(1, "tmp")[0]

    def free(self, c):
        assert c not in self.temps_free
        self.temps_free.append(c)

    def level(self, n):
        """The flag pair of the equality test at ifeq nesting depth n."""
        while len(self.levels) <= n:
            self.levels.append(tuple(self.alloc(2, "lv%d" % len(self.levels))))
        return self.levels[n]

    def err(self, node, msg):
        raise BflError("%s:%s: %s" % (self.file, getattr(node, "lineno", "?"), msg))

    # ------------------------------------------------------------ constants and types

    def try_type(self, node):
        if isinstance(node, ast.Name) and node.id in self.types:
            return self.types[node.id]
        if isinstance(node, ast.Subscript):
            elem = self.try_type(node.value)
            if elem is None:
                return None
            return ArrTy(elem, self.const_eval(node.slice, Scope()))
        return None

    def type_of(self, node):
        ty = self.try_type(node)
        if ty is None:
            self.err(node, "unknown type")
        return ty

    def const_eval(self, node, scope):
        v = self.try_const(node, scope)
        if v is None:
            self.err(node, "not a compile-time constant")
        return v

    def try_const(self, node, scope):
        if isinstance(node, ast.Constant):
            if isinstance(node.value, bool):
                return int(node.value)
            return node.value if isinstance(node.value, (int, str)) else None
        if isinstance(node, ast.Name):
            v = scope.const(node.id)
            if v is not None:
                return v
            if scope.lookup(node.id) is not None:
                return None
            return self.consts.get(node.id)
        if isinstance(node, ast.UnaryOp):
            v = self.try_const(node.operand, scope)
            if v is None:
                return None
            if isinstance(node.op, ast.USub):
                return -v
            if isinstance(node.op, ast.Invert):
                return ~v
            if isinstance(node.op, ast.Not):
                return int(not v)
            return None
        if isinstance(node, ast.BinOp):
            a, b = self.try_const(node.left, scope), self.try_const(node.right, scope)
            if a is None or b is None:
                return None
            f = {ast.Add: lambda: a + b, ast.Sub: lambda: a - b, ast.Mult: lambda: a * b,
                 ast.FloorDiv: lambda: a // b, ast.Mod: lambda: a % b, ast.LShift: lambda: a << b,
                 ast.RShift: lambda: a >> b, ast.BitAnd: lambda: a & b, ast.BitOr: lambda: a | b,
                 ast.BitXor: lambda: a ^ b}.get(type(node.op))
            return f() if f else None
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and \
                node.func.id in ("str", "ord", "chr", "len"):
            args = [self.try_const(a, scope) for a in node.args]
            if len(args) != 1 or args[0] is None:
                return None
            return {"str": str, "ord": ord, "chr": chr, "len": len}[node.func.id](args[0])
        if isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name):
            return self.consts.get("%s.%s" % (node.value.id, node.attr))
        if isinstance(node, ast.JoinedStr):
            parts = []
            for v in node.values:
                if isinstance(v, ast.Constant):
                    parts.append(v.value)
                    continue
                x = self.try_const(v.value, scope)
                if x is None:
                    return None
                parts.append(str(x))
            return "".join(parts)
        if isinstance(node, ast.Subscript):
            base, idx = self.try_const(node.value, scope), self.try_const(node.slice, scope)
            if isinstance(base, str) and isinstance(idx, int):
                return base[idx]
        return None


# ---------------------------------------------------------------- front end

class Func:
    def __init__(self, prog, node):
        self.prog, self.node, self.name = prog, node, node.name
        self.inline = any(isinstance(d, ast.Name) and d.id == "inline" for d in node.decorator_list)
        self.params = []
        for a in node.args.args:
            if a.annotation is None:
                prog.err(node, "parameter %s needs a type" % a.arg)
            self.params.append((a.arg, prog.type_of(a.annotation)))
        r = node.returns
        self.ret_ty = None if r is None or (isinstance(r, ast.Constant) and r.value is None) \
            else prog.type_of(r)
        self.pool, self.pool_free = [], []
        self.ret = self.retval = self.entry = None
        self.param_locs = []
        self.recursive_callees = set()
        self.split_cache = None
        self.file = prog.file

    def take(self, n, name):
        cells = []
        for _ in range(n):
            if self.pool_free:
                cells.append(self.pool_free.pop())
            else:
                c = self.prog.alloc(1, "%s.%s" % (self.name, name))[0]
                self.pool.append(c)
                cells.append(c)
        return cells

    def give(self, cells):
        self.pool_free.extend(reversed(cells))

    def frame(self):
        return self.pool + self.ret


class State:
    def __init__(self, prog, label):
        self.id = len(prog.states)
        self.label = label
        self.ops = []
        prog.states.append(self)


class Scope:
    def __init__(self, parent=None):
        self.vars, self.consts, self.parent = {}, {}, parent

    def lookup(self, name):
        s = self
        while s is not None:
            if name in s.vars:
                return s.vars[name]
            s = s.parent
        return None

    def const(self, name):
        s = self
        while s is not None:
            if name in s.consts:
                return s.consts[name]
            s = s.parent
        return None


class Ctx:
    """Where lowering appends: the current state's op list (or an inline
    branch), the function being expanded and the frame that owns locals."""

    def __init__(self, func, owner, scope, ops, state):
        self.func, self.owner, self.scope, self.ops, self.state = func, owner, scope, ops, state
        self.loops = []

    def sub(self, ops):
        c = Ctx(self.func, self.owner, self.scope, ops, self.state)
        c.loops = self.loops
        return c


def load_program(paths):
    prog = Program()
    for path in paths:
        with open(path, encoding="utf-8") as f:
            tree = ast.parse(f.read(), path)
        prog.file = os.path.basename(path)
        for node in tree.body:
            declare(prog, node)
    return prog


def declare(prog, node):
    if isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant):
        return
    if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
        ty = prog.try_type(node.value)
        if ty is not None:
            prog.types[node.targets[0].id] = ty
        else:
            prog.consts[node.targets[0].id] = prog.const_eval(node.value, Scope())
        return
    if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
        ty = prog.type_of(node.annotation)
        init = prog.const_eval(node.value, Scope()) if node.value is not None else None
        prog.globals[node.target.id] = (Loc(ty, prog.alloc(ty.size, node.target.id)), init)
        return
    if isinstance(node, ast.ClassDef):
        st = StructTy(node.name)
        for item in node.body:
            if isinstance(item, ast.Expr):
                continue
            if isinstance(item, ast.Assign) and len(item.targets) == 1 and                     isinstance(item.targets[0], ast.Name):
                # A class of plain assignments is a constant namespace: K.ADD.
                prog.consts["%s.%s" % (node.name, item.targets[0].id)] =                     prog.const_eval(item.value, Scope())
                continue
            if not isinstance(item, ast.AnnAssign) or not isinstance(item.target, ast.Name):
                prog.err(item, "class bodies hold only typed fields")
            ty = prog.type_of(item.annotation)
            st.fields[item.target.id] = (st.size, ty)
            st.size += ty.size
        if st.fields:
            prog.types[node.name] = st
        return
    if isinstance(node, ast.FunctionDef):
        if node.name in prog.funcs:
            prog.err(node, "function %s defined twice" % node.name)
        prog.funcs[node.name] = Func(prog, node)
        return
    prog.err(node, "unsupported top-level statement")


# ---------------------------------------------------------------- analysis

def build_call_graph(prog):
    direct = {n: {c.func.id for c in ast.walk(f.node) if isinstance(c, ast.Call) and
                  isinstance(c.func, ast.Name) and c.func.id in prog.funcs}
              for n, f in prog.funcs.items()}
    memo = {}

    def real(name, stack=()):
        if name in memo:
            return memo[name]
        out = set()
        for c in direct[name]:
            if prog.funcs[c].inline:
                if c in stack:
                    raise BflError("inline function %s is recursive" % c)
                out |= real(c, stack + (c,))
            else:
                out.add(c)
        memo[name] = out
        return out

    graph = {n: real(n) for n in prog.funcs}
    prog.graph = graph
    for n, f in prog.funcs.items():
        if f.inline:
            continue
        for c in graph[n]:
            seen, todo = set(), [c]
            while todo:
                x = todo.pop()
                if x in seen:
                    continue
                seen.add(x)
                todo.extend(graph[x])
            if n in seen:
                f.recursive_callees.add(c)


def _is_true(test):
    return isinstance(test, ast.Constant) and test.value is True


def splits(prog, node):
    """True when lowering `node` needs more than one state."""
    if isinstance(node, list):
        return any(splits(prog, n) for n in node)
    for n in ast.walk(node):
        if isinstance(n, (ast.Break, ast.Continue, ast.Return)):
            return True
        if isinstance(n, ast.While) and (_is_true(n.test) or n.orelse):
            return True
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name):
            if n.func.id == "halt":
                return True
            f = prog.funcs.get(n.func.id)
            if f is not None and (not f.inline or inline_splits(prog, f)):
                return True
    return False


def inline_splits(prog, f):
    if f.split_cache is None:
        body = f.node.body
        if body and isinstance(body[-1], ast.Return):
            body = body[:-1]
        f.split_cache = splits(prog, body)
    return f.split_cache


# ---------------------------------------------------------------- lowering

class Lower:
    def __init__(self, prog):
        self.prog = prog

    def err(self, node, msg):
        self.prog.err(node, msg)

    # ------------------------------------------------------------ states

    def enter(self, ctx, st):
        ctx.state, ctx.ops = st, st.ops

    def goto(self, ctx, st):
        """End the current state with a jump to `st` and continue there."""
        if ctx.state is not None:
            ctx.ops.append(("npc", st))
        self.enter(ctx, st)

    def dead(self, ctx):
        ctx.state, ctx.ops = None, []

    # ------------------------------------------------------------ names

    def lvalue(self, ctx, node):
        """Loc of an l-value expression, or None when it is not one."""
        if isinstance(node, ast.Name):
            if ctx.scope.const(node.id) is not None:
                return None
            loc = ctx.scope.lookup(node.id)
            if loc is not None:
                return loc
            if node.id in self.prog.globals:
                return self.prog.globals[node.id][0]
            return None
        if isinstance(node, ast.Attribute):
            base = self.lvalue(ctx, node.value)
            if base is None:
                return None
            if not isinstance(base.ty, StructTy) or node.attr not in base.ty.fields:
                self.err(node, "no field %s" % node.attr)
            off, ty = base.ty.fields[node.attr]
            return Loc(ty, base.cells[off:off + ty.size])
        if isinstance(node, ast.Subscript):
            base = self.lvalue(ctx, node.value)
            if base is None:
                return None
            if not isinstance(base.ty, ArrTy):
                self.err(node, "not an array")
            i = self.prog.try_const(node.slice, ctx.scope)
            if not isinstance(i, int):
                self.err(node, "array index must be a compile-time constant")
            if not 0 <= i < base.ty.n:
                self.err(node, "index %d out of range" % i)
            es = base.ty.elem.size
            return Loc(base.ty.elem, base.cells[i * es:(i + 1) * es])
        return None

    def u8loc(self, ctx, node):
        loc = self.lvalue(ctx, node)
        if loc is not None and loc.ty is not U8:
            self.err(node, "expected a u8, found %s" % loc.ty.name)
        return loc

    def const(self, ctx, node):
        v = self.prog.try_const(node, ctx.scope)
        return v if isinstance(v, int) else None

    # ------------------------------------------------------------ copies

    def copy_add(self, ops, src, dst, k=1):
        """dst += src * k, keeping src. With dst zero and k == 1 this is the
        copy idiom (the temporary sits above dst)."""
        k &= 255
        if not k:
            return
        ops.append(("cadd", src, dst, k))

    def copy(self, ops, src, dst):
        if src != dst:
            ops.append(clr(dst))
            self.copy_add(ops, src, dst, 1)

    # ------------------------------------------------------------ expressions

    def refs(self, ctx, node, cells):
        """True when `node` may read any of `cells`."""
        cells = set(cells)
        for n in ast.walk(node):
            if isinstance(n, ast.Call):
                return True
            if isinstance(n, (ast.Name, ast.Attribute, ast.Subscript)):
                try:
                    loc = self.lvalue(ctx, n)
                except BflError:
                    loc = None
                if loc is not None and cells & set(loc.cells):
                    return True
        return False

    def acc(self, ctx, dst, node, sign):
        """dst += sign * value(node) for a u8 expression."""
        ops = ctx.ops
        k = self.const(ctx, node)
        if k is not None:
            if k * sign & 255:
                ops.append(add(dst, k * sign))
            return
        if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub)):
            self.acc(ctx, dst, node.left, sign)
            self.acc(ctx, dst, node.right, sign if isinstance(node.op, ast.Add) else -sign)
            return
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            self.acc(ctx, dst, node.operand, -sign)
            return
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Mult):
            ka, kb = self.const(ctx, node.left), self.const(ctx, node.right)
            if ka is not None or kb is not None:
                factor = kb if kb is not None else ka
                other = node.left if kb is not None else node.right
                loc = self.u8loc(ctx, other)
                if loc is not None:
                    self.copy_add(ops, loc.cell, dst, factor * sign)
                    return
                c = self.eval_temp(ctx, other)
                if factor * sign & 255:
                    ops.append(("mov", c, [(dst, factor * sign & 255)]))
                else:
                    ops.append(clr(c))
                self.prog.free(c)
                return
        loc = self.u8loc(ctx, node)
        if loc is not None:
            self.copy_add(ops, loc.cell, dst, sign)
            return
        c = self.eval_temp(ctx, node)
        ops.append(("mov", c, [(dst, sign & 255)]))
        self.prog.free(c)

    def eval_temp(self, ctx, node):
        """A fresh zero-based temporary holding the u8 value of `node`. The
        caller clears and frees it."""
        prog = self.prog
        k = self.const(ctx, node)
        if k is not None:
            t = prog.temp()
            if k & 255:
                ctx.ops.append(add(t, k))
            return t
        if isinstance(node, ast.Call):
            return self.call_expr(ctx, node)
        if isinstance(node, (ast.Compare, ast.BoolOp)) or (isinstance(node, ast.UnaryOp) and
                                                          isinstance(node.op, ast.Not)):
            r = prog.temp()
            ctx.ops.extend(self.cond(ctx, node, [add(r, 1)], []))
            return r
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Mult) and \
                self.const(ctx, node.left) is None and self.const(ctx, node.right) is None:
            t = prog.temp()
            self.mul_vars(ctx, t, node.left, node.right)
            return t
        if isinstance(node, ast.BinOp) and not isinstance(node.op, (ast.Add, ast.Sub, ast.Mult)):
            self.err(node, "unsupported operator")
        if not isinstance(node, (ast.BinOp, ast.UnaryOp, ast.Name, ast.Attribute, ast.Subscript)):
            self.err(node, "unsupported expression")
        t = prog.temp()
        self.acc(ctx, t, node, 1)
        return t

    def mul_vars(self, ctx, t, a, b):
        cnt = self.eval_temp(ctx, b)
        body = []
        sub = ctx.sub(body)
        la = self.u8loc(ctx, a)
        if la is not None:
            self.copy_add(body, la.cell, t, 1)
        else:
            x = self.eval_temp(sub, a)
            self.copy_add(body, x, t, 1)
            body.append(clr(x))
            self.prog.free(x)
        body.append(add(cnt, -1))
        ctx.ops.append(("loop", cnt, body))
        self.prog.free(cnt)

    def call_expr(self, ctx, node):
        """A value-returning call inside an expression: getc() or an inline
        function without state splits."""
        name = getattr(node.func, "id", None)
        if name == "getc":
            t = self.prog.temp()
            ctx.ops.append(("outk", [DEV_GETC]))
            ctx.ops.append(("in", t))
            return t
        f = self.prog.funcs.get(name)
        if f is None:
            self.err(node, "unknown function %s" % name)
        if not f.inline or inline_splits(self.prog, f):
            self.err(node, "%s needs its own statement: x = %s(...)" % (name, name))
        if f.ret_ty is not U8:
            self.err(node, "%s does not return a u8" % name)
        res = self.inline_call(ctx, f, node)
        t = self.prog.temp()
        ctx.ops.append(("mov", res.cell, [(t, 1)]))
        ctx.owner.give(res.cells)
        return t

    # ------------------------------------------------------------ conditions

    def cond(self, ctx, node, then, other):
        """Ops that run `then` when `node` holds, else `other`. Branches are
        op lists or callables that build them; callables run only after the
        condition's temporaries are reserved, so a branch can never reuse a
        cell the test still holds."""
        ops = []
        sub = ctx.sub(ops)
        prog = self.prog
        mk = lambda b: b() if callable(b) else list(b)  # noqa: E731
        empty = lambda b: not callable(b) and not b  # noqa: E731
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            return self.cond(ctx, node.operand, other, then)
        k = self.const(ctx, node)
        if k is not None:
            return mk(then if k else other)

        def test(s, val, t, o):
            ops.append(("ifeq", s, val, mk(t), mk(o)))

        if isinstance(node, ast.Compare) and len(node.ops) == 1 and \
                isinstance(node.ops[0], (ast.Eq, ast.NotEq)):
            left, right = node.left, node.comparators[0]
            if isinstance(node.ops[0], ast.NotEq):
                then, other = other, then
            kl, kr = self.const(ctx, left), self.const(ctx, right)
            if kr is None and kl is not None:
                left, right, kr = right, left, kl
            if kr is not None:
                loc = self.u8loc(ctx, left)
                if loc is not None:
                    test(loc.cell, kr & 255, then, other)
                    return ops
                t = self.eval_temp(sub, left)
                test(t, kr & 255, then, other)
                ops.append(clr(t))
                prog.free(t)
                return ops
            d = prog.temp()
            self.acc(sub, d, left, 1)
            self.acc(sub, d, right, -1)
            test(d, 0, then, other)
            ops.append(clr(d))
            prog.free(d)
            return ops
        if isinstance(node, ast.BoolOp):
            values = node.values
            chain = lambda i, t, o: (lambda: self.cond(ctx, values[i], t, o))  # noqa: E731
            if isinstance(node.op, ast.And) and empty(other):
                inner = then
                for i in reversed(range(1, len(values))):
                    inner = chain(i, inner, [])
                return self.cond(ctx, values[0], inner, [])
            if isinstance(node.op, ast.Or) and empty(then):
                inner = other
                for i in reversed(range(1, len(values))):
                    inner = chain(i, [], inner)
                return self.cond(ctx, values[0], [], inner)
            r = prog.temp()
            if isinstance(node.op, ast.And):
                inner = [add(r, 1)]
                for i in reversed(range(1, len(values))):
                    inner = chain(i, inner, [])
                ops.extend(self.cond(sub, values[0], inner, []))
            else:
                for v in values:
                    ops.extend(self.cond(sub, v, [clr(r), add(r, 1)], []))
            test(r, 1, then, other)
            ops.append(clr(r))
            prog.free(r)
            return ops
        loc = self.u8loc(ctx, node)
        if loc is not None:
            test(loc.cell, 0, other, then)
            return ops
        t = self.eval_temp(sub, node)
        test(t, 0, other, then)
        ops.append(clr(t))
        prog.free(t)
        return ops

    # ------------------------------------------------------------ statements

    def block(self, ctx, stmts):
        for s in stmts:
            if ctx.state is None:
                return  # unreachable after a control transfer
            self.stmt(ctx, s)

    def branch(self, ctx, stmts):
        """Op list of a pure (split-free) statement list."""
        ops = []
        sub = ctx.sub(ops)
        self.block(sub, stmts)
        return ops

    def stmt(self, ctx, node):
        prog = self.prog
        if isinstance(node, ast.Pass):
            return
        if isinstance(node, ast.Expr):
            if isinstance(node.value, ast.Constant):
                return
            if isinstance(node.value, ast.Call):
                self.call_stmt(ctx, node.value, None)
                return
            self.err(node, "expression statement has no effect")
        if isinstance(node, ast.AnnAssign):
            if not isinstance(node.target, ast.Name):
                self.err(node, "declare plain names")
            ty = prog.type_of(node.annotation)
            if node.target.id in ctx.scope.vars:
                self.err(node, "%s declared twice" % node.target.id)
            loc = Loc(ty, ctx.owner.take(ty.size, node.target.id))
            ctx.scope.vars[node.target.id] = loc
            if node.value is not None:
                self.assign(ctx, loc, node.value, node)
            return
        if isinstance(node, ast.Assign):
            if len(node.targets) != 1:
                self.err(node, "one target per assignment")
            loc = self.lvalue(ctx, node.targets[0])
            if loc is None:
                self.err(node, "cannot assign to this")
            self.assign(ctx, loc, node.value, node)
            return
        if isinstance(node, ast.AugAssign):
            loc = self.u8loc(ctx, node.target)
            if loc is None:
                self.err(node, "augmented assignment needs a u8")
            if not isinstance(node.op, (ast.Add, ast.Sub)):
                self.err(node, "only += and -=")
            sign = 1 if isinstance(node.op, ast.Add) else -1
            if self.const(ctx, node.value) is None and self.refs(ctx, node.value, loc.cells):
                t = self.eval_temp(ctx, node.value)
                ctx.ops.append(("mov", t, [(loc.cell, sign & 255)]))
                prog.free(t)
            else:
                self.acc(ctx, loc.cell, node.value, sign)
            return
        if isinstance(node, ast.If):
            self.if_stmt(ctx, node)
            return
        if isinstance(node, ast.While):
            self.while_stmt(ctx, node)
            return
        if isinstance(node, ast.For):
            self.for_stmt(ctx, node)
            return
        if isinstance(node, ast.Match):
            self.match_stmt(ctx, node)
            return
        if isinstance(node, (ast.Break, ast.Continue)):
            if not ctx.loops:
                self.err(node, "break/continue outside a loop")
            self.goto(ctx, ctx.loops[-1][1 if isinstance(node, ast.Break) else 0])
            self.dead(ctx)
            return
        if isinstance(node, ast.Return):
            self.return_stmt(ctx, node)
            return
        self.err(node, "unsupported statement %s" % type(node).__name__)

    def is_call_to(self, value, pred):
        return isinstance(value, ast.Call) and isinstance(value.func, ast.Name) and \
            value.func.id in self.prog.funcs and pred(self.prog.funcs[value.func.id])

    def assign(self, ctx, loc, value, node):
        prog = self.prog
        if self.is_call_to(value, lambda f: not f.inline or inline_splits(prog, f)):
            self.call_stmt(ctx, value, loc)
            return
        if loc.ty is U8:
            k = self.const(ctx, value)
            if k is not None:
                ctx.ops.append(clr(loc.cell))
                if k & 255:
                    ctx.ops.append(add(loc.cell, k))
                return
            src = self.u8loc(ctx, value)
            if src is not None:
                self.copy(ctx.ops, src.cell, loc.cell)
                return
            if isinstance(value, (ast.Call, ast.Compare, ast.BoolOp)) or \
                    (isinstance(value, ast.UnaryOp) and isinstance(value.op, ast.Not)) or \
                    self.refs(ctx, value, loc.cells):
                t = self.eval_temp(ctx, value)
                ctx.ops.append(clr(loc.cell))
                ctx.ops.append(("mov", t, [(loc.cell, 1)]))
                prog.free(t)
                return
            ctx.ops.append(clr(loc.cell))
            self.acc(ctx, loc.cell, value, 1)
            return
        if isinstance(value, ast.Call) and getattr(value.func, "id", None) in ("le", "dec10"):
            k = prog.const_eval(value.args[0], ctx.scope)
            n = loc.ty.size
            if value.func.id == "le":
                vals = [(k >> (8 * i)) & 255 for i in range(n)]
            else:
                k %= 10 ** n
                vals = [(k // 10 ** i) % 10 for i in range(n)]
            for c, v in zip(loc.cells, vals):
                ctx.ops.append(clr(c))
                if v:
                    ctx.ops.append(add(c, v))
            return
        if self.is_call_to(value, lambda f: True):
            self.call_stmt(ctx, value, loc)
            return
        src = self.lvalue(ctx, value)
        if src is None or src.ty.size != loc.ty.size:
            self.err(node, "aggregate assignment needs a same-sized aggregate")
        for s, d in zip(src.cells, loc.cells):
            self.copy(ctx.ops, s, d)

    def if_stmt(self, ctx, node):
        if not splits(self.prog, node):
            then = lambda: self.branch(ctx, node.body)  # noqa: E731
            other = (lambda: self.branch(ctx, node.orelse)) if node.orelse else []
            ctx.ops.extend(self.cond(ctx, node.test, then, other))
            return
        then_st = State(self.prog, "then")
        else_st = State(self.prog, "else") if node.orelse else None
        join = State(self.prog, "join")
        ctx.ops.extend(self.cond(ctx, node.test, [("npc", then_st)], [("npc", else_st or join)]))
        for st, body in ((then_st, node.body), (else_st, node.orelse)):
            if st is None:
                continue
            self.enter(ctx, st)
            self.block(ctx, body)
            if ctx.state is not None:
                ctx.ops.append(("npc", join))
        self.enter(ctx, join)

    def while_stmt(self, ctx, node):
        prog = self.prog
        if node.orelse:
            self.err(node, "while/else is not supported")
        if not splits(prog, node):
            # A pure loop stays inside the current state as a Brainfuck loop.
            test = node.test
            loc = None
            if isinstance(test, ast.Compare) and len(test.ops) == 1 and \
                    isinstance(test.ops[0], ast.NotEq) and self.const(ctx, test.comparators[0]) == 0:
                loc = self.u8loc(ctx, test.left)
            elif isinstance(test, (ast.Name, ast.Attribute, ast.Subscript)):
                loc = self.u8loc(ctx, test)
            if loc is not None:
                ctx.ops.append(("loop", loc.cell, self.branch(ctx, node.body)))
                return
            r = prog.temp()
            ctx.ops.extend(self.cond(ctx, test, [add(r, 1)], []))
            body = [clr(r)] + self.branch(ctx, node.body)
            body.extend(self.cond(ctx, test, [add(r, 1)], []))
            ctx.ops.append(("loop", r, body))
            prog.free(r)
            return
        head = State(prog, "while")
        done = State(prog, "done")
        self.goto(ctx, head)
        if not _is_true(node.test):
            body = State(prog, "do")
            ctx.ops.extend(self.cond(ctx, node.test, [("npc", body)], [("npc", done)]))
            self.enter(ctx, body)
        ctx.loops.append((head, done))
        self.block(ctx, node.body)
        ctx.loops.pop()
        if ctx.state is not None:
            ctx.ops.append(("npc", head))
        self.enter(ctx, done)

    def for_stmt(self, ctx, node):
        """`for i in range(...)` with constant bounds, unrolled."""
        if not (isinstance(node.iter, ast.Call) and getattr(node.iter.func, "id", None) == "range"):
            self.err(node, "only for ... in range(...)")
        if not isinstance(node.target, ast.Name):
            self.err(node, "the loop variable must be a name")
        bounds = [self.prog.const_eval(a, ctx.scope) for a in node.iter.args]
        saved = ctx.scope
        for i in range(*bounds):
            ctx.scope = Scope(saved)
            ctx.scope.consts[node.target.id] = i
            self.block(ctx, node.body)
            for loc in ctx.scope.vars.values():
                ctx.owner.give(loc.cells)
            ctx.scope = saved
            if ctx.state is None:
                return

    def match_stmt(self, ctx, node):
        prog = self.prog
        cases, default = [], None
        seen = set()
        for case in node.cases:
            if case.guard is not None:
                self.err(case, "match guards are not supported")
            pat = case.pattern
            if isinstance(pat, ast.MatchAs) and pat.pattern is None and pat.name is None:
                default = case.body
                continue
            vals = []
            for p in (pat.patterns if isinstance(pat, ast.MatchOr) else [pat]):
                if not isinstance(p, ast.MatchValue):
                    self.err(case, "case values must be constants")
                v = prog.const_eval(p.value, ctx.scope) & 255
                if v in seen:
                    self.err(case, "duplicate case %d" % v)
                seen.add(v)
                vals.append(v)
            cases.append((vals, case.body))
        # The subject goes to a temporary that no case body can write, so the
        # tests form one switch.
        s = self.eval_temp(ctx, node.subject)
        pure = not splits(prog, [b for _, b in cases] + ([default] if default else []))
        need_hit = default is not None or not pure
        hit = prog.temp() if need_hit else None
        targets = []
        for vals, body in cases:
            if pure:
                for v in vals:
                    ops = self.branch(ctx, body)
                    if hit is not None:
                        ops.append(add(hit, 1))
                    ctx.ops.append(("ifeq", s, v, ops, []))
            else:
                st = State(prog, "case")
                targets.append((st, body))
                for v in vals:
                    ctx.ops.append(("ifeq", s, v, [("npc", st), add(hit, 1)], []))
        ctx.ops.append(clr(s))
        prog.free(s)
        if pure:
            if hit is not None:
                ctx.ops.append(("ifeq", hit, 0, self.branch(ctx, default), []))
                ctx.ops.append(clr(hit))
                prog.free(hit)
            return
        join = State(prog, "join")
        rest = join
        if default is not None:
            rest = State(prog, "default")
            targets.append((rest, default))
        ctx.ops.append(("ifeq", hit, 0, [("npc", rest)], []))
        ctx.ops.append(clr(hit))
        prog.free(hit)
        for st, body in targets:
            self.enter(ctx, st)
            self.block(ctx, body)
            if ctx.state is not None:
                ctx.ops.append(("npc", join))
        self.enter(ctx, join)

    # ------------------------------------------------------------ calls

    def call_stmt(self, ctx, node, result):
        prog = self.prog
        name = getattr(node.func, "id", None)
        if name in BUILTINS:
            if result is not None:
                if name != "getc" or result.ty is not U8:
                    self.err(node, "%s returns nothing" % name)
                ctx.ops.append(("outk", [DEV_GETC]))
                ctx.ops.append(("in", result.cell))
                return
            BUILTINS[name](self, ctx, node)
            return
        f = prog.funcs.get(name)
        if f is None:
            self.err(node, "unknown function %s" % name)
        if len(node.args) != len(f.params) or node.keywords:
            self.err(node, "%s takes %d arguments" % (name, len(f.params)))
        if not f.inline:
            self.real_call(ctx, f, node, result)
            return
        res = self.inline_call(ctx, f, node)
        if result is not None:
            if res is None or res.ty.size != result.ty.size:
                self.err(node, "%s: result type mismatch" % name)
            for s, d in zip(res.cells, result.cells):
                ctx.ops.append(clr(d))
                ctx.ops.append(("mov", s, [(d, 1)]))
        if res is not None:
            ctx.owner.give(res.cells)

    def out_arg(self, ctx, pty, arg, node):
        """Ops writing an argument's bytes to the device."""
        k = self.const(ctx, arg)
        if pty is U8 and k is not None:
            ctx.ops.append(("outk", [k & 255]))
            return
        if isinstance(arg, ast.Call) and getattr(arg.func, "id", None) in ("le", "dec10"):
            n = pty.size
            k = self.prog.const_eval(arg.args[0], ctx.scope)
            if arg.func.id == "le":
                vals = [(k >> (8 * i)) & 255 for i in range(n)]
            else:
                k %= 10 ** n
                vals = [(k // 10 ** i) % 10 for i in range(n)]
            ctx.ops.append(("outk", vals))
            return
        loc = self.lvalue(ctx, arg)
        if loc is not None:
            if loc.ty.size != pty.size:
                self.err(node, "argument type mismatch")
            ctx.ops.extend(("out", c) for c in loc.cells)
            return
        if pty is not U8:
            self.err(arg, "aggregate arguments must be variables")
        t = self.eval_temp(ctx, arg)
        ctx.ops += [("out", t), clr(t)]
        self.prog.free(t)

    def real_call(self, ctx, f, node, result):
        """Arguments and results travel through the device's argument and
        result buffers, so a call's Brainfuck stays next to the cells of the
        function that makes it."""
        caller = ctx.owner
        size = sum(pty.size for _, pty in f.params)
        if size:
            ctx.ops.append(("outk", [DEV_ARGW, size]))
            for (_, pty), arg in zip(f.params, node.args):
                self.out_arg(ctx, pty, arg, node)
        save = f.name in caller.recursive_callees
        if save:
            ctx.ops.append(("save", caller))
        cont = State(self.prog, "ret")
        ctx.ops.append(("setret", f, cont))
        ctx.ops.append(("npc", f.entry))
        self.enter(ctx, cont)
        if save:
            ctx.ops.append(("restore", caller))
        if result is not None:
            if f.ret_ty is None or f.ret_ty.size != result.ty.size:
                self.err(node, "%s: result type mismatch" % f.name)
            ctx.ops.append(("outk", [DEV_RETR, result.ty.size]))
            ctx.ops.extend(("in", c) for c in result.cells)

    def inline_call(self, ctx, f, node):
        """Expands inline function `f` in place. Parameters alias l-value
        arguments; other arguments get frame cells. Returns the result Loc
        (frame cells the caller gives back) or None."""
        if len(node.args) != len(f.params):
            self.err(node, "%s takes %d arguments" % (f.name, len(f.params)))
        scope = Scope(None)
        owned = []
        for (pname, pty), arg in zip(f.params, node.args):
            loc = self.lvalue(ctx, arg)
            if loc is not None:
                if loc.ty.size != pty.size:
                    self.err(arg, "argument %s: expected %s" % (pname, pty.name))
                scope.vars[pname] = Loc(pty, loc.cells)
                continue
            cells = ctx.owner.take(pty.size, pname)
            owned.append(cells)
            ploc = Loc(pty, cells)
            self.assign(ctx, ploc, arg, arg)
            scope.vars[pname] = ploc
        params = {p for p, _ in f.params}
        body = f.node.body
        ret = None
        if body and isinstance(body[-1], ast.Return):
            ret, body = body[-1], body[:-1]
        sub = Ctx(f, ctx.owner, scope, ctx.ops, ctx.state)
        self.block(sub, body)
        if sub.state is None:
            self.err(node, "inline function %s must fall through to its end" % f.name)
        ctx.state, ctx.ops = sub.state, sub.ops
        res = None
        if ret is not None and ret.value is not None:
            if f.ret_ty is None:
                self.err(ret, "%s has no return type" % f.name)
            res = Loc(f.ret_ty, ctx.owner.take(f.ret_ty.size, "ret"))
            self.assign(sub, res, ret.value, ret)
            ctx.state, ctx.ops = sub.state, sub.ops
        for name, loc in scope.vars.items():
            if name not in params:
                ctx.owner.give(loc.cells)
        for cells in owned:
            ctx.owner.give(cells)
        return res

    def return_stmt(self, ctx, node):
        f = ctx.owner
        if ctx.func.inline:
            self.err(node, "return in an inline function must be its last statement")
        if node.value is not None:
            if f.retval is None:
                self.err(node, "%s has no return type" % f.name)
            self.assign(ctx, f.retval, node.value, node)
            ctx.ops.append(("outk", [DEV_RETW, f.retval.ty.size]))
            ctx.ops.extend(("out", c) for c in f.retval.cells)
        ctx.ops.append(("ret", f))
        self.dead(ctx)


# ---------------------------------------------------------------- builtins

def _out_value(low, ctx, node):
    k = low.const(ctx, node)
    if k is not None:
        ctx.ops.append(("outk", [k & 255]))
        return
    loc = low.u8loc(ctx, node)
    if loc is not None:
        ctx.ops.append(("out", loc.cell))
        return
    t = low.eval_temp(ctx, node)
    ctx.ops.append(("out", t))
    ctx.ops.append(clr(t))
    low.prog.free(t)


def _out_vars(low, ctx, nodes):
    for a in nodes:
        loc = low.lvalue(ctx, a)
        if loc is None:
            low.err(a, "expected a variable")
        ctx.ops.extend(("out", c) for c in loc.cells)


def _ptr(low, ctx, node):
    loc = low.lvalue(ctx, node)
    if loc is None or loc.ty.size != 4:
        low.err(node, "expected a 4-byte address variable")
    return loc


def _text(low, ctx, node):
    s = low.prog.try_const(node.args[0], ctx.scope)
    if not isinstance(s, str):
        low.err(node, "expected a constant string")
    data = list(s.encode("utf-8"))
    if 0 in data:
        low.err(node, "strings cannot hold NUL")
    return data


def b_getc(low, ctx, node):
    t = low.prog.temp()
    ctx.ops += [("outk", [DEV_GETC]), ("in", t), clr(t)]
    low.prog.free(t)


def b_putc(low, ctx, node):
    ctx.ops.append(("outk", [DEV_PUTC]))
    _out_value(low, ctx, node.args[0])


def b_puts(low, ctx, node):
    data = _text(low, ctx, node)
    if data:
        ctx.ops.append(("outk", [DEV_PUTS] + data + [0]))


def b_diag(low, ctx, node):
    for b in _text(low, ctx, node):
        ctx.ops.append(("outk", [DEV_DIAG, b]))


def b_diagc(low, ctx, node):
    ctx.ops.append(("outk", [DEV_DIAG]))
    _out_value(low, ctx, node.args[0])


def _range(low, ctx, node, loc):
    """load/store's optional byte range [lo, hi) of the variable; the
    address then points at byte 0 and must be 64-aligned (lo < 64)."""
    if len(node.args) == 2:
        return 0, loc.ty.size
    lo, hi = (low.prog.const_eval(a, ctx.scope) for a in node.args[2:4])
    if not 0 <= lo < hi <= loc.ty.size or lo >= 64:
        low.err(node, "bad byte range")
    return lo, hi


def _out_address(low, ctx, a, lo):
    """The address a + lo, a 64-aligned (no carry out of byte 0)."""
    if lo == 0:
        ctx.ops.extend(("out", c) for c in a.cells)
        return
    t = low.prog.temp()
    low.copy_add(ctx.ops, a.cells[0], t, 1)
    ctx.ops += [add(t, lo), ("out", t), clr(t)]
    low.prog.free(t)
    ctx.ops.extend(("out", c) for c in a.cells[1:])


def b_load(low, ctx, node):
    """load(variable, address[, lo, hi]): the variable's bytes from memory."""
    d, a = low.lvalue(ctx, node.args[0]), _ptr(low, ctx, node.args[1])
    if d is None or not 0 < d.ty.size < 256:
        low.err(node, "load(variable, address)")
    lo, hi = _range(low, ctx, node, d)
    ctx.ops.append(("outk", [DEV_LOAD]))
    _out_address(low, ctx, a, lo)
    ctx.ops.append(("outk", [hi - lo]))
    ctx.ops.extend(("in", c) for c in d.cells[lo:hi])


def b_store(low, ctx, node):
    """store(variable, address[, lo, hi]): the variable's bytes to memory."""
    s, a = low.lvalue(ctx, node.args[0]), _ptr(low, ctx, node.args[1])
    if s is None or not 0 < s.ty.size < 256:
        low.err(node, "store(variable, address)")
    lo, hi = _range(low, ctx, node, s)
    ctx.ops.append(("outk", [DEV_STORE]))
    _out_address(low, ctx, a, lo)
    ctx.ops.append(("outk", [hi - lo]))
    ctx.ops.extend(("out", c) for c in s.cells[lo:hi])


def b_store8(low, ctx, node):
    """store8(address, value): one byte."""
    a = _ptr(low, ctx, node.args[0])
    ctx.ops.append(("outk", [DEV_STORE]))
    ctx.ops.extend(("out", c) for c in a.cells)
    ctx.ops.append(("outk", [1]))
    _out_value(low, ctx, node.args[1])


def b_mcopy(low, ctx, node):
    """mcopy(start, end, dst): memmove of [start, end) to dst."""
    for a in node.args:
        _ptr(low, ctx, a)
    ctx.ops.append(("outk", [DEV_COPY]))
    _out_vars(low, ctx, node.args)


def b_mdiff(low, ctx, node):
    """mdiff(start, end, other, result): result = first address in
    [start, end) whose byte differs from the byte at the same distance from
    `other`, else end."""
    for a in node.args:
        _ptr(low, ctx, a)
    ctx.ops.append(("outk", [DEV_DIFF]))
    _out_vars(low, ctx, node.args[:3])
    ctx.ops.extend(("in", c) for c in low.lvalue(ctx, node.args[3]).cells)


def b_halt(low, ctx, node):
    ctx.ops.append(("outk", [DEV_EXIT]))
    _out_value(low, ctx, node.args[0])
    ctx.ops.append(("halt",))
    low.dead(ctx)


def b_slurp(low, ctx, node):
    """slurp(address, end): job bytes through the next NUL to memory."""
    _ptr(low, ctx, node.args[0])
    ctx.ops.append(("outk", [DEV_SLURP]))
    _out_vars(low, ctx, node.args[:1])
    ctx.ops.extend(("in", c) for c in _ptr(low, ctx, node.args[1]).cells)


def b_source(low, ctx, node):
    """source(address): getc() reads memory from address on."""
    _ptr(low, ctx, node.args[0])
    ctx.ops.append(("outk", [DEV_SOURCE]))
    _out_vars(low, ctx, node.args[:1])


def b_jobsrc(low, ctx, node):
    ctx.ops.append(("outk", [DEV_JOB]))


def b_select(low, ctx, node):
    ctx.ops.append(("outk", [DEV_SELECT]))
    _out_value(low, ctx, node.args[0])


BUILTINS = {"slurp": b_slurp, "source": b_source, "jobsrc": b_jobsrc, "select": b_select,
            "getc": b_getc, "putc": b_putc, "puts": b_puts, "diag": b_diag, "diagc": b_diagc,
            "load": b_load, "store": b_store, "store8": b_store8, "mcopy": b_mcopy, "mdiff": b_mdiff,
            "halt": b_halt}


# ---------------------------------------------------------------- program assembly

def compile_program(prog):
    build_call_graph(prog)
    if "main" not in prog.funcs or prog.funcs["main"].inline:
        raise BflError("no main()")
    prog.owner = "sys"
    prog.RUN, prog.PC0, prog.PC1, prog.NPC0, prog.NPC1, prog.IO = prog.alloc(6, "sys")
    for c, n in zip((prog.RUN, prog.PC0, prog.PC1, prog.NPC0, prog.NPC1, prog.IO),
                    ("RUN", "PC0", "PC1", "NPC0", "NPC1", "IO")):
        prog.cell_names[c] = n
    prog.level(0)
    prog.level(1)
    prog.SP = Loc(ArrTy(U8, 4), prog.alloc(4, "SP"))
    trap = State(prog, "trap")          # state 0: a jump nobody set
    trap.ops += [("outk", [DEV_EXIT, 255]), ("halt",)]
    funcs = [f for f in prog.funcs.values() if not f.inline]
    for f in funcs:
        prog.owner = f.name
        f.io = prog.alloc(1, f.name + ".io")[0]
        f.entry = State(prog, f.name)
        f.ret = prog.alloc(2, f.name + ".ret")
        f.param_locs = [Loc(pty, f.take(pty.size, pname)) for pname, pty in f.params]
        if f.ret_ty is not None:
            f.retval = Loc(f.ret_ty, prog.alloc(f.ret_ty.size, f.name + ".rv"))
    low = Lower(prog)
    for f in funcs:
        first = len(prog.states)
        prog.owner = f.name
        prog.file = f.file
        prog.temps_free = []    # temporaries stay inside the function's cells
        scope = Scope(None)
        for (pname, _), loc in zip(f.params, f.param_locs):
            scope.vars[pname] = loc
        ctx = Ctx(f, f, scope, f.entry.ops, f.entry)
        size = sum(pty.size for _, pty in f.params)
        if size:
            ctx.ops.append(("outk", [DEV_ARGR, size]))
            for loc in f.param_locs:
                ctx.ops.extend(("in", c) for c in loc.cells)
        low.block(ctx, f.node.body)
        if ctx.state is not None:
            if f.name == "main":
                ctx.ops += [("outk", [DEV_EXIT, 0]), ("halt",)]
            else:
                ctx.ops.append(("ret", f))
        states = prog.states[first:] + [f.entry]
        for st in states:
            st.func = f
        need = max(ifeq_depth(st.ops) for st in states)
        f.levels = [tuple(prog.alloc(2, "%s.lv%d" % (f.name, i))) for i in range(need)]
    trap.func = None
    layout(prog, funcs)
    for f in funcs:
        if len(f.frame()) > FRAME - 1:
            raise BflError("%s: frame of %d cells is too large" % (f.name, len(f.frame())))
    return emit(prog)


# ---------------------------------------------------------------- Brainfuck emission

class Emitter:
    """Writes Brainfuck. Helper methods take tape addresses; ops() takes
    op lists over virtual cells and translates them."""

    def __init__(self, prog):
        self.prog = prog
        self.P = prog.phys
        self.parts = []
        self.pos = 0
        self.levels = []
        self.io = None

    def w(self, s):
        self.parts.append(s)

    def goto(self, c):
        d = c - self.pos
        self.w(">" * d if d > 0 else "<" * -d)
        self.pos = c

    def add(self, c, k):
        k &= 255
        if k:
            self.goto(c)
            self.w("+" * k if k <= 128 else "-" * (256 - k))

    def clr(self, c):
        self.goto(c)
        self.w("[-]")

    def mov(self, src, dsts):
        merged = {}
        for d, k in dsts:
            assert d != src, (src, dsts)
            merged[d] = (merged.get(d, 0) + k) & 255
        self.goto(src)
        self.w("[-")
        for d, k in merged.items():
            self.add(d, k)
        self.goto(src)
        self.w("]")

    def cadd(self, src, dst, k, idiom=False):
        """dst += src * k through a copy temporary. The equality test's copy
        must be the copy idiom (temporary above dst); any other copy uses the
        temporary nearest src, which halves the pointer's travel."""
        if idiom:
            t = tcell_above(max(src, dst))
        else:
            t = tcell_above(src)
            below = src - src % TSTRIDE - 1
            if below >= 0 and below != dst and src - below < t - src:
                t = below
            if t == dst:
                t = tcell_above(max(src, dst) + TSTRIDE)
        assert t != src
        self.mov(src, [(dst, k), (t, 1)])
        self.mov(t, [(src, 1)])

    def test(self, f, e, s, val, then_fn, other_fn):
        """The equality idiom: f := s, f -= val, e = 1,
        if f {e = 0; other; f = 0}, if e {then; e = 0}."""
        assert s not in (f, e)
        self.cadd(s, f, 1, idiom=True)
        self.add(f, -val)
        self.add(e, 1)
        self.goto(f)
        self.w("[")
        self.clr(e)
        other_fn()
        self.clr(f)
        self.goto(f)
        self.w("]")
        self.goto(e)
        self.w("[")
        then_fn()
        self.clr(e)
        self.goto(e)
        self.w("]")

    def ops(self, ops, depth):
        prog, V = self.prog, self.P
        for op in ops:
            k = op[0]
            if k == "clr":
                self.clr(V[op[1]])
            elif k == "add":
                self.add(V[op[1]], op[2])
            elif k == "mov":
                self.mov(V[op[1]], [(V[d], n) for d, n in op[2]])
            elif k == "cadd":
                self.cadd(V[op[1]], V[op[2]], op[3])
            elif k == "in":
                self.goto(V[op[1]])
                self.w(",")
            elif k == "out":
                self.goto(V[op[1]])
                self.w(".")
            elif k == "outk":
                v = 0
                for b in op[1]:
                    self.add(self.io, b - v)
                    v = b
                    self.goto(self.io)
                    self.w(".")
                if v:
                    self.clr(self.io)
            elif k == "ifeq":
                f, e = self.levels[depth]
                self.test(f, e, V[op[1]], op[2], lambda: self.ops(op[3], depth + 1),
                          lambda: self.ops(op[4], depth + 1))
            elif k == "loop":
                c = V[op[1]]
                self.goto(c)
                self.w("[")
                self.ops(op[2], depth)
                self.goto(c)
                self.w("]")
            elif k == "npc":
                self.add(V[prog.NPC0], op[1].id & 255)
                if prog.wide:
                    self.add(V[prog.NPC1], op[1].id >> 8)
            elif k == "setret":
                f, st = op[1], op[2]
                self.ops([clr(f.ret[0]), clr(f.ret[1]), add(f.ret[0], st.id & 255),
                          add(f.ret[1], st.id >> 8)], depth)
            elif k == "ret":
                f = op[1]
                self.mov(V[f.ret[0]], [(V[prog.NPC0], 1)])
                if prog.wide:
                    self.mov(V[f.ret[1]], [(V[prog.NPC1], 1)])
                else:
                    self.clr(V[f.ret[1]])
            elif k == "save":
                cells = op[1].frame()
                self.ops([("outk", [DEV_STORE])] + [("out", c) for c in prog.SP.cells] +
                         [("outk", [len(cells)])] + [("out", c) for c in cells] +
                         sp_step(prog, +1), depth)
            elif k == "restore":
                cells = op[1].frame()
                self.ops(sp_step(prog, -1) + [("outk", [DEV_LOAD])] +
                         [("out", c) for c in prog.SP.cells] + [("outk", [len(cells)])] +
                         [("in", c) for c in cells], depth)
            elif k == "halt":
                self.clr(V[prog.RUN])
            else:
                raise BflError("unknown op %r" % (op,))


def tcell_above(c):
    return c - c % TSTRIDE + TSTRIDE - 1


ZERO_SLOTS = (1, 5, 9, 13)     # zero-class addresses within each 16-cell group


def zero_class(prog, c):
    """Cells that are zero at every state boundary: temporaries, test
    flags and I/O cells."""
    n = prog.cell_names[c]
    return n == "tmp" or n == "IO" or n.endswith(".io") or n.startswith("lv") or ".lv" in n


def layout(prog, funcs):
    """Tape addresses. Every 16-cell group holds one copy temporary (15),
    four zero-class cells and eleven value cells.

    Value cells: dispatch registers and globals first, then function frames
    laid out like a static call stack: a frame sits above every frame that
    can call it, so functions never active at the same time share cells.
    Members of a recursive cycle get disjoint frames (recursion saves them).

    Zero-class cells are zero between states, so any functions may share
    them; each function takes the ones nearest its frame."""
    value_pos = [a for a in range(1 << 20) if a % TSTRIDE != TSTRIDE - 1 and a % TSTRIDE not in ZERO_SLOTS]
    zero_pos = [a for a in range(1 << 20) if a % TSTRIDE in ZERO_SLOTS]
    groups, zgroups = {}, {}
    for c in range(prog.next_cell):
        (zgroups if zero_class(prog, c) else groups).setdefault(prog.cell_owner[c], []).append(c)

    graph = {f.name: prog.graph[f.name] for f in funcs}
    order = [f.name for f in funcs]
    index, low, stack, on, comp, comps = {}, {}, [], set(), {}, []

    def visit(v):
        index[v] = low[v] = len(index)
        stack.append(v)
        on.add(v)
        for w in sorted(graph[v]):
            if w not in index:
                visit(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            members = []
            while True:
                w = stack.pop()
                on.discard(w)
                comp[w] = len(comps)
                members.append(w)
                if w == v:
                    break
            comps.append(sorted(members, key=order.index))

    sys.setrecursionlimit(max(10000, sys.getrecursionlimit()))
    for f in funcs:
        if f.name not in index:
            visit(f.name)
    size = {n: len(groups.get(n, [])) for n in graph}
    csize = [sum(size[m] for m in members) for members in comps]
    preds = {i: set() for i in range(len(comps))}
    for v in graph:
        for w in graph[v]:
            if comp[v] != comp[w]:
                preds[comp[w]].add(comp[v])
    base = {}
    for i in reversed(range(len(comps))):        # Tarjan lists callees first
        base[i] = max((base[q] + csize[q] for q in preds[i]), default=0)

    prog.phys = {}
    # Globals, coldest first, then the dispatch registers, then the frames:
    # the hottest globals and the registers every state visits end up next
    # to the frames.
    uses = {}

    def count(ops):
        for op in ops:
            for x in op[1:]:
                if isinstance(x, int):
                    uses[x] = uses.get(x, 0) + 1
                elif isinstance(x, list):
                    for y in x:
                        if isinstance(y, tuple) and y and isinstance(y[0], str):
                            count([y])
                        elif isinstance(y, tuple):
                            uses[y[0]] = uses.get(y[0], 0) + 1
                        elif isinstance(y, int):
                            uses[y] = uses.get(y, 0) + 1

    for st in prog.states:
        count(st.ops)
    n = 0
    for c in sorted(groups.get(None, []), key=lambda c: (uses.get(c, 0), c)) + groups.get("sys", []):
        prog.phys[c] = value_pos[n]
        n += 1
    area = n
    span = {}
    for i, members in enumerate(comps):
        off = area + base[i]
        for m in members:
            cells = groups.get(m, [])
            for c in cells:
                prog.phys[c] = value_pos[off]
                off += 1
            first = prog.phys[cells[0]] if cells else value_pos[area + base[i]]
            last = prog.phys[cells[-1]] if cells else first
            span[m] = (first + last) // 2
    # Zero-class cells: the dispatch ones next to the dispatch registers,
    # then per function the free zero positions closest to its frame.
    sys_at = value_pos[area - 1] if area else 0
    zi = max(0, next(j for j, a in enumerate(zero_pos) if a >= sys_at) - len(zgroups.get("sys", [])) // 2)
    first_z = zi
    for key in ["sys", None]:
        for c in zgroups.get(key, []):
            prog.phys[c] = zero_pos[zi]
            zi += 1
    reserved = set(zero_pos[first_z:zi])
    for f in funcs:
        cells = zgroups.get(f.name, [])
        if not cells:
            continue
        mid = span.get(f.name, 0)
        # Hot cells (I/O, then flags by depth) get the nearest positions.
        cells.sort(key=lambda c: (0 if prog.cell_names[c].endswith(".io") else
                                  1 if ".lv" in prog.cell_names[c] else 2, c))
        k = next(j for j, a in enumerate(zero_pos) if a >= mid)
        lo, hi = k - 1, k
        for c in cells:
            while True:
                if lo >= 0 and (hi >= len(zero_pos) or mid - zero_pos[lo] <= zero_pos[hi] - mid):
                    a, lo = zero_pos[lo], lo - 1
                else:
                    a, hi = zero_pos[hi], hi + 1
                if a not in reserved:
                    break
            prog.phys[c] = a
    last = max(prog.phys.values(), default=0)
    prog.tape_cells = last - last % TSTRIDE + TSTRIDE


def ifeq_depth(ops):
    """Deepest nesting of equality tests in an op list (flag cells needed)."""
    best = 0
    for op in ops:
        if op[0] == "ifeq":
            best = max(best, 1 + ifeq_depth(op[3]), 1 + ifeq_depth(op[4]))
        elif op[0] == "loop":
            best = max(best, ifeq_depth(op[2]))
        elif op[0] in ("save", "restore"):
            best = max(best, 2)
    return best


def sp_step(prog, sign):
    """SP += sign * 256 (frames are 256 bytes; SP stays 256-aligned)."""
    _, s1, s2, s3 = prog.SP.cells
    if sign > 0:
        return [add(s1, 1), ("ifeq", s1, 0, [add(s2, 1), ("ifeq", s2, 0, [add(s3, 1)], [])], [])]
    return [("ifeq", s1, 0, [("ifeq", s2, 0, [add(s3, -1)], []), add(s2, -1)], []), add(s1, -1)]


def emit(prog):
    prog.wide = len(prog.states) > 256
    e = Emitter(prog)
    V = prog.phys
    main = prog.funcs["main"]
    init = [add(prog.RUN, 1), ("npc", main.entry)]
    init += [add(c, (STACK_BASE >> (8 * i)) & 255) for i, c in enumerate(prog.SP.cells)]
    for name, (loc, value) in prog.globals.items():
        if value is not None:
            if loc.ty is not U8:
                raise BflError("only u8 globals take initial values")
            init.append(add(loc.cell, value))
    e.ops(init, 0)
    e.w("\n")
    e.goto(V[prog.RUN])
    e.w("[\n")
    body = [clr(prog.PC0), ("mov", prog.NPC0, [(prog.PC0, 1)])]
    if prog.wide:
        body += [clr(prog.PC1), ("mov", prog.NPC1, [(prog.PC1, 1)])]
    e.ops(body, 0)
    e.w("\n")
    by_hi = {}
    for st in prog.states:
        by_hi.setdefault(st.id >> 8, []).append(st)
    hf, he = (V[c] for c in prog.level(0))
    lf, le_ = (V[c] for c in prog.level(1 if prog.wide else 0))

    def state(st):
        f = st.func
        e.levels = [(V[a], V[b]) for a, b in f.levels] if f else []
        e.io = V[f.io] if f else V[prog.IO]
        e.ops(st.ops, 0)

    def cases(chain):
        for st in chain:
            # One dispatch case per state: `if (pc == id)` with no else.
            e.test(lf, le_, V[prog.PC0], st.id & 255, lambda st=st: state(st), lambda: None)
            e.w("\n")

    for hi in sorted(by_hi):
        if prog.wide:
            e.test(hf, he, V[prog.PC1], hi, lambda hi=hi: cases(by_hi[hi]), lambda: None)
            e.w("\n")
        else:
            cases(by_hi[hi])
    e.goto(V[prog.RUN])
    e.w("]\n")
    return "".join(e.parts)


def write_map(prog, path):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("cells %d states %d\n" % (prog.tape_cells, len(prog.states)))
        for st in prog.states:
            f.write("state %d %s %s\n" % (st.id, st.label, st.func.name if st.func else "-"))
        for c in sorted(prog.cell_names, key=lambda c: prog.phys[c]):
            f.write("cell %d %s\n" % (prog.phys[c], prog.cell_names[c]))


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
COMPILER = os.path.join(ROOT, "brainfuck", "compiler")
# The compiler's sources, in declaration order.
SOURCES = ["lib.bfl", "ir.bfl", "prop.bfl", "lint.bfl", "emit.bfl"]
OUTPUT = os.path.join(COMPILER, "bfcc.bf")
HEADER = ("bfcc: the Brainfuck compiler of GmailHideAds; generated by tools/bfcc/bflc "
          "from brainfuck/compiler/*bfl and not to be edited\n")


def build_compiler():
    """(Brainfuck text of bfcc, Program) from brainfuck/compiler/*.bfl."""
    prog = load_program([os.path.join(COMPILER, n) for n in SOURCES])
    text = HEADER + compile_program(prog)
    assert not set(HEADER) & set("+-<>[].,")
    return text, prog


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description="Compiles BFL to Brainfuck. With no sources, "
                                 "builds brainfuck/compiler/bfcc.bf.")
    ap.add_argument("sources", nargs="*")
    ap.add_argument("-o")
    ap.add_argument("--map")
    ap.add_argument("--check", action="store_true", help="fail when bfcc.bf is stale")
    args = ap.parse_args(argv)
    try:
        if args.sources:
            prog = load_program(args.sources)
            text = compile_program(prog)
        else:
            text, prog = build_compiler()
    except BflError as e:
        print("bflc: %s" % e, file=sys.stderr)
        return 1
    out = args.o or (None if args.sources else OUTPUT)
    if out is None:
        ap.error("-o is required with explicit sources")
    if args.check:
        with open(out, encoding="utf-8", newline="") as f:
            if f.read() != text:
                print("bflc: %s is stale; run python tools/bfcc/bflc.py" % os.path.relpath(out, ROOT))
                return 1
    else:
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    if args.map:
        write_map(prog, args.map)
    print("bflc: %d commands, %d cells, %d states" % (
        sum(text.count(c) for c in "+-<>[].,"), prog.tape_cells, len(prog.states)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
