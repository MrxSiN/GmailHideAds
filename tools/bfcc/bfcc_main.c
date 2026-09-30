/*
 * bfcc command line: files in, files out. The Brainfuck compiler itself
 * (brainfuck/compiler/bfcc.bf, compiled to bfcc.generated.c) makes every
 * decision about Brainfuck; this file only reads the inputs it names, hands
 * them over as one job and writes back what the compiler printed.
 *
 *   bfcc gen [--check] [--root DIR]
 *       brainfuck/programs.json and the sources it lists ->
 *       app/src/main/cpp/generated/bf_programs.generated.c and
 *       brainfuck/generated/MEMORY_MAP.md (both printed by the compiler);
 *       brainfuck/constants.txt -> bf_abi.h and BfAbi.java (the ABI
 *       constants are copied here: they involve no Brainfuck).
 *       --check writes nothing and fails when a file is stale.
 *   bfcc compile SOURCE NAME TAPE [--no-propagate] [--static] [-o OUT]
 *       one program's C function (the self-hosting step uses this).
 *   bfcc run JOB [-o OUT]
 *       a raw job (tests).
 *
 * Exit status: 0 success, 1 rejected program or stale files, 2 usage,
 * 66 unreadable input, 70 internal error, 74 unwritable output.
 */
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "bfcc_host.h"

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

#define MAX_SOURCE (8u * 1024u * 1024u)
#define MAX_NAME 100

static void die(int code, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    fputs("bfcc: ", stderr);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
    exit(code);
}

static uint8_t *read_file(const char *path, size_t *n)
{
    FILE *f = fopen(path, "rb");
    if (f == NULL) {
        die(66, "cannot read %s", path);
    }
    uint8_t *data = NULL;
    size_t len = 0, cap = 0;
    for (;;) {
        if (len == cap) {
            cap = cap ? cap * 2 : 65536;
            data = realloc(data, cap + 1);
            if (data == NULL) {
                die(70, "out of memory");
            }
        }
        size_t got = fread(data + len, 1, cap - len, f);
        len += got;
        if (got == 0) {
            break;
        }
    }
    fclose(f);
    data[len] = 0;
    *n = len;
    return data;
}

static int same_file(const char *path, const bfcc_buf *b)
{
    FILE *f = fopen(path, "rb");
    if (f == NULL) {
        return 0;
    }
    size_t n;
    fclose(f);
    uint8_t *data = read_file(path, &n);
    int same = n == b->len && (n == 0 || memcmp(data, b->data, n) == 0);
    free(data);
    return same;
}

static void write_file(const char *path, const bfcc_buf *b)
{
    FILE *f = path == NULL ? stdout : fopen(path, "wb");
    if (f == NULL || (b->len && fwrite(b->data, 1, b->len, f) != b->len)) {
        die(74, "cannot write %s", path ? path : "stdout");
    }
    if (path != NULL) {
        fclose(f);
    } else {
        fflush(f);
    }
}

static void put(bfcc_buf *b, const void *data, size_t n)
{
    if (b->len + n > b->cap) {
        while (b->len + n > b->cap) {
            b->cap = b->cap ? b->cap * 2 : 4096;
        }
        b->data = realloc(b->data, b->cap);
        if (b->data == NULL) {
            die(70, "out of memory");
        }
    }
    memcpy(b->data + b->len, data, n);
    b->len += n;
}

static void puts_z(bfcc_buf *b, const char *s)
{
    put(b, s, strlen(s) + 1);
}

static void printf_buf(bfcc_buf *b, const char *fmt, ...)
{
    char tmp[512];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(tmp, sizeof tmp, fmt, ap);
    va_end(ap);
    if (n < 0 || (size_t) n >= sizeof tmp) {
        die(70, "line too long");
    }
    put(b, tmp, (size_t) n);
}

