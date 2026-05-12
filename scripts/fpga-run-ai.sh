#!/usr/bin/env bash
#
# FPGA run helper for xsai-env.
# Inspired by OpenXiangShan/env-scripts and OpenXiangShan/minjie-playground FPGA flows.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XS_PROJECT_ROOT="${XS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

HOST="${FPGA_HOST:-fpga}"
REMOTE_PAYLOAD="${FPGA_REMOTE_PAYLOAD:-~/t3.bin}"
LTX="${FPGA_LTX:-/home/fpga/xsai.ltx}"
DRIVER="${FPGA_DRIVER:-~/nexus-am/apps/dse-driver-ai/build/dse-driver-ai-riscv64-xs-driver.bin}"
XDMA_PROCESS="${FPGA_XDMA_PROCESS:-~/ai/xdma_process/build/xdma_process}"
TIMEOUT="${FPGA_TIMEOUT:-60}"
UART_CMD="${FPGA_UART_CMD:-}"
PASS_PATTERN="${FPGA_PASS_PATTERN:-}"
FAIL_PATTERN="${FPGA_FAIL_PATTERN:-}"
PCIE_REMOVE_CMD="${FPGA_PCIE_REMOVE_CMD:-}"
PCIE_RESCAN_CMD="${FPGA_PCIE_RESCAN_CMD:-}"

RESET_ONLY=0
PAYLOAD=""

usage() {
  cat <<'EOF'
Usage:
  scripts/fpga-run-ai.sh --payload <local-payload>
  scripts/fpga-run-ai.sh --reset-only

Environment knobs:
  FPGA_HOST, FPGA_REMOTE_PAYLOAD, FPGA_LTX, FPGA_DRIVER, FPGA_XDMA_PROCESS
  FPGA_TIMEOUT, FPGA_UART_CMD, FPGA_PASS_PATTERN, FPGA_FAIL_PATTERN
  FPGA_PCIE_REMOVE_CMD, FPGA_PCIE_RESCAN_CMD
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --payload)
      PAYLOAD="${2:-}"
      shift 2
      ;;
    --reset-only)
      RESET_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

run_remote() {
  local cmd="$1"
  ssh "$HOST" "bash -lc $(printf '%q' "$cmd")"
}

require_cmd ssh
require_cmd scp

if [[ "$RESET_ONLY" -eq 0 ]]; then
  [[ -n "$PAYLOAD" ]] || { echo "Missing --payload" >&2; exit 1; }
  [[ -f "$PAYLOAD" ]] || { echo "Payload not found: $PAYLOAD" >&2; exit 1; }
fi

RESET_TCL_LOCAL="$XS_PROJECT_ROOT/scripts/fpga/reset_cpu.tcl"
[[ -f "$RESET_TCL_LOCAL" ]] || { echo "Missing reset helper: $RESET_TCL_LOCAL" >&2; exit 1; }

run_id="$(date +%Y%m%d-%H%M%S)-$$"
remote_tcl="/tmp/xsai-reset-cpu-${run_id}.tcl"
remote_uart_log="/tmp/xsai-fpga-uart-${run_id}.log"
remote_uart_pid="/tmp/xsai-fpga-uart-${run_id}.pid"
local_uart_log="$XS_PROJECT_ROOT/log/fpga-uart-${run_id}.log"
uart_started=0

cleanup() {
  if [[ "$uart_started" -eq 1 ]]; then
    run_remote "if [ -f ${remote_uart_pid} ]; then kill \$(cat ${remote_uart_pid}) >/dev/null 2>&1 || true; fi" || true
  fi
  run_remote "rm -f ${remote_tcl} ${remote_uart_pid}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

reset_cpu() {
  echo "[fpga] Uploading reset helper to ${HOST}:${remote_tcl}"
  scp "$RESET_TCL_LOCAL" "${HOST}:${remote_tcl}"

  echo "[fpga] Resetting CPU via Vivado with LTX: ${LTX}"
  run_remote "test -f ${LTX}"
  run_remote "vivado -mode batch -source ${remote_tcl} -tclargs ${LTX}"
}

if [[ "$RESET_ONLY" -eq 0 ]]; then
  echo "[fpga] Uploading payload: ${PAYLOAD} -> ${HOST}:${REMOTE_PAYLOAD}"
  scp "$PAYLOAD" "${HOST}:${REMOTE_PAYLOAD}"
fi

reset_cpu

if [[ -n "$PCIE_REMOVE_CMD" ]]; then
  echo "[fpga] Running optional PCIe remove hook"
  run_remote "$PCIE_REMOVE_CMD"
fi

if [[ -n "$PCIE_RESCAN_CMD" ]]; then
  echo "[fpga] Running optional PCIe rescan hook"
  run_remote "$PCIE_RESCAN_CMD"
fi

if [[ "$RESET_ONLY" -eq 1 ]]; then
  echo "[fpga] Reset-only flow complete"
  exit 0
fi

if [[ -n "$UART_CMD" ]]; then
  mkdir -p "$XS_PROJECT_ROOT/log"
  echo "[fpga] Starting UART capture on ${HOST}"
  run_remote "rm -f ${remote_uart_log} ${remote_uart_pid}; nohup bash -lc $(printf '%q' "$UART_CMD") > ${remote_uart_log} 2>&1 & echo \$! > ${remote_uart_pid}"
  uart_started=1
fi

echo "[fpga] Running XDMA loader"
run_remote "sudo ${XDMA_PROCESS} -d ${DRIVER} -i ${REMOTE_PAYLOAD}"

if [[ "$uart_started" -eq 1 ]]; then
  echo "[fpga] Streaming UART output (timeout=${TIMEOUT}s)"
  set +e
  ssh "$HOST" "timeout ${TIMEOUT}s tail -n +1 -F ${remote_uart_log}" | tee "$local_uart_log"
  tail_rc=${PIPESTATUS[0]}
  set -e
  if [[ "$tail_rc" -ne 0 && "$tail_rc" -ne 124 ]]; then
    echo "[fpga] UART tail failed with exit code ${tail_rc}" >&2
    exit "$tail_rc"
  fi

  if [[ -n "$PASS_PATTERN" ]] && ! grep -Eq "$PASS_PATTERN" "$local_uart_log"; then
    echo "[fpga] PASS pattern not found: ${PASS_PATTERN}" >&2
    exit 1
  fi
  if [[ -n "$FAIL_PATTERN" ]] && grep -Eq "$FAIL_PATTERN" "$local_uart_log"; then
    echo "[fpga] FAIL pattern matched: ${FAIL_PATTERN}" >&2
    exit 1
  fi
  echo "[fpga] UART log saved to ${local_uart_log}"
fi

echo "[fpga] Run completed"
