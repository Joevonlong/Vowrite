#!/usr/bin/env bash
# Coordinate isolated agent worktrees with pinned SHAs and a single integrator.

set -euo pipefail

die() {
    echo "agent-task: $1" >&2
    exit 2
}

usage() {
    cat <<'USAGE'
Usage:
  scripts/agent-task.sh start --task ID --owner NAME --branch BRANCH --worktree ABS_PATH \
      --write-set GLOB [--write-set GLOB ...] --accept COMMAND [--accept COMMAND ...] [--base SHA]
  scripts/agent-task.sh adopt --task ID --owner NAME --base SHA \
      --write-set PATH [--write-set PATH ...] --accept COMMAND [--accept COMMAND ...]
  scripts/agent-task.sh handoff --task ID --owner NAME --commit SHA
  scripts/agent-task.sh refresh --task ID --owner NAME [--base SHA]
  scripts/agent-task.sh refresh-continue --task ID --owner NAME
  scripts/agent-task.sh refresh-abort --task ID --owner NAME
  scripts/agent-task.sh ensure-integration-checkout --owner NAME --worktree ABS_PATH
  scripts/agent-task.sh claim-integration --owner NAME
  scripts/agent-task.sh release-integration --owner NAME
  scripts/agent-task.sh integrate --task ID --owner NAME --message MESSAGE
  scripts/agent-task.sh publish --task ID --owner NAME [--remote REMOTE]
  scripts/agent-task.sh cleanup --task ID --owner NAME [--local-only]
  scripts/agent-task.sh abort --task ID --owner NAME --reason TEXT
  scripts/agent-task.sh status [--task ID] [--json]
USAGE
}

command -v git >/dev/null 2>&1 || die "git is required"
command -v jq >/dev/null 2>&1 || die "jq is required"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run inside the target Git repository"
COMMON_DIR_RAW="$(git rev-parse --git-common-dir 2>/dev/null)" || die "cannot resolve git common dir"
COMMON_DIR="$(cd "$COMMON_DIR_RAW" 2>/dev/null && pwd -P)" || die "cannot open git common dir"
STATE_DIR="$COMMON_DIR/vowrite-agent-platform"
TASKS_DIR="$STATE_DIR/tasks"
LOGS_DIR="$STATE_DIR/logs"
LOCK_PATH="$STATE_DIR/state.lock"
LEGACY_LOCK_DIR="$STATE_DIR/lock"
LEASE_FILE="$STATE_DIR/integration-lease.json"
LOCK_HELD=false
LOCK_TOKEN=""

mkdir -p "$TASKS_DIR" "$LOGS_DIR"

release_lock() {
    if [[ "$LOCK_HELD" == true && -f "$LOCK_PATH" ]]; then
        if jq -e --arg token "$LOCK_TOKEN" '.token == $token' "$LOCK_PATH" >/dev/null 2>&1; then
            rm -f "$LOCK_PATH"
        fi
    fi
}
trap release_lock EXIT

now_utc() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

legacy_lock_is_stale() {
    local lock_pid=""
    local modified=""
    local now
    local age

    if [[ -f "$LEGACY_LOCK_DIR/pid" ]]; then
        lock_pid="$(cat "$LEGACY_LOCK_DIR/pid" 2>/dev/null || true)"
        [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null
        return
    fi
    if modified="$(stat -f '%m' "$LEGACY_LOCK_DIR" 2>/dev/null)"; then
        :
    elif modified="$(stat -c '%Y' "$LEGACY_LOCK_DIR" 2>/dev/null)"; then
        :
    else
        return 1
    fi
    now="$(date +%s)"
    age=$((now - modified))
    [[ "$age" -ge 30 ]]
}

recover_stale_lock() {
    local lock_pid=""
    local lock_host=""
    local current_host

    current_host="$(uname -n)"
    if [[ -d "$LEGACY_LOCK_DIR" ]]; then
        legacy_lock_is_stale || return 1
        rm -f "$LEGACY_LOCK_DIR/pid"
        rmdir "$LEGACY_LOCK_DIR" 2>/dev/null
        return
    fi
    [[ -f "$LOCK_PATH" && ! -L "$LOCK_PATH" ]] || return 1
    lock_pid="$(jq -r '.pid // empty' "$LOCK_PATH" 2>/dev/null || true)"
    lock_host="$(jq -r '.host // empty' "$LOCK_PATH" 2>/dev/null || true)"
    [[ -n "$lock_pid" && "$lock_host" == "$current_host" ]] || return 1
    kill -0 "$lock_pid" 2>/dev/null && return 1
    rm -f "$LOCK_PATH"
}

acquire_lock() {
    local candidate
    local attempt

    LOCK_TOKEN="$(uname -n):$$:$(date +%s):${RANDOM:-0}"
    candidate="$(mktemp "$STATE_DIR/.lock-candidate.XXXXXX")"
    jq -n \
        --arg token "$LOCK_TOKEN" \
        --arg host "$(uname -n)" \
        --argjson pid "$$" \
        --arg acquired_at "$(now_utc)" \
        '{schema:1,token:$token,host:$host,pid:$pid,acquired_at:$acquired_at}' > "$candidate"
    chmod 600 "$candidate"

    for attempt in 1 2; do
        if [[ -e "$LEGACY_LOCK_DIR" ]]; then
            if [[ "$attempt" -eq 1 ]] && recover_stale_lock; then
                continue
            fi
            rm -f "$candidate"
            die "another agent-task state change is in progress ($LEGACY_LOCK_DIR)"
        fi
        if ln "$candidate" "$LOCK_PATH" 2>/dev/null; then
            rm -f "$candidate"
            LOCK_HELD=true
            return 0
        fi
        if [[ "$attempt" -eq 1 ]] && recover_stale_lock; then
            continue
        fi
        rm -f "$candidate"
        die "another agent-task state change is in progress ($LOCK_PATH)"
    done
}

validate_identity() {
    local value="$1"
    local label="$2"
    [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]] || die "$label must match [A-Za-z0-9._-]+"
}

task_file() {
    printf '%s/%s.json\n' "$TASKS_DIR" "$1"
}

require_task_file() {
    local file
    file="$(task_file "$1")"
    [[ -f "$file" ]] || die "unknown task '$1'"
    printf '%s\n' "$file"
}

atomic_json_write() {
    local target="$1"
    local temp_file
    temp_file="$(mktemp "$STATE_DIR/.agent-task.XXXXXX")"
    cat > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$target"
}

resolve_commit() {
    git rev-parse --verify "$1^{commit}" 2>/dev/null || die "not a commit: $1"
}

