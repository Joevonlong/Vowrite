---
name: vowrite-review
description: "Run an evidence-based Vowrite code, architecture, or security review at a fixed baseline. Use for full, cluster, feature, or change-set reviews."
---

# Vowrite review

Review is read-only unless the user separately authorizes fixes. Use model-neutral roles: one primary reviewer and, when parallel review is authorized, an independent challenger. Never hardcode model names, historical file counts, or a moving `HEAD`.

## 1. Freeze the review contract

Record repository root, full baseline and target SHAs, dirty state, worktrees, scope, affected platforms, review dimensions, severity rubric, and output path. Read `AGENTS.md`, the relevant spec, and the current review charter under `Vowrite-internal/reviews/` when available.

Supported scopes are full repository, architecture cluster, feature F-ID, or an explicit commit range. Count files and tests dynamically with `rg --files` and test output.

## 2. Run deterministic evidence

Use `ops/scripts/review-scan.sh` for the requested rule set and save its report. Run focused unit tests, `ops/scripts/test-agent-platform.sh` for agent infrastructure changes, `scripts/check-parity.sh` for platform-sensitive work, and `ops/scripts/test.sh` once for a full completion review.

For a clean Swift build, use `swift package clean` followed by `swift build`; `swift build --clean` is not a valid command. Preserve logs with `mktemp`, and distinguish missing tools or unavailable credentials from a pass.

## 3. Review the change on two axes

Standards axis: correctness, security/privacy, concurrency, lifecycle, error handling, test quality, documentation, platform parity, and repository conventions.

Spec axis: requirement coverage, acceptance evidence, scope control, architecture consistency, migration/rollback, and any unverified manual or live gate.

Trace every finding to a tight file/line range and explain impact plus the smallest credible fix. Rank P0 through P3 from actual risk; do not inherit old severities without revalidation.

## 4. Challenge and consolidate

Actively search for counterexamples to high-severity findings and for paths that bypass the proposed enforcement. Collapse duplicate symptoms into root causes. Recheck current state before the final verdict so concurrent commits do not invalidate the baseline.

If fixes were authorized, implement them in an isolated task worktree, rerun the affected evidence, and review the resulting fixed diff. Otherwise, leave the tree unchanged and hand off precise remediation.

## 5. Publish a durable report

Write the report under `Vowrite-internal/reviews/{date}-{scope}/` when the workspace exists; otherwise return a standalone report artifact. Include baseline/target SHAs, scope, commands/results, findings, passed checks, limitations, manual gates, and recommended disposition.

The report is complete only when another reviewer can reproduce every claim without relying on an ephemeral chat transcript.
