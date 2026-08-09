#!/usr/bin/env bash
# Behavioral contract for the Vowrite Claude Code + Codex agent platform.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$PROJECT_ROOT/.agents/hooks/branch-guard.sh"
BOOTSTRAP="$PROJECT_ROOT/scripts/bootstrap-agent-platform.sh"
TASK_CLI="$PROJECT_ROOT/scripts/agent-task.sh"
PUBLISH_RELEASE="$PROJECT_ROOT/scripts/publish-release.sh"
PRE_PUSH="$PROJECT_ROOT/.githooks/pre-push"
PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "PASS: $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: $1" >&2
}

expect_file() {
    local path="$1"
    local label="$2"
    if [[ -f "$path" ]]; then
        pass "$label"
    else
        fail "$label (missing: $path)"
    fi
}

expect_executable() {
    local path="$1"
    local label="$2"
    if [[ -x "$path" ]]; then
        pass "$label"
    else
        fail "$label (not executable: $path)"
    fi
}

expect_exit() {
    local expected="$1"
    local label="$2"
    local command_log
    shift 2

    command_log="$(mktemp "$TEST_ROOT/expect.XXXXXX")"
    "$@" >"$command_log" 2>&1
    local actual=$?
    if [[ "$actual" -eq "$expected" ]]; then
        pass "$label"
        rm -f "$command_log"
    else
        fail "$label (expected exit $expected, got $actual)"
        sed 's/^/  | /' "$command_log" >&2
    fi
}

run_hook() {
    local payload="$1"
    printf '%s\n' "$payload" | "$GUARD"
}

TEST_ROOT="$(mktemp -d /tmp/vowrite-agent-platform.XXXXXX)"
cleanup() {
    if [[ -n "${TEST_ROOT:-}" && "$TEST_ROOT" == /tmp/vowrite-agent-platform.* ]]; then
        rm -rf -- "$TEST_ROOT"
    fi
}
trap cleanup EXIT

echo "Agent platform behavioral tests"

expect_file "$PROJECT_ROOT/AGENTS.md" "standalone AGENTS.md exists"
expect_file "$PROJECT_ROOT/CLAUDE.md" "standalone CLAUDE.md exists"
expect_executable "$GUARD" "canonical branch guard exists"
expect_executable "$BOOTSTRAP" "bootstrap command exists"
expect_executable "$TASK_CLI" "agent task command exists"
expect_executable "$PUBLISH_RELEASE" "governed release publisher exists"
expect_executable "$PRE_PUSH" "repository pre-push gate exists"
expect_file "$PROJECT_ROOT/.claude/settings.json" "standalone Claude hook config exists"
expect_file "$PROJECT_ROOT/.codex/hooks.json" "standalone Codex hook config exists"

if [[ -L "$PROJECT_ROOT/.claude/skills" ]] && [[ "$(readlink "$PROJECT_ROOT/.claude/skills")" == "../.agents/skills" ]]; then
    pass "Claude skills mount is relative and standalone-safe"
else
    fail "Claude skills mount is relative and standalone-safe"
fi

for skill_name in vowrite-feature-lifecycle vowrite-provider-integration vowrite-release vowrite-review; do
    expect_file "$PROJECT_ROOT/.agents/skills/$skill_name/SKILL.md" "standalone skill: $skill_name"
done

for protocol_term in "worktree" "base SHA" "integration owner" "write-set" "handoff"; do
    if grep -qi "$protocol_term" "$PROJECT_ROOT/AGENTS.md"; then
        pass "AGENTS protocol declares: $protocol_term"
    else
        fail "AGENTS protocol declares: $protocol_term"
    fi
done

if grep -qx '@AGENTS.md' "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null; then
    pass "Claude imports standalone AGENTS.md"
else
    fail "Claude imports standalone AGENTS.md"
fi

if jq -e '.hooks.PreToolUse | any(.matcher == "Bash|apply_patch")' "$PROJECT_ROOT/.codex/hooks.json" >/dev/null 2>&1; then
    pass "Codex guard covers Bash and apply_patch"
else
    fail "Codex guard covers Bash and apply_patch"
fi

if jq -e '.hooks.PreToolUse | any(.matcher == "Bash|Edit|Write")' "$PROJECT_ROOT/.claude/settings.json" >/dev/null 2>&1; then
    pass "Claude guard covers Bash, Edit, and Write"
else
    fail "Claude guard covers Bash, Edit, and Write"
fi

MAIN_ROOT="$TEST_ROOT/main-product"
FEATURE_ROOT="$TEST_ROOT/feature-product"
git init -q -b main "$MAIN_ROOT"
git -C "$MAIN_ROOT" config user.name "Agent Platform Test"
git -C "$MAIN_ROOT" config user.email "agent-platform@example.invalid"
mkdir -p "$MAIN_ROOT/VowriteKit" "$MAIN_ROOT/VowriteMac"
printf 'fixture\n' > "$MAIN_ROOT/AGENTS.md"
printf 'marker\n' > "$MAIN_ROOT/VowriteKit/.agent-platform-marker"
printf 'marker\n' > "$MAIN_ROOT/VowriteMac/.agent-platform-marker"
git -C "$MAIN_ROOT" add AGENTS.md VowriteKit/.agent-platform-marker VowriteMac/.agent-platform-marker
git -C "$MAIN_ROOT" commit -q -m "test: base"
git clone -q "$MAIN_ROOT" "$FEATURE_ROOT"
git -C "$FEATURE_ROOT" switch -q -c feature/test
pass "main and feature topology fixtures created"