/* The source, checked for the job's framing: NUL-terminated, no NUL inside. */
static void put_source(bfcc_buf *job, const char *path)
{
    size_t n;
    uint8_t *src = read_file(path, &n);
    if (n > MAX_SOURCE) {
        die(1, "%s: sources are limited to %u bytes", path, MAX_SOURCE);
    }
    if (memchr(src, 0, n) != NULL) {
        die(1, "%s: a source cannot contain NUL bytes", path);
    }
    put(job, src, n + 1);
    free(src);
}

static int run_job(const bfcc_buf *job, bfcc_buf streams[BFCC_STREAMS])
{
    bfcc_buf diag = {0};
    uint64_t steps = 0;
    clock_t start = clock();
    int code = bfcc_run(job->data, job->len, streams, &diag, &steps);
    if (diag.len) {
        fwrite(diag.data, 1, diag.len, stderr);
    }
    if (getenv("BFCC_STATS")) {
        fprintf(stderr, "bfcc: %llu loop iterations, %.3f s\n", (unsigned long long) steps,
                (double) (clock() - start) / CLOCKS_PER_SEC);
    }
    return code;
}

/* ------------------------------------------------------------------ gen */

/* Just enough JSON for brainfuck/programs.json: objects with string and
 * integer members inside a "programs" array. */
typedef struct {
    int id, tape;
    char name[MAX_NAME + 1], source[MAX_NAME + 1];
} entry;

static const char *skip_ws(const char *p)
{
    while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') {
        p++;
    }
    return p;
}

static const char *json_string(const char *p, char *out, const char *path)
{
    size_t n = 0;
    if (*p != '"') {
        die(1, "%s: expected a string", path);
    }
    for (p++; *p != '"'; p++) {
        if (*p == 0 || *p == '\\' || n == MAX_NAME) {
            die(1, "%s: unsupported string", path);
        }
        out[n++] = *p;
    }
    out[n] = 0;
    return p + 1;
}

static int load_manifest(const char *path, entry *out, int max)
{
    size_t n;
    char *text = (char *) read_file(path, &n);
    const char *p = strstr(text, "\"programs\"");
    int count = 0;
    if (p == NULL || (p = strchr(p, '[')) == NULL) {
        die(1, "%s: no programs array", path);
    }
    p = skip_ws(p + 1);
    while (*p == '{') {
        entry e = {-1, -1, "", ""};
        p = skip_ws(p + 1);
        while (*p == '"') {
            char key[MAX_NAME + 1];
            p = skip_ws(json_string(p, key, path));
            if (*p != ':') {
                die(1, "%s: expected ':'", path);
            }
            p = skip_ws(p + 1);
            if (strcmp(key, "name") == 0) {
                p = json_string(p, e.name, path);
            } else if (strcmp(key, "source") == 0) {
                p = json_string(p, e.source, path);
            } else if (strcmp(key, "id") == 0 || strcmp(key, "tape") == 0) {
                char *end;
                long v = strtol(p, &end, 10);
                if (end == p || v < 0 || v > 1000000) {
                    die(1, "%s: bad %s", path, key);
                }
                *(strcmp(key, "id") == 0 ? &e.id : &e.tape) = (int) v;
                p = end;
            } else {
                die(1, "%s: unknown key %s", path, key);
            }
            p = skip_ws(p);
            if (*p == ',') {
                p = skip_ws(p + 1);
            }
        }
        if (*p != '}' || !e.name[0] || !e.source[0] || e.tape < 1) {
            die(1, "%s: incomplete program entry", path);
        }
        if (e.id != count) {
            die(1, "programs.json ids must be 0..n-1 in order");
        }
        if (count == max) {
            die(1, "%s: too many programs", path);
        }
        out[count++] = e;
        p = skip_ws(p + 1);
        if (*p == ',') {
            p = skip_ws(p + 1);
        }
    }
    free(text);
    return count;
}

