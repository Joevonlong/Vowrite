#!/usr/bin/env bash
# Commit only the explicitly staged release paths and roll them back on failure.

set -euo pipefail

MESSAGE=""
PATHS=()

usage() {
    echo "Usage: ops/scripts/release-git-commit.sh --message MESSAGE --path PATH [--path PATH ...]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --message)
            MESSAGE="${2:-}"
            shift 2
            ;;
        --path)
            PATHS+=("${2:-}")
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

[[ -n "$MESSAGE" && ${#PATHS[@]} -gt 0 ]] || {
    usage >&2
    exit 2
}

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Release commit must run inside a Git repository." >&2
    exit 2
}
BEFORE_HEAD="$(git -C "$ROOT" rev-parse HEAD)"

if git -C "$ROOT" diff --cached --quiet --exit-code -- "${PATHS[@]}"; then
    echo "  (nothing to commit)"
    exit 0
fi

if VOWRITE_RELEASE=1 git -C "$ROOT" commit -m "$MESSAGE" -- "${PATHS[@]}"; then
    exit 0
fi

AFTER_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
if [[ "$AFTER_HEAD" != "$BEFORE_HEAD" ]]; then
    echo "Release commit returned failure after HEAD moved to $AFTER_HEAD; refusing an automatic rewind." >&2
    exit 2
fi

git -C "$ROOT" restore --source=HEAD --staged --worktree -- "${PATHS[@]}" || {
    echo "Release commit failed and the explicit release paths could not be rolled back." >&2
    exit 2
}
echo "Release commit failed; explicit release paths were rolled back and no tag was created." >&2
exit 1
