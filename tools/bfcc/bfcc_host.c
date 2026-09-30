/*
 * Host for a Brainfuck program compiled to C: the operating-system facilities
 * Brainfuck lacks, reached through `,` and `.` only. It is a device, not a
 * compiler: it moves bytes between the job, a large paged memory, output
 * streams and the program, and never interprets what the bytes mean.
 *
 * The program writes a command with `.` and reads the answer with `,`:
 *
 *   1 GETC                    -> next input byte, 0 after the end
 *   2 PUTC b                     append b to the current output stream
 *   3 LOAD a0..a3 n           -> n bytes of memory at address a (n < 256)
 *   4 STORE a0..a3 n b1..bn      write n bytes at address a
 *   5 COPY s e d                 memmove [s, e) to d (addresses 4 bytes each)
 *   6 DIFF s e o              -> first x in [s, e) with memory[x] !=
 *                                memory[o + (x - s)], else e
 *   7 EXIT code                  the program's result (0 = success)
 *   8 PUTS b1..bn 0              append b1..bn to the current output stream
 *   9 DIAG b                     append b to the diagnostics
 *  10 SLURP a                 -> copy job bytes up to and including the
 *                                next NUL to memory at a; answer the address
 *                                after the NUL
 *  11 SOURCE a                   GETC now reads memory from address a on
 *  12 JOB                        GETC reads the job again
 *  13 SELECT k                   output goes to stream k (0..3)
 *  14 ARGW n b1..bn              the arguments of a call (n < 256)
 *  15 ARGR n                  -> the arguments of the call
 *  16 RETW n b1..bn              the result of a return
 *  17 RETR n                  -> the result of the return
 *
 * Addresses are 32-bit little endian; memory is zero until written.
 * docs/BFCC.md documents the protocol; tools/bfcc/bflc.py emits it.
 *
 * The program's C is included: BFCC_PROGRAM names the file, BFCC_ENTRY its
 * function, BFCC_TAPE its tape size. By default that is the compiler itself,
 * so `cc -O2 bfcc_host.c bfcc_main.c -o bfcc` builds bfcc from the committed
 * bfcc.generated.c.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "bfcc_host.h"

#ifndef BFCC_PROGRAM
#define BFCC_PROGRAM "bfcc.generated.c"
#define BFCC_ENTRY bf_prog_bfcc
#endif
#ifndef BFCC_TAPE
#define BFCC_TAPE 65536
#endif

/* ------------------------------------------------------------------ memory */

#define PAGE_BITS 16
#define PAGE_SIZE (1u << PAGE_BITS)
#define PAGES (1u << (32 - PAGE_BITS))
#define MEMORY_LIMIT (2048u * 1024u * 1024u)

static uint8_t *pages[PAGES];
static size_t allocated;

static void fail(const char *what)
{
    fprintf(stderr, "bfcc: %s\n", what);
    exit(70);
}

static uint8_t *page(uint32_t addr, int create)
{
    uint8_t **slot = &pages[addr >> PAGE_BITS];
    if (*slot == NULL && create) {
        if (allocated + PAGE_SIZE > MEMORY_LIMIT) {
            fail("memory limit exceeded");
        }
        *slot = calloc(1, PAGE_SIZE);
        if (*slot == NULL) {
            fail("out of memory");
        }
        allocated += PAGE_SIZE;
    }
    return *slot;
}

static uint8_t mem_get(uint32_t addr)
{
    uint8_t *p = pages[addr >> PAGE_BITS];
    return p == NULL ? 0 : p[addr & (PAGE_SIZE - 1)];
}

static void mem_set(uint32_t addr, uint8_t v)
{
    if (v == 0 && pages[addr >> PAGE_BITS] == NULL) {
        return;
    }
    page(addr, 1)[addr & (PAGE_SIZE - 1)] = v;
}

static uint32_t room(uint32_t addr)
{
    return PAGE_SIZE - (addr & (PAGE_SIZE - 1));
}

static void mem_move(uint32_t s, uint32_t e, uint32_t d)
{
    if (e < s) {
        fail("COPY with end before start");
    }
    uint32_t n = e - s;
    if (n == 0 || s == d) {
        return;
    }
    if (d < s || d - s >= n) {
        /* Forward, page chunk by page chunk. */
        while (n) {
            uint32_t k = n;
            if (room(s) < k) k = room(s);
            if (room(d) < k) k = room(d);
            uint8_t *ps = page(s, 0);
            if (ps == NULL && page(d, 0) == NULL) {
                /* zero onto zero */
            } else if (ps == NULL) {
                memset(page(d, 1) + (d & (PAGE_SIZE - 1)), 0, k);
            } else {
                memmove(page(d, 1) + (d & (PAGE_SIZE - 1)), ps + (s & (PAGE_SIZE - 1)), k);
            }
            s += k;
            d += k;
            n -= k;
        }
    } else {
        for (uint32_t i = n; i-- > 0;) {
            mem_set(d + i, mem_get(s + i));
        }
    }
}