if [[ -x "$GUARD" && -n "$MAIN_ROOT" ]]; then
    main_edit_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg file "$MAIN_ROOT/AGENTS.md" '{cwd:$cwd,tool_name:"Edit",tool_input:{file_path:$file}}')"
    feature_edit_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg file "$FEATURE_ROOT/AGENTS.md" '{cwd:$cwd,tool_name:"Edit",tool_input:{file_path:$file}}')"
    feature_outside_edit_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg file "$FEATURE_ROOT/VowriteKit/outside.swift" '{cwd:$cwd,tool_name:"Edit",tool_input:{file_path:$file}}')"
    feature_bash_write_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command 'touch AGENTS.md' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    feature_bash_outside_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command 'touch VowriteKit/outside.swift' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    feature_unknown_mutator_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command 'python3 scripts/generate.py' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    move_patch_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command $'*** Begin Patch\n*** Update File: AGENTS.md\n*** Move to: docs/AGENT_RULES.md\n*** End Patch' '{cwd:$cwd,tool_name:"apply_patch",tool_input:{command:$command}}')"
    bash_write_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'printf changed > AGENTS.md' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    bash_copy_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'cp AGENTS.md AGENTS.copy.md' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    bash_generator_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'python3 scripts/generate.py' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    bash_read_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'git status --short --branch' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    git_output_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'git diff --output=Probe.md' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    sort_output_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'sort -o Probe.md AGENTS.md' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    sed_in_place_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'sed --in-place=.bak s/a/b/ AGENTS.md' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    find_output_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'find . -fprint Probe.md' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    uniq_output_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'uniq AGENTS.md Probe.md' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    safe_chain_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command './scripts/agent-task.sh status; touch Probe.swift' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    bootstrap_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'scripts/bootstrap-agent-platform.sh' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    bootstrap_fallback_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'scripts/bootstrap-agent-platform.sh --check || scripts/bootstrap-agent-platform.sh' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    multiline_start_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command $'scripts/agent-task.sh start --task T-CLI \\\n  --owner codex --branch feature/T-CLI --worktree /tmp/t-cli \\\n  --write-set docs/** --accept "git diff --check"' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    absolute_touch_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command '/usr/bin/touch Probe.swift' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    disable_hooks_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'git config core.hooksPath /dev/null' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    feature_disable_hooks_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command 'git config core.hooksPath /dev/null' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    feature_worktree_control_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command 'git worktree remove /tmp/another-task' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    direct_push_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command 'git push origin HEAD' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    git_config_push_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command 'git -c core.hooksPath=/dev/null push escape HEAD:refs/heads/main' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    git_no_pager_push_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command 'git --no-pager push --no-verify escape HEAD:refs/heads/main' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    git_config_commit_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command 'git -c core.hooksPath=/dev/null commit -m bypass' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    git_no_verify_commit_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command 'git commit --no-verify -m bypass' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    release_push_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'VOWRITE_RELEASE=1 git push origin main --tags' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    release_wrapper_payload="$(jq -cn --arg cwd "$MAIN_ROOT" --arg command 'scripts/publish-release.sh --tag v0.0.0.1' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    cross_worktree_bash_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command "touch $MAIN_ROOT/Probe.swift" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$command}}')"
    cross_worktree_patch_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command "*** Begin Patch\n*** Add File: $MAIN_ROOT/Probe.swift\n+probe\n*** End Patch" '{cwd:$cwd,tool_name:"apply_patch",tool_input:{command:$command}}')"
    ln -s "$MAIN_ROOT" "$FEATURE_ROOT/escape"
    symlink_escape_patch_payload="$(jq -cn --arg cwd "$FEATURE_ROOT" --arg command $'*** Begin Patch\n*** Add File: escape/Probe.md\n+probe\n*** End Patch' '{cwd:$cwd,tool_name:"apply_patch",tool_input:{command:$command}}')"

    expect_exit 2 "Edit is blocked on product main" run_hook "$main_edit_payload"
    expect_exit 2 "Edit is blocked in an unregistered feature worktree" run_hook "$feature_edit_payload"
    expect_exit 2 "mutating Bash is blocked in an unregistered feature worktree" run_hook "$feature_bash_write_payload"

    FEATURE_COMMON="$(git -C "$FEATURE_ROOT" rev-parse --path-format=absolute --git-common-dir)"
    mkdir -p "$FEATURE_COMMON/vowrite-agent-platform/tasks"
    jq -n \
        --arg task "fixture-feature" \
        --arg branch "feature/test" \
        --arg worktree "$(cd "$FEATURE_ROOT" && pwd -P)" \
        '{schema:1, task:$task, branch:$branch, worktree:$worktree, write_set:["AGENTS.md", "escape/**"], status:"active"}' \
        > "$FEATURE_COMMON/vowrite-agent-platform/tasks/fixture-feature.json"
    expect_exit 0 "Edit is allowed inside a registered feature write-set" run_hook "$feature_edit_payload"
    expect_exit 2 "Edit outside a registered feature write-set is blocked" run_hook "$feature_outside_edit_payload"
    expect_exit 0 "mutating Bash is allowed only after feature registration" run_hook "$feature_bash_write_payload"
    expect_exit 2 "registered Bash cannot write outside its declared write-set" run_hook "$feature_bash_outside_payload"
    expect_exit 2 "registered workers cannot run opaque source-mutating generators" run_hook "$feature_unknown_mutator_payload"
    expect_exit 2 "apply_patch cannot escape through a symlinked directory" run_hook "$symlink_escape_patch_payload"
    expect_exit 2 "apply_patch Move is blocked on product main" run_hook "$move_patch_payload"
    expect_exit 2 "Bash redirection is blocked on product main" run_hook "$bash_write_payload"
    expect_exit 2 "Bash copy is blocked on product main" run_hook "$bash_copy_payload"
    expect_exit 2 "Bash generators are blocked on product main" run_hook "$bash_generator_payload"
    expect_exit 0 "read-only Bash is allowed on product main" run_hook "$bash_read_payload"
    expect_exit 2 "git diff --output is not classified as read-only" run_hook "$git_output_payload"
    expect_exit 2 "sort -o is not classified as read-only" run_hook "$sort_output_payload"
    expect_exit 2 "sed --in-place is not classified as read-only" run_hook "$sed_in_place_payload"
    expect_exit 2 "find -fprint is not classified as read-only" run_hook "$find_output_payload"
    expect_exit 2 "uniq output operands are not classified as read-only" run_hook "$uniq_output_payload"
    expect_exit 2 "trusted control command cannot hide a chained mutation" run_hook "$safe_chain_payload"
    expect_exit 0 "single idempotent bootstrap command is allowed on main" run_hook "$bootstrap_payload"
    expect_exit 2 "compound bootstrap fallback is rejected on main" run_hook "$bootstrap_fallback_payload"
    expect_exit 0 "documented multiline task start is normalized and allowed" run_hook "$multiline_start_payload"
    expect_exit 2 "absolute mutating executables are blocked on product main" run_hook "$absolute_touch_payload"
    expect_exit 2 "Bash cannot disable the repository Git backstop" run_hook "$disable_hooks_payload"
    expect_exit 2 "feature workers cannot disable the shared Git backstop" run_hook "$feature_disable_hooks_payload"
    expect_exit 2 "feature workers cannot control task worktrees directly" run_hook "$feature_worktree_control_payload"
    expect_exit 2 "workers cannot invoke git push directly" run_hook "$direct_push_payload"
    expect_exit 2 "git -c cannot hide a direct push" run_hook "$git_config_push_payload"
    expect_exit 2 "git --no-pager cannot hide a --no-verify push" run_hook "$git_no_pager_push_payload"
    expect_exit 2 "git -c cannot disable hooks for commit" run_hook "$git_config_commit_payload"
    expect_exit 2 "workers cannot commit with --no-verify" run_hook "$git_no_verify_commit_payload"
    expect_exit 2 "agents cannot bypass the release wrapper with a direct push" run_hook "$release_push_payload"
    expect_exit 0 "the governed release wrapper can reach the Git pre-push gate" run_hook "$release_wrapper_payload"
    expect_exit 2 "feature Bash cannot target the shared main worktree" run_hook "$cross_worktree_bash_payload"
    expect_exit 2 "feature apply_patch cannot target the shared main worktree" run_hook "$cross_worktree_patch_payload"

    ESCAPE_REMOTE="$TEST_ROOT/escape-remote.git"
    git init -q --bare "$ESCAPE_REMOTE"
    git -C "$FEATURE_ROOT" remote add escape "$ESCAPE_REMOTE"
    expect_exit 2 "guard stops the real git -c hooksPath push bypass" bash -c "printf '%s\n' '$git_config_push_payload' | '$GUARD' && git -C '$FEATURE_ROOT' -c core.hooksPath=/dev/null push escape HEAD:refs/heads/main"
    if git --git-dir="$ESCAPE_REMOTE" show-ref --verify --quiet refs/heads/main; then
        fail "blocked git -c push leaves the remote main ref absent"
    else
        pass "blocked git -c push leaves the remote main ref absent"
    fi
