# Software Workstream

`software/` is the umbrella namespace for workload projects in `xsai-env`.

Today, active software also lives in:

- `firmware/riscv-rootfs/apps/` for Linux/rootfs userspace programs
- `nexus-am/apps/` for AM-style bare-metal apps

## Key Paths

The current high-priority software paths are:

- `firmware/riscv-rootfs/apps/hello_xsai/`
- `firmware/riscv-rootfs/apps/gemm_precomp/`
- `firmware/riscv-rootfs/apps/llama.cpp/`

`hello_xsai` and `gemm_precomp` are the main Linux/rootfs smoke tests.

`llama.cpp` is the main AI software adaptation path for XSAI.
The most important development points there are:

- `ggml` AME operators
- `llama-simple-xsai`
- `llama-bench`

## Scope

- Benchmarks, demos, applications, and workload integration
- Linux-side user programs and AM-side workload code
- Performance or functionality validation of Matrix-enabled software stacks

## Rules

- Prefer keeping platform/runtime setup in the owning subsystem rather than copying it into every app.
- Rootfs packaging belongs with `firmware/riscv-rootfs/`.
- Bare-metal runtime/library semantics belong with `nexus-am/`.
- Toolchain or ISA contract changes should be pushed down into `llvm-project-ame/`, `DSL/`, `NEMU/`, `qemu/`, or `XSAI/` as appropriate, not hidden in app-local workarounds.

For rootfs smoke tests, remember that "the software path works" only when all three layers line up:

- `firmware/riscv-rootfs/Makefile`
- `firmware/riscv-rootfs/rootfsimg/initramfs-disk-xsai.txt`
- `firmware/riscv-rootfs/rootfsimg/init-disk-xsai.sh`

## Validation

- For rootfs apps, start with app-local builds under `firmware/riscv-rootfs/apps/<app>/`, then validate via `make firmware` and `make run-qemu`.
- For AM apps, use app-local or test-local `nexus-am` targets first, then validate on the intended simulator or RTL path.

For the current smoke path, explicitly check that `hello_xsai` and `gemm_precomp` are still built, packed, and reachable from init.

See `../docs/workstreams.md` for the full dependency map.