static uint32_t mem_diff(uint32_t s, uint32_t e, uint32_t o)
{
    while (s != e) {
        uint32_t k = e - s;
        if (room(s) < k) k = room(s);
        if (room(o) < k) k = room(o);
        uint8_t *pa = page(s, 0);
        uint8_t *pb = page(o, 0);
        if (pa != NULL || pb != NULL) {
            for (uint32_t i = 0; i < k; i++) {
                uint8_t a = pa ? pa[(s & (PAGE_SIZE - 1)) + i] : 0;
                uint8_t b = pb ? pb[(o & (PAGE_SIZE - 1)) + i] : 0;
                if (a != b) {
                    return s + i;
                }
            }
        }
        s += k;
        o += k;
    }
    return e;
}

/* ------------------------------------------------------------------ buffers */

static void buf_put(bfcc_buf *b, uint8_t v)
{
    if (b->len == b->cap) {
        b->cap = b->cap ? b->cap * 2 : 4096;
        b->data = realloc(b->data, b->cap);
        if (b->data == NULL) {
            fail("out of memory");
        }
    }
    b->data[b->len++] = v;
}

/* ------------------------------------------------------------------ device */

static const uint8_t *job;
static size_t job_len, job_pos;
static int from_memory;
static uint32_t cursor;
static bfcc_buf out[BFCC_STREAMS], diag;
static int stream;
static int exit_code = -1;

static uint8_t cmd[16];
static int cmd_len, cmd_need;
static uint8_t resp[256];
static int resp_len, resp_pos;
static int puts_mode;
static uint32_t store_addr, store_left;
static uint8_t args[2][256], *write_to;
static uint32_t write_left;
static uint64_t steps;

static uint32_t u32_at(const uint8_t *p)
{
    return (uint32_t) p[0] | (uint32_t) p[1] << 8 | (uint32_t) p[2] << 16 | (uint32_t) p[3] << 24;
}

static void answer_u32(uint32_t v)
{
    resp[0] = (uint8_t) v;
    resp[1] = (uint8_t) (v >> 8);
    resp[2] = (uint8_t) (v >> 16);
    resp[3] = (uint8_t) (v >> 24);
    resp_len = 4;
    resp_pos = 0;
}

static uint64_t cmd_count[32], outs, ins;
#ifdef BFCC_PROFILE
static const uint8_t *prof_tape;
static uint64_t io_profile[65536];
#define IO_PROFILE() (io_profile[prof_tape[BFCC_PC0] | prof_tape[BFCC_PC1] << 8]++)
#else
#define IO_PROFILE() ((void) 0)
#endif

static void execute(void)
{
    cmd_count[cmd[0] & 31]++;
    if (resp_pos != resp_len) {
        fail("protocol: a new command before the last answer was read");
    }
    switch (cmd[0]) {
    case BFCC_GETC:
        if (from_memory) {
            resp[0] = mem_get(cursor++);
        } else {
            resp[0] = job_pos < job_len ? job[job_pos++] : 0;
        }
        resp_len = 1;
        resp_pos = 0;
        break;
    case BFCC_PUTC:
        buf_put(&out[stream], cmd[1]);
        break;
    case BFCC_LOAD: {
        uint32_t a = u32_at(cmd + 1);
        for (int i = 0; i < cmd[5]; i++) {
            resp[i] = mem_get(a + (uint32_t) i);
        }
        resp_len = cmd[5];
        resp_pos = 0;
        break;
    }
    case BFCC_STORE:
        store_addr = u32_at(cmd + 1);
        store_left = cmd[5];
        break;
    case BFCC_COPY:
        mem_move(u32_at(cmd + 1), u32_at(cmd + 5), u32_at(cmd + 9));
        break;
    case BFCC_DIFF:
        answer_u32(mem_diff(u32_at(cmd + 1), u32_at(cmd + 5), u32_at(cmd + 9)));
        break;
    case BFCC_EXIT:
        exit_code = cmd[1];
        break;
    case BFCC_PUTS:
        puts_mode = 1;
        break;
    case BFCC_DIAG:
        buf_put(&diag, cmd[1]);
        break;
    case BFCC_SLURP: {
        uint32_t a = u32_at(cmd + 1);
        for (;;) {
            uint8_t v = job_pos < job_len ? job[job_pos++] : 0;
            mem_set(a++, v);
            if (v == 0) {
                break;
            }
        }
        answer_u32(a);
        break;
    }
    case BFCC_SOURCE:
        from_memory = 1;
        cursor = u32_at(cmd + 1);
        break;
    case BFCC_JOB:
        from_memory = 0;
        break;
    case BFCC_SELECT:
        if (cmd[1] >= BFCC_STREAMS) {
            fail("protocol: no such output stream");
        }
        stream = cmd[1];
        break;
    case BFCC_ARGW:
    case BFCC_RETW:
        write_to = args[cmd[0] == BFCC_RETW];
        write_left = cmd[1];
        break;
    case BFCC_ARGR:
    case BFCC_RETR:
        memcpy(resp, args[cmd[0] == BFCC_RETR], cmd[1]);
        resp_len = cmd[1];
        resp_pos = 0;
        break;
    default:
        fail("protocol: unknown command");
    }
}

