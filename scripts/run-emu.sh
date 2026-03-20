#!/usr/bin/env bash
# =============================================================================
# run-emu.sh — Run XSAI RTL emulator with optional logging and diff mode
#
# Usage:
#   ./scripts/run-emu.sh [OPTIONS] <payload>
#
# Options:
#   --log          Save output to log/<name>_<timestamp>.log (and tee to stdout)
#   --diff         Enable diff mode (compare against NEMU reference)
#   --log-dir DIR  Log directory (default: log/)
#   --diff-so PATH Path to reference .so (default: auto-detected)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XS_PROJECT_ROOT="${XS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
NOOP_HOME="${NOOP_HOME:-$XS_PROJECT_ROOT/XSAI}"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
ENABLE_LOG=0
ENABLE_DIFF=0
LOG_DIR="$XS_PROJECT_ROOT/log"
DIFF_SO="$NOOP_HOME/ready-to-run/riscv64-nemu-interpreter-so"
PAYLOAD=""

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --log)         ENABLE_LOG=1;        shift ;;
        --diff)        ENABLE_DIFF=1;       shift ;;
        --log-dir)     LOG_DIR="$2";        shift 2 ;;
        --diff-so)     DIFF_SO="$2";        shift 2 ;;
        -*)            echo "Unknown flag: $1" >&2; exit 1 ;;
        *)             PAYLOAD="$1";        shift ;;
    esac
done

[[ -n "$PAYLOAD" ]] || { echo "Usage: $0 [--log] [--diff] <payload>" >&2; exit 1; }
[[ -f "$PAYLOAD" ]] || { echo "Payload not found: $PAYLOAD" >&2; exit 1; }
[[ -x "$NOOP_HOME/build/emu" ]] || { echo "emu not found: $NOOP_HOME/build/emu" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Derive a clean program name from the payload path
# ---------------------------------------------------------------------------
prog_name="$(basename "$(dirname "$PAYLOAD")")"
if [[ -z "$prog_name" || "$prog_name" == "." || "$prog_name" == "/" ]]; then
    prog_name="$(basename "$PAYLOAD")"
    prog_name="${prog_name%.gz}"
    prog_name="${prog_name%.*}"
fi

# ---------------------------------------------------------------------------
# Build emu argument list
# ---------------------------------------------------------------------------
emu_args=(-i "$PAYLOAD" --no-diff)

if [[ "$ENABLE_DIFF" == "1" ]]; then
    [[ -f "$DIFF_SO" ]] || { echo "diff .so not found: $DIFF_SO" >&2; exit 1; }
    emu_args+=(--diff="$DIFF_SO")
fi

# ---------------------------------------------------------------------------
# Run with or without logging
# ---------------------------------------------------------------------------
if [[ "$ENABLE_LOG" == "1" ]]; then
    mkdir -p "$LOG_DIR"
    ts="$(date +%Y%m%d-%H%M%S)"
    log_file="$LOG_DIR/${prog_name}_${ts}.log"
    echo "[run-emu] payload : $PAYLOAD"
    echo "[run-emu] log     : $log_file"
    [[ "$ENABLE_DIFF" == "1" ]] && echo "[run-emu] diff    : $DIFF_SO"
    "$NOOP_HOME/build/emu" "${emu_args[@]}" 2>/dev/null | tee "$log_file"
else
    "$NOOP_HOME/build/emu" "${emu_args[@]}" 2>/dev/null
fi
