#!/usr/bin/env bash
# Canonical Vowrite write policy for Claude Code, Codex, pre-commit, and pre-push.

set -uo pipefail

deny() {
    echo "Vowrite agent policy: $1" >&2
    exit 2
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        deny "required command '$1' is unavailable; refusing to bypass the guard"
    fi
}

is_governed_root() {
    local root="$1"
    [[ -f "$root/AGENTS.md" ]] || return 1
    [[ -d "$root/VowriteKit" && -d "$root/VowriteMac" ]] && return 0
    [[ -d "$root/Vowrite-internal" ]] && return 0
    return 1
}

is_product_root() {
    local root="$1"
    [[ -d "$root/VowriteKit" && -d "$root/VowriteMac" ]]
}

canonical_candidate_path() {
    local candidate="$1"
    local cwd="$2"
    local suffix=""
    local name
    local resolved

    if [[ "$candidate" != /* ]]; then
        candidate="$cwd/$candidate"
    fi
    while [[ ! -e "$candidate" && ! -L "$candidate" && "$candidate" != "/" ]]; do
        name="$(basename "$candidate")"
        suffix="$name${suffix:+/$suffix}"
        candidate="$(dirname "$candidate")"
    done

    command -v realpath >/dev/null 2>&1 || return 1
    resolved="$(realpath "$candidate" 2>/dev/null)" || return 1
    if [[ -n "$suffix" ]]; then
        printf '%s/%s\n' "$resolved" "$suffix"
    else
        printf '%s\n' "$resolved"
    fi
}

absolute_existing_parent() {
    local candidate="$1"
    local cwd="$2"
    local resolved

    resolved="$(canonical_candidate_path "$candidate" "$cwd" 2>/dev/null)" || return 1
    while [[ ! -d "$resolved" && "$resolved" != "/" ]]; do
        resolved="$(dirname "$resolved")"
    done
    [[ -d "$resolved" ]] || return 1
    (cd "$resolved" 2>/dev/null && pwd -P)
}

governed_root_for_path() {
    local candidate="$1"
    local cwd="$2"
    local parent
    local root

    parent="$(absolute_existing_parent "$candidate" "$cwd" 2>/dev/null || true)"
    [[ -n "$parent" ]] || return 1
    root="$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$root" ]] || return 1
    is_governed_root "$root" || return 1
    printf '%s\n' "$root"
}

current_governed_root() {
    local cwd="$1"
    local root
    root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$root" ]] && is_governed_root "$root"; then
        printf '%s\n' "$root"
    fi
}

branch_for_root() {
    git -C "$1" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'DETACHED\n'
}

guard_file_path() {
    local candidate="$1"
    local cwd="$2"
    local current_root
    local target_root
    local target_branch
    local relative_path

    current_root="$(current_governed_root "$cwd")"
    target_root="$(governed_root_for_path "$candidate" "$cwd" 2>/dev/null || true)"

    if [[ -n "$current_root" ]]; then
        [[ -n "$target_root" ]] || deny "path '$candidate' is outside the current governed repository"
        [[ "$target_root" == "$current_root" ]] || deny "cross-repository/worktree write from '$current_root' to '$target_root'"
        target_branch="$(branch_for_root "$current_root")"
        if [[ "$target_branch" == "main" ]]; then
            deny "writes require an isolated registered task worktree; '$current_root' is on '$target_branch'"
        fi
        registered_task_manifest "$current_root" \
            || deny "feature branch '$target_branch' is not the unique active registered task worktree"
        if [[ "$target_branch" == "DETACHED" ]] \
            && ! jq -e '.status == "refreshing"' "$REGISTERED_MANIFEST" >/dev/null 2>&1; then
            deny "detached writes are allowed only during a registered refresh conflict"
        fi
        relative_path="$(repo_relative_candidate "$current_root" "$candidate" "$cwd" 2>/dev/null || true)"
        [[ -n "$relative_path" ]] || deny "cannot normalize write target '$candidate' inside '$current_root'"
        manifest_contains_path "$REGISTERED_MANIFEST" "$relative_path" \
            || deny "path '$relative_path' exceeds the registered task write-set"
        return 0
    fi

    [[ -n "$target_root" ]] || return 0
    target_branch="$(branch_for_root "$target_root")"
    if [[ "$target_branch" == "main" || "$target_branch" == "DETACHED" ]]; then
        deny "writes to '$candidate' require an isolated task worktree; '$target_root' is on '$target_branch'"
    fi
}

has_shell_control_syntax() {
    local command_text="$1"
    case "$command_text" in
        *$'\n'*|*';'*|*'|'*|*'&'*|*'>'*|*'<'*|*'`'*|*'$('* ) return 0 ;;
    esac
    return 1
}

normalize_command_text() {
    local command_text="$1"
    local continuation=$'\\\n'
    while [[ "$command_text" == *"$continuation"* ]]; do
        command_text="${command_text//$continuation/ }"
    done
    printf '%s\n' "$command_text"
}

is_safe_control_command() {
    local command_text="$1"
    local root="$2"

    has_shell_control_syntax "$command_text" && return 1
    [[ "$command_text" =~ ^[[:space:]]*(\./)?scripts/agent-task\.sh([[:space:]].*)?[[:space:]]*$ ]] && return 0
    [[ "$command_text" =~ ^[[:space:]]*${root//./\.}/scripts/agent-task\.sh([[:space:]].*)?[[:space:]]*$ ]] && return 0
    [[ "$command_text" =~ ^[[:space:]]*(\./)?scripts/bootstrap-agent-platform\.sh([[:space:]].*)?[[:space:]]*$ ]] && return 0
    [[ "$command_text" =~ ^[[:space:]]*${root//./\.}/scripts/bootstrap-agent-platform\.sh([[:space:]].*)?[[:space:]]*$ ]] && return 0
    [[ "$command_text" =~ ^[[:space:]]*(\./)?scripts/publish-release\.sh([[:space:]].*)?[[:space:]]*$ ]] && return 0
    [[ "$command_text" =~ ^[[:space:]]*${root//./\.}/scripts/publish-release\.sh([[:space:]].*)?[[:space:]]*$ ]] && return 0
    [[ "$command_text" =~ ^[[:space:]]*(\./)?ops/scripts/release\.sh([[:space:]].*)?[[:space:]]*$ ]] && return 0
    [[ "$command_text" =~ ^[[:space:]]*${root//./\.}/ops/scripts/release\.sh([[:space:]].*)?[[:space:]]*$ ]] && return 0
    return 1
}

parse_git_invocation() {
    local command_text="$1"
    local tokens=()
    local token
    local index

    GIT_FOUND=false
    GIT_SUBCOMMAND=""
    GIT_DANGEROUS_GLOBAL=false
    GIT_HAS_C=false
    IFS=$' \t' read -r -a tokens <<< "$command_text"
    (( ${#tokens[@]} > 0 )) || return 1
    token="${tokens[0]}"
    token="${token#\"}"; token="${token#\'}"
    token="${token%\"}"; token="${token%\'}"
    [[ "${token##*/}" == "git" ]] || return 1

    GIT_FOUND=true
    index=1
    while (( index < ${#tokens[@]} )); do
        token="${tokens[$index]}"
        token="${token#\"}"; token="${token#\'}"
        token="${token%\"}"; token="${token%\'}"
        case "$token" in
            -C)
                GIT_HAS_C=true
                index=$((index + 2))
                continue
                ;;
            -c|--config-env|--git-dir|--work-tree|--namespace|--super-prefix|--exec-path)
                GIT_DANGEROUS_GLOBAL=true
                index=$((index + 2))
                continue
                ;;
            -c*|--config-env=*|--git-dir=*|--work-tree=*|--namespace=*|--super-prefix=*|--exec-path=*)
                GIT_DANGEROUS_GLOBAL=true
                index=$((index + 1))
                continue
                ;;
            --no-pager|--no-replace-objects|--bare|--literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|--icase-pathspecs|--no-lazy-fetch)
                index=$((index + 1))
                continue
                ;;
            --)
                index=$((index + 1))
                continue
                ;;
            -*)
                GIT_DANGEROUS_GLOBAL=true
                index=$((index + 1))
                continue
                ;;
            *)
                GIT_SUBCOMMAND="${token##*/}"
                return 0
                ;;
        esac
    done
    return 0
}

