---
name: xsai-checkpoint-flow
description: Guide for the xsai-env checkpoint and profiling workflow. Use this when working on SimPoint profiling, clustering, checkpoint dumping, GCPT restore, or the top-level profile/cluster/ckpt targets.
---

# XSAI Checkpoint Flow

This skill is for the repo-level checkpoint flow, not just one upstream component in isolation.

## What owns the flow

The current repo checkpoint path spans:

- top-level `Makefile` targets: `simpoint`, `profile`, `cluster`, `ckpt`, `uniform`
- `scripts/checkpoint.sh`
- `qemu/` and its profiling plugin
- `firmware/gcpt_restore/`
- firmware payloads and DTB generation
- `NEMU/resource/simpoint/simpoint_repo`

Treat this as an integration workstream.

## Workload cooperation is required

In this repo, slicing/profiling is not controlled only by the outer script. The workload itself must cooperate with the simulator by issuing custom `nemu_signal(...)` markers.

For a reusable workload-side skeleton, see:

- `docs/checkpoint-workload-template.md`

Representative definitions live in:

- `firmware/riscv-rootfs/apps/hello_xsai/ame.h`

Current signal values:

```c
#define DISABLE_TIME_INTR   0x100
#define NOTIFY_PROFILER     0x101
#define NOTIFY_PROFILE_EXIT 0x102
#define GOOD_TRAP           0x0
```

Representative helper:

```c
static void nemu_signal(int a){
    asm volatile ("mv a0, %0\n\t"
                  ".insn r 0x6B, 0, 0, x0, x0, x0\n\t"
                  :
                  : "r"(a)
                  : "a0");
}
```

Typical intended sequence:

1. `nemu_signal(DISABLE_TIME_INTR);`
2. `nemu_signal(NOTIFY_PROFILER);`
3. run the region of interest
4. `nemu_signal(NOTIFY_PROFILE_EXIT);`
5. `nemu_signal(GOOD_TRAP);`

Meaning:

- `DISABLE_TIME_INTR`: prepare for sampling by disabling timer interrupts
- `NOTIFY_PROFILER`: tell the simulator to start profiling/sampling
- `NOTIFY_PROFILE_EXIT`: tell the simulator to stop profiling/sampling
- `GOOD_TRAP`: terminate the program cleanly

For new apps, prefer the minimal single-ROI template in `docs/checkpoint-workload-template.md` instead of copying historical examples blindly.

Important consequence:

- After `DISABLE_TIME_INTR`, workloads that depend on timer interrupts, time slicing, or normal multithread scheduling may no longer behave correctly for profiling purposes.
- That means profiling/slicing should focus on stable regions of interest, not arbitrary software that still needs normal timer-driven behavior.

## Primary commands

```bash
make simpoint
make profile MODEL_IMG=<disk.img>
make cluster MODEL_IMG=<disk.img>
make ckpt MODEL_IMG=<disk.img>
```

Single-phase reruns:

```bash
make ckpt PHASE=profile MODEL_IMG=<disk.img>
make ckpt PHASE=cluster MODEL_IMG=<disk.img>
make ckpt PHASE=checkpoint MODEL_IMG=<disk.img>
```

## Current repo-specific flow

1. Build or verify the SimPoint binary from `NEMU/resource/simpoint/simpoint_repo`.
2. Build or verify QEMU and its profiling plugin.
3. Build or verify the firmware payload and DTB.
4. Run profiling to produce BBV data.
5. Run clustering to produce `simpoints0`.
6. Run checkpoint dumping to produce checkpoint images under `firmware/checkpoints/`.

At the repo root, profiling and checkpoint dumping run through QEMU integration scripts, even though NEMU also has its own upstream checkpoint-related capabilities.

Also note:

- the outer flow chooses *when* to profile or dump
- the workload markers choose *which region* is actually treated as the profiling/slicing window

## Two common slicing modes

### 1. Fast single-slice path

Use this when you want to skip OS-startup-heavy sampling and just cut quickly into the target workload region.

Typical top-level settings:

- `CPT_INTERVAL=100`
- `PROFILING_INTERVALS=$(CPT_INTERVAL)`
- `SIMPOINT_MAX_K=10`
- `SMP=1`

Typical behavior:

- go through `no_simpoint + do_checkpoint`
- usually emit a single checkpoint `.zstd`
- useful when the main goal is to skip firmware/OS startup and jump into the ROI fast

### 2. SimPoint sampling path

Use this when you want representative slices for performance-oriented replay.

Typical flow:

- `do_profile`
- `do_cluster`
- `do_checkpoint`

Representative tuning example:

- `CPT_INTERVAL=100000`
- `SIMPOINT_MAX_K=30`

Typical behavior:

- produce multiple representative fragments
- those fragments can be replayed in parallel on NEMU or emu
- useful for quickly estimating software behavior on hardware-oriented backends

## Common touch points

- `Makefile`
- `scripts/checkpoint.sh`
- `mk/memory.mk` when memory layout assumptions change
- `firmware/gcpt_restore/`
- `firmware/nemu_board/`
- `qemu/` machine or plugin behavior

## High-risk coupling

Do not treat these as isolated edits:

- checkpoint format or restore behavior
- QEMU plugin output expectations
- DTB or memory-map assumptions used during restore
- path/layout assumptions for `firmware/checkpoints/`

These usually need one integrator and end-to-end validation.

## Validation advice

- Start by confirming the exact phase that is broken: profile, cluster, or checkpoint.
- Validate prerequisites before debugging outputs.
- `make simpoint`
- `make qemu`
- `make -C firmware build-gcpt-qemu`
- `make -C firmware build-gcpt-restore`
- Use the narrowest rerun that proves the change instead of always repeating the full flow.
- Read `docs/workstreams.md` when the bug may actually belong to firmware, QEMU, or a shared platform contract.

## Default validation ladder

For software validation around checkpointed workloads, the current repo order is:

1. `make run-qemu`
2. `make run-nemu`
3. `make ckpt`
4. `make run-nemu PAYLOAD=firmware/checkpoints/build/app/1/_1_1.zstd`
5. `make run-emu PAYLOAD=firmware/checkpoints/build/app/1/_1_1.zstd`

The checkpoint payload above matches the current defaults. If `WORKLOAD_NAME` or `CHECKPOINT_CONFIG` changes, adjust it.

Current top-level defaults from `Makefile` are:

- `CPT_INTERVAL ?= 100`
- `PROFILING_INTERVALS ?= $(CPT_INTERVAL)`
- `SIMPOINT_MAX_K ?= 10`
- `SMP ?= 1`

If you call `scripts/checkpoint.sh` directly, keep those defaults in mind and make sure they match your intended top-level flow.

## Easy mistakes

- Forgetting that the workload itself must emit `nemu_signal(...)` markers for the region of interest
- Starting profiling without first sending `DISABLE_TIME_INTR` when the intended flow expects a stable non-timer-interrupted region
- Profiling code that still depends on timer interrupts or normal multithread scheduling after interrupts are disabled
- Mixing up the fast single-slice `no_simpoint` path with the full SimPoint sampling path
- Treating `make ckpt` as the first software validation step instead of validating first on QEMU and NEMU
- Assuming the checkpoint path is always `firmware/checkpoints/build/app/1/_1_1.zstd` even after changing config knobs
- Debugging the full flow when only one phase is broken
- Blaming checkpoint logic for issues that already reproduce before checkpoint generation
