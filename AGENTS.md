# AGENTS.md — Vowrite product repository

This file is the product repository's authoritative agent contract. It works in a standalone clone, a linked Git worktree, or as `Vowrite/` inside `Vowrite-Workspace`. The surrounding workspace may add tracking rules, but this file is sufficient for product work.

Claude Code loads the same contract through `CLAUDE.md`; Codex reads it natively. Product skills and policy code live in `.agents/`. Do not copy shared rules into tool-specific files.

## Session bootstrap

Before any write:

```bash
scripts/bootstrap-agent-platform.sh
```

This activates `.githooks/pre-commit` and `.githooks/pre-push` for the clone. Claude Code and Codex project hooks are useful early guards, but each tool may require a workspace-trust review. The Git hooks are tool-agnostic backstops and fail closed when their canonical guard is missing.

## Parallel work contract

Every product write task uses one task branch in one isolated worktree. The shared checkout is never a worker workspace.

The task manifest must pin:

- task ID and owner;
- base SHA;
- branch and absolute worktree path;
- exclusive write-set;
- acceptance commands;
- result commit at handoff.

Create it from a clean integration checkout:

```bash
scripts/agent-task.sh start \
  --task F-XXX \
  --owner <agent-id> \
  --base <full-commit-sha> \
  --branch feature/F-XXX-<slug> \
  --worktree /absolute/path/to/worktree \
  --write-set 'VowriteKit/**' \
  --accept 'ops/scripts/test.sh'
```

`agent-task` stores manifests and the integration lease in the Git common directory, shared by every linked worktree. It rejects an active overlapping write-set. Use separate tasks only for genuinely disjoint changes.

If Claude Code, Codex, or another trusted orchestrator already created the non-main worktree, register it before writing or committing. `adopt` requires an explicit ancestor base SHA and verifies every existing changed/untracked path against the declared write-set:

If the primary checkout is already being used by another feature branch and no checkout owns `main`, first provision the stable integration checkout through the coordinator:

```bash
scripts/agent-task.sh ensure-integration-checkout \
  --owner <integrator-id> \
  --worktree /absolute/path/to/main-integration
```

```bash
scripts/agent-task.sh adopt \
  --task F-XXX \
  --owner <agent-id> \
  --base <full-commit-sha> \
  --write-set 'VowriteKit/**' \
  --accept 'ops/scripts/test.sh'
```

### Worker responsibilities

Workers, including headless Claude Code and `codex exec`, stay on the assigned branch and worktree. They may edit, test, and commit only their declared write-set. They do not switch branches, merge, push, edit workspace tracking, delete worktrees, or update task manifests manually.

Finish with a clean worktree and a structured handoff:

```bash
scripts/agent-task.sh handoff \
  --task F-XXX \
  --owner <agent-id> \
  --commit <full-result-sha>
```

The command verifies the result is the branch tip, every changed path is inside the write-set, the worktree is clean, and every acceptance command passes. It records the immutable result SHA and evidence log.

### Integration owner responsibilities

Exactly one integration owner holds the repository lease. Only that owner may update `main`, push, or clean completed task branches.

```bash
scripts/agent-task.sh claim-integration --owner <integrator-id>
scripts/agent-task.sh integrate --task F-XXX --owner <integrator-id> --message "feat: description"
```

Integration is SHA-pinned: `main` must still equal the task's base SHA. If another task landed first, the worker runs `refresh`, resolves any conflict inside its own worktree, reruns `handoff`, and then the integrator retries:

```bash
scripts/agent-task.sh refresh --task F-XXX --owner <agent-id> --base <new-main-sha>
```

If rebase stops on a conflict, the manifest enters `refreshing` and the worktree remains at the conflict. Resolve and stage only declared write-set paths, then continue; repeat for later conflicts. To return exactly to the pre-refresh branch and manifest state, abort through the coordinator:

```bash
scripts/agent-task.sh refresh-continue --task F-XXX --owner <agent-id>
# or
scripts/agent-task.sh refresh-abort --task F-XXX --owner <agent-id>
```

If an active or ready task is deliberately cancelled, its owner runs the audited abort from a clean main integration checkout. This records the last recoverable commit and reason before removing only that task's worktree and branch:

```bash
scripts/agent-task.sh abort --task F-XXX --owner <agent-id> --reason "why the task was cancelled"
```

Remote publication is a separate external action. Run it only when the user explicitly authorizes a push:

```bash
scripts/agent-task.sh publish --task F-XXX --owner <integrator-id>
scripts/agent-task.sh cleanup --task F-XXX --owner <integrator-id>
scripts/agent-task.sh release-integration --owner <integrator-id>
```

Use `cleanup --local-only` only for a deliberately local integration. Never substitute a dynamic `HEAD` for a recorded base or result SHA.

## Branch and commit policy

- Product task branches: `feature/F-{ID}-{slug}`, `fix/{slug}`, or another task-specific branch approved by the integration owner.
- Every agent-authored product change, including scripts and configuration, uses a task worktree. `main` is integration-only.
- Commits use `<type>: <description>` with types `feat`, `fix`, `docs`, `refactor`, `chore`, `security`, `style`, or `test`.
- Prefer platform scopes such as `feat(mac):`, `feat(ios):`, `feat(kit):`, and `feat(ops):`.
- Commit messages and repository documentation are English.
- Never add AI authorship trailers. The configured human remains the commit author.

## Build and test

```bash
cd VowriteMac && swift build
ops/scripts/test-agent-platform.sh
ops/scripts/test.sh
scripts/check-parity.sh
```

Run focused tests while working and the full suite once before handoff. Shared logic tests live under `VowriteKit/Tests/VowriteKitTests/` and observe public behavior rather than implementation details.

## Repository layout

- `VowriteKit/` — shared macOS/iOS library: audio, engine, provider registry, STT adapters, polish services, configuration, models, and IPC.
- `VowriteMac/` — macOS menu-bar app and platform adapters.
- `VowriteIOS/` — iOS host app.
- `VowriteKeyboard/` — iOS keyboard extension.
- `ops/scripts/` — test, review, build, and release operations.
- `scripts/` — parity, agent-task, and bootstrap commands.
- `.agents/` — canonical product skills and policy hooks.

## Platform and changelog policy

Every macOS feature must be evaluated for iOS host and keyboard parity. Run `scripts/check-parity.sh` before handoff whenever macOS or shared code changes.

Changelog routing:

- `VowriteMac/` only → `CHANGELOG.md`;
- `VowriteIOS/` or `VowriteKeyboard/` only → `CHANGELOG-IOS.md`;
- user-visible `VowriteKit/` behavior → `CHANGELOG.md` by conservative default;
- cross-platform user-visible behavior → both changelogs, with platform-specific prose;
- agent infrastructure, docs, tests, and scripts → neither changelog unless they change shipped behavior.

`AppVersion.current`, macOS tags, and `ops/scripts/release.sh` belong to the macOS release track. Vowrite currently has no iOS release version or iOS tags.

## Product skills

- `vowrite-feature-lifecycle` — spec, task, handoff, integration, and tracking lifecycle.
- `vowrite-provider-integration` — registry-first STT or polish provider integration.
- `vowrite-release` — beta/stable macOS release with explicit remote gates.
- `vowrite-review` — evidence-based code and security review without fixed model roles or stale file counts.

Skills are canonical in `.agents/skills/`; `.claude/skills` is only a relative mount. Tool-specific settings may differ, but shared workflow knowledge stays in `.agents/` and this file.

## Enforcement model

`.agents/hooks/branch-guard.sh` is the single branch-policy implementation:

- Claude Code: `.claude/settings.json` matches `Bash|Edit|Write`;
- Codex: `.codex/hooks.json` matches `Bash|apply_patch`;
- Git commit: `.githooks/pre-commit` requires either the registered task/write-set or a validated main integration/release context.
- Git push: `.githooks/pre-push` rejects direct publication and accepts only the pinned `agent-task publish` context or an explicit validated release context.

On `main`, Bash is default-deny except for a small read-only allowlist and exact control commands. File hooks validate that targets stay in the current registered worktree; cross-worktree targets fail. Shell parsing is not a security sandbox, and this repository does not assume GitHub branch protection is enabled. The local Git gates, task manifest, immutable SHAs, acceptance checks, and CI provide the repository-owned enforcement layers; server-side branch protection remains a separately administered defense.