is_read_only_command() {
    local command_text="$1"

    has_shell_control_syntax "$command_text" && return 1
    [[ "$command_text" =~ (^|[[:space:]])--output(=|[[:space:]]|$) ]] && return 1
    [[ "$command_text" =~ (^|[[:space:]])--in-place(=|[[:space:]]|$) ]] && return 1
    [[ "$command_text" =~ (^|[[:space:]])--open-files-in-pager(=|[[:space:]]|$) ]] && return 1
    [[ "$command_text" =~ (^|[[:space:]])--pre(=|[[:space:]]|$) ]] && return 1
    [[ "$command_text" =~ (^|[[:space:]])--(ext-diff|textconv)([[:space:]]|$) ]] && return 1
    [[ "$command_text" =~ (^|[[:space:]])-O([^[:space:]]*|[[:space:]]+[^[:space:]]+) ]] && return 1

    if parse_git_invocation "$command_text"; then
        [[ "$GIT_DANGEROUS_GLOBAL" == false ]] || return 1
        case "$GIT_SUBCOMMAND" in
            status|diff|log|show|rev-parse|merge-base|ls-files|grep|blame|describe)
                return 0
                ;;
            config)
                [[ "$command_text" =~ (^|[[:space:]])(--add|--replace-all|--unset|--unset-all|--rename-section|--remove-section|--edit|-e)([[:space:]]|$) ]] && return 1
                [[ "$command_text" =~ (^|[[:space:]])(--get|--get-all|--get-regexp|--get-urlmatch|--list|-l|--show-origin|--show-scope)([[:space:]]|$) ]]
                return
                ;;
            worktree)
                [[ "$command_text" =~ (^|[[:space:]])worktree[[:space:]]+list([[:space:]]|$) ]]
                return
                ;;
            branch)
                [[ "$command_text" =~ (^|[[:space:]])branch[[:space:]]+(--show-current|--list)[[:space:]]*$ ]]
                return
                ;;
            remote)
                [[ "$command_text" =~ (^|[[:space:]])remote[[:space:]]+(-v|get-url([[:space:]]+[^[:space:]]+)?)[[:space:]]*$ ]]
                return
                ;;
            tag)
                [[ "$command_text" =~ (^|[[:space:]])tag[[:space:]]+--list([[:space:]]+[^[:space:]]+)?[[:space:]]*$ ]]
                return
                ;;
            submodule)
                [[ "$command_text" =~ (^|[[:space:]])submodule[[:space:]]+status([[:space:]]|$) ]]
                return
                ;;
            *)
                return 1
                ;;
        esac
    fi

    [[ "$command_text" =~ ^[[:space:]]*([^[:space:]]*/)?(rg|grep|cat|head|tail|wc|ls|pwd|stat|readlink|realpath|file|shasum|md5|diff|comm|cut|tr|jq|which)([[:space:]]|$) ]] && return 0
    [[ "$command_text" =~ ^[[:space:]]*([^[:space:]]*/)?command[[:space:]]+-v([[:space:]]|$) ]] && return 0
    [[ "$command_text" =~ ^[[:space:]]*([^[:space:]]*/)?(echo|printf)([[:space:]]|$) ]] && return 0
    if [[ "$command_text" =~ ^[[:space:]]*([^[:space:]]*/)?find([[:space:]]|$) ]] \
        && [[ ! "$command_text" =~ (^|[[:space:]])-(delete|exec|execdir|ok|okdir|fprint|fprint0|fprintf|fls)([[:space:]]|$) ]]; then
        return 0
    fi
    [[ "$command_text" =~ ^[[:space:]]*([^[:space:]]*/)?bash[[:space:]]+-n([[:space:]]|$) ]] && return 0
    return 1
}

