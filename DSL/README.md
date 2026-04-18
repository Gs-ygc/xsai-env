# DSL Workstream

`DSL/` is the umbrella namespace for higher-level compiler projects in `xsai-env`, such as Triton, TileLang, TVM, or future matrix-oriented compiler frontends.

## Scope

- Own DSL-specific lowering, scheduling, code generation pipelines, and integration glue
- Emit code or artifacts that eventually run through the XSAI toolchain/runtime stack
- Track how DSL-generated kernels map onto the Matrix ISA and runtime expectations

## Dependencies

Typical downstream dependencies are:

- `llvm-project-ame/` for low-level codegen support
- `nexus-am/` or Linux-side runtime layers for execution support
- `software/` or `firmware/riscv-rootfs/apps/` for packaged workloads
- `NEMU/`, `qemu/`, and `XSAI/` as execution backends

## Rules

- Do not make `DSL/` the only source of truth for ISA semantics.
- If a DSL change requires new instructions, ABI rules, or CSR behavior, coordinate with toolchain, simulator, and hardware owners.
- Keep project-local workflows inside `DSL/`, but document shared repo assumptions in `docs/workstreams.md`.

See `../docs/workstreams.md` for the full subsystem map.
