# Checkpoint Workload Template

This document gives a minimal workload-side template for profiling and slicing in `xsai-env`.

The key point is:

- outer scripts choose the checkpoint flow
- the workload chooses the region of interest by emitting `nemu_signal(...)`

## When to use this template

Use this when you are adding a new app and want it to cooperate with:

- `make profile`
- `make cluster`
- `make ckpt`
- `make run-nemu PAYLOAD=<checkpoint>`
- `make run-emu PAYLOAD=<checkpoint>`

This template is especially useful for:

- rootfs smoke apps
- matrix kernel microbenchmarks
- single-threaded or otherwise stable regions of interest

## Signal meanings

The current signal values live in `firmware/riscv-rootfs/apps/hello_xsai/ame.h`:

```c
#define DISABLE_TIME_INTR   0x100
#define NOTIFY_PROFILER     0x101
#define NOTIFY_PROFILE_EXIT 0x102
#define GOOD_TRAP           0x0
```

Typical meaning:

- `DISABLE_TIME_INTR`: prepare for sampling; disable timer interrupts
- `NOTIFY_PROFILER`: start profiling the region of interest
- `NOTIFY_PROFILE_EXIT`: stop profiling the region of interest
- `GOOD_TRAP`: terminate cleanly

## Minimal single-ROI skeleton

```c
#include <stdio.h>
#include "ame.h"

static int setup_phase(void) {
    /* parse inputs, allocate memory, load model, warm basic state */
    return 0;
}

static int roi_phase(void) {
    /* region of interest: the code you actually want to profile/slice */
    return 0;
}

static void teardown_phase(void) {
    /* optional cleanup */
}

int main(void) {
    int ret = setup_phase();
    if (ret != 0) {
        nemu_signal(ret);
        return ret;
    }

    /* Profiling window begins here. Keep the ROI as tight as possible. */
    nemu_signal(DISABLE_TIME_INTR);
    nemu_signal(NOTIFY_PROFILER);

    ret = roi_phase();

    nemu_signal(NOTIFY_PROFILE_EXIT);

    teardown_phase();

    if (ret == 0) {
        nemu_signal(GOOD_TRAP);
    } else {
        nemu_signal(ret);
    }
    return ret;
}
```

## Loop-based test skeleton

If you have many test cases, do not usually start and stop profiling around every tiny iteration. Prefer one stable profiling window that covers the representative loop body.

```c
int main(void) {
    int ret = setup_phase();
    if (ret != 0) {
        nemu_signal(ret);
        return ret;
    }

    nemu_signal(DISABLE_TIME_INTR);
    nemu_signal(NOTIFY_PROFILER);

    for (int i = 0; i < NUM_CASES; i++) {
        ret = run_case(i);
        if (ret != 0) {
            break;
        }
    }

    nemu_signal(NOTIFY_PROFILE_EXIT);

    if (ret == 0) {
        nemu_signal(GOOD_TRAP);
    } else {
        nemu_signal(ret);
    }
    return ret;
}
```

## Placement rules

- Put setup work before `NOTIFY_PROFILER` whenever possible.
- Put the actual hot kernel or representative workload between `NOTIFY_PROFILER` and `NOTIFY_PROFILE_EXIT`.
- Put cleanup after `NOTIFY_PROFILE_EXIT` whenever possible.
- Keep the ROI stable and repeatable.
- Prefer one clean ROI over many noisy, tiny regions.

## Important limitations

- After `DISABLE_TIME_INTR`, workloads that depend on timer interrupts may not behave normally.
- Multi-threaded or scheduler-dependent workloads are poor first candidates unless you know exactly what behavior remains valid after interrupts are disabled.
- If the ROI includes too much setup, your checkpoint may represent boot/setup behavior rather than the real hot path.
- If the ROI is too tiny or unstable, clustering results are often not useful.

## Recommended validation order

For new software, prefer this order:

```bash
make run-qemu
make run-nemu
make ckpt
make run-nemu PAYLOAD=firmware/checkpoints/build/app/1/_1_1.zstd
make run-emu PAYLOAD=firmware/checkpoints/build/app/1/_1_1.zstd
```

Use the checkpoint path above as the current default example only. If `WORKLOAD_NAME` or `CHECKPOINT_CONFIG` changes, the output path changes too.

For a stricter SimPoint flow:

```bash
make profile
make cluster
make ckpt PHASE=checkpoint
```

## Checklist for a new app

- The app builds and installs into `firmware/riscv-rootfs/rootfsimg/build/`
- The app is listed in `firmware/riscv-rootfs/Makefile`
- The binary is included in `firmware/riscv-rootfs/rootfsimg/initramfs-disk-xsai.txt`
- The app is reachable from `firmware/riscv-rootfs/rootfsimg/init-disk-xsai.sh`
- The ROI sends `DISABLE_TIME_INTR`
- The ROI sends `NOTIFY_PROFILER`
- The ROI sends `NOTIFY_PROFILE_EXIT`
- The program exits with `GOOD_TRAP` on success

## Existing examples

Current workload-side examples include:

- `firmware/riscv-rootfs/apps/hello_xsai/hello_xsai.c`
- `firmware/riscv-rootfs/apps/gemm_precomp/precomp_test.c`

Use them as real repo examples, but prefer the skeleton in this document as the cleaner starting point for new apps.