/* brainfuck/constants.txt: `const NAME = VALUE` lines, `#` comments. */
static void emit_abi(const char *path, bfcc_buf *java, bfcc_buf *c)
{
    size_t n;
    char *text = (char *) read_file(path, &n);
    char names[256][64];
    unsigned long long values[256];
    int count = 0, line_no = 0;
    char *line = text;
    while (line != NULL && *line) {
        char *next = strchr(line, '\n');
        if (next) {
            *next++ = 0;
        }
        line_no++;
        char *hash = strchr(line, '#');
        if (hash) {
            *hash = 0;
        }
        char *s = line, *e = line + strlen(line);
        while (*s == ' ' || *s == '\t' || *s == '\r') s++;
        while (e > s && (e[-1] == ' ' || e[-1] == '\t' || e[-1] == '\r')) e--;
        *e = 0;
        if (*s) {
            char name[64];
            const char *q = s;
            int ok = strncmp(q, "const", 5) == 0 && (q[5] == ' ' || q[5] == '\t');
            size_t k = 0;
            if (ok) {
                for (q += 5; *q == ' ' || *q == '\t'; q++) {
                }
                ok = (*q >= 'A' && *q <= 'Z') || *q == '_';
                while (ok && ((*q >= 'A' && *q <= 'Z') || (*q >= '0' && *q <= '9') || *q == '_')) {
                    if (k == sizeof name - 1) {
                        ok = 0;
                        break;
                    }
                    name[k++] = *q++;
                }
                name[k] = 0;
                while (*q == ' ' || *q == '\t') q++;
                ok = ok && *q == '=';
                if (ok) {
                    for (q++; *q == ' ' || *q == '\t'; q++) {
                    }
                }
            }
            char *end = NULL;
            unsigned long long v = 0;
            if (ok && q[0] == '0' && q[1] == 'x') {
                v = strtoull(q + 2, &end, 16);
                ok = end != q + 2 && *end == 0 && strspn(q + 2, "0123456789abcdefABCDEF") == strlen(q + 2);
            } else if (ok) {
                v = strtoull(q, &end, 10);
                ok = end != q && *end == 0 && strspn(q, "0123456789") == strlen(q);
            }
            for (int i = 0; ok && i < count; i++) {
                ok = strcmp(names[i], name) != 0;
            }
            if (!ok || count == 256) {
                die(1, "%s:%d: bad constant line", path, line_no);
            }
            strcpy(names[count], name);
            values[count++] = v;
        }
        line = next;
    }
    free(text);
    printf_buf(java, "package my.MrxSiN.gmailhideads.policy;\n\n"
               "/** Generated by bfcc from brainfuck/constants.txt. Do not edit. */\n"
               "final class BfAbi {\n\n    private BfAbi() {\n    }\n\n");
    printf_buf(c, "/* Generated by bfcc from brainfuck/constants.txt. Do not edit. */\n"
               "#ifndef GMAILHIDEADS_BF_ABI_H\n#define GMAILHIDEADS_BF_ABI_H\n\n");
    for (int i = 0; i < count; i++) {
        if (values[i] > 0x7FFFFFFFull) {
            printf_buf(java, "    static final int %s = 0x%llX;\n", names[i], values[i]);
            printf_buf(c, "#define BF_%s %lluu\n", names[i], values[i]);
        } else {
            printf_buf(java, "    static final int %s = %llu;\n", names[i], values[i]);
            printf_buf(c, "#define BF_%s %llu\n", names[i], values[i]);
        }
    }
    printf_buf(java, "}\n");
    printf_buf(c, "\n#endif\n");
}