static int arg_bytes(uint8_t op)
{
    switch (op) {
    case BFCC_GETC:
    case BFCC_PUTS:
    case BFCC_JOB:
        return 0;
    case BFCC_PUTC:
    case BFCC_EXIT:
    case BFCC_DIAG:
    case BFCC_SELECT:
    case BFCC_ARGW:
    case BFCC_ARGR:
    case BFCC_RETW:
    case BFCC_RETR:
        return 1;
    case BFCC_SLURP:
    case BFCC_SOURCE:
        return 4;
    case BFCC_LOAD:
    case BFCC_STORE:
        return 5;
    case BFCC_COPY:
    case BFCC_DIFF:
        return 12;
    default:
        fail("protocol: unknown command");
        return 0;
    }
}

static void dev_out(uint8_t v)
{
    outs++;
    IO_PROFILE();
    if (puts_mode) {
        if (v == 0) {
            puts_mode = 0;
        } else {
            buf_put(&out[stream], v);
        }
        return;
    }
    if (store_left) {
        mem_set(store_addr++, v);
        store_left--;
        return;
    }
    if (write_left) {
        *write_to++ = v;
        write_left--;
        return;
    }
    if (cmd_len == 0) {
        cmd_need = 1 + arg_bytes(v);
    }
    cmd[cmd_len++] = v;
    if (cmd_len == cmd_need) {
        execute();
        cmd_len = 0;
    }
}

static uint8_t dev_in(void)
{
    ins++;
    IO_PROFILE();
    if (resp_pos >= resp_len) {
        fail("protocol: read with no answer pending");
    }
    return resp[resp_pos++];
}

/* ------------------------------------------------------------------ program */

typedef struct bf_io bf_io;
enum { BF_OK = 0, BF_ERR_TAPE = 1, BF_ERR_OUTPUT = 2, BF_ERR_LIMIT = 3 };

#define BF_IN(io) dev_in()
#define BF_OUT(io, v) dev_out((uint8_t) (v))
#ifdef BFCC_PROFILE
/* Loop iterations by dispatch state (the program counter cells 1, 2). */
static uint64_t profile[65536];
#define BF_TICK(io) (steps++, profile[t[BFCC_PC0] | t[BFCC_PC1] << 8]++)
#else
#define BF_TICK(io) (steps++)
#endif
#define BF_PROGRAM(name) static int BFCC_ENTRY(uint8_t *restrict t, bf_io *restrict io)

#include BFCC_PROGRAM

static uint8_t tape[BFCC_TAPE];

int bfcc_run(const uint8_t *job_bytes, size_t n, bfcc_buf streams[BFCC_STREAMS], bfcc_buf *diagnostics,
             uint64_t *loop_steps)
{
    job = job_bytes;
    job_len = n;
#ifdef BFCC_PROFILE
    prof_tape = tape;
#endif
    int status = BFCC_ENTRY(tape, NULL);
    if (status != BF_OK) {
        fail("the compiler program failed at run time");
    }
    if (cmd_len != 0 || puts_mode || store_left || write_left || resp_pos != resp_len) {
        fail("protocol: the program stopped inside a command");
    }
    if (exit_code < 0) {
        fail("the compiler program ended without EXIT");
    }
    for (int i = 0; i < BFCC_STREAMS; i++) {
        streams[i] = out[i];
    }
    *diagnostics = diag;
    if (getenv("BFCC_STATS")) {
        fprintf(stderr, "bfcc: device: %llu bytes out, %llu in; commands:", (unsigned long long) outs,
                (unsigned long long) ins);
        for (int i = 1; i < 18; i++) {
            fprintf(stderr, " %d:%llu", i, (unsigned long long) cmd_count[i]);
        }
        fputc(10, stderr);
    }
    if (loop_steps != NULL) {
        *loop_steps = steps;
    }
#ifdef BFCC_PROFILE
    FILE *f = fopen("bfcc.profile", "w");
    for (int i = 0; f != NULL && i < 65536; i++) {
        if (profile[i] || io_profile[i]) {
            fprintf(f, "%d %llu %llu\n", i, (unsigned long long) profile[i],
                    (unsigned long long) io_profile[i]);
        }
    }
    if (f != NULL) {
        fclose(f);
    }
#endif
    return exit_code;
}
