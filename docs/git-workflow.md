# Git Development Workflow

This repository uses an issue-first, branch-per-change workflow. Keep changes small enough to review and validate on the narrowest path that proves the behavior.

## 1. Start From An Issue

Open or link an issue before non-trivial work:

- Bugs: use the bug report template after checking `docs/troubleshooting.md`.
- Unclear failures: use the problem report template until the root cause is known.
- New behavior or workflow changes: use the feature request template.
- Questions: use the question template.

Terminal-first flow:

```bash
bash scripts/bug-report.sh
bash scripts/create-issue.sh --type bug --title "..."
bash scripts/create-issue.sh --type feature --title "..."
```

Issue titles are human-facing summaries, not commit messages. Prefix them with
the selected issue template:

- `[Bug Report] Checkpoint replay fails with a restored QEMU payload`
- `[Feature Request] Package a llama bench preset into the rootfs image`
- `[Feature Request] Clarify the SimPoint defaults used by top-level checkpoint targets`
- `[Problem] Firmware checkpoint replay fails after generated payload selection`

Reserve Conventional Commit style such as `fix(qemu): ...` or
`docs(checkpoint): ...` for commits and PR titles.

If the root cause belongs in an upstream component repository such as `XSAI`, `NEMU`, `qemu`, or `riscv-rootfs`, file or link the upstream issue and keep the `xsai-env` issue focused on integration context.

## 2. Create A Branch

Create branches from current `master`:

```bash
git switch master
git pull --ff-only
git switch -c fix/123-checkpoint-replay
```

Branch naming:

- `fix/<issue>-short-topic` for bug fixes
- `feat/<issue>-short-topic` for new behavior
- `docs/<issue>-short-topic` for documentation-only work
- `test/<issue>-short-topic` for tests only
- `refactor/<issue>-short-topic` for behavior-preserving structure changes
- `chore/<issue>-short-topic` for maintenance
- `ci/<issue>-short-topic` for CI changes
- `bump/<component>-<rev-or-topic>` for submodule or version bumps
- `wip/<topic>` only for temporary private work; rename before opening a PR

Use one primary write scope per branch. If a change crosses high-risk contracts such as Matrix ISA semantics, difftest, memory-map, checkpoint format, or rootfs boot flow, split it into serial PRs unless the interface change itself requires a coordinated patch.

## 3. Commit

Use concise Conventional Commits-style subjects:

```text
fix(checkpoint): respect Makefile SimPoint defaults
feat(rootfs): add llama bench model preset
docs(workflow): document branch and PR flow
chore(submodule): bump NEMU to a587e09
```

Guidelines:

- Keep each commit reviewable and buildable when practical.
- Separate mechanical formatting from behavior changes.
- Mention issue IDs in commit bodies when useful: `Fixes #123`, `Refs #123`.
- Do not commit generated artifacts from `local/`, `build/`, `log/`, or `firmware/checkpoints/`.
- For submodule bumps, include the old and new revisions and why the bump is needed.

## 4. Open A Pull Request

Open PRs against `master`.

The PR description should include:

- Linked issue: `Fixes #123` or `Refs #123`
- Summary of the user-visible or workflow-visible change
- Primary workstream and touched paths
- Validation commands run, or a clear reason validation was not run
- Risk notes for coupled areas and expected reviewer focus
- Upstream issue or PR links when the root cause crosses repository boundaries

Keep draft PRs for incomplete work. Convert to ready for review only after the branch is rebased or merged onto current `master` and the listed validation has passed or the remaining gap is explicit.

## 5. Submodule Development

This repository pins many dependencies as git submodules. A submodule change has two different commits:

- the real code commit in the submodule repository
- the gitlink bump commit in `xsai-env`

Do not mix those concepts. The outer repository should point only to a submodule commit that exists in a reachable remote repository.

### Normal Submodule Flow

1. Identify the owning repository from `.gitmodules`.
2. Create or link an issue in the owning repository when the change is not purely local integration.
3. Create a branch inside the submodule from its configured upstream branch.
4. Commit, validate, push, and open a PR in the submodule repository.
5. After the submodule PR is merged, update the submodule checkout in `xsai-env`.
6. Run `make versions`.
7. Commit the gitlink bump and `VERSIONS` update in `xsai-env`, with validation and links to the submodule PR.

Example for `qemu`:

```bash
git submodule update --init qemu
git -C qemu fetch origin
git -C qemu switch -c fix/123-checkpoint-plugin origin/9.0.0_matrix-v0.6

# edit qemu files, validate, then:
git -C qemu status --short
git -C qemu add <paths>
git -C qemu commit -m "fix(riscv): handle checkpoint plugin edge case"
git -C qemu push -u origin fix/123-checkpoint-plugin
```

