#!/usr/bin/env bash
# Publish exactly the prepared Vowrite release intent created by release.sh.

set -euo pipefail

die() {
    echo "publish-release: $1" >&2
    exit 2
}

TAG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag) TAG="${2:-}"; shift 2 ;;
        -h|--help)
            echo "Usage: scripts/publish-release.sh --tag vX.Y.Z.W[-beta.N]"
            exit 0
            ;;
        *) die "unknown argument '$1'" ;;
    esac
done

[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$ ]] \
    || die "--tag must be a four-segment Vowrite release tag"
command -v jq >/dev/null 2>&1 || die "jq is required"
command -v gh >/dev/null 2>&1 || die "gh is required to publish the GitHub Release"
command -v shasum >/dev/null 2>&1 || die "shasum is required to verify the release asset"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run inside the Vowrite product repository"
[[ -d "$ROOT/VowriteKit" && -d "$ROOT/VowriteMac" ]] || die "this is not the Vowrite product repository"
[[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" == "main" ]] || die "release publication requires the main integration checkout"
[[ -z "$(git status --porcelain)" ]] || die "main must be clean before release publication"

COMMON_RAW="$(git rev-parse --git-common-dir)"
if [[ "$COMMON_RAW" != /* ]]; then
    COMMON_RAW="$ROOT/$COMMON_RAW"
fi
COMMON_DIR="$(cd "$COMMON_RAW" && pwd -P)"
INTENT="$COMMON_DIR/vowrite-agent-platform/release-intent.json"
[[ -f "$INTENT" ]] || die "no prepared release intent; run ops/scripts/release.sh first"
[[ ! -L "$INTENT" ]] || die "release intent must be a regular file"

HEAD_SHA="$(git rev-parse HEAD)"
TAG_COMMIT="$(git rev-parse "$TAG^{commit}" 2>/dev/null)" || die "tag '$TAG' does not exist"
jq -e --arg tag "$TAG" --arg commit "$HEAD_SHA" \
    '.schema == 1 and (.status == "prepared" or .status == "git_published") and .tag == $tag and .commit == $commit
     and (.repository | type == "string" and length > 0)
     and (.title | type == "string" and length > 0)
     and (.notes | type == "string")
     and (.asset | type == "string" and length > 0)
     and (.asset_sha256 | test("^[0-9a-f]{64}$"))
     and (.prerelease | type == "boolean")' \
    "$INTENT" >/dev/null 2>&1 || die "release intent does not pin $TAG at current main $HEAD_SHA"
[[ "$TAG_COMMIT" == "$HEAD_SHA" ]] || die "tag '$TAG' does not point to current main"
ORIGIN_URL="$(git config --get remote.origin.url 2>/dev/null)" || die "origin remote is unavailable"

STATUS="$(jq -r '.status' "$INTENT")"
REPOSITORY="$(jq -r '.repository' "$INTENT")"
TITLE="$(jq -r '.title' "$INTENT")"
ASSET_RELATIVE="$(jq -r '.asset' "$INTENT")"
PRERELEASE="$(jq -r '.prerelease' "$INTENT")"
ASSET_SHA256="$(jq -r '.asset_sha256' "$INTENT")"
case "$ORIGIN_URL" in
    git@github.com:*) EXPECTED_REPOSITORY="${ORIGIN_URL#git@github.com:}" ;;
    ssh://git@github.com/*) EXPECTED_REPOSITORY="${ORIGIN_URL#ssh://git@github.com/}" ;;
    https://github.com/*) EXPECTED_REPOSITORY="${ORIGIN_URL#https://github.com/}" ;;
    *) die "origin must identify a GitHub repository, got: $ORIGIN_URL" ;;
esac
EXPECTED_REPOSITORY="${EXPECTED_REPOSITORY%.git}"
EXPECTED_REPOSITORY="${EXPECTED_REPOSITORY%/}"
[[ "$EXPECTED_REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] \
    || die "cannot derive owner/repository from origin: $ORIGIN_URL"
[[ "$REPOSITORY" == "$EXPECTED_REPOSITORY" ]] \
    || die "release intent repository '$REPOSITORY' does not match origin '$EXPECTED_REPOSITORY'"
[[ "$ASSET_RELATIVE" != /* && "$ASSET_RELATIVE" != ".." && "$ASSET_RELATIVE" != ../* && "$ASSET_RELATIVE" != */../* && "$ASSET_RELATIVE" != */.. ]] \
    || die "release asset must be a repository-relative path without traversal"
ASSET="$ROOT/$ASSET_RELATIVE"
[[ -f "$ASSET" && ! -L "$ASSET" ]] || die "release asset is missing or is not a regular file: $ASSET_RELATIVE"
[[ "$(shasum -a 256 "$ASSET" | awk '{print $1}')" == "$ASSET_SHA256" ]] \
    || die "release asset digest no longer matches the prepared intent"

update_intent() {
    local filter="$1"
    local timestamp_key="$2"
    local temp
    temp="$(mktemp "$COMMON_DIR/vowrite-agent-platform/.release-intent.XXXXXX")"
    jq --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg key "$timestamp_key" \
        "$filter | .[\$key] = \$timestamp" "$INTENT" > "$temp"
    chmod 600 "$temp"
    mv "$temp" "$INTENT"
}

if [[ "$STATUS" == "prepared" ]]; then
    VOWRITE_RELEASE=1 VOWRITE_RELEASE_TAG="$TAG" \
        git push --atomic origin "refs/heads/main:refs/heads/main" "refs/tags/$TAG:refs/tags/$TAG"
fi

REMOTE_MAIN="$(git ls-remote origin refs/heads/main | awk 'NR == 1 {print $1}')"
REMOTE_TAG_COMMIT="$(git ls-remote origin "refs/tags/$TAG^{}" | awk 'NR == 1 {print $1}')"
[[ "$REMOTE_MAIN" == "$HEAD_SHA" && "$REMOTE_TAG_COMMIT" == "$HEAD_SHA" ]] \
    || die "origin does not resolve both main and $TAG to the prepared commit"
if [[ "$STATUS" == "prepared" ]]; then
    update_intent '.status = "git_published" | .remote = "origin"' git_published_at
fi

NOTES_TEMP="$(mktemp "$COMMON_DIR/vowrite-agent-platform/.release-notes.XXXXXX")"
trap 'rm -f "$NOTES_TEMP"' EXIT
jq -j '.notes' "$INTENT" > "$NOTES_TEMP"

release_metadata_matches_intent() {
    local release_json="$1"
    jq -e --arg tag "$TAG" --argjson prerelease "$PRERELEASE" --arg title "$TITLE" --rawfile notes "$NOTES_TEMP" \
        '.tagName == $tag and .isPrerelease == $prerelease and .name == $title
         and (.body == $notes or .body == ($notes + "\n"))' <<<"$release_json" >/dev/null 2>&1
}

if RELEASE_JSON="$(gh release view "$TAG" --repo "$REPOSITORY" --json tagName,isPrerelease,name,body,assets 2>/dev/null)"; then
    ASSET_NAME="$(basename "$ASSET")"
    release_metadata_matches_intent "$RELEASE_JSON" \
        || die "existing GitHub Release metadata conflicts with the prepared intent"
    if ! jq -e --arg asset "$ASSET_NAME" '.assets | any(.name == $asset)' <<<"$RELEASE_JSON" >/dev/null 2>&1; then
        gh release upload "$TAG" "$ASSET" --repo "$REPOSITORY"
    fi
else
    GH_ARGS=(release create "$TAG" "$ASSET" --repo "$REPOSITORY" --title "$TITLE" --notes-file "$NOTES_TEMP" --verify-tag)
    if [[ "$PRERELEASE" == "true" ]]; then
        GH_ARGS+=(--prerelease)
    fi
    gh "${GH_ARGS[@]}"
fi

RELEASE_JSON="$(gh release view "$TAG" --repo "$REPOSITORY" --json tagName,isPrerelease,name,body,assets 2>/dev/null)" \
    || die "GitHub Release is unavailable after create/upload"
release_metadata_matches_intent "$RELEASE_JSON" \
    || die "GitHub Release metadata does not match the prepared intent after create/upload"
ASSET_NAME="$(basename "$ASSET")"
jq -e --arg asset "$ASSET_NAME" '.assets | any(.name == $asset)' <<<"$RELEASE_JSON" >/dev/null 2>&1 \
    || die "GitHub Release asset is missing after create/upload"
VERIFY_DIR="$(mktemp -d /tmp/vowrite-release-asset.XXXXXX)"
trap 'rm -f "$NOTES_TEMP"; rm -rf -- "$VERIFY_DIR"' EXIT
gh release download "$TAG" --repo "$REPOSITORY" --pattern "$ASSET_NAME" --dir "$VERIFY_DIR"
[[ -f "$VERIFY_DIR/$ASSET_NAME" ]] \
    && [[ "$(shasum -a 256 "$VERIFY_DIR/$ASSET_NAME" | awk '{print $1}')" == "$ASSET_SHA256" ]] \
    || die "GitHub Release asset does not match the prepared digest after create/upload"

update_intent '.status = "published"' published_at
echo "Release $TAG published to origin and GitHub repository $REPOSITORY"