validate_scope() {
    local scope="$1"
    [[ -n "$scope" ]] || die "write-set cannot be empty"
    [[ "$scope" != *[[:cntrl:]]* ]] || die "write-set cannot contain control characters"
    [[ "$scope" != /* ]] || die "write-set must be repository-relative: $scope"
    [[ "$scope" != ".." && "$scope" != ../* && "$scope" != */../* && "$scope" != */.. ]] || die "write-set cannot traverse parents: $scope"
    [[ "$scope" != ./* && "$scope" != */ && "$scope" != *//* ]] || die "write-set must use a normalized path: $scope"
    if [[ "$scope" == *"*"* || "$scope" == *"?"* || "$scope" == *"["* ]]; then
        [[ "$scope" == *"/**" ]] || die "write-set supports only exact paths or a trailing '/**': $scope"
        local base="${scope%"/**"}"
        if [[ -z "$base" || "$base" == *"*"* || "$base" == *"?"* || "$base" == *"["* ]]; then
            die "ambiguous write-set glob: $scope"
        fi
    fi
}

scopes_overlap() {
    local left="$1"
    local right="$2"
    local left_directory=false
    local right_directory=false

    if [[ "$left" == *"/**" ]]; then
        left="${left%"/**"}"
        left_directory=true
    fi
    if [[ "$right" == *"/**" ]]; then
        right="${right%"/**"}"
        right_directory=true
    fi

    [[ "$left" == "$right" ]] && return 0
    if [[ "$left_directory" == true && ( "$right" == "$left/"* || "$right" == "$left" ) ]]; then
        return 0
    fi
    if [[ "$right_directory" == true && ( "$left" == "$right/"* || "$left" == "$right" ) ]]; then
        return 0
    fi
    return 1
}

reject_scope_conflicts() {
    local requested_scope
    local manifest
    local existing_status
    local existing_task
    local existing_scope

    for manifest in "$TASKS_DIR"/*.json; do
        [[ -f "$manifest" ]] || continue
        existing_status="$(jq -r '.status' "$manifest")"
        [[ "$existing_status" == "active" || "$existing_status" == "ready" || "$existing_status" == "refreshing" ]] || continue
        existing_task="$(jq -r '.task' "$manifest")"
        while IFS= read -r existing_scope; do
            for requested_scope in "${WRITE_SETS[@]}"; do
                if scopes_overlap "$requested_scope" "$existing_scope"; then
                    die "write-set '$requested_scope' overlaps active task '$existing_task' scope '$existing_scope'"
                fi
            done
        done < <(jq -r '.write_set[]' "$manifest")
    done
}

owner_matches() {
    local manifest="$1"
    local owner="$2"
    jq -e --arg owner "$owner" '.owner == $owner' "$manifest" >/dev/null 2>&1 || die "owner '$owner' does not own task '$(jq -r '.task' "$manifest")'"
}

lease_matches() {
    local owner="$1"
    [[ -f "$LEASE_FILE" ]] || die "no integration owner has claimed the lease"
    jq -e --arg owner "$owner" '.owner == $owner' "$LEASE_FILE" >/dev/null 2>&1 || {
        die "integration lease belongs to '$(jq -r '.owner' "$LEASE_FILE")', not '$owner'"
    }
}

path_matches_scope() {
    local path="$1"
    local scope
    while IFS= read -r scope; do
        if [[ "$scope" == *"/**" ]]; then
            scope="${scope%"/**"}"
            [[ "$path" == "$scope" || "$path" == "$scope/"* ]] && return 0
        elif [[ "$path" == "$scope" ]]; then
            return 0
        fi
    done
    return 1
}

validate_acceptance_command() {
    local command_text="$1"

    [[ -n "$command_text" ]] || die "acceptance command cannot be empty"
    case "$command_text" in
        *$'\n'*|*';'*|*'|'*|*'&'*|*'>'*|*'<'*|*'`'*|*'$('* )
            die "acceptance commands must be one non-compound validation command: $command_text"
            ;;
    esac
    [[ ! "$command_text" =~ (^|[[:space:]])(--output|--in-place)(=|[[:space:]]|$) ]] \
        || die "acceptance command contains a file-output option: $command_text"

    case "$command_text" in
        ops/scripts/test.sh|ops/scripts/test.sh\ *|ops/scripts/test-agent-platform.sh|ops/scripts/test-agent-platform.sh\ *|ops/scripts/website-check.sh|ops/scripts/website-check.sh\ *)
            return 0
            ;;
        scripts/check-*.sh|scripts/check-*.sh\ *)
            return 0
            ;;
        "git diff --check"|"git diff --check "*)
            return 0
            ;;
        "swift test"|"swift test "*|"swift build"|"swift build "*|"xcodebuild "*)
            return 0
            ;;
        "bash -n "*|"jq empty "*)
            return 0
            ;;
        *)
            die "acceptance must use a repository-owned test/check script or an approved read-only validator: $command_text"
            ;;
    esac
}

repository_protected_fingerprint() {
    local manifest="$1"
    local worktree
    local worktree_branch=""
    local listed_worktree=""
    local task_branch
    local task_worktree
    local manifest_file
    local head
    local status_hash

    task_branch="$(jq -r '.branch' "$manifest")"
    task_worktree="$(jq -r '.worktree' "$manifest")"
    printf 'main %s\n' "$(git rev-parse refs/heads/main^{commit} 2>/dev/null || printf 'MISSING')"
    printf 'task-branch %s\n' "$(git rev-parse "$task_branch^{commit}" 2>/dev/null || printf 'MISSING')"
    printf 'tags %s\n' "$(git for-each-ref --format='%(objectname) %(refname)' refs/tags | git hash-object --stdin)"
    while IFS= read -r worktree_line; do
        case "$worktree_line" in
            worktree\ *)
                listed_worktree="${worktree_line#worktree }"
                worktree_branch=""
                ;;
            "branch refs/heads/"*)
                worktree_branch="${worktree_line#branch refs/heads/}"
                if [[ "$worktree_branch" == "main" || "$listed_worktree" == "$task_worktree" ]]; then
                    worktree="$listed_worktree"
                    if [[ ! -d "$worktree" ]]; then
                        printf 'missing %s\n' "$worktree"
                        continue
                    fi
                    head="$(git -C "$worktree" rev-parse HEAD 2>/dev/null || printf 'MISSING')"
                    status_hash="$(git -C "$worktree" status --porcelain=v1 -z --untracked-files=all 2>/dev/null | git hash-object --stdin)"
                    printf 'worktree %s\nhead %s\nstatus %s\n' "$worktree" "$head" "$status_hash"
                fi
                ;;
        esac
    done < <(git worktree list --porcelain)
    for manifest_file in "$TASKS_DIR"/*.json; do
        [[ -f "$manifest_file" ]] || continue
        printf 'manifest %s %s\n' "$(basename "$manifest_file")" "$(git hash-object "$manifest_file")"
    done
    if [[ -f "$LEASE_FILE" ]]; then
        printf 'lease %s\n' "$(git hash-object "$LEASE_FILE")"
    else
        printf 'lease MISSING\n'
    fi
}

run_acceptance() {
    local manifest="$1"
    local result_commit="$2"
    local task_id
    local acceptance_root
    local command_text
    local log_file
    local before_fingerprint
    local after_fingerprint
    local result=0

    task_id="$(jq -r '.task' "$manifest")"
    result_commit="$(resolve_commit "$result_commit")"
    log_file="$(mktemp "$LOGS_DIR/${task_id}.acceptance.XXXXXX")"
    while IFS= read -r command_text; do
        validate_acceptance_command "$command_text"
    done < <(jq -r '.acceptance[]' "$manifest")
    before_fingerprint="$(repository_protected_fingerprint "$manifest")"
    acceptance_root="$(mktemp -d /tmp/vowrite-acceptance.XXXXXX)"
    rmdir "$acceptance_root"
    if ! git worktree add -q --detach "$acceptance_root" "$result_commit"; then
        echo "Acceptance worktree could not be created: $acceptance_root" >&2
        return 1
    fi

    while IFS= read -r command_text; do
        printf 'COMMAND: %s\n' "$command_text" >> "$log_file"
        if ! (cd "$acceptance_root" && bash -lc "$command_text") >> "$log_file" 2>&1; then
            echo "Acceptance failed: $command_text" >&2
            echo "Log: $log_file" >&2
            result=1
            break
        fi
    done < <(jq -r '.acceptance[]' "$manifest")

    if ! git worktree remove --force "$acceptance_root" >/dev/null 2>&1; then
        echo "Acceptance worktree cleanup failed: $acceptance_root" >&2
        result=1
    fi
    after_fingerprint="$(repository_protected_fingerprint "$manifest")"
    if [[ "$before_fingerprint" != "$after_fingerprint" ]]; then
        echo "Acceptance changed protected main/task refs, worktrees, tags, or coordinator state" >&2
        echo "Log: $log_file" >&2
        result=1
    fi
    [[ "$result" -eq 0 ]] || return 1

    printf '%s\n' "$log_file"
}

canonical_requested_worktree_path() {
    local candidate="$1"
    local parent

    [[ "$candidate" != *[[:cntrl:]]* ]] || die "worktree path cannot contain control characters"
    parent="$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P)" \
        || die "worktree parent does not exist: $(dirname "$candidate")"
    printf '%s/%s\n' "$parent" "$(basename "$candidate")"
}

reject_nested_worktree_path() {
    local candidate="$1"
    local listed_worktree
    local listed_canonical

    while IFS= read -r listed_worktree; do
        [[ -n "$listed_worktree" ]] || continue
        listed_canonical="$(cd "$listed_worktree" 2>/dev/null && pwd -P)" \
            || die "cannot resolve existing worktree path: $listed_worktree"
        case "$candidate/" in
            "$listed_canonical/"*)
                die "worktree path must be outside every existing checkout: $candidate is inside $listed_canonical"
                ;;
        esac
    done < <(git worktree list --porcelain | sed -n 's/^worktree //p')
}

start_task() {
    local task_id=""
    local owner=""
    local branch=""
    local worktree=""
    local base=""
    local base_sha
    local manifest
    local write_sets_json
    local acceptance_json
    WRITE_SETS=()
    ACCEPTANCE=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --owner) owner="${2:-}"; shift 2 ;;
            --branch) branch="${2:-}"; shift 2 ;;
            --worktree) worktree="${2:-}"; shift 2 ;;
            --base) base="${2:-}"; shift 2 ;;
            --write-set) WRITE_SETS+=("${2:-}"); shift 2 ;;
            --accept) ACCEPTANCE+=("${2:-}"); shift 2 ;;
            *) die "unknown start argument '$1'" ;;
        esac
    done

    [[ -n "$task_id" && -n "$owner" && -n "$branch" && -n "$worktree" ]] || die "start requires --task, --owner, --branch, and --worktree"
    validate_identity "$task_id" "task"
    validate_identity "$owner" "owner"
    [[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" == "main" ]] || die "start must run from the main integration checkout"
    [[ -z "$(git status --porcelain)" ]] || die "start requires a clean main integration checkout"
    [[ "$branch" != "main" ]] || die "task branch cannot be main"
    git check-ref-format --branch "$branch" >/dev/null 2>&1 || die "invalid branch name '$branch'"
    [[ "$worktree" == /* ]] || die "worktree path must be absolute"
    worktree="$(canonical_requested_worktree_path "$worktree")"
    reject_nested_worktree_path "$worktree"
    [[ ! -e "$worktree" ]] || die "worktree path already exists: $worktree"
    [[ ${#WRITE_SETS[@]} -gt 0 ]] || die "at least one --write-set is required"
    [[ ${#ACCEPTANCE[@]} -gt 0 ]] || die "at least one --accept command is required"
    for scope in "${WRITE_SETS[@]}"; do validate_scope "$scope"; done
    for command_text in "${ACCEPTANCE[@]}"; do validate_acceptance_command "$command_text"; done

    if [[ -z "$base" ]]; then
        base="$(git rev-parse HEAD)"
    fi
    base_sha="$(resolve_commit "$base")"
    manifest="$(task_file "$task_id")"

    acquire_lock
    [[ ! -e "$manifest" ]] || die "task '$task_id' already exists"
    git show-ref --verify --quiet "refs/heads/$branch" && die "branch already exists: $branch"
    reject_scope_conflicts
    git worktree add -q -b "$branch" "$worktree" "$base_sha" || die "failed to create worktree '$worktree'"
    worktree="$(cd "$worktree" && pwd -P)"

    write_sets_json="$(jq -cn --args '$ARGS.positional' "${WRITE_SETS[@]}")"
    acceptance_json="$(jq -cn --args '$ARGS.positional' "${ACCEPTANCE[@]}")"
    jq -n \
        --arg task "$task_id" \
        --arg owner "$owner" \
        --arg repo "$REPO_ROOT" \
        --arg base_sha "$base_sha" \
        --arg branch "$branch" \
        --arg worktree "$worktree" \
        --arg created_at "$(now_utc)" \
        --argjson write_set "$write_sets_json" \
        --argjson acceptance "$acceptance_json" \
        '{schema:1, task:$task, owner:$owner, repo:$repo, base_sha:$base_sha, branch:$branch, worktree:$worktree, write_set:$write_set, acceptance:$acceptance, status:"active", created_at:$created_at}' \
        | atomic_json_write "$manifest"

    echo "Task $task_id active"
    echo "  base SHA: $base_sha"
    echo "  branch: $branch"
    echo "  worktree: $worktree"
}

adopt_task() {
    local task_id=""
    local owner=""
    local base=""
    local base_sha
    local branch
    local worktree
    local manifest
    local changed_file
    local write_sets_json
    local acceptance_json
    local git_dir
    local common_dir
    local listed_worktree=""
    local main_worktree=""
    local worktree_line
    WRITE_SETS=()
    ACCEPTANCE=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --owner) owner="${2:-}"; shift 2 ;;
            --base) base="${2:-}"; shift 2 ;;
            --write-set) WRITE_SETS+=("${2:-}"); shift 2 ;;
            --accept) ACCEPTANCE+=("${2:-}"); shift 2 ;;
            *) die "unknown adopt argument '$1'" ;;
        esac
    done

    [[ -n "$task_id" && -n "$owner" && -n "$base" ]] || die "adopt requires --task, --owner, and an explicit --base SHA"
    validate_identity "$task_id" "task"
    validate_identity "$owner" "owner"
    branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    [[ -n "$branch" && "$branch" != "main" ]] || die "adopt must run inside an existing non-main task worktree"
    git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null)" || die "cannot resolve task worktree git dir"
    common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || die "cannot resolve git common dir"
    [[ "$git_dir" != "$common_dir" ]] || die "adopt requires a linked worktree, not the primary/shared checkout"
    while IFS= read -r worktree_line; do
        case "$worktree_line" in
            worktree\ *) listed_worktree="${worktree_line#worktree }" ;;
            "branch refs/heads/main") main_worktree="$listed_worktree" ;;
        esac
    done < <(git worktree list --porcelain)
    [[ -n "$main_worktree" && "$main_worktree" != "$REPO_ROOT" ]] \
        || die "adopt requires a separate main integration worktree"
    [[ ${#WRITE_SETS[@]} -gt 0 ]] || die "at least one --write-set is required"
    [[ ${#ACCEPTANCE[@]} -gt 0 ]] || die "at least one --accept command is required"
    for scope in "${WRITE_SETS[@]}"; do validate_scope "$scope"; done
    for command_text in "${ACCEPTANCE[@]}"; do validate_acceptance_command "$command_text"; done

    base_sha="$(resolve_commit "$base")"
    git merge-base --is-ancestor "$base_sha" HEAD 2>/dev/null || die "adopt base $base_sha is not an ancestor of the task branch"
    worktree="$(cd "$REPO_ROOT" && pwd -P)"
    manifest="$(task_file "$task_id")"

    while IFS= read -r -d '' changed_file; do
        if ! printf '%s\n' "${WRITE_SETS[@]}" | path_matches_scope "$changed_file"; then
            die "existing changed file '$changed_file' is outside the declared write-set"
        fi
    done < <(git diff --name-only --no-renames --diff-filter=ACDMRTUXB -z "$base_sha")
    while IFS= read -r -d '' changed_file; do
        if ! printf '%s\n' "${WRITE_SETS[@]}" | path_matches_scope "$changed_file"; then
            die "existing untracked file '$changed_file' is outside the declared write-set"
        fi
    done < <(git ls-files --others --exclude-standard -z)

    acquire_lock
    [[ ! -e "$manifest" ]] || die "task '$task_id' already exists"
    reject_scope_conflicts
    write_sets_json="$(jq -cn --args '$ARGS.positional' "${WRITE_SETS[@]}")"
    acceptance_json="$(jq -cn --args '$ARGS.positional' "${ACCEPTANCE[@]}")"
    jq -n \
        --arg task "$task_id" \
        --arg owner "$owner" \
        --arg repo "$REPO_ROOT" \
        --arg base_sha "$base_sha" \
        --arg branch "$branch" \
        --arg worktree "$worktree" \
        --arg created_at "$(now_utc)" \
        --argjson write_set "$write_sets_json" \
        --argjson acceptance "$acceptance_json" \
        '{schema:1, task:$task, owner:$owner, repo:$repo, base_sha:$base_sha, branch:$branch, worktree:$worktree, write_set:$write_set, acceptance:$acceptance, status:"active", adopted:true, created_at:$created_at}' \
        | atomic_json_write "$manifest"

    echo "Task $task_id adopted"
    echo "  base SHA: $base_sha"
    echo "  branch: $branch"
    echo "  worktree: $worktree"
}

handoff_task() {
    local task_id=""
    local owner=""
    local commit=""
    local commit_sha
    local manifest
    local base_sha
    local branch
    local worktree
    local branch_tip
    local changed_file
    local acceptance_log
    local temp_file

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --owner) owner="${2:-}"; shift 2 ;;
            --commit) commit="${2:-}"; shift 2 ;;
            *) die "unknown handoff argument '$1'" ;;
        esac
    done
    [[ -n "$task_id" && -n "$owner" && -n "$commit" ]] || die "handoff requires --task, --owner, and --commit"
    validate_identity "$task_id" "task"
    validate_identity "$owner" "owner"

    acquire_lock
    manifest="$(require_task_file "$task_id")"
    owner_matches "$manifest" "$owner"
    jq -e '.status == "active"' "$manifest" >/dev/null 2>&1 || die "task '$task_id' is not active"
    commit_sha="$(resolve_commit "$commit")"
    base_sha="$(jq -r '.base_sha' "$manifest")"
    branch="$(jq -r '.branch' "$manifest")"
    worktree="$(jq -r '.worktree' "$manifest")"
    branch_tip="$(git rev-parse "$branch^{commit}" 2>/dev/null)" || die "task branch is missing: $branch"
    [[ "$commit_sha" == "$branch_tip" ]] || die "handoff commit must equal branch tip $branch_tip"
    [[ -z "$(git -C "$worktree" status --porcelain)" ]] || die "task worktree is not clean: $worktree"

    CHANGED_COUNT=0
    while IFS= read -r -d '' changed_file; do
        CHANGED_COUNT=$((CHANGED_COUNT + 1))
        if ! jq -r '.write_set[]' "$manifest" | path_matches_scope "$changed_file"; then
            die "changed file '$changed_file' is outside the declared write-set"
        fi
    done < <(git diff --name-only --no-renames --diff-filter=ACDMRTUXB -z "$base_sha..$commit_sha")
    [[ "$CHANGED_COUNT" -gt 0 ]] || die "handoff commit contains no changes from base SHA"

    acceptance_log="$(run_acceptance "$manifest" "$commit_sha")" || die "acceptance commands failed"
    [[ -z "$(git -C "$worktree" status --porcelain)" ]] || die "acceptance commands dirtied the task worktree"
    [[ "$(git -C "$worktree" rev-parse HEAD)" == "$commit_sha" ]] || die "acceptance commands moved the task result commit"
    [[ "$(git rev-parse "$branch^{commit}" 2>/dev/null)" == "$commit_sha" ]] || die "acceptance commands moved the task branch tip"
    temp_file="$(mktemp "$STATE_DIR/.handoff.XXXXXX")"
    jq \
        --arg result_commit "$commit_sha" \
        --arg handed_off_at "$(now_utc)" \
        --arg acceptance_log "$acceptance_log" \
        '.status = "ready" | .result_commit = $result_commit | .handed_off_at = $handed_off_at | .acceptance_log = $acceptance_log' \
        "$manifest" > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$manifest"
    echo "Task $task_id ready for integration at $commit_sha"
}

refresh_task() {
    local task_id=""
    local owner=""
    local base=""
    local base_sha
    local manifest
    local worktree
    local previous_status
    local temp_file

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --owner) owner="${2:-}"; shift 2 ;;
            --base) base="${2:-}"; shift 2 ;;
            *) die "unknown refresh argument '$1'" ;;
        esac
    done
    [[ -n "$task_id" && -n "$owner" ]] || die "refresh requires --task and --owner"
    [[ -n "$base" ]] || base="$(git rev-parse main 2>/dev/null)"
    base_sha="$(resolve_commit "$base")"

    acquire_lock
    manifest="$(require_task_file "$task_id")"
    owner_matches "$manifest" "$owner"
    jq -e '.status == "active" or .status == "ready"' "$manifest" >/dev/null 2>&1 \
        || die "task '$task_id' can be refreshed only while active or ready"
    jq -e '.integration_attempt == null' "$manifest" >/dev/null 2>&1 \
        || die "task '$task_id' has a pending integration attempt; the same integration owner must rerun integrate with the original message to reconcile it"
    worktree="$(jq -r '.worktree' "$manifest")"
    [[ -z "$(git -C "$worktree" status --porcelain)" ]] || die "task worktree is not clean: $worktree"
    previous_status="$(jq -r '.status' "$manifest")"
    if ! git -C "$worktree" rebase "$base_sha"; then
        if rebase_in_progress "$worktree"; then
            temp_file="$(mktemp "$STATE_DIR/.refresh-conflict.XXXXXX")"
            jq \
                --arg previous_status "$previous_status" \
                --arg target_base_sha "$base_sha" \
                --arg refresh_started_at "$(now_utc)" \
                '.status = "refreshing" | .refresh_previous_status = $previous_status | .refresh_target_base_sha = $target_base_sha | .refresh_started_at = $refresh_started_at' \
                "$manifest" > "$temp_file"
            chmod 600 "$temp_file"
            mv "$temp_file" "$manifest"
            die "rebase stopped on a conflict in $worktree; resolve only declared write-set paths, stage them, then run refresh-continue"
        fi
        die "rebase failed before creating a resolvable conflict state"
    fi
    complete_refresh "$manifest" "$base_sha" "$worktree"
}

rebase_in_progress() {
    local worktree="$1"
    local git_dir
    git_dir="$(git -C "$worktree" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
    [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]
}

complete_refresh() {
    local manifest="$1"
    local base_sha="$2"
    local worktree="$3"
    local task_id
    local temp_file

    task_id="$(jq -r '.task' "$manifest")"
    [[ -z "$(git -C "$worktree" status --porcelain)" ]] || die "refresh left the task worktree dirty"
    temp_file="$(mktemp "$STATE_DIR/.refresh.XXXXXX")"
    jq --arg base_sha "$base_sha" --arg refreshed_at "$(now_utc)" \
        '.base_sha = $base_sha | .status = "active" | .refreshed_at = $refreshed_at | del(.result_commit, .handed_off_at, .acceptance_log, .refresh_previous_status, .refresh_target_base_sha, .refresh_started_at)' \
        "$manifest" > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$manifest"
    echo "Task $task_id rebased onto $base_sha; run handoff again"
}

refresh_continue_task() {
    local task_id=""
    local owner=""
    local manifest
    local worktree
    local target_base_sha

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --owner) owner="${2:-}"; shift 2 ;;
            *) die "unknown refresh-continue argument '$1'" ;;
        esac
    done
    [[ -n "$task_id" && -n "$owner" ]] || die "refresh-continue requires --task and --owner"
    validate_identity "$task_id" "task"
    validate_identity "$owner" "owner"

    acquire_lock
    manifest="$(require_task_file "$task_id")"
    owner_matches "$manifest" "$owner"
    jq -e '.status == "refreshing" and (.refresh_target_base_sha | type == "string")' "$manifest" >/dev/null 2>&1 \
        || die "task '$task_id' is not waiting on a refresh conflict"
    worktree="$(jq -r '.worktree' "$manifest")"
    target_base_sha="$(jq -r '.refresh_target_base_sha' "$manifest")"
    rebase_in_progress "$worktree" || die "task '$task_id' has no Git rebase in progress"
    [[ -z "$(git -C "$worktree" diff --name-only --diff-filter=U)" ]] \
        || die "refresh still has unresolved paths; resolve and stage them first"
    if ! GIT_EDITOR=true git -C "$worktree" rebase --continue; then
        if rebase_in_progress "$worktree"; then
            die "refresh reached another conflict; resolve declared write-set paths, stage them, and run refresh-continue again"
        fi
        die "refresh-continue failed outside a recoverable rebase state"
    fi
    complete_refresh "$manifest" "$target_base_sha" "$worktree"
}

refresh_abort_task() {
    local task_id=""
    local owner=""
    local manifest
    local worktree
    local previous_status
    local temp_file

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --owner) owner="${2:-}"; shift 2 ;;
            *) die "unknown refresh-abort argument '$1'" ;;
        esac
    done
    [[ -n "$task_id" && -n "$owner" ]] || die "refresh-abort requires --task and --owner"
    validate_identity "$task_id" "task"
    validate_identity "$owner" "owner"

    acquire_lock
    manifest="$(require_task_file "$task_id")"
    owner_matches "$manifest" "$owner"
    jq -e '.status == "refreshing"' "$manifest" >/dev/null 2>&1 \
        || die "task '$task_id' is not waiting on a refresh conflict"
    worktree="$(jq -r '.worktree' "$manifest")"
    previous_status="$(jq -r '.refresh_previous_status // "active"' "$manifest")"
    rebase_in_progress "$worktree" || die "task '$task_id' has no Git rebase in progress"
    git -C "$worktree" rebase --abort || die "failed to abort refresh rebase"
    [[ -z "$(git -C "$worktree" status --porcelain)" ]] || die "refresh-abort left the task worktree dirty"
    temp_file="$(mktemp "$STATE_DIR/.refresh-abort.XXXXXX")"
    jq --arg previous_status "$previous_status" --arg refresh_aborted_at "$(now_utc)" \
        '.status = $previous_status | .refresh_aborted_at = $refresh_aborted_at | del(.refresh_previous_status, .refresh_target_base_sha, .refresh_started_at)' \
        "$manifest" > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$manifest"
    echo "Task $task_id refresh aborted; status restored to $previous_status"
}

ensure_integration_checkout() {
    local owner=""
    local worktree=""
    local listed_worktree=""
    local main_worktree=""
    local worktree_line
    local main_sha
    local checkout_file="$STATE_DIR/integration-checkout.json"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --owner) owner="${2:-}"; shift 2 ;;
            --worktree) worktree="${2:-}"; shift 2 ;;
            *) die "unknown ensure-integration-checkout argument '$1'" ;;
        esac
    done
    [[ -n "$owner" && -n "$worktree" ]] \
        || die "ensure-integration-checkout requires --owner and --worktree"
    validate_identity "$owner" "owner"
    [[ "$worktree" == /* ]] || die "integration worktree path must be absolute"
    worktree="$(canonical_requested_worktree_path "$worktree")"
    [[ -z "$(git status --porcelain)" ]] || die "checkout provisioning requires a clean current worktree"

    acquire_lock
    while IFS= read -r worktree_line; do
        case "$worktree_line" in
            worktree\ *) listed_worktree="${worktree_line#worktree }" ;;
            "branch refs/heads/main") main_worktree="$listed_worktree" ;;
        esac
    done < <(git worktree list --porcelain)
    if [[ -n "$main_worktree" ]]; then
        main_worktree="$(cd "$main_worktree" && pwd -P)"
        [[ "$main_worktree" == "$worktree" ]] \
            || die "main integration checkout already exists at $main_worktree"
        echo "Main integration checkout already available at $main_worktree"
        return 0
    fi
    reject_nested_worktree_path "$worktree"
    [[ ! -e "$worktree" ]] || die "integration worktree path already exists: $worktree"
    main_sha="$(resolve_commit refs/heads/main)"
    git worktree add -q "$worktree" main || die "failed to create main integration checkout: $worktree"
    worktree="$(cd "$worktree" && pwd -P)"
    jq -n \
        --arg owner "$owner" \
        --arg repo "$REPO_ROOT" \
        --arg worktree "$worktree" \
        --arg main_sha "$main_sha" \
        --arg created_at "$(now_utc)" \
        '{schema:1,provisioned_by:$owner,repo:$repo,worktree:$worktree,main_sha:$main_sha,created_at:$created_at}' \
        | atomic_json_write "$checkout_file"
    echo "Main integration checkout prepared at $worktree ($main_sha)"
}

claim_integration() {
    local owner=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --owner) owner="${2:-}"; shift 2 ;;
            *) die "unknown claim-integration argument '$1'" ;;
        esac
    done
    [[ -n "$owner" ]] || die "claim-integration requires --owner"
    validate_identity "$owner" "owner"
    acquire_lock
    if [[ -f "$LEASE_FILE" ]]; then
        if jq -e --arg owner "$owner" '.owner == $owner' "$LEASE_FILE" >/dev/null 2>&1; then
            echo "Integration lease already held by $owner"
            return 0
        fi
        die "integration lease already held by '$(jq -r '.owner' "$LEASE_FILE")'"
    fi
    jq -n --arg owner "$owner" --arg repo "$REPO_ROOT" --arg claimed_at "$(now_utc)" \
        '{schema:1, owner:$owner, repo:$repo, claimed_at:$claimed_at}' | atomic_json_write "$LEASE_FILE"
    echo "Integration lease claimed by $owner"
}

release_integration() {
    local owner=""
    local manifest
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --owner) owner="${2:-}"; shift 2 ;;
            *) die "unknown release-integration argument '$1'" ;;
        esac
    done
    [[ -n "$owner" ]] || die "release-integration requires --owner"
    acquire_lock
    lease_matches "$owner"
    for manifest in "$TASKS_DIR"/*.json; do
        [[ -f "$manifest" ]] || continue
        if jq -e '.status == "ready" and (.integration_attempt | type == "object")' "$manifest" >/dev/null 2>&1; then
            die "integration lease cannot be released while task '$(jq -r '.task' "$manifest")' needs reconciliation"
        fi
    done
    rm "$LEASE_FILE"
    echo "Integration lease released by $owner"
}

integrate_task() {
    local task_id=""
    local owner=""
    local message=""
    local manifest
    local base_sha
    local result_commit
    local worktree
    local acceptance_log
    local integration_commit
    local main_head
    local expected_tree
    local actual_tree
    local parent_count
    local parent_commit
    local actual_message
    local temp_file

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --owner) owner="${2:-}"; shift 2 ;;
            --message) message="${2:-}"; shift 2 ;;
            *) die "unknown integrate argument '$1'" ;;
        esac
    done
    [[ -n "$task_id" && -n "$owner" && -n "$message" ]] || die "integrate requires --task, --owner, and --message"
    validate_identity "$task_id" "task"
    validate_identity "$owner" "owner"

    acquire_lock
    lease_matches "$owner"
    manifest="$(require_task_file "$task_id")"
    jq -e '.status == "ready"' "$manifest" >/dev/null 2>&1 || die "task '$task_id' is not ready"
    [[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" == "main" ]] || die "integration must run from the main worktree"
    [[ -z "$(git status --porcelain)" ]] || die "main worktree is not clean"
    base_sha="$(jq -r '.base_sha' "$manifest")"
    result_commit="$(jq -r '.result_commit' "$manifest")"
    worktree="$(jq -r '.worktree' "$manifest")"
    [[ "$(git -C "$worktree" rev-parse HEAD)" == "$result_commit" ]] || die "task worktree no longer matches result commit $result_commit"
    expected_tree="$(git rev-parse "$result_commit^{tree}")"
    main_head="$(git rev-parse HEAD)"

    if [[ "$main_head" != "$base_sha" ]]; then
        actual_tree="$(git rev-parse "$main_head^{tree}" 2>/dev/null || true)"
        parent_count="$(git rev-list --parents -n 1 "$main_head" | awk '{print NF - 1}')"
        parent_commit="$(git rev-list --parents -n 1 "$main_head" | awk '{print $2}')"
        actual_message="$(git log -1 --format=%B "$main_head")"
        if ! jq -e \
            --arg base_sha "$base_sha" \
            --arg result_commit "$result_commit" \
            --arg expected_tree "$expected_tree" \
            --arg message "$message" \
            '.integration_attempt.base_sha == $base_sha
             and .integration_attempt.result_commit == $result_commit
             and .integration_attempt.expected_tree == $expected_tree
             and .integration_attempt.message == $message' "$manifest" >/dev/null 2>&1 \
            || [[ "$parent_count" != "1" || "$parent_commit" != "$base_sha" || "$actual_tree" != "$expected_tree" || "$actual_message" != "$message" ]]; then
            die "main moved beyond pinned base $base_sha and does not match a recoverable integration attempt"
        fi
        acceptance_log="$(run_acceptance "$manifest" "$result_commit")" || die "recovery acceptance commands failed"
        [[ -z "$(git -C "$worktree" status --porcelain)" ]] || die "recovery acceptance dirtied the task worktree"
        [[ "$(git -C "$worktree" rev-parse HEAD)" == "$result_commit" ]] || die "recovery acceptance moved the task result commit"
        [[ "$(git rev-parse HEAD)" == "$main_head" && -z "$(git status --porcelain)" ]] \
            || die "recovery acceptance changed the integration checkout"
        jq \
            --arg integration_commit "$main_head" \
            --arg integrated_at "$(now_utc)" \
            --arg integration_acceptance_log "$acceptance_log" \
            '.status = "integrated"
             | .integration_commit = $integration_commit
             | .integrated_at = $integrated_at
             | .integration_acceptance_log = $integration_acceptance_log
             | .recovered_after_commit = true
             | del(.integration_attempt)' "$manifest" | atomic_json_write "$manifest"
        echo "Task $task_id reconciled after integration commit $main_head"
        return 0
    fi

    acceptance_log="$(run_acceptance "$manifest" "$result_commit")" || die "integration acceptance commands failed"
    [[ -z "$(git -C "$worktree" status --porcelain)" ]] || die "acceptance commands dirtied the task worktree"
    [[ "$(git -C "$worktree" rev-parse HEAD)" == "$result_commit" ]] || die "acceptance commands moved the task result commit"
    [[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" == "main" ]] || die "acceptance moved integration away from main"
    [[ "$(git rev-parse HEAD)" == "$base_sha" ]] || die "acceptance moved main beyond pinned base $base_sha"
    [[ -z "$(git status --porcelain)" ]] || die "acceptance dirtied the main integration worktree"

    git merge --squash "$result_commit" >/dev/null || die "squash merge failed"
    jq \
        --arg base_sha "$base_sha" \
        --arg result_commit "$result_commit" \
        --arg expected_tree "$expected_tree" \
        --arg message "$message" \
        --arg started_at "$(now_utc)" \
        '.integration_attempt = {
            base_sha: $base_sha,
            result_commit: $result_commit,
            expected_tree: $expected_tree,
            message: $message,
            started_at: $started_at
        }' "$manifest" | atomic_json_write "$manifest"
    if ! VOWRITE_INTEGRATION_TASK="$task_id" VOWRITE_INTEGRATION_OWNER="$owner" git commit -m "$message"; then
        if [[ "$(git rev-parse HEAD)" != "$base_sha" ]]; then
            die "integration commit may have been created; rerun integrate with the same owner and message to reconcile it"
        fi
        git reset --hard "$base_sha" >/dev/null \
            || die "integration commit failed before commit creation and the staged squash could not be rolled back"
        [[ -z "$(git status --porcelain)" ]] \
            || die "integration commit failed before commit creation and rollback left the integration checkout dirty"
        jq 'del(.integration_attempt)' "$manifest" | atomic_json_write "$manifest"
        die "integration commit failed before commit creation; the staged squash was rolled back and the ready task can be retried"
    fi
    integration_commit="$(git rev-parse HEAD)"
    [[ -z "$(git status --porcelain)" ]] || die "integration commit left main dirty; manifest remains ready"
    temp_file="$(mktemp "$STATE_DIR/.integrate.XXXXXX")"
    jq \
        --arg integration_commit "$integration_commit" \
        --arg integrated_at "$(now_utc)" \
        --arg integration_acceptance_log "$acceptance_log" \
        '.status = "integrated" | .integration_commit = $integration_commit | .integrated_at = $integrated_at | .integration_acceptance_log = $integration_acceptance_log | .recovered_after_commit = false | del(.integration_attempt)' \
        "$manifest" > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$manifest"
    echo "Task $task_id integrated at $integration_commit"
}

publish_task() {
    local task_id=""
    local owner=""
    local remote="origin"
    local manifest
    local integration_commit
    local temp_file

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --owner) owner="${2:-}"; shift 2 ;;
            --remote) remote="${2:-}"; shift 2 ;;
            *) die "unknown publish argument '$1'" ;;
        esac
    done
    [[ -n "$task_id" && -n "$owner" ]] || die "publish requires --task and --owner"
    acquire_lock
    lease_matches "$owner"
    manifest="$(require_task_file "$task_id")"
    jq -e '.status == "integrated"' "$manifest" >/dev/null 2>&1 || die "task '$task_id' is not integrated"
    integration_commit="$(jq -r '.integration_commit' "$manifest")"
    [[ "$(git rev-parse HEAD)" == "$integration_commit" ]] || die "main HEAD is not the task integration commit"
    [[ -z "$(git status --porcelain)" ]] || die "main worktree is not clean"
    git remote get-url "$remote" >/dev/null 2>&1 || die "unknown remote '$remote'"
    VOWRITE_PUBLISH_TASK="$task_id" VOWRITE_PUBLISH_OWNER="$owner" \
        git push "$remote" "$integration_commit:refs/heads/main"
    temp_file="$(mktemp "$STATE_DIR/.publish.XXXXXX")"
    jq --arg published_at "$(now_utc)" --arg remote "$remote" \
        '.status = "published" | .published_at = $published_at | .remote = $remote' "$manifest" > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$manifest"
    echo "Task $task_id published to $remote/main"
}

cleanup_task() {
    local task_id=""
    local owner=""
    local local_only=false
    local manifest
    local task_status
    local worktree
    local branch
    local result_commit
    local temp_file

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --owner) owner="${2:-}"; shift 2 ;;
            --local-only) local_only=true; shift ;;
            *) die "unknown cleanup argument '$1'" ;;
        esac
    done
    [[ -n "$task_id" && -n "$owner" ]] || die "cleanup requires --task and --owner"
    acquire_lock
    lease_matches "$owner"
    manifest="$(require_task_file "$task_id")"
    task_status="$(jq -r '.status' "$manifest")"
    if [[ "$local_only" == true ]]; then
        [[ "$task_status" == "integrated" || "$task_status" == "published" ]] || die "local cleanup requires an integrated task"
    else
        [[ "$task_status" == "published" ]] || die "cleanup requires a published task (or pass --local-only)"
    fi
    worktree="$(jq -r '.worktree' "$manifest")"
    branch="$(jq -r '.branch' "$manifest")"
    result_commit="$(jq -r '.result_commit' "$manifest")"
    [[ -z "$(git -C "$worktree" status --porcelain)" ]] || die "task worktree is not clean: $worktree"
    [[ "$(git -C "$worktree" rev-parse HEAD 2>/dev/null)" == "$result_commit" ]] \
        || die "task worktree no longer points to the integrated result $result_commit"
    [[ "$(git rev-parse "$branch^{commit}" 2>/dev/null)" == "$result_commit" ]] \
        || die "task branch advanced beyond the integrated result; refusing destructive cleanup"
    git worktree remove "$worktree" || die "failed to remove worktree $worktree"
    git branch -D "$branch" >/dev/null || die "failed to delete integrated branch $branch"
    temp_file="$(mktemp "$STATE_DIR/.cleanup.XXXXXX")"
    jq --arg cleaned_at "$(now_utc)" '.status = "cleaned" | .cleaned_at = $cleaned_at' "$manifest" > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$manifest"
    echo "Task $task_id worktree and branch cleaned"
}

abort_task() {
    local task_id=""
    local owner=""
    local reason=""
    local manifest
    local task_status
    local worktree
    local branch
    local aborted_commit
    local temp_file

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --owner) owner="${2:-}"; shift 2 ;;
            --reason) reason="${2:-}"; shift 2 ;;
            *) die "unknown abort argument '$1'" ;;
        esac
    done
    [[ -n "$task_id" && -n "$owner" && -n "$reason" ]] || die "abort requires --task, --owner, and --reason"
    validate_identity "$task_id" "task"
    validate_identity "$owner" "owner"
    [[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" == "main" ]] \
        || die "abort must run from the main integration checkout"
    [[ -z "$(git status --porcelain)" ]] || die "abort requires a clean main integration checkout"

    acquire_lock
    manifest="$(require_task_file "$task_id")"
    owner_matches "$manifest" "$owner"
    task_status="$(jq -r '.status' "$manifest")"
    [[ "$task_status" == "active" || "$task_status" == "ready" ]] \
        || die "task '$task_id' can be aborted only while active or ready"
    jq -e '.integration_attempt == null' "$manifest" >/dev/null 2>&1 \
        || die "task '$task_id' has a pending integration attempt; the same integration owner must reconcile it before abort"
    worktree="$(jq -r '.worktree' "$manifest")"
    branch="$(jq -r '.branch' "$manifest")"
    [[ -d "$worktree" ]] || die "task worktree is missing: $worktree"
    [[ -z "$(git -C "$worktree" status --porcelain)" ]] || die "task worktree is not clean: $worktree"
    aborted_commit="$(git -C "$worktree" rev-parse HEAD 2>/dev/null)" || die "cannot resolve task worktree commit"
    [[ "$(git rev-parse "$branch^{commit}" 2>/dev/null)" == "$aborted_commit" ]] \
        || die "task branch and worktree have diverged; refusing destructive abort"

    git worktree remove "$worktree" || die "failed to remove aborted worktree $worktree"
    git branch -D "$branch" >/dev/null || die "failed to delete aborted branch $branch"
    temp_file="$(mktemp "$STATE_DIR/.abort.XXXXXX")"
    jq \
        --arg aborted_at "$(now_utc)" \
        --arg aborted_from_status "$task_status" \
        --arg aborted_commit "$aborted_commit" \
        --arg abort_reason "$reason" \
        '.status = "aborted" | .aborted_at = $aborted_at | .aborted_from_status = $aborted_from_status | .aborted_commit = $aborted_commit | .abort_reason = $abort_reason' \
        "$manifest" > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$manifest"
    echo "Task $task_id aborted; previous commit remains recorded as $aborted_commit"
}

show_status() {
    local task_id=""
    local as_json=false
    local manifest

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task_id="${2:-}"; shift 2 ;;
            --json) as_json=true; shift ;;
            *) die "unknown status argument '$1'" ;;
        esac
    done

    if [[ -n "$task_id" ]]; then
        manifest="$(require_task_file "$task_id")"
        if [[ "$as_json" == true ]]; then
            cat "$manifest"
        else
            jq -r '"\(.task)  \(.status)  owner=\(.owner)  base=\(.base_sha)  branch=\(.branch)"' "$manifest"
        fi
        return 0
    fi

    if [[ "$as_json" == true ]]; then
        jq -s '.' "$TASKS_DIR"/*.json 2>/dev/null || printf '[]\n'
    else
        for manifest in "$TASKS_DIR"/*.json; do
            [[ -f "$manifest" ]] || continue
            jq -r '"\(.task)  \(.status)  owner=\(.owner)  base=\(.base_sha)  branch=\(.branch)"' "$manifest"
        done
    fi
}

COMMAND="${1:-}"
[[ -n "$COMMAND" ]] || { usage; exit 2; }
shift

case "$COMMAND" in
    start) start_task "$@" ;;
    adopt) adopt_task "$@" ;;
    handoff) handoff_task "$@" ;;
    refresh) refresh_task "$@" ;;
    refresh-continue) refresh_continue_task "$@" ;;
    refresh-abort) refresh_abort_task "$@" ;;
    ensure-integration-checkout) ensure_integration_checkout "$@" ;;
    claim-integration) claim_integration "$@" ;;
    release-integration) release_integration "$@" ;;
    integrate) integrate_task "$@" ;;
    publish) publish_task "$@" ;;
    cleanup) cleanup_task "$@" ;;
    abort) abort_task "$@" ;;
    status) show_status "$@" ;;
    -h|--help|help) usage ;;
    *) usage >&2; die "unknown command '$COMMAND'" ;;
esac
