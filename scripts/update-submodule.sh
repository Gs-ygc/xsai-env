#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[update] Updating submodules..."
cd XSAI;             git fetch origin;                               git checkout origin/master;          make init; cd "$ROOT"
cd NEMU;             git checkout dev-v0.6;                          git pull --rebase;                              cd "$ROOT"
cd nexus-am;         git checkout master;                            git pull --rebase;                              cd "$ROOT"
cd llvm-project-ame; git fetch --depth=1 origin triton-commit-hash; git checkout triton-commit-hash;                cd "$ROOT"
cd qemu;             git fetch --depth=1 origin 9.0.0_matrix-v0.6;  git checkout 9.0.0_matrix-v0.6;                cd "$ROOT"

echo "[update] Refreshing VERSIONS..."
bash "$ROOT/scripts/update-versions.sh"

echo "[update] Done."
