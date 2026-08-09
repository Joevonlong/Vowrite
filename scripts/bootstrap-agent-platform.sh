#!/usr/bin/env bash
# Activate and verify the repository-owned, tool-agnostic Git policy hook.

set -euo pipefail

MODE="apply"
TARGET="${PWD}"

usage() {
    echo "Usage: scripts/bootstrap-agent-platform.sh [--check] [--repo PATH]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            MODE="check"
            shift
            ;;
        --repo)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            TARGET="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

REPO_ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Not inside a Git repository: $TARGET" >&2
    exit 2
}
PRE_COMMIT="$REPO_ROOT/.githooks/pre-commit"
PRE_PUSH="$REPO_ROOT/.githooks/pre-push"
BRANCH_GUARD="$REPO_ROOT/.agents/hooks/branch-guard.sh"

if [[ ! -x "$PRE_COMMIT" ]]; then
    echo "Missing executable Git hook: $PRE_COMMIT" >&2
    exit 2
fi
if [[ ! -x "$PRE_PUSH" ]]; then
    echo "Missing executable Git hook: $PRE_PUSH" >&2
    exit 2
fi
if [[ ! -x "$BRANCH_GUARD" ]]; then
    echo "Missing executable canonical guard: $BRANCH_GUARD" >&2
    exit 2
fi

if [[ "$MODE" == "apply" ]]; then
    git -C "$REPO_ROOT" config --local core.hooksPath .githooks
fi

HOOKS_PATH="$(git -C "$REPO_ROOT" config --local --get core.hooksPath 2>/dev/null || true)"
if [[ "$HOOKS_PATH" != ".githooks" ]]; then
    echo "core.hooksPath is '$HOOKS_PATH'; expected '.githooks'." >&2
    echo "Run: $REPO_ROOT/scripts/bootstrap-agent-platform.sh" >&2
    exit 2
fi

echo "Agent platform bootstrap: OK"
echo "  repo: $REPO_ROOT"
echo "  core.hooksPath: .githooks"
echo "  note: Claude Code and Codex project hooks remain subject to each tool's workspace trust review"