fi

PRECOMMIT_REPO="$TEST_ROOT/precommit-repo"
git init -q -b main "$PRECOMMIT_REPO"
git -C "$PRECOMMIT_REPO" config user.name "Agent Platform Test"
git -C "$PRECOMMIT_REPO" config user.email "agent-platform@example.invalid"
mkdir -p "$PRECOMMIT_REPO/.agents/hooks"
if [[ -x "$GUARD" ]]; then
    cp "$GUARD" "$PRECOMMIT_REPO/.agents/hooks/branch-guard.sh"
    chmod +x "$PRECOMMIT_REPO/.agents/hooks/branch-guard.sh"
    printf 'fixture\n' > "$PRECOMMIT_REPO/AGENTS.md"
    mkdir -p "$PRECOMMIT_REPO/VowriteKit" "$PRECOMMIT_REPO/VowriteMac"
    git -C "$PRECOMMIT_REPO" add AGENTS.md VowriteKit VowriteMac
    expect_exit 2 "pre-commit mode blocks staged product changes on main" bash -c "cd \"$PRECOMMIT_REPO\" && .agents/hooks/branch-guard.sh --pre-commit"
    expect_exit 2 "release flag cannot bypass unrelated staged paths" bash -c "cd \"$PRECOMMIT_REPO\" && VOWRITE_RELEASE=1 .agents/hooks/branch-guard.sh --pre-commit"
    git -C "$PRECOMMIT_REPO" switch -q -c feature/test
    expect_exit 2 "pre-commit rejects an unregistered feature worktree" bash -c "cd \"$PRECOMMIT_REPO\" && .agents/hooks/branch-guard.sh --pre-commit"
fi

