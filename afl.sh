#!/usr/bin/env bash

set -e

EXE=${EXE:-"zig-out/bin/fuzz"}
INPUT_DIR=${INPUT_DIR:-"afl_input"}
OUTPUT_DIR=${OUTPUT_DIR:-"afl_output"}

if ! [[ -f "$EXE" && -x "$EXE" ]]; then
    echo "$EXE not found or not executable." 1>&2
    exit 1
fi

if ! [[ -d "$INPUT_DIR" ]]; then
    echo "Please create the directory \"$INPUT_DIR\" or point INPUT_DIR to a folder containing ONLY test archives." 1>&2
    exit 1
fi

trap ctrl_c INT
function ctrl_c() {
    killall afl-fuzz
}

if [[ "$1" == "parallel" ]]; then
    afl-fuzz -i "$INPUT_DIR" -o "$OUTPUT_DIR" -M "fuzzer0" -- "$EXE" "$TMPFILE" &
    for i in $(seq 2 $(( $(nproc)/2 )) ); do
        afl-fuzz -i "$INPUT_DIR" -o "$OUTPUT_DIR" -S "fuzzer$i" -- "$EXE" "$TMPFILE" >/dev/null 2>&1 &
    done
    wait
else
    afl-fuzz -i "$INPUT_DIR" -o "$OUTPUT_DIR" -- "$EXE" "$TMPFILE"
fi
