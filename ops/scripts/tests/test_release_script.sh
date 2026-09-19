#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RELEASE_SCRIPT="$SOURCE_ROOT/ops/scripts/release.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

fixture="$(mktemp -d "${TMPDIR:-/tmp}/vowrite-release-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

git -C "$fixture" init -q
git -C "$fixture" config user.name "Release test"
git -C "$fixture" config user.email "release-test@example.invalid"

transaction_files=(
    "CHANGELOG.md"
    "VowriteMac/Resources/Info.plist"
    "VowriteMac/Vowrite.app/Contents/Info.plist"
    "VowriteKit/Sources/VowriteKit/Version.swift"
    "docs/appcast.xml"
    "docs/appcast-beta.xml"
)
for file in "${transaction_files[@]}"; do
    mkdir -p "$(dirname "$fixture/$file")"
    printf 'original %s\n' "$file" > "$fixture/$file"
done
git -C "$fixture" add "${transaction_files[@]}"
git -C "$fixture" commit -qm "initial stable"
git -C "$fixture" tag v0.2.2.0
printf 'beta\n' >> "$fixture/CHANGELOG.md"
git -C "$fixture" commit -am "beta candidate" -q
git -C "$fixture" tag v0.2.3.0-beta.1

# Load only pure helper functions. Test mode returns before the release script
# installs its ERR trap, parses arguments, fetches, signs, or changes a tree.
trap - ERR
VOWRITE_RELEASE_TEST_MODE=1 VOWRITE_RELEASE_PROJECT_ROOT="$fixture" source "$RELEASE_SCRIPT"
[[ -z "$(trap -p ERR)" ]] || fail "test-mode source installed an ERR trap"

[[ "$(last_stable_tag "$fixture")" == "v0.2.2.0" ]] \
    || fail "stable preflight selected a beta tag"
[[ -z "$(git -C "$fixture" log --format=%H v0.2.3.0-beta.1..HEAD)" ]] \
    || fail "fixture must have zero commits since its beta tag"
[[ -n "$(git -C "$fixture" log --format=%H "$(last_stable_tag "$fixture")"..HEAD)" ]] \
    || fail "stable comparison must include the beta commit"

release_transaction_paths | grep -Fx "$BUNDLED_INFO_PLIST" >/dev/null \
    || fail "tracked bundled Info.plist is absent from transactional rollback paths"

for file in "${transaction_files[@]}"; do
    printf 'mutated %s\n' "$file" > "$fixture/$file"
done
git -C "$fixture" add "${transaction_files[@]}"
rollback_mutated_files
git -C "$fixture" diff --quiet -- "${transaction_files[@]}" \
    || fail "rollback left unstaged release metadata"
git -C "$fixture" diff --cached --quiet -- "${transaction_files[@]}" \
    || fail "rollback left staged release metadata"

echo "PASS: stable preflight ignores a zero-commit beta tag; source and bundled plists roll back"
