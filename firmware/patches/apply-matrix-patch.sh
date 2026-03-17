#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <linux-source-dir>"
  exit 1
fi

LINUX_DIR="$1"
PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_FILE="$PATCH_DIR/0001-riscv-matrix-first-use-support.patch"

if [[ ! -d "$LINUX_DIR" ]]; then
  echo "Error: linux source dir not found: $LINUX_DIR"
  exit 1
fi

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "Error: patch file not found: $PATCH_FILE"
  exit 1
fi

cd "$LINUX_DIR"
patch --forward --reject-file=- -p1 < "$PATCH_FILE"
echo "Applied: $PATCH_FILE"
