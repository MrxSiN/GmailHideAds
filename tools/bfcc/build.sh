#!/usr/bin/env sh
#
# Builds bfcc, the Brainfuck compiler, from the committed
# tools/bfcc/bfcc.generated.c with the host C compiler. No Python involved.
#
#   tools/bfcc/build.sh [OUTPUT]      (default build/bfcc/bfcc)
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=${1:-$HERE/../../build/bfcc/bfcc}
mkdir -p "$(dirname -- "$OUT")"
${CC:-cc} -O2 -std=c11 -o "$OUT" "$HERE/bfcc_host.c" "$HERE/bfcc_main.c"
echo "built $OUT"
