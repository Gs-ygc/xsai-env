#!/usr/bin/env bash
set -euo pipefail

xs_project_root="${XS_PROJECT_ROOT:?XS_PROJECT_ROOT is required}"
work_dir="${NOOP_HOME:?NOOP_HOME is required}"
pldm_tar_prefix="${PLDM_TAR_PREFIX:-XSAI-pldm}"
pldm_build_backup_prefix="${PLDM_BUILD_BACKUP_PREFIX:-${work_dir}/.pldm-build-backup}"
pldm_nemu_so="${PLDM_NEMU_SO:-${xs_project_root}/local/riscv64-nemu-interpreter-so}"
pldm_compress="${PLDM_COMPRESS:-1}"
pldm_keep_build="${PLDM_KEEP_BUILD:-1}"

mkdir -p "${xs_project_root}/local"

if [[ -f "$pldm_nemu_so" ]]; then
  echo "Updating ready-to-run/riscv64-nemu-interpreter-so from $pldm_nemu_so..."
  cp -f "$pldm_nemu_so" "$work_dir/ready-to-run/riscv64-nemu-interpreter-so"
else
  echo "warning: $pldm_nemu_so not found; keeping existing ready-to-run/riscv64-nemu-interpreter-so"
fi

ts="$(date +%Y%m%d-%H%M%S)"
archive_ext='.tar.gz'
if [[ "$pldm_compress" == "0" ]]; then
  archive_ext='.tar'
fi
archive="${xs_project_root}/local/${pldm_tar_prefix}-${ts}${archive_ext}"

echo "Packaging $archive..."
cd "$xs_project_root"

tar_opts="-czf"
if [[ "$pldm_compress" == "0" ]]; then
  tar_opts="-cf"
fi

tar $tar_opts "$archive" \
  --exclude='XSAI/out' \
  --exclude='XSAI/.bloop' \
  --exclude='XSAI/.metals' \
  --exclude='XSAI/.idea' \
  --exclude='XSAI/.vscode' \
  --exclude='XSAI/build-*' \
  --exclude='XSAI/.pldm-build-backup-*' \
  --exclude='XSAI/.git' \
  --exclude='XSAI/.gitignore' \
  --exclude='XSAI/.gitmodules' \
  --exclude='*/.git' \
  --exclude='*/out' \
  --exclude='*/.*' \
  --exclude='*.fir' \
  --exclude='*.json' \
  --exclude='*.anno.json' \
  --exclude='*.fir.mlir' \
  --exclude='*.pb' \
  --exclude='XSAI/build/rtl/*.vcs' \
  --exclude='XSAI/build/*.json' \
  XSAI 2>/dev/null || {
    echo "error: tar failed"
    exit 1
  }

echo "✓ PLDM package ready: $archive"
