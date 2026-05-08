---
name: xsai-issue-pr-flow
description: Guide for creating xsai-env GitHub issues and PRs. Use when opening issues, choosing issue templates, writing issue titles/bodies, creating branches from issues, preparing PR descriptions, or following the issue-first workflow in xsai-env.
---

# XSAI Issue And PR Flow

Use this skill before creating or editing GitHub issues or PRs for `xsai-env`.

## Issue Template First

Before creating an issue:

1. Read `.github/ISSUE_TEMPLATE/`.
2. Choose the matching template:
   - `Bug report`: confirmed incorrect behavior.
   - `Feature request`: new capability, workflow, documentation, or automation improvement.
   - `Build or runtime problem`: failure whose root cause is not confirmed.
   - `Other question`: only when the other templates do not fit.
3. If the target repository has no matching template, has issues disabled, or the issue belongs in a submodule repository, report that before creating anything.
4. Search existing issues briefly to avoid duplicates.

Do not use a blank issue if `blank_issues_enabled: false`.

## Issue Titles

Issue titles are human-facing problem/request summaries, not commit messages.

Use the template prefix in the title:

- `[Bug Report] <clear incorrect behavior>`
- `[Feature Request] <clear requested capability>`
- `[Problem] <clear failing workflow or symptom>`
- `[Question] <clear question>`

Good examples:

- `[Feature Request] Document the repository Git workflow and submodule contribution process`
- `[Feature Request] Make local environment overrides work consistently in env.sh and direnv`
- `[Problem] Firmware checkpoint replay fails after generated payload selection`
- `[Bug Report] make ckpt uses the wrong SimPoint interval from the top-level flow`

Avoid commit-style titles for issues:

- `docs(workflow): codify issue-first Git and submodule development flow`
- `fix(checkpoint): align SimPoint defaults`

Use Conventional Commit style for commits and PR titles when appropriate, not for issue titles unless the repository convention explicitly says so.

## Issue Body

Follow the selected template fields. For feature requests, describe the pre-change problem first:

- What cannot be done today?
- What goes wrong or becomes confusing before the change?
- Who is affected: user, CI, Agent, reviewer, or maintainer?
- What files or workflow are likely involved?

For bugs/problems, include exact commands, logs or log locations, environment/revision details, and whether the issue reproduces on current `master`.

## Branch And PR

After an issue exists, create a scoped branch:

```bash
git switch master
git pull --ff-only origin master
git switch -c fix/<issue>-short-topic
git switch -c feat/<issue>-short-topic
git switch -c docs/<issue>-short-topic
```

PR titles may use Conventional Commit style, for example:

- `docs(workflow): document Git and submodule flow`
- `feat(checkpoint): add weighted SimPoint evaluation helper`

PR bodies should link the issue, list touched workstreams, state submodule status, and include validation.

## Submodules

For submodule code changes, also use `xsai-submodule-git-flow`.

If the owning submodule repository has issues disabled or lacks templates, do not invent a root issue silently. Report the blocker and ask whether to:

- enable issues in the submodule repository,
- track the work as an `xsai-env` integration issue,
- or proceed with a PR-only flow.

Known exception: `firmware/riscv-rootfs` may be tracked by an `xsai-env`
integration issue while rootfs issues are unavailable. The issue body must say
that the code change lives in rootfs, explain why the root issue is used, and
link the pushed rootfs branch/commit before the parent gitlink bump PR is
opened.
