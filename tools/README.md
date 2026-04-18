# Tools Workstream

`tools/` is the top-level namespace for developer-facing tooling that supports `xsai-env` workflows.

Related helper code also lives under:

- `scripts/` for top-level shell helpers
- component-local tool directories such as `NEMU/tools/` and `XSAI/tools/`

## Scope

- Automation helpers
- Analysis or inspection tools
- Packaging, reporting, or repository-maintenance helpers

## Rules

- Prefer small, deterministic tools with clear ownership.
- Do not let `tools/` become a hidden source of architectural truth that the real subsystem cannot derive.
- If a tool encodes an interface contract, document that contract in the owning subsystem and keep the tool aligned with it.

See `../docs/workstreams.md` for the full subsystem map and coupling rules.