After the submodule PR is merged:

```bash
git -C qemu fetch origin
git -C qemu checkout <merged-submodule-sha>
git diff --submodule=log qemu
git add qemu
make versions
git add VERSIONS
git commit -m "bump(qemu): update checkpoint plugin fix"
```

Run `make versions` for every intentional root-level submodule bump. It refreshes the top-level `VERSIONS` record so reviewers can inspect the pinned dependency state without reconstructing it from gitlinks.

The root bump PR should include:

- submodule path
- old commit and new commit
- linked submodule issue or PR
- why the bump is needed in `xsai-env`
- whether `make versions` changed `VERSIONS`
- validation run from the root workflow

### Rootfs Issue-Disabled Flow

`firmware/riscv-rootfs` is currently allowed to use a root-tracked
integration issue when its owning repository cannot accept issues.

For this exception:

1. Commit and push the rootfs change to the `riscv-rootfs` remote first.
2. Open an `xsai-env` issue with the matching template prefix, such as
   `[Feature Request] ...` or `[Problem] ...`.
3. State that the root cause or requested code change lives in
   `firmware/riscv-rootfs`, and that the rootfs repository cannot currently
   accept issues.
4. Include the rootfs branch, pushed commit SHA, and any rootfs PR link if one
   exists.
5. Update the `firmware/riscv-rootfs` gitlink in `xsai-env`, run
   `make versions`, and include `VERSIONS` in the parent commit.

This exception does not allow local-only gitlinks. The rootfs commit still must
be pushed and fetchable before the parent PR is opened.

### Nested Submodules

For nested submodules, submit from the inside out.

Example: if a change is inside `XSAI/CUTE`:

1. Commit and merge the change in `XSAI/CUTE`.
2. Update the `XSAI/CUTE` gitlink inside `XSAI` and merge the `XSAI` PR.
3. Update the top-level `XSAI` gitlink inside `xsai-env`, run `make versions`, and open the root bump PR.

Each layer should point to a committed, pushed, reviewable revision from the layer below.

### Local Integration Changes

Sometimes a root PR intentionally depends on an unmerged submodule PR. In that case:

- keep the root PR as draft
- link the submodule PR
- state the exact temporary commit SHA
- do not merge the root PR until the submodule commit is merged or otherwise made stable

Avoid committing a gitlink that points to a local-only commit. Other developers and CI cannot fetch it.

### Updating Existing Submodules

Prefer explicit path updates over broad remote updates:

```bash
git submodule update --init <path>
git -C <path> fetch origin
git -C <path> checkout <sha-or-branch>
git diff --submodule=log <path>
```

Do not run broad `git submodule update --remote --recursive` unless the task is specifically a multi-submodule refresh. Some entries in `.gitmodules` are shallow, pinned to non-default branches, or marked `update = none`.

Use these checks before opening the root PR:

```bash
git status --short
git submodule status --recursive
git diff --submodule=log
```

## 6. Review

Reviewers should prioritize:

- Correctness and behavioral regressions
- Ownership boundaries and whether the right subsystem owns the change
- Validation coverage relative to risk
- Coupled contract changes across `XSAI`, `NEMU`, `qemu`, firmware, toolchain, and software
- Generated artifacts or unrelated churn

Authors should respond by either applying a change or explaining the tradeoff. Resolve review threads only after the code or explanation addresses the concern.

For high-risk coupled changes, require at least one reviewer familiar with the owning subsystem. Examples include Matrix ISA/ABI changes, difftest alignment, DTB or memory-map changes, checkpoint/restore behavior, and rootfs boot-flow changes.

For submodule bump PRs, reviewers should verify that the target commit is fetchable from the submodule remote and that the root validation covers the integration behavior, not only the submodule-local behavior.
They should also verify that `VERSIONS` was refreshed with `make versions` when the root gitlink changed.

## 7. Merge

Before merge:

- PR branch is up to date with `master`.
- CI passes, or failures are understood and documented.
- Required validation from `AGENTS.md` or `docs/workstreams.md` is complete for the touched workstream.
- PR description reflects the final behavior and validation.

Prefer squash or rebase merge to keep `master` linear. Use a final merge title that follows the commit subject style, for example:

```text
fix(checkpoint): respect Makefile SimPoint defaults
```

After merge:

- Close or verify linked issues.
- Delete the feature branch.
- For workflow or agent-rule changes, update `AGENTS.md`, `.agents/skills/`, and relevant docs in the same PR when they are the source of truth.