static int gen(const char *root, int check)
{
    static const char *outputs[4] = {
        "app/src/main/cpp/generated/bf_programs.generated.c",
        "brainfuck/generated/MEMORY_MAP.md",
        "app/src/main/cpp/generated/bf_abi.h",
        "app/src/main/java/my/MrxSiN/gmailhideads/policy/BfAbi.java",
    };
    char path[1024];
    entry programs[255];
    snprintf(path, sizeof path, "%s/brainfuck/programs.json", root);
    int count = load_manifest(path, programs, 255);
    bfcc_buf job = {0};
    uint8_t head[2] = {3, (uint8_t) count};
    put(&job, head, 2);
    for (int i = 0; i < count; i++) {
        puts_z(&job, programs[i].name);
        puts_z(&job, programs[i].source);
        printf_buf(&job, "%d", programs[i].tape);
        put(&job, "", 1);
        snprintf(path, sizeof path, "%s/brainfuck/%s", root, programs[i].source);
        put_source(&job, path);
    }
    bfcc_buf files[4] = {{0}};
    bfcc_buf streams[BFCC_STREAMS] = {{0}};
    int code = run_job(&job, streams);
    if (code != 0) {
        return 1;
    }
    files[0] = streams[0];
    files[1] = streams[1];
    snprintf(path, sizeof path, "%s/brainfuck/constants.txt", root);
    emit_abi(path, &files[3], &files[2]);
    int stale = 0;
    for (int i = 0; i < 4; i++) {
        snprintf(path, sizeof path, "%s/%s", root, outputs[i]);
        if (same_file(path, &files[i])) {
            continue;
        }
        if (check) {
            if (!stale) {
                printf("Generated Brainfuck files are stale; run bfcc gen:\n");
            }
            printf("  %s\n", outputs[i]);
        } else {
            write_file(path, &files[i]);
            printf("wrote %s\n", outputs[i]);
        }
        stale = 1;
    }
    if (check) {
        if (stale) {
            return 1;
        }
        printf("Generated Brainfuck files are up to date.\n");
    }
    return 0;
}

/* ------------------------------------------------------------------ main */

static int usage(void)
{
    fprintf(stderr, "usage: bfcc gen [--check] [--root DIR]\n"
                    "       bfcc compile SOURCE NAME TAPE [--no-propagate] [--static] [-o OUT]\n"
                    "       bfcc run JOB [-o OUT]\n");
    return 2;
}

int main(int argc, char **argv)
{
#ifdef _WIN32
    /* Byte-exact output and diagnostics: no CR LF translation. */
    _setmode(_fileno(stdout), _O_BINARY);
    _setmode(_fileno(stderr), _O_BINARY);
#endif
    if (argc >= 2 && strcmp(argv[1], "gen") == 0) {
        const char *root = ".";
        int check = 0;
        for (int i = 2; i < argc; i++) {
            if (strcmp(argv[i], "--check") == 0) {
                check = 1;
            } else if (strcmp(argv[i], "--root") == 0 && i + 1 < argc) {
                root = argv[++i];
            } else {
                return usage();
            }
        }
        return gen(root, check);
    }
    if (argc >= 5 && strcmp(argv[1], "compile") == 0) {
        const char *out = NULL;
        int flags = 1;
        for (int i = 5; i < argc; i++) {
            if (strcmp(argv[i], "--no-propagate") == 0) {
                flags &= ~1;
            } else if (strcmp(argv[i], "--static") == 0) {
                flags |= 2;
            } else if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
                out = argv[++i];
            } else {
                return usage();
            }
        }
        char *end;
        long tape = strtol(argv[4], &end, 10);
        if (*end || tape < 1 || tape > 499999 || strlen(argv[3]) > MAX_NAME) {
            return usage();
        }
        bfcc_buf job = {0};
        put(&job, "\1", 1);
        printf_buf(&job, "%ld", tape);
        put(&job, "", 1);
        puts_z(&job, argv[3]);
        uint8_t f = (uint8_t) flags;
        put(&job, &f, 1);
        put_source(&job, argv[2]);
        bfcc_buf streams[BFCC_STREAMS] = {{0}};
        int code = run_job(&job, streams);
        if (code == 0) {
            write_file(out, &streams[0]);
        }
        return code;
    }
    if (argc >= 3 && strcmp(argv[1], "run") == 0) {
        const char *out = argc >= 5 && strcmp(argv[3], "-o") == 0 ? argv[4] : NULL;
        size_t n;
        bfcc_buf job = {0};
        job.data = read_file(argv[2], &n);
        job.len = n;
        bfcc_buf streams[BFCC_STREAMS] = {{0}};
        int code = run_job(&job, streams);
        write_file(out, &streams[0]);
        return code;
    }
    return usage();
}
