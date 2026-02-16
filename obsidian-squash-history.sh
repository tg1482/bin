#!/bin/bash
set -euo pipefail

# Squash entire repo history into one commit per calendar day.
# Produces a new branch (default: daily-squash) built from daily snapshots.
# This rewrites history; push to a new branch or force-push only if you understand the risk.

REPO="${REPO:-$HOME/dev/obsidian-notes}"
SOURCE_BRANCH="${SOURCE_BRANCH:-main}"
TARGET_BRANCH="${TARGET_BRANCH:-daily-squash}"
TMP_BRANCH="${TARGET_BRANCH}-tmp-$$"

cd "$REPO"

if [ -n "$(git status --porcelain)" ]; then
    echo "Working tree not clean; aborting." >&2
    exit 1
fi

# Ensure we’re up to date
git fetch origin "$SOURCE_BRANCH" >/dev/null 2>&1 || true

dates=$(git log "$SOURCE_BRANCH" --reverse --format=%ad --date=format:%Y-%m-%d | uniq)
if [ -z "$dates" ]; then
    echo "No commits found on $SOURCE_BRANCH" >&2
    exit 1
fi

# Clean any leftover temp branch
if git rev-parse --verify "$TMP_BRANCH" >/dev/null 2>&1; then
    git branch -D "$TMP_BRANCH" >/dev/null 2>&1 || true
fi

git checkout "$SOURCE_BRANCH"
git checkout --orphan "$TMP_BRANCH"

# Start from a blank tree
git rm -rf . >/dev/null 2>&1 || true
git clean -fdx >/dev/null 2>&1 || true

for day in $dates; do
    last_commit=$(git rev-list -1 --before="$day 23:59:59" "$SOURCE_BRANCH")
    if [ -z "$last_commit" ]; then
        echo "Skipping $day (no commit found)" >&2
        continue
    fi

    # Reset working tree to that day's last commit contents
    git rm -rf . >/dev/null 2>&1 || true
    git clean -fdx >/dev/null 2>&1 || true
    git checkout "$last_commit" -- .

    git add -A
    author=$(git show -s --format='%an <%ae>' "$last_commit")
    adate=$(git show -s --format='%aI' "$last_commit")
    GIT_AUTHOR_DATE="$adate" GIT_COMMITTER_DATE="$adate" git commit -m "Daily snapshot $day (from $last_commit)" --author="$author"
done

# Replace/rename tmp branch to target
git branch -M "$TMP_BRANCH" "$TARGET_BRANCH"
git checkout "$TARGET_BRANCH"

echo "Done. Inspect branch '$TARGET_BRANCH'."
echo "Push (rewriting remote) with:"
echo "  git push --force-with-lease origin $TARGET_BRANCH"