is_direct_remote_mutation() {
    local command_text="$1"
    if parse_git_invocation "$command_text" && [[ "$GIT_SUBCOMMAND" == "push" ]]; then
        return 0
    fi
    [[ "$command_text" =~ (^|[[:space:];|&()])([^[:space:];|&()]*/)?gh[[:space:]]+(pr|release|repo)[[:space:]]+(create|edit|delete|merge)([[:space:]]|$) ]] && return 0
    [[ "$command_text" =~ (^|[[:space:];|&()])([^[:space:];|&()]*/)?gh[[:space:]]+api[[:space:]].*(-X|--method)[[:space:]]*(POST|PUT|PATCH|DELETE)([[:space:]]|$) ]] && return 0
    return 1
}

is_forbidden_repository_control() {
    local command_text="$1"
    parse_git_invocation "$command_text" || return 1
    [[ "$GIT_DANGEROUS_GLOBAL" == false ]] || return 0
    case "$GIT_SUBCOMMAND" in
        add)
            return 1
            ;;
        commit)
            [[ "$command_text" =~ (^|[[:space:]])(--no-verify|-n)([[:space:]]|$) ]] && return 0
            return 1
            ;;
        status|diff|log|show|rev-parse|merge-base|ls-files|grep|blame|describe|config|worktree|branch|remote|tag|submodule)
            is_read_only_command "$command_text" && return 1
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

