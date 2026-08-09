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

WORKTREE_CONFIG_ENABLED="$(git -C "$REPO_ROOT" config --local --bool --get extensions.worktreeConfig 2>/dev/null || true)"

for_each_worktree() {
    local record
    local worktree
    local failed=0

    while IFS= read -r -d '' record; do
        case "$record" in
            worktree\ *)
                worktree="${record#worktree }"
                if ! "$@" "$worktree"; then
                    failed=1
                fi
                ;;
        esac
    done < <(git -C "$REPO_ROOT" worktree list --porcelain -z)
    return "$failed"
}

clear_worktree_hooks_override() {
    local worktree="$1"
    if git -C "$worktree" config --worktree --get-all core.hooksPath >/dev/null 2>&1; then
        git -C "$worktree" config --worktree --unset-all core.hooksPath || {
            echo "Cannot clear worktree core.hooksPath override: $worktree" >&2
            return 2
        }
    fi
}

verify_effective_hooks_path() {
    local worktree="$1"
    local hooks_path
    hooks_path="$(git -C "$worktree" config --get core.hooksPath 2>/dev/null || true)"
    if [[ "$hooks_path" != ".githooks" ]]; then
        echo "Effective core.hooksPath is '$hooks_path' in '$worktree'; expected '.githooks'." >&2
        return 2
    fi
}

if [[ "$MODE" == "apply" ]]; then
    git -C "$REPO_ROOT" config --local core.hooksPath .githooks
    if [[ "$WORKTREE_CONFIG_ENABLED" == "true" ]]; then
        for_each_worktree clear_worktree_hooks_override
    fi
fi

LOCAL_HOOKS_PATH="$(git -C "$REPO_ROOT" config --local --get core.hooksPath 2>/dev/null || true)"
if [[ "$LOCAL_HOOKS_PATH" != ".githooks" ]]; then
    echo "Repository core.hooksPath is '$LOCAL_HOOKS_PATH'; expected '.githooks'." >&2
    echo "Run: $REPO_ROOT/scripts/bootstrap-agent-platform.sh" >&2
    exit 2
fi
if ! for_each_worktree verify_effective_hooks_path; then
    echo "Run: $REPO_ROOT/scripts/bootstrap-agent-platform.sh" >&2
    exit 2
fi

echo "Agent platform bootstrap: OK"
echo "  repo: $REPO_ROOT"
echo "  core.hooksPath: .githooks"
echo "  note: Claude Code and Codex project hooks remain subject to each tool's workspace trust review"
