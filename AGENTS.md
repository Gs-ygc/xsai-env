# Repository Agent Notes

## Preferred entrypoints

- Use the top-level `Makefile` from the repo root.
- Default to the shared shell environment: `source env.sh` for one-shot shells, or `direnv allow` if direnv is already part of the user's workflow.
- Treat Nix as optional. Use `make nix-shell`, `make nix-init`, `make nix-smoke`, or `make nix-test` only when the task explicitly asks for Nix or when you need to reproduce a Nix-specific issue.
- Run `make init-force` before the first heavy build on a fresh checkout.
- Use `make gsim` only when the task explicitly needs `gsim`; it downloads the latest upstream release into `local/bin`.

## Environment

- `env.sh` and `.envrc.base` share `scripts/env-common.sh` and are the canonical environment setup paths.
- `.envrc` currently layers shared env loading, optional `.envrc.local` overrides, and submodule freshness hints; it does not currently auto-enter the Nix devshell.
- The top-level environment intentionally does not export `CROSS_COMPILE`; firmware and software flows set toolchain prefixes locally.
- `RISCV`, `RISCV_SYSROOT`, and `QEMU_LD_PREFIX` are auto-detected when possible; use `.envrc.local` or explicit exports for machine-specific overrides.
- `local/`, `build/`, `log/`, and `firmware/checkpoints/` are generated artifacts.

## Validation

- Start with `make help` and `make -n <target>` for setup/build entrypoints to confirm the intended command path.
- Be careful with `make -n` on orchestration or `run-*` targets: recursive `$(MAKE)` inside recipes may still execute, so inspect the Makefile first when a dry run must be side-effect free.
- Prefer `make test-smoke` for fast top-level validation.
- Use `make test` for the heavier manual-environment sanity check.
- Use `make nix-smoke` or `make nix-test` only for Nix-specific work.
- Avoid full RTL rebuilds unless the task requires them.

## Agent workflow

- Keep docs, scripts, and CI aligned with the top-level `Makefile`, `env.sh`, `.envrc`, and firmware/QEMU entrypoints.
- Prefer editing shared root scripts over duplicating logic in CI or ad hoc wrappers.
- Do not recommend Nix as the default setup path unless the user explicitly wants it.
- When documenting workflows, call out local-only helpers such as `make run-user` instead of presenting them as portable validation targets.
- Point users to `docs/troubleshooting.md`, `scripts/bug-report.sh`, and `scripts/create-issue.sh` when reporting build or runtime issues.
- Favor deterministic inputs over `latest` downloads unless explicitly requested.

## Workstream Boundaries

- Read `docs/workstreams.md` before making broad repo-structure changes or when the request spans multiple subsystems.
- Classify each task into one primary workstream first: top-level orchestration, RTL/`XSAI`, `NEMU`, `qemu`, firmware, `nexus-am`, compiler/toolchain, `DSL`, `software`, `tests`, or `tools`.
- Treat `DSL/`, `software/`, `tests/`, and `tools/` as umbrella namespaces. Active code for those concerns may also live in `llvm-project-ame/`, `firmware/riscv-rootfs/apps/`, `nexus-am/apps/`, `nexus-am/tests/`, `scripts/`, or component-local tool directories.
- Prefer changing the subsystem that owns an interface rather than patching around failures in downstream consumers.

## Parallel-Change Rules

- One task should have one primary write scope.
- Safe parallel work usually means disjoint directories and no shared source of truth.
- Do not edit coupled subsystem contracts concurrently unless the split is explicit and carefully coordinated.

High-risk coupled areas:
- Matrix ISA, intrinsic, CSR, or ABI changes across `llvm-project-ame/`, `DSL/`, `nexus-am/`, `NEMU/`, `qemu/`, and `XSAI/`
- Difftest alignment between `NEMU/` and `XSAI/`
- Memory-map and DTB changes across `mk/`, firmware board files, Linux config assumptions, and rootfs apps such as `hello_xsai`
- Checkpoint flow changes across `scripts/checkpoint.sh`, `Makefile`, `qemu/`, `firmware/gcpt_restore/`, and `NEMU/resource/simpoint/`
- Rootfs boot-flow changes across app code, `firmware/riscv-rootfs/Makefile`, initramfs manifests, and init scripts

## Validation by Workstream

- `xsai-env` base: prefer `make test-smoke`, then `make test` when needed.
- RTL / `XSAI`: prefer the narrowest `make xsai` or `make run-emu-debug PAYLOAD=...` path that proves the change.
- `NEMU`: build or run the intended defconfig/flow directly; do not assume QEMU validation covers NEMU semantics.
- `qemu` and firmware: `make qemu`, `make firmware`, and `make run-qemu` are the main integration paths.
- `nexus-am`, `software`, and rootfs apps: validate at the app/test level first, then run the narrowest simulator or firmware path that exercises the change.

For software validation, the current default ladder is:
- `make run-qemu`
- `make run-nemu`
- `make ckpt`
- `make run-nemu PAYLOAD=firmware/checkpoints/build/app/1/_1_1.zstd`
- `make run-emu PAYLOAD=firmware/checkpoints/build/app/1/_1_1.zstd`

Rationale:
- QEMU is usually much faster than NEMU and easier for software bug analysis.
- NEMU is much faster than RTL and should be the main golden-model gate before RTL.
- RTL is mainly for realistic performance behavior and workload-level ST validation after software issues have been narrowed down.

If `WORKLOAD_NAME` or `CHECKPOINT_CONFIG` changes, adjust the checkpoint payload path accordingly.
