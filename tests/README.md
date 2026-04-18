# Tests Workstream

`tests/` is the top-level namespace for repository-level validation, integration tests, and future consolidated regression entrypoints.

There are already many component-local tests elsewhere:

- `nexus-am/tests/`
- `XSAI` component-local flows
- `NEMU` configs and example flows
- top-level smoke and environment checks under `scripts/`

## Scope

- End-to-end or cross-subsystem validation
- Regression coverage for repository integration points
- Documentation of what should be tested for each workstream

## Rules

- Tests should validate subsystem contracts, not become the only place where those contracts are defined.
- Keep production logic in the owning subsystem and keep test harness logic in test code.
- When adding tests, document which workstream they cover and what validation level they provide: smoke, subsystem, or end-to-end.

See `../docs/workstreams.md` for the workstream boundaries and validation matrix.