WORKSPACE_RELEASE_REPO="$TEST_ROOT/workspace-release-repo"
git init -q -b main "$WORKSPACE_RELEASE_REPO"
git -C "$WORKSPACE_RELEASE_REPO" config user.name "Agent Platform Test"
git -C "$WORKSPACE_RELEASE_REPO" config user.email "agent-platform@example.invalid"
mkdir -p "$WORKSPACE_RELEASE_REPO/.agents/hooks" "$WORKSPACE_RELEASE_REPO/Vowrite-internal"
cp "$GUARD" "$WORKSPACE_RELEASE_REPO/.agents/hooks/branch-guard.sh"
chmod +x "$WORKSPACE_RELEASE_REPO/.agents/hooks/branch-guard.sh"
printf 'fixture\n' > "$WORKSPACE_RELEASE_REPO/AGENTS.md"
printf 'tracking\n' > "$WORKSPACE_RELEASE_REPO/Vowrite-internal/tracking.md"
git -C "$WORKSPACE_RELEASE_REPO" add AGENTS.md Vowrite-internal/tracking.md
git -C "$WORKSPACE_RELEASE_REPO" commit -q -m "test: workspace base"
printf 'release\n' > "$WORKSPACE_RELEASE_REPO/CHANGELOG.md"
git -C "$WORKSPACE_RELEASE_REPO" add CHANGELOG.md
expect_exit 2 "workspace main has no product release pre-commit exemption" bash -c "cd \"$WORKSPACE_RELEASE_REPO\" && VOWRITE_RELEASE=1 .agents/hooks/branch-guard.sh --pre-commit"
expect_exit 2 "workspace main has no product release pre-push exemption" bash -c "cd \"$WORKSPACE_RELEASE_REPO\" && printf 'refs/heads/main %s refs/heads/main %s\n' \"$(git -C "$WORKSPACE_RELEASE_REPO" rev-parse HEAD)\" \"$(printf '0%.0s' {1..40})\" | VOWRITE_RELEASE=1 .agents/hooks/branch-guard.sh --pre-push"

TYPECHANGE_REPO="$TEST_ROOT/typechange-repo"
git init -q -b main "$TYPECHANGE_REPO"
git -C "$TYPECHANGE_REPO" config user.name "Agent Platform Test"
git -C "$TYPECHANGE_REPO" config user.email "agent-platform@example.invalid"
mkdir -p "$TYPECHANGE_REPO/.agents/hooks" "$TYPECHANGE_REPO/VowriteKit" "$TYPECHANGE_REPO/VowriteMac"
cp "$GUARD" "$TYPECHANGE_REPO/.agents/hooks/branch-guard.sh"
chmod +x "$TYPECHANGE_REPO/.agents/hooks/branch-guard.sh"
printf 'fixture\n' > "$TYPECHANGE_REPO/AGENTS.md"
printf 'regular\n' > "$TYPECHANGE_REPO/VowriteKit/type-change"
git -C "$TYPECHANGE_REPO" add AGENTS.md VowriteKit/type-change VowriteMac
git -C "$TYPECHANGE_REPO" commit -q -m "test: type-change base"
rm "$TYPECHANGE_REPO/VowriteKit/type-change"
ln -s AGENTS.md "$TYPECHANGE_REPO/VowriteKit/type-change"
git -C "$TYPECHANGE_REPO" add VowriteKit/type-change
expect_exit 2 "pre-commit counts a staged Git type change on main" bash -c "cd \"$TYPECHANGE_REPO\" && .agents/hooks/branch-guard.sh --pre-commit"

BOOTSTRAP_REPO="$TEST_ROOT/bootstrap-repo"
git init -q -b main "$BOOTSTRAP_REPO"
mkdir -p "$BOOTSTRAP_REPO/.agents/hooks" "$BOOTSTRAP_REPO/.githooks" "$BOOTSTRAP_REPO/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$BOOTSTRAP_REPO/.githooks/pre-commit"
chmod +x "$BOOTSTRAP_REPO/.githooks/pre-commit"
if [[ -x "$BOOTSTRAP" ]]; then
    cp "$GUARD" "$BOOTSTRAP_REPO/.agents/hooks/branch-guard.sh"
    chmod +x "$BOOTSTRAP_REPO/.agents/hooks/branch-guard.sh"
    cp "$BOOTSTRAP" "$BOOTSTRAP_REPO/scripts/bootstrap-agent-platform.sh"
    cp "$PRE_PUSH" "$BOOTSTRAP_REPO/.githooks/pre-push" 2>/dev/null || true
    chmod +x "$BOOTSTRAP_REPO/scripts/bootstrap-agent-platform.sh"
    [[ ! -f "$BOOTSTRAP_REPO/.githooks/pre-push" ]] || chmod +x "$BOOTSTRAP_REPO/.githooks/pre-push"
    expect_exit 0 "fresh repo bootstrap succeeds" bash -c "cd \"$BOOTSTRAP_REPO\" && scripts/bootstrap-agent-platform.sh"
    if [[ "$(git -C "$BOOTSTRAP_REPO" config --get core.hooksPath || true)" == ".githooks" ]]; then
        pass "fresh repo bootstrap activates core.hooksPath"
    else
        fail "fresh repo bootstrap activates core.hooksPath"
    fi
    expect_exit 0 "fresh repo bootstrap check succeeds" bash -c "cd \"$BOOTSTRAP_REPO\" && scripts/bootstrap-agent-platform.sh --check"
fi

NO_MAIN_REPO="$TEST_ROOT/no-main-repo"
NO_MAIN_INTEGRATION="$TEST_ROOT/no-main-integration"
git init -q -b main "$NO_MAIN_REPO"
git -C "$NO_MAIN_REPO" config user.name "Agent Platform Test"
git -C "$NO_MAIN_REPO" config user.email "agent-platform@example.invalid"
printf 'fixture\n' > "$NO_MAIN_REPO/base.txt"
git -C "$NO_MAIN_REPO" add base.txt
git -C "$NO_MAIN_REPO" commit -q -m "test: base"
git -C "$NO_MAIN_REPO" switch -q -c feature/primary-worker
expect_exit 0 "coordinator provisions a dedicated main checkout when the primary checkout is a worker" \
    bash -c "cd \"$NO_MAIN_REPO\" && \"$TASK_CLI\" ensure-integration-checkout --owner integrator --worktree \"$NO_MAIN_INTEGRATION\""
if [[ "$(git -C "$NO_MAIN_INTEGRATION" symbolic-ref --quiet --short HEAD 2>/dev/null || true)" == "main" ]]; then
    pass "provisioned integration checkout owns the main branch"
