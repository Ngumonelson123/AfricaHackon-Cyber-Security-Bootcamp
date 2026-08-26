#!/bin/bash
###############################################################################
# Script Name : decode_base64.sh
# Author      : Nelson Ngumo (Squad 5)
# Course      : AfricaHackon Academy - Cohort 6
# Assignment  : Bash Scripting - Custom Bash Automation Scripts (Bonus)
#
# Description : Reads a file of Base64 strings (one per line), decodes each
#               one back to plaintext, and writes the results to an output
#               file - one decoded line per input line, in order. If a line
#               isn't valid Base64, it doesn't abort the whole run: it writes
#               an explanatory placeholder for that line and keeps going.
#
# Usage       : ./decode_base64.sh
#               The script will interactively prompt you for:
#                 1. The path to the input file (Base64 strings, one per line)
#                 2. The path to the output file to create/overwrite
#
#               Non-interactive use is also possible by piping the two
#               answers in, e.g.:
#                 printf 'encoded.txt\ndecoded.txt\n' | ./decode_base64.sh
#
# Portability : GNU coreutils, BusyBox, and macOS/BSD `base64` all decode
#               correctly but disagree on the flag: GNU accepts `--decode`
#               or `-d`, BusyBox typically only accepts `-d`, and macOS/BSD
#               requires `-D` (uppercase). SECTION 2 below probes the local
#               `base64` binary with a known test string and remembers
#               whichever flag actually works. If no working `base64` flag
#               is found at all, falls back to Python3.
#
# Exit codes  : 0 on success (even if some individual lines failed to decode -
#                 that's reported per-line in the output, not treated as fatal)
#               1 on any fatal error (missing input file, unreadable input,
#                 unwritable output location, no decoder available, etc.)
###############################################################################

set -u  # treat unset variables as errors (but NOT -e; we handle errors explicitly)

# -----------------------------------------------------------------------------
# SECTION 0: SMALL HELPERS
# -----------------------------------------------------------------------------
die() {
    echo "ERROR: $1" >&2
    exit 1
}

# -----------------------------------------------------------------------------
# SECTION 1: PROMPT FOR INPUT / OUTPUT FILES
# -----------------------------------------------------------------------------
read -r -p "Enter the path to the input file (Base64 strings, one per line): " INPUT_FILE
read -r -p "Enter the path to the output file (decoded plaintext will be written here): " OUTPUT_FILE

[ -n "$INPUT_FILE" ]  || die "No input file path was provided."
[ -n "$OUTPUT_FILE" ] || die "No output file path was provided."
[ -f "$INPUT_FILE" ]  || die "Input file '$INPUT_FILE' does not exist."
[ -r "$INPUT_FILE" ]  || die "Input file '$INPUT_FILE' is not readable (check permissions)."

OUTPUT_DIR=$(dirname -- "$OUTPUT_FILE")
[ -d "$OUTPUT_DIR" ] || die "Output directory '$OUTPUT_DIR' does not exist."
[ -w "$OUTPUT_DIR" ] || die "Output directory '$OUTPUT_DIR' is not writable."

# -----------------------------------------------------------------------------
# SECTION 2: DETECT THE CORRECT BASE64 DECODE FLAG FOR THIS SYSTEM
# -----------------------------------------------------------------------------
# "aGVsbG8=" is the known Base64 encoding of "hello". We try each candidate
# flag against it and keep the first one that actually decodes it correctly.
# This avoids guessing the OS and instead tests real behaviour directly.
DECODE_MODE=""   # "base64" (with $BASE64_DECODE_FLAG set) or "python3"
BASE64_DECODE_FLAG=""

if command -v base64 >/dev/null 2>&1; then
    for flag in --decode -d -D; do
        result=$(printf '%s' "aGVsbG8=" | base64 "$flag" 2>/dev/null)
        if [ "$result" = "hello" ]; then
            DECODE_MODE="base64"
            BASE64_DECODE_FLAG="$flag"
            break
        fi
    done
fi

if [ -z "$DECODE_MODE" ]; then
    if command -v python3 >/dev/null 2>&1; then
        DECODE_MODE="python3"
    else
        die "No working Base64 decoder found: 'base64' (any known flag) and 'python3' are both unavailable."
    fi
fi

# decode_line: $1 = the Base64 string to decode.
# On success: echoes the decoded plaintext and returns 0.
# On failure: returns non-zero and prints nothing (caller handles the message).
decode_line() {
    local line="$1"
    case "$DECODE_MODE" in
        base64)
            printf '%s' "$line" | base64 "$BASE64_DECODE_FLAG" 2>/dev/null
            ;;
        python3)
            python3 -c '
import sys, base64
try:
    sys.stdout.write(base64.b64decode(sys.argv[1], validate=True).decode(errors="strict"))
except Exception:
    sys.exit(1)
' "$line"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# SECTION 3: READ, DECODE, WRITE (WITH GRACEFUL PER-LINE ERROR HANDLING)
# -----------------------------------------------------------------------------
: > "$OUTPUT_FILE" || die "Could not create/write to output file '$OUTPUT_FILE'."

LINE_NUM=0
DECODED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

while IFS= read -r line || [ -n "$line" ]; do
    LINE_NUM=$((LINE_NUM + 1))

    if [ -z "$(echo "$line" | tr -d '[:space:]')" ]; then
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi

    if decoded=$(decode_line "$line"); then
        echo "$decoded" >> "$OUTPUT_FILE"
        DECODED_COUNT=$((DECODED_COUNT + 1))
    else
        # Don't abort the whole batch over one bad line - record it and
        # keep processing the rest of the file.
        echo "[DECODE ERROR: line $LINE_NUM is not valid Base64: '$line']" >> "$OUTPUT_FILE"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done < "$INPUT_FILE"

# -----------------------------------------------------------------------------
# SECTION 4: SUMMARY
# -----------------------------------------------------------------------------
echo "Done. Decoded $DECODED_COUNT line(s), $FAILED_COUNT failed (placeholder written), $SKIPPED_COUNT empty line(s) skipped."
echo "Decoder used : $DECODE_MODE${BASE64_DECODE_FLAG:+ (flag: $BASE64_DECODE_FLAG)}"
echo "Output file  : $OUTPUT_FILE"

exit 0
