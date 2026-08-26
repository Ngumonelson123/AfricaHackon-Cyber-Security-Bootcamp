#!/bin/bash
###############################################################################
# Script Name : encode_base64.sh
# Author      : Nelson Ngumo (Squad 5)
# Course      : AfricaHackon Academy - Cohort 6
# Assignment  : Bash Scripting - Custom Bash Automation Scripts
#
# Description : Reads a plaintext file (one password/string per line),
#               Base64-encodes each non-empty line, and writes the encoded
#               strings to an output file - one per line, in the same order
#               as the input.
#
# Usage       : ./encode_base64.sh
#               The script will interactively prompt you for:
#                 1. The path to the input file (e.g. passwords.txt)
#                 2. The path to the output file to create/overwrite
#
#               Non-interactive use is also possible by piping the two
#               answers in, e.g.:
#                 printf 'passwords.txt\nencoded.txt\n' | ./encode_base64.sh
#
# Portability : Uses the system's `base64` utility when available (works on
#               both GNU/Linux coreutils and macOS/BSD - see SECTION 2 for
#               why we don't rely on either's line-wrapping flags). If no
#               `base64` binary exists at all, falls back to Python3.
#
# Exit codes  : 0 on success
#               1 on any fatal error (missing input file, unreadable input,
#                 unwritable output location, no encoder available, etc.)
###############################################################################

set -u  # treat unset variables as errors (but NOT -e; we handle errors explicitly)

# -----------------------------------------------------------------------------
# SECTION 0: SMALL HELPERS
# -----------------------------------------------------------------------------
# die() prints a clear, consistent error message to stderr and exits non-zero,
# so every fatal error in this script looks the same and is easy to spot.
die() {
    echo "ERROR: $1" >&2
    exit 1
}

# -----------------------------------------------------------------------------
# SECTION 1: PROMPT FOR INPUT / OUTPUT FILES
# -----------------------------------------------------------------------------
read -r -p "Enter the path to the input file (plaintext, one entry per line): " INPUT_FILE
read -r -p "Enter the path to the output file (Base64 lines will be written here): " OUTPUT_FILE

# Basic sanity checks on what the user typed before we touch anything.
[ -n "$INPUT_FILE" ]  || die "No input file path was provided."
[ -n "$OUTPUT_FILE" ] || die "No output file path was provided."
[ -f "$INPUT_FILE" ]  || die "Input file '$INPUT_FILE' does not exist."
[ -r "$INPUT_FILE" ]  || die "Input file '$INPUT_FILE' is not readable (check permissions)."

# Make sure the directory the output file will live in actually exists and
# is writable, so we fail early with a clear message instead of a cryptic
# "No such file or directory" from a later redirect.
OUTPUT_DIR=$(dirname -- "$OUTPUT_FILE")
[ -d "$OUTPUT_DIR" ] || die "Output directory '$OUTPUT_DIR' does not exist."
[ -w "$OUTPUT_DIR" ] || die "Output directory '$OUTPUT_DIR' is not writable."

# -----------------------------------------------------------------------------
# SECTION 2: PICK A PORTABLE BASE64 ENCODER
# -----------------------------------------------------------------------------
# GNU coreutils `base64` and macOS/BSD `base64` both encode a single line the
# same way, but they DISAGREE on the flag used to disable line-wrapping
# (`-w 0` on GNU, `-b 0` on BSD/macOS). Rather than sniff the OS or the flag
# support, we sidestep the whole problem: let each implementation wrap
# however it likes, then strip every newline it inserted with `tr -d '\n'`.
# Since we feed it one line at a time, the result is always a single,
# unwrapped Base64 string per input line - portable on both platforms.
#
# If no `base64` binary exists at all (rare, but possible on a minimal
# container/image), we fall back to Python3's base64 module.
ENCODE_MODE=""
if command -v base64 >/dev/null 2>&1; then
    ENCODE_MODE="base64"
elif command -v python3 >/dev/null 2>&1; then
    ENCODE_MODE="python3"
else
    die "No Base64 encoder found: neither 'base64' nor 'python3' is installed on this system."
fi

encode_line() {
    # $1 = the plaintext line to encode. Echoes the Base64 result (no newline
    # embedded) to stdout.
    local line="$1"
    case "$ENCODE_MODE" in
        base64)
            printf '%s' "$line" | base64 | tr -d '\n'
            ;;
        python3)
            python3 -c 'import sys, base64; sys.stdout.write(base64.b64encode(sys.argv[1].encode()).decode())' "$line"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# SECTION 3: READ, ENCODE, WRITE
# -----------------------------------------------------------------------------
# We truncate/create the output file up front, then append one encoded line
# at a time so a huge input file doesn't have to be held in memory at once.
: > "$OUTPUT_FILE" || die "Could not create/write to output file '$OUTPUT_FILE'."

LINE_NUM=0
ENCODED_COUNT=0
SKIPPED_COUNT=0

# IFS='' + `read -r` preserves leading/trailing whitespace and backslashes
# exactly as they appear in the file. Using `|| [ -n "$line" ]` in the while
# condition ensures the very last line is still processed even if the input
# file doesn't end with a trailing newline.
while IFS= read -r line || [ -n "$line" ]; do
    LINE_NUM=$((LINE_NUM + 1))

    # Skip lines that are empty, or whitespace-only, without breaking the
    # ordering of the non-empty lines that follow.
    if [ -z "$(echo "$line" | tr -d '[:space:]')" ]; then
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi

    encoded=$(encode_line "$line") || die "Failed to encode line $LINE_NUM of '$INPUT_FILE'."
    echo "$encoded" >> "$OUTPUT_FILE"
    ENCODED_COUNT=$((ENCODED_COUNT + 1))
done < "$INPUT_FILE"

# -----------------------------------------------------------------------------
# SECTION 4: SUMMARY
# -----------------------------------------------------------------------------
echo "Done. Encoded $ENCODED_COUNT line(s), skipped $SKIPPED_COUNT empty line(s)."
echo "Encoder used : $ENCODE_MODE"
echo "Output file  : $OUTPUT_FILE"

exit 0
