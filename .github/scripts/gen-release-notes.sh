#!/usr/bin/env bash
# Print the release notes for a tag: the tag message body, GitHub's
# "What's Changed" PR list as "- summary (#nn by @author)", and the
# full commit list collapsed (direct pushes never appear as PRs).
# Usage: gen-release-notes.sh <tag> [owner/repo]
set -euo pipefail

TAG=$1
REPO=${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}
# --exclude, so the previous tag is found even when the tag is on a merge
PREV=$(git describe --tags --abbrev=0 --match='v*' --exclude="$TAG" "$TAG" 2>/dev/null || true)

BODY=$(git tag -l --format='%(contents:body)' "$TAG")
test -z "$BODY" || printf '%s\n\n' "$BODY"

gh api "repos/$REPO/releases/generate-notes" -f tag_name="$TAG" \
    ${PREV:+-f previous_tag_name="$PREV"} -q .body \
  | sed -E 's|^\* (.*) by @([A-Za-z0-9-]+) in https://[^ ]+/pull/([0-9]+)\r?$|- \1 (#\3 by @\2)|'

printf '\n<details><summary>All commits</summary>\n\n'
git log --pretty=format:'- %h: %s' ${PREV:+$PREV..}$TAG
printf '\n\n</details>\n'
