# =============================================================================
# Memory Layout Configuration — single source of truth
# =============================================================================
# Included by:
#   root Makefile                              (QEMU -m flag)
#   firmware/Makefile                          (DTB generation)
#   firmware/riscv-rootfs/apps/llama.cpp/Makefile  (cmake -DRESERVED_* flags)
#
# Physical address map (NEMU/QEMU board, RAM base 0x80000000):
#
#   0x080000000  ┌──────────────────────────────┐
#                │  Kernel-visible system RAM   │  ← XSAI_MEMORY_SIZE
#                │  (DTB /memory node)          │
#   0x100000000  ├──────────────────────────────┤  ← XSAI_DIRECT_MAP_MEM_START
#                │  XSAI DMA-coherent pool      │  ← XSAI_DIRECT_MAP_MEM_SIZE
#   0x140000000  └──────────────────────────────┘
#
# Constraint: 0x80000000 + MEMORY  ≥  XSAI_DIRECT_MAP_MEM_START + XSAI_DIRECT_MAP_MEM_SIZE
#             Currently: 0x180000000 ≥ 0x140000000  ✓
# =============================================================================

# QEMU/NEMU physical RAM size passed to -m flag.
MEMORY ?= 4G

# System RAM in the DTB /memory node (kernel-visible, starts at 0x80000000).
XSAI_MEMORY_SIZE ?= 0x80000000

# XSAI DMA-coherent tensor pool (reserved, not in kernel address space).
# Exported so all sub-makes inherit the values without extra passthrough rules.
export XSAI_DIRECT_MAP_MEM_START ?= 0x100000000
# 1 GiB
# export XSAI_DIRECT_MAP_MEM_SIZE  ?= 0x40000000
# 100MB (for smaller models or to save RAM)
export XSAI_DIRECT_MAP_MEM_SIZE  ?= 0x6400000