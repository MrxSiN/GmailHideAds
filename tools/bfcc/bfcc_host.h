/* Memory and I/O device for Brainfuck programs compiled to C (bfcc_host.c). */
#ifndef BFCC_HOST_H
#define BFCC_HOST_H

#include <stddef.h>
#include <stdint.h>

enum {
    BFCC_GETC = 1,
    BFCC_PUTC = 2,
    BFCC_LOAD = 3,
    BFCC_STORE = 4,
    BFCC_COPY = 5,
    BFCC_DIFF = 6,
    BFCC_EXIT = 7,
    BFCC_PUTS = 8,
    BFCC_DIAG = 9,
    BFCC_SLURP = 10,
    BFCC_SOURCE = 11,
    BFCC_JOB = 12,
    BFCC_SELECT = 13,
    BFCC_ARGW = 14,
    BFCC_ARGR = 15,
    BFCC_RETW = 16,
    BFCC_RETR = 17
};

#define BFCC_STREAMS 4

typedef struct {
    uint8_t *data;
    size_t len, cap;
} bfcc_buf;

/* Runs the program once over `job`. Returns its EXIT code; `streams`
 * receive what it wrote to each output stream, `diagnostics` its messages.
 * The process exits on a device protocol violation. */
int bfcc_run(const uint8_t *job, size_t n, bfcc_buf streams[BFCC_STREAMS], bfcc_buf *diagnostics,
             uint64_t *loop_steps);

#endif