else
    fail "provisioned integration checkout owns the main branch"
fi
expect_exit 0 "integration checkout provisioning is idempotent for the recorded path" \
    bash -c "cd \"$NO_MAIN_REPO\" && \"$TASK_CLI\" ensure-integration-checkout --owner integrator --worktree \"$NO_MAIN_INTEGRATION\""

TASK_REPO="$TEST_ROOT/task-repo"
TASK_WORKTREE="$TEST_ROOT/task-worktree"
SECOND_WORKTREE="$TEST_ROOT/second-worktree"
DIRTY_WORKTREE="$TEST_ROOT/dirty-worktree"
FEATURE_START_WORKTREE="$TEST_ROOT/feature-start-worktree"
INVALID_SCOPE_WORKTREE="$TEST_ROOT/invalid-scope-worktree"
ADOPT_WORKTREE="$TEST_ROOT/adopt-worktree"
TASK_REMOTE="$TEST_ROOT/task-remote.git"
git init -q -b main "$TASK_REPO"
git -C "$TASK_REPO" config user.name "Agent Platform Test"
git -C "$TASK_REPO" config user.email "agent-platform@example.invalid"
mkdir -p "$TASK_REPO/src" "$TASK_REPO/VowriteKit" "$TASK_REPO/VowriteMac"
printf 'base\n' > "$TASK_REPO/src/base.txt"
printf 'marker\n' > "$TASK_REPO/VowriteKit/.fixture"
printf 'marker\n' > "$TASK_REPO/VowriteMac/.fixture"
printf 'fixture\n' > "$TASK_REPO/AGENTS.md"
printf 'releases/\n' > "$TASK_REPO/.gitignore"
git -C "$TASK_REPO" add .gitignore AGENTS.md src/base.txt VowriteKit/.fixture VowriteMac/.fixture
git -C "$TASK_REPO" commit -q -m "test: base"
mkdir -p "$TASK_REPO/.agents/hooks" "$TASK_REPO/.githooks"
cp "$GUARD" "$TASK_REPO/.agents/hooks/branch-guard.sh"
chmod +x "$TASK_REPO/.agents/hooks/branch-guard.sh"
printf '#!/usr/bin/env bash\nexec "$(git rev-parse --show-toplevel)/.agents/hooks/branch-guard.sh" --pre-commit\n' > "$TASK_REPO/.githooks/pre-commit"
chmod +x "$TASK_REPO/.githooks/pre-commit"
if [[ -x "$PRE_PUSH" ]]; then
    cp "$PRE_PUSH" "$TASK_REPO/.githooks/pre-push"
    chmod +x "$TASK_REPO/.githooks/pre-push"
fi
git -C "$TASK_REPO" add .agents/hooks/branch-guard.sh .githooks/pre-commit
if [[ -f "$TASK_REPO/.githooks/pre-push" ]]; then
    git -C "$TASK_REPO" add .githooks/pre-push
fi
git -C "$TASK_REPO" commit -q --no-verify -m "test: agent platform"
git -C "$TASK_REPO" config core.hooksPath .githooks
git init -q --bare "$TASK_REMOTE"
git -C "$TASK_REPO" remote add publish-test "$TASK_REMOTE"

