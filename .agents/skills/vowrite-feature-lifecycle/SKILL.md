---
name: vowrite-feature-lifecycle
description: "Run a Vowrite feature through spec creation, isolated implementation, immutable handoff, integration, and tracking sync. Use when a feature is proposed, changes state, or finishes."
---

# Vowrite feature lifecycle

Treat product code and workspace tracking as two repositories with separate commits and task records. A worker never spans both repositories in one write task.

## 1. Establish topology and state

Locate the product Git root and, when present, the surrounding workspace root. Record both full SHAs, branches, status, remotes, and worktrees. Read `AGENTS.md`, the relevant feature spec, and `Vowrite-internal/tracking/DOC_UPDATE_POLICY.md` when the workspace exists.

Classify the run as create, update, implementation, or completion sync. Finish this step only when every repository and owner boundary is explicit.

## 2. Create or update the durable spec

In a full workspace, use `Vowrite-internal/tracking/FEATURES.md` to allocate the next F-ID and write `Vowrite-internal/tracking/features/F-{ID}-{slug}.md`. In a standalone product clone, do not invent tracking state: produce a structured tracking handoff for the workspace integration owner.

The spec records status, priority, target version, creation date, dependencies, owner, and `Platforms:`. Allowed platform values are `[mac]`, `[ios]`, `[mac, ios]`, and `[meta]`. Match the established tracking language; internal Chinese specs are allowed even though product code and public repository docs are English.

Define motivation, scope/non-scope, design, files, risks, acceptance commands, manual gates, and rollback. Mark uncertain claims as assumptions. Completion criterion: the feature table and spec agree, or a standalone tracking handoff names every required update.

## 3. Start isolated implementation

Create the product task with `scripts/agent-task.sh start`. If a trusted tool already created the non-main worktree, run `scripts/agent-task.sh adopt` there before writing. When the primary checkout is itself on a worker branch and no checkout owns `main`, first run `scripts/agent-task.sh ensure-integration-checkout --owner <integrator-id> --worktree <absolute-path>` from a clean worktree. In all paths, pin a full base SHA, assign one owner, declare a non-overlapping exact-path or `directory/**` write-set, and provide behavior-level acceptance commands. Use one task worktree per writing agent.

Workspace tracking edits use their own workspace branch/worktree and owner. Serialize shared Markdown tables through the workspace integration owner.

## 4. Implement and hand off

Stay inside the assigned write-set. Run focused checks during implementation and the declared full checks before handoff. Commit on the task branch, leave the worktree clean, then run:

```bash
scripts/agent-task.sh handoff --task F-XXX --owner <agent-id> --commit <full-result-sha>
```

The handoff is complete only when the manifest is `ready`, contains the result SHA, and points to passing acceptance evidence.

## 5. Integrate through the owner

The single integration owner claims the lease and integrates the pinned result. If another completed task moved `main` and the manifest has no `integration_attempt`, the worker refreshes onto the new full SHA and repeats handoff; the integrator never merges a stale result dynamically. A conflicting refresh enters the explicit `refreshing` state: resolve and stage only declared write-set paths, then run `refresh-continue` until complete, or use `refresh-abort` to restore the pre-refresh branch and manifest state.

If an integration was interrupted after its commit, the ready manifest retains `integration_attempt`. Never refresh that task: the same lease owner reruns `integrate` with the exact original message so the coordinator can verify and reconcile the existing commit. A pre-commit failure before commit creation is rolled back automatically to a clean, retryable ready state.

Remote publication requires explicit user authorization. Workers never merge, push, switch shared checkouts, delete branches, or edit tracking.

If work is cancelled while `active` or `ready`, the task owner runs `scripts/agent-task.sh abort --task F-XXX --owner <agent-id> --reason "..."` from a clean main integration checkout. The command records the final recoverable commit and reason, then removes only that task's worktree and branch so its write-set is released.

## 6. Synchronize tracking

After product integration, the workspace integration owner updates all applicable records in one reviewable tracking change:

- feature spec implementation record and evidence;
- `FEATURES.md` status/version/commit;
- `TODO.md` completed and follow-up items;
- `DASHBOARD.md` material status changes;
- `development.md` only for release history or a material architecture milestone;
- the platform-appropriate changelog only when shipped user behavior changed;
- a durable local review/report file when the spec references an evaluation.

Use `Partial` while any code, evidence, manual gate, or tracking item remains. Use `Done` only after repository state and documentation agree. Report product and workspace commits separately.