command_targets_other_main_worktree() {
    local command_text="$1"
    local current_root="$2"
    local worktree_path
    local worktree_branch
    local token
    local token_root
    local tokens=()

    [[ "$command_text" == *"../"* ]] && return 0
    IFS=$' \t' read -r -a tokens <<< "$command_text"
    for token in "${tokens[@]}"; do
        token="${token#\"}"
        token="${token#\'}"
        token="${token%\"}"
        token="${token%\'}"
        token="${token%;}"
        token="${token%,}"
        token_root="$(governed_root_for_path "$token" "$current_root" 2>/dev/null || true)"
        if [[ -n "$token_root" && "$token_root" != "$current_root" && "$(branch_for_root "$token_root")" == "main" ]]; then
            return 0
        fi
    done
    while IFS= read -r worktree_path; do
        [[ -n "$worktree_path" && "$worktree_path" != "$current_root" ]] || continue
        worktree_branch="$(branch_for_root "$worktree_path")"
        if [[ "$worktree_branch" == "main" && "$command_text" == *"$worktree_path"* ]]; then
            return 0
        fi
    done < <(git -C "$current_root" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
    return 1
}

registered_worker_command_allowed() {
    local command_text="$1"
    local root="$2"
    local cwd="$3"
    local tokens=()
    local binary
    local token
    local relative_path
    local index

    if parse_git_invocation "$command_text"; then
        [[ "$GIT_DANGEROUS_GLOBAL" == false ]] || return 1
        [[ "$GIT_HAS_C" == false ]] || return 1
        case "$GIT_SUBCOMMAND" in
            add|commit) return 0 ;;
            *) return 1 ;;
        esac
    fi

    [[ "$command_text" =~ ^[[:space:]]*(\./)?(ops/scripts/test\.sh|ops/scripts/test-agent-platform\.sh|ops/scripts/website-check\.sh|scripts/check-[^[:space:]]+\.sh|scripts/check-parity\.sh|scripts/sync-agent-platform\.sh)([[:space:]]|$) ]] && return 0
    [[ "$command_text" =~ ^[[:space:]]*([^[:space:]]*/)?(swift[[:space:]]+(build|test)|xcodebuild|shellcheck)([[:space:]]|$) ]] && return 0

    IFS=$' \t' read -r -a tokens <<< "$command_text"
    [[ ${#tokens[@]} -gt 1 ]] || return 1
    binary="${tokens[0]#\"}"; binary="${binary#\'}"
    binary="${binary%\"}"; binary="${binary%\'}"
    binary="${binary##*/}"
    case "$binary" in
        touch)
            index=1
            ;;
        mkdir)
            index=1
            [[ "${tokens[$index]:-}" == "-p" ]] && index=$((index + 1))
            ;;
        chmod)
            index=2
            [[ "${tokens[1]:-}" =~ ^([0-7]{3,4}|[ugoa]*[+=-][rwxXstugo,]+)$ ]] || return 1
            ;;
        *)
            return 1
            ;;
    esac
    (( index < ${#tokens[@]} )) || return 1
    for ((; index < ${#tokens[@]}; index++)); do
        token="${tokens[$index]}"
        token="${token#\"}"; token="${token#\'}"
        token="${token%\"}"; token="${token%\'}"
        [[ -n "$token" && "$token" != -* ]] || return 1
        relative_path="$(repo_relative_candidate "$root" "$token" "$cwd" 2>/dev/null || true)"
        [[ -n "$relative_path" ]] || return 1
        manifest_contains_path "$REGISTERED_MANIFEST" "$relative_path" || return 1
    done
    return 0
}

guard_command() {
    local command_text="$1"
    local cwd="$2"
    local root
    local branch

    command_text="$(normalize_command_text "$command_text")"
    root="$(current_governed_root "$cwd")"
    if [[ -n "$root" ]] && is_safe_control_command "$command_text" "$root"; then
        return 0
    fi
    if is_direct_remote_mutation "$command_text"; then
        deny "direct remote mutation is forbidden; use the leased agent-task publish/release flow"
    fi
    if is_forbidden_repository_control "$command_text" && ! is_read_only_command "$command_text"; then
        deny "branch, worktree, repository configuration, and ref control belongs to scripts/agent-task.sh"
    fi

    if [[ -n "$root" ]]; then
        branch="$(branch_for_root "$root")"
        if [[ "$branch" == "main" ]]; then
            is_read_only_command "$command_text" && return 0
            deny "Bash on '$branch' is read-only; run writes through scripts/agent-task.sh in an isolated worktree"
        fi
        is_read_only_command "$command_text" && return 0
        registered_task_manifest "$root" \
            || deny "feature branch '$branch' is not the unique active registered task worktree"
        if [[ "$branch" == "DETACHED" ]] \
            && ! jq -e '.status == "refreshing"' "$REGISTERED_MANIFEST" >/dev/null 2>&1; then
            deny "detached Bash writes are allowed only during a registered refresh conflict"
        fi
        if command_targets_other_main_worktree "$command_text" "$root"; then
            deny "feature worktree command targets another/main worktree"
        fi
        registered_worker_command_allowed "$command_text" "$root" "$cwd" \
            || deny "mutating Bash is limited to registered write-set paths, Git add/commit, and approved repository validators"
        return 0
    fi

    is_read_only_command "$command_text" && return 0
    while IFS= read -r root; do
        [[ -n "$root" ]] || continue
        if [[ "$(branch_for_root "$root")" == "main" && "$command_text" == *"$root"* ]]; then
            deny "command outside a governed repo targets shared main '$root'"
        fi
    done < <(find "$cwd" -maxdepth 2 -name AGENTS.md -print 2>/dev/null | while IFS= read -r marker; do governed_root_for_path "$marker" "$cwd"; done)
}

git_common_dir() {
    local root="${1:-$PWD}"
    local common
    common="$(git -C "$root" rev-parse --git-common-dir 2>/dev/null)" || return 1
    if [[ "$common" != /* ]]; then
        common="$root/$common"
    fi
    (cd "$common" 2>/dev/null && pwd -P)
}

task_state_paths() {
    local root="${1:-$PWD}"
    local common
    common="$(git_common_dir "$root")" || return 1
    STATE_DIR="$common/vowrite-agent-platform"
    TASKS_DIR="$STATE_DIR/tasks"
    LEASE_FILE="$STATE_DIR/integration-lease.json"
}

integration_context_valid() {
    local manifest
    local task_id="${VOWRITE_INTEGRATION_TASK:-}"
    local owner="${VOWRITE_INTEGRATION_OWNER:-}"
    local base_sha
    local result_commit
    local expected_tree
    local staged_tree

    [[ -n "$task_id" && -n "$owner" ]] || return 1
    require_command jq
    task_state_paths || return 1
    manifest="$TASKS_DIR/$task_id.json"
    [[ -f "$manifest" && -f "$LEASE_FILE" ]] || return 1
    jq -e --arg owner "$owner" '.owner == $owner' "$LEASE_FILE" >/dev/null 2>&1 || return 1
    jq -e --arg task "$task_id" '.task == $task and .status == "ready" and (.result_commit | type == "string")' "$manifest" >/dev/null 2>&1 || return 1
    base_sha="$(jq -r '.base_sha' "$manifest")"
    result_commit="$(jq -r '.result_commit' "$manifest")"
    [[ "$(git rev-parse HEAD 2>/dev/null)" == "$base_sha" ]] || return 1
    expected_tree="$(git rev-parse "$result_commit^{tree}" 2>/dev/null)" || return 1
    staged_tree="$(git write-tree 2>/dev/null)" || return 1
    [[ "$staged_tree" == "$expected_tree" ]]
}

release_commit_context_valid() {
    local root
    local staged_path
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
    is_product_root "$root" || return 1
    while IFS= read -r -d '' staged_path; do
        case "$staged_path" in
            CHANGELOG.md|VowriteMac/Resources/Info.plist|VowriteKit/Sources/VowriteKit/Version.swift|docs/appcast.xml|docs/appcast-beta.xml)
                ;;
            *)
                return 1
                ;;
        esac
    done < <(git diff --cached --name-only --no-renames --diff-filter=ACDMRTUXB -z)
    return 0
}

scope_contains_path() {
    local scope="$1"
    local path="$2"
    if [[ "$scope" == *"/**" ]]; then
        scope="${scope%"/**"}"
        [[ "$path" == "$scope" || "$path" == "$scope/"* ]]
        return
    fi
    [[ "$path" == "$scope" ]]
}

repo_relative_candidate() {
    local root="$1"
    local candidate="$2"
    local cwd="$3"
    local resolved

    root="$(cd "$root" 2>/dev/null && pwd -P)" || return 1
    resolved="$(canonical_candidate_path "$candidate" "$cwd" 2>/dev/null)" || return 1
    [[ "$resolved" == "$root/"* ]] || return 1
    resolved="${resolved#"$root/"}"
    [[ -n "$resolved" && "$resolved" != ".." && "$resolved" != ../* && "$resolved" != */../* && "$resolved" != */.. ]] || return 1
    printf '%s\n' "$resolved"
}

manifest_contains_path() {
    local manifest="$1"
    local path="$2"
    local scope

    while IFS= read -r scope; do
        if scope_contains_path "$scope" "$path"; then
            return 0
        fi
    done < <(jq -r '.write_set[]' "$manifest")
    return 1
}

registered_task_manifest() {
    local root="${1:-}"
    local branch
    local manifest
    local status
    local manifest_branch
    local manifest_worktree
    local count=0

    require_command jq
    if [[ -z "$root" ]]; then
        root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
    fi
    root="$(cd "$root" && pwd -P)"
    task_state_paths "$root" || return 1
    branch="$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    [[ -d "$TASKS_DIR" ]] || return 1

    REGISTERED_MANIFEST=""
    for manifest in "$TASKS_DIR"/*.json; do
        [[ -f "$manifest" ]] || continue
        status="$(jq -r '.status' "$manifest")"
        [[ "$status" == "active" || "$status" == "refreshing" ]] || continue
        manifest_branch="$(jq -r '.branch' "$manifest")"
        manifest_worktree="$(jq -r '.worktree' "$manifest")"
        if [[ "$manifest_worktree" == "$root" ]] \
            && { [[ "$manifest_branch" == "$branch" ]] || [[ -z "$branch" && "$status" == "refreshing" ]]; }; then
            REGISTERED_MANIFEST="$manifest"
            count=$((count + 1))
        fi
    done
    [[ "$count" -eq 1 ]]
}

staged_paths_fit_manifest() {
    local manifest="$1"
    local staged_path
    local scope
    local matched

    while IFS= read -r -d '' staged_path; do
        matched=false
        while IFS= read -r scope; do
            if scope_contains_path "$scope" "$staged_path"; then
                matched=true
                break
            fi
        done < <(jq -r '.write_set[]' "$manifest")
        [[ "$matched" == true ]] || return 1
    done < <(git diff --cached --name-only --no-renames --diff-filter=ACDMRTUXB -z)
    return 0
}

guard_pre_commit() {
    local branch
    local staged_count

    branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'DETACHED\n')"
    staged_count="$(git diff --cached --name-only --no-renames --diff-filter=ACDMRTUXB -z | tr -cd '\0' | wc -c | tr -d ' ')"
    [[ "$staged_count" -gt 0 ]] || exit 0

    if [[ "$branch" != "main" ]]; then
        registered_task_manifest || deny "branch '$branch' is not the active registered task worktree"
        if [[ "$branch" == "DETACHED" ]] \
            && ! jq -e '.status == "refreshing"' "$REGISTERED_MANIFEST" >/dev/null 2>&1; then
            deny "detached commits are allowed only during a registered refresh conflict"
        fi
        staged_paths_fit_manifest "$REGISTERED_MANIFEST" || deny "staged paths exceed the registered task write-set"
        exit 0
    fi

    if [[ "${VOWRITE_RELEASE:-}" == "1" ]] && release_commit_context_valid; then
        exit 0
    fi
    if integration_context_valid; then
        exit 0
    fi
    deny "$staged_count staged path(s) on '$branch'; integrate the pinned task through the active lease"
}

publish_context_valid() {
    local task_id="${VOWRITE_PUBLISH_TASK:-}"
    local owner="${VOWRITE_PUBLISH_OWNER:-}"
    local manifest

    [[ -n "$task_id" && -n "$owner" ]] || return 1
    require_command jq
    task_state_paths || return 1
    manifest="$TASKS_DIR/$task_id.json"
    [[ -f "$manifest" && -f "$LEASE_FILE" ]] || return 1
    jq -e --arg owner "$owner" '.owner == $owner' "$LEASE_FILE" >/dev/null 2>&1 || return 1
    jq -e --arg task "$task_id" '.task == $task and .status == "integrated" and (.integration_commit | type == "string")' "$manifest" >/dev/null 2>&1 || return 1
    PUBLISH_COMMIT="$(jq -r '.integration_commit' "$manifest")"
    [[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" == "main" ]] || return 1
    [[ "$(git rev-parse HEAD 2>/dev/null)" == "$PUBLISH_COMMIT" ]] || return 1
    [[ -z "$(git status --porcelain)" ]]
}

release_push_context_valid() {
    local root
    local intent
    local tag_commit
    [[ "${VOWRITE_RELEASE:-}" == "1" ]] || return 1
    RELEASE_TAG="${VOWRITE_RELEASE_TAG:-}"
    [[ "$RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$ ]] || return 1
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
    is_product_root "$root" || return 1
    [[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" == "main" ]] || return 1
    [[ -z "$(git status --porcelain)" ]] || return 1
    require_command jq
    task_state_paths "$root" || return 1
    intent="$STATE_DIR/release-intent.json"
    [[ -f "$intent" && ! -L "$intent" ]] || return 1
    RELEASE_COMMIT="$(git rev-parse HEAD 2>/dev/null)" || return 1
    jq -e --arg tag "$RELEASE_TAG" --arg commit "$RELEASE_COMMIT" \
        '.schema == 1 and .status == "prepared" and .tag == $tag and .commit == $commit' \
        "$intent" >/dev/null 2>&1 || return 1
    tag_commit="$(git rev-parse "$RELEASE_TAG^{commit}" 2>/dev/null)" || return 1
    [[ "$tag_commit" == "$RELEASE_COMMIT" ]]
}

guard_pre_push() {
    local local_ref
    local local_sha
    local remote_ref
    local remote_sha
    local ref_count=0
    local zero_sha="0000000000000000000000000000000000000000"
    local mode=""

    if publish_context_valid; then
        mode="task"
    elif release_push_context_valid; then
        mode="release"
    else
        deny "push requires an integrated task publish context or explicit validated release context"
    fi

    while read -r local_ref local_sha remote_ref remote_sha; do
        [[ -n "${local_ref:-}" ]] || continue
        ref_count=$((ref_count + 1))
        [[ "$local_sha" != "$zero_sha" ]] || deny "remote ref deletion is not allowed by this gate"
        if [[ "$mode" == "task" ]]; then
            [[ "$remote_ref" == "refs/heads/main" ]] || deny "task publish may update only refs/heads/main"
            [[ "$local_sha" == "$PUBLISH_COMMIT" ]] || deny "task publish SHA does not match the integrated commit"
        else
            case "$remote_ref" in
                refs/heads/main)
                    [[ "$local_ref" == "refs/heads/main" && "$local_sha" == "$RELEASE_COMMIT" ]] \
                        || deny "release main ref must equal the prepared release commit"
                    ;;
                "refs/tags/$RELEASE_TAG")
                    [[ "$local_ref" == "refs/tags/$RELEASE_TAG" ]] \
                        || deny "release tag source must be refs/tags/$RELEASE_TAG"
                    [[ "$(git rev-parse "$local_sha^{commit}" 2>/dev/null || true)" == "$RELEASE_COMMIT" ]] \
                        || deny "release tag '$remote_ref' does not pin the prepared release commit"
                    ;;
                *)
                    deny "release push attempted an unsupported ref '$remote_ref'"
                    ;;
            esac
        fi
    done
    [[ "$ref_count" -gt 0 ]] || exit 0
}

guard_hook() {
    local input
    local cwd
    local tool_name
    local command_text
    local file_path
    local candidate
    local candidate_count=0

    require_command jq
    input="$(cat)"
    cwd="$(jq -r '.cwd // empty' <<<"$input")"
    [[ -n "$cwd" ]] || cwd="$PWD"
    tool_name="$(jq -r '.tool_name // empty' <<<"$input")"
    command_text="$(jq -r '.tool_input.command // empty' <<<"$input")"

    case "$tool_name" in
        Edit|Write)
            file_path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
            [[ -n "$file_path" ]] || deny "$tool_name hook input omitted tool_input.file_path"
            guard_file_path "$file_path" "$cwd"
            ;;
        apply_patch)
            [[ -n "$command_text" ]] || deny "apply_patch hook input omitted tool_input.command"
            while IFS= read -r candidate; do
                [[ -n "$candidate" ]] || continue
                candidate_count=$((candidate_count + 1))
                guard_file_path "$candidate" "$cwd"
            done < <(printf '%s\n' "$command_text" | sed -n -E \
                -e 's/^\*\*\* (Update|Add|Delete) File: (.+)$/\2/p' \
                -e 's/^\*\*\* Move to: (.+)$/\1/p')
            [[ "$candidate_count" -gt 0 ]] || deny "apply_patch input contained no recognized file targets"
            ;;
        Bash)
            [[ -n "$command_text" ]] || deny "Bash hook input omitted tool_input.command"
            guard_command "$command_text" "$cwd"
            ;;
    esac
}

case "${1:-}" in
    --pre-commit)
        guard_pre_commit
        ;;
    --pre-push)
        guard_pre_push
        ;;
    --check-path)
        [[ -n "${2:-}" ]] || deny "--check-path requires a path"
        guard_file_path "$2" "${3:-$PWD}"
        ;;
    --check-command)
        [[ -n "${2:-}" ]] || deny "--check-command requires a command"
        guard_command "$2" "${3:-$PWD}"
        ;;
    "")
        guard_hook
        ;;
    *)
        deny "unknown mode '$1'"
        ;;
esac

exit 0