if [[ -x "$TASK_CLI" ]]; then
    TASK_COMMON="$(git -C "$TASK_REPO" rev-parse --path-format=absolute --git-common-dir)"
    mkdir -p "$TASK_COMMON/vowrite-agent-platform"
    jq -n --arg token active-fixture --arg host "$(uname -n)" --argjson pid "$$" \
        '{schema:1,token:$token,host:$host,pid:$pid}' > "$TASK_COMMON/vowrite-agent-platform/state.lock"
    expect_exit 2 "an active atomic state lock blocks a concurrent coordinator" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" claim-integration --owner lock-test"
    rm "$TASK_COMMON/vowrite-agent-platform/state.lock"
    mkdir "$TASK_COMMON/vowrite-agent-platform/lock"
    touch -t 200001010000 "$TASK_COMMON/vowrite-agent-platform/lock"
    expect_exit 0 "a stale legacy empty lock is recovered without a permanent deadlock" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" claim-integration --owner lock-test"
    expect_exit 0 "recovered lock lease can be released normally" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" release-integration --owner lock-test"

    git -C "$TASK_REPO" worktree add -q -b feature/T-ADOPT "$ADOPT_WORKTREE" main
    expect_exit 0 "coordinator adopts a tool-created worktree with a pinned base" bash -c "cd \"$ADOPT_WORKTREE\" && \"$TASK_CLI\" adopt --task T-ADOPT --owner claude --base \"$(git -C "$TASK_REPO" rev-parse main)\" --write-set 'adopt/**' --accept 'git diff --check'"
    mkdir -p "$ADOPT_WORKTREE/adopt"
    printf 'adopted\n' > "$ADOPT_WORKTREE/adopt/result.txt"
    git -C "$ADOPT_WORKTREE" add adopt/result.txt
    expect_exit 0 "adopted worktree commits through its registered write-set" git -C "$ADOPT_WORKTREE" commit -q -m "test: adopted worktree"
    adopt_commit="$(git -C "$ADOPT_WORKTREE" rev-parse HEAD)"
    expect_exit 0 "adopted worktree produces a normal handoff" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" handoff --task T-ADOPT --owner claude --commit \"$adopt_commit\""

    printf 'dirty\n' > "$TASK_REPO/dirty.txt"
    expect_exit 2 "task start requires a clean integration checkout" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-DIRTY --owner codex --branch feature/T-DIRTY --worktree \"$DIRTY_WORKTREE\" --write-set 'src/**' --accept 'git diff --check'"
    rm "$TASK_REPO/dirty.txt"
    git -C "$TASK_REPO" switch -q -c feature/unregistered
    expect_exit 2 "task start must run from main" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-FEATURE --owner codex --branch feature/T-FEATURE --worktree \"$FEATURE_START_WORKTREE\" --write-set 'src/**' --accept 'git diff --check'"
    expect_exit 2 "adopt rejects a primary checkout merely switched to a feature branch" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" adopt --task T-PRIMARY --owner codex --base \"$(git -C "$TASK_REPO" rev-parse main)\" --write-set 'src/**' --accept 'git diff --check'"
    git -C "$TASK_REPO" switch -q main
    expect_exit 2 "task write-set rejects ambiguous glob syntax" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-GLOB --owner codex --branch feature/T-GLOB --worktree \"$INVALID_SCOPE_WORKTREE\" --write-set 'src/Foo*Bar' --accept 'git diff --check'"
    expect_exit 0 "agent task creates an isolated worktree" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-001 --owner codex --branch feature/T-001 --worktree \"$TASK_WORKTREE\" --write-set 'src/**' --accept 'git diff --check'"
    expect_exit 2 "agent task rejects overlapping active write-sets" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-002 --owner claude --branch feature/T-002 --worktree \"$SECOND_WORKTREE\" --write-set 'src/base.txt' --accept 'git diff --check'"

    printf 'result\n' > "$TASK_WORKTREE/src/result.txt"
    git -C "$TASK_WORKTREE" add src/result.txt
    expect_exit 0 "registered task worktree can commit its declared write-set" git -C "$TASK_WORKTREE" commit -q -m "test: result"
    result_commit="$(git -C "$TASK_WORKTREE" rev-parse HEAD)"
    expect_exit 0 "agent task validates and records a clean handoff" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" handoff --task T-001 --owner codex --commit \"$result_commit\""
    expect_exit 0 "one integration owner can claim the lease" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" claim-integration --owner integrator"
    expect_exit 2 "a second integration owner is rejected" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" claim-integration --owner another"

    task_json="$(cd "$TASK_REPO" && "$TASK_CLI" status --task T-001 --json 2>/dev/null)"
    if jq -e --arg commit "$result_commit" '.status == "ready" and .result_commit == $commit' <<<"$task_json" >/dev/null 2>&1; then
        pass "handoff manifest pins the result commit"
    else
        fail "handoff manifest pins the result commit"
    fi

    expect_exit 0 "integration owner lands the pinned result on main" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" integrate --task T-001 --owner integrator --message 'test: integrate result'"
    integration_json="$(cd "$TASK_REPO" && "$TASK_CLI" status --task T-001 --json 2>/dev/null)"
    integration_commit="$(git -C "$TASK_REPO" rev-parse HEAD)"
    if jq -e --arg commit "$integration_commit" '.status == "integrated" and .integration_commit == $commit' <<<"$integration_json" >/dev/null 2>&1; then
        pass "integration manifest pins the main commit"
    else
        fail "integration manifest pins the main commit"
    fi
    expect_exit 2 "direct pre-push without a publish context is rejected" bash -c "cd \"$TASK_REPO\" && printf 'refs/heads/main %s refs/heads/main %s\n' \"$(git rev-parse HEAD)\" \"$(printf '0%.0s' {1..40})\" | .agents/hooks/branch-guard.sh --pre-push"
    RELEASE_TAG="v0.0.0.1"
    RELEASE_COMMIT="$(git -C "$TASK_REPO" rev-parse HEAD)"
    git -C "$TASK_REPO" tag -a "$RELEASE_TAG" -m "test: prepared release"
    RELEASE_TAG_OBJECT="$(git -C "$TASK_REPO" rev-parse "refs/tags/$RELEASE_TAG")"
    TASK_COMMON="$(git -C "$TASK_REPO" rev-parse --path-format=absolute --git-common-dir)"
    mkdir -p "$TASK_COMMON/vowrite-agent-platform"
    mkdir -p "$TASK_REPO/releases"
    printf 'fixture dmg\n' > "$TASK_REPO/releases/Vowrite-test.dmg"
    RELEASE_ASSET_SHA256="$(shasum -a 256 "$TASK_REPO/releases/Vowrite-test.dmg" | awk '{print $1}')"
    jq -n \
        --arg tag "$RELEASE_TAG" \
        --arg commit "$RELEASE_COMMIT" \
        --arg asset_sha256 "$RELEASE_ASSET_SHA256" \
        '{schema:1,status:"prepared",tag:$tag,version:"0.0.0.1",commit:$commit,repository:"example.invalid/Vowrite",title:"Vowrite test",notes:"test",asset:"releases/Vowrite-test.dmg",asset_sha256:$asset_sha256,prerelease:false}' \
        > "$TASK_COMMON/vowrite-agent-platform/release-intent.json"
    expect_exit 2 "environment-only release context is rejected without its pinned tag" bash -c "cd \"$TASK_REPO\" && printf 'refs/heads/main %s refs/heads/main %s\n' '$RELEASE_COMMIT' \"$(printf '0%.0s' {1..40})\" | VOWRITE_RELEASE=1 .agents/hooks/branch-guard.sh --pre-push"
    expect_exit 0 "prepared release context accepts only its pinned main and tag" bash -c "cd \"$TASK_REPO\" && printf 'refs/heads/main %s refs/heads/main %s\nrefs/tags/%s %s refs/tags/%s %s\n' '$RELEASE_COMMIT' \"$(printf '0%.0s' {1..40})\" '$RELEASE_TAG' '$RELEASE_TAG_OBJECT' '$RELEASE_TAG' \"$(printf '0%.0s' {1..40})\" | VOWRITE_RELEASE=1 VOWRITE_RELEASE_TAG='$RELEASE_TAG' .agents/hooks/branch-guard.sh --pre-push"
    expect_exit 2 "release context cannot publish an unrelated branch" bash -c "cd \"$TASK_REPO\" && printf 'refs/heads/feature/test %s refs/heads/feature/test %s\n' '$RELEASE_COMMIT' \"$(printf '0%.0s' {1..40})\" | VOWRITE_RELEASE=1 VOWRITE_RELEASE_TAG='$RELEASE_TAG' .agents/hooks/branch-guard.sh --pre-push"
    RELEASE_REMOTE="$TEST_ROOT/release-remote.git"
    FAKE_BIN="$TEST_ROOT/fake-bin"
    GH_LOG="$TEST_ROOT/gh.log"
    git init -q --bare "$RELEASE_REMOTE"
    git -C "$TASK_REPO" remote add origin git@github.com:example.invalid/Vowrite.git
    git -C "$TASK_REPO" config "url.$RELEASE_REMOTE.insteadOf" git@github.com:example.invalid/Vowrite.git
    mkdir -p "$FAKE_BIN"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> %q\nif [[ "$1 $2" == "release view" ]]; then exit 1; fi\nexit 0\n' "$GH_LOG" > "$FAKE_BIN/gh"
    chmod +x "$FAKE_BIN/gh"
    expect_exit 0 "release wrapper atomically publishes the pinned main, tag, and GitHub Release" bash -c "cd \"$TASK_REPO\" && PATH='$FAKE_BIN':\"\$PATH\" '$PUBLISH_RELEASE' --tag '$RELEASE_TAG'"
    if [[ "$(git --git-dir="$RELEASE_REMOTE" rev-parse refs/heads/main 2>/dev/null || true)" == "$RELEASE_COMMIT" ]] \
        && [[ "$(git --git-dir="$RELEASE_REMOTE" rev-parse "refs/tags/$RELEASE_TAG^{commit}" 2>/dev/null || true)" == "$RELEASE_COMMIT" ]] \
        && jq -e '.status == "published"' "$TASK_COMMON/vowrite-agent-platform/release-intent.json" >/dev/null 2>&1; then
        pass "release wrapper records and publishes only the pinned release"
    else
        fail "release wrapper records and publishes only the pinned release"
    fi
    expect_exit 0 "integration owner publishes only the pinned commit" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" publish --task T-001 --owner integrator --remote publish-test"
    expect_exit 0 "integration owner cleans a published integration" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" cleanup --task T-001 --owner integrator"
    expect_exit 0 "integration owner releases the lease" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" release-integration --owner integrator"

    OUTSIDE_WORKTREE="$TEST_ROOT/outside-worktree"
    expect_exit 0 "new task starts after the prior write-set is cleaned" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-003 --owner codex --branch feature/T-003 --worktree \"$OUTSIDE_WORKTREE\" --write-set 'src/**' --accept 'git diff --check'"
    printf 'outside\n' > "$OUTSIDE_WORKTREE/README.md"
    git -C "$OUTSIDE_WORKTREE" add README.md
    git -C "$OUTSIDE_WORKTREE" commit -q --no-verify -m "test: simulate bypass outside scope"
    outside_commit="$(git -C "$OUTSIDE_WORKTREE" rev-parse HEAD)"
    expect_exit 2 "handoff rejects a changed path outside the write-set" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" handoff --task T-003 --owner codex --commit \"$outside_commit\""
    expect_exit 2 "only the task owner can abort a rejected task" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" abort --task T-003 --owner claude --reason 'wrong owner'"
    expect_exit 0 "task owner can abort a clean rejected task and free its write-set" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" abort --task T-003 --owner codex --reason 'out-of-scope fixture'"
    abort_json="$(cd "$TASK_REPO" && "$TASK_CLI" status --task T-003 --json 2>/dev/null)"
    if jq -e --arg commit "$outside_commit" '.status == "aborted" and .aborted_commit == $commit and .abort_reason == "out-of-scope fixture"' <<<"$abort_json" >/dev/null 2>&1 \
        && [[ ! -d "$OUTSIDE_WORKTREE" ]] \
        && ! git -C "$TASK_REPO" show-ref --verify --quiet refs/heads/feature/T-003; then
        pass "aborted task records recovery evidence and removes only its own resources"
    else
        fail "aborted task records recovery evidence and removes only its own resources"
    fi

    DIRTY_ACCEPT_WORKTREE="$TEST_ROOT/dirty-accept-worktree"
    expect_exit 2 "task creation rejects a mutating acceptance command" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-004 --owner codex --branch feature/T-004 --worktree \"$DIRTY_ACCEPT_WORKTREE\" --write-set 'accept/**' --accept 'touch acceptance-dirty.txt'"

    MOVED_ACCEPT_WORKTREE="$TEST_ROOT/moved-accept-worktree"
    expect_exit 2 "task creation rejects a HEAD-moving acceptance command" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-005 --owner codex --branch feature/T-005 --worktree \"$MOVED_ACCEPT_WORKTREE\" --write-set 'move/**' --accept 'git commit --allow-empty -m acceptance-moved-head'"

    CROSS_ACCEPT_WORKTREE="$TEST_ROOT/cross-accept-worktree"
    CROSS_ACCEPT_TARGET="$TASK_REPO/main-dirtied.txt"
    expect_exit 2 "task creation rejects acceptance that targets the main checkout" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-007 --owner codex --branch feature/T-007 --worktree \"$CROSS_ACCEPT_WORKTREE\" --write-set 'cross/**' --accept 'touch $CROSS_ACCEPT_TARGET'"
    if [[ ! -e "$CROSS_ACCEPT_TARGET" ]]; then
        pass "rejected acceptance leaves the main checkout unchanged"
    else
        fail "rejected acceptance leaves the main checkout unchanged"
    fi

    TYPE_SCOPE_WORKTREE="$TEST_ROOT/type-scope-worktree"
    expect_exit 0 "type-change scope task starts" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-006 --owner codex --branch feature/T-006 --worktree \"$TYPE_SCOPE_WORKTREE\" --write-set 'allowed/**' --accept 'git diff --check'"
    rm "$TYPE_SCOPE_WORKTREE/.githooks/pre-commit"
    ln -s ../.agents/hooks/branch-guard.sh "$TYPE_SCOPE_WORKTREE/.githooks/pre-commit"
    git -C "$TYPE_SCOPE_WORKTREE" add .githooks/pre-commit
    git -C "$TYPE_SCOPE_WORKTREE" commit -q --no-verify -m "test: simulate out-of-scope type change"
    type_scope_commit="$(git -C "$TYPE_SCOPE_WORKTREE" rev-parse HEAD)"
    expect_exit 2 "handoff detects an out-of-scope Git type change" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" handoff --task T-006 --owner codex --commit \"$type_scope_commit\""

    expect_exit 2 "cleaned tasks cannot be refreshed back to active" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" refresh --task T-001 --owner codex --base \"$(git -C "$TASK_REPO" rev-parse HEAD)\""

    INTEGRATION_ACCEPT_WORKTREE="$TEST_ROOT/integration-accept-worktree"
    INTEGRATION_COUNTER="$TEST_ROOT/integration-accept-counter"
    INTEGRATION_DIRTY_TARGET="$TASK_REPO/integration-dirty"
    expect_exit 0 "integration-isolation task starts" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-008 --owner codex --branch feature/T-008 --worktree \"$INTEGRATION_ACCEPT_WORKTREE\" --write-set 'scripts/check-integration-isolation.sh' --accept 'scripts/check-integration-isolation.sh'"
    mkdir -p "$INTEGRATION_ACCEPT_WORKTREE/scripts"
    printf '#!/usr/bin/env bash\nset -e\nif [[ -e %q ]]; then\n  touch %q\nelse\n  touch %q\nfi\n' "$INTEGRATION_COUNTER" "$INTEGRATION_DIRTY_TARGET" "$INTEGRATION_COUNTER" > "$INTEGRATION_ACCEPT_WORKTREE/scripts/check-integration-isolation.sh"
    chmod +x "$INTEGRATION_ACCEPT_WORKTREE/scripts/check-integration-isolation.sh"
    git -C "$INTEGRATION_ACCEPT_WORKTREE" add scripts/check-integration-isolation.sh
    git -C "$INTEGRATION_ACCEPT_WORKTREE" commit -q -m "test: integration acceptance isolation"
    integration_accept_commit="$(git -C "$INTEGRATION_ACCEPT_WORKTREE" rev-parse HEAD)"
    expect_exit 0 "first acceptance run hands off an isolated result" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" handoff --task T-008 --owner codex --commit \"$integration_accept_commit\""
    expect_exit 0 "integration-isolation owner claims the lease" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" claim-integration --owner isolation-integrator"
    expect_exit 2 "integration aborts when its acceptance mutates main" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" integrate --task T-008 --owner isolation-integrator --message 'test: must not integrate'"
    isolation_json="$(cd "$TASK_REPO" && "$TASK_CLI" status --task T-008 --json 2>/dev/null)"
    if jq -e '.status == "ready" and (.integration_commit == null)' <<<"$isolation_json" >/dev/null 2>&1; then
        pass "failed integration leaves the manifest ready and unintegrated"
    else
        fail "failed integration leaves the manifest ready and unintegrated"
    fi
    rm -f "$INTEGRATION_DIRTY_TARGET" "$INTEGRATION_COUNTER"
    expect_exit 0 "integration-isolation owner releases the lease" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" release-integration --owner isolation-integrator"

    PARALLEL_WORKTREE="$TEST_ROOT/parallel-accept-worktree"
    VOLATILE_WORKTREE="$TEST_ROOT/volatile-other-worktree"
    git -C "$TASK_REPO" worktree add -q -b feature/volatile-other "$VOLATILE_WORKTREE" main
    expect_exit 0 "parallel acceptance task starts beside another worker" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" start --task T-009 --owner codex --branch feature/T-009 --worktree \"$PARALLEL_WORKTREE\" --write-set 'scripts/check-parallel-acceptance.sh' --accept 'scripts/check-parallel-acceptance.sh'"
    mkdir -p "$PARALLEL_WORKTREE/scripts"
    printf '#!/usr/bin/env bash\nsleep 1\n' > "$PARALLEL_WORKTREE/scripts/check-parallel-acceptance.sh"
    chmod +x "$PARALLEL_WORKTREE/scripts/check-parallel-acceptance.sh"
    git -C "$PARALLEL_WORKTREE" add scripts/check-parallel-acceptance.sh
    git -C "$PARALLEL_WORKTREE" commit -q -m "test: parallel acceptance"
    parallel_commit="$(git -C "$PARALLEL_WORKTREE" rev-parse HEAD)"
    (sleep 0.2; printf 'independent worker change\n' > "$VOLATILE_WORKTREE/independent.txt") &
    volatile_pid=$!
    expect_exit 0 "unrelated worker writes do not create a false acceptance failure" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" handoff --task T-009 --owner codex --commit '$parallel_commit'"
    wait "$volatile_pid"
    if [[ -f "$VOLATILE_WORKTREE/independent.txt" ]]; then
        pass "parallel acceptance preserved the independent worker change"
    else
        fail "parallel acceptance preserved the independent worker change"
    fi
    expect_exit 0 "parallel fixture task abort frees its isolated resources" bash -c "cd \"$TASK_REPO\" && \"$TASK_CLI\" abort --task T-009 --owner codex --reason 'parallel fixture complete'"
fi

echo "Agent platform results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi
