#!/usr/bin/env bash
# Sync fork with upstream:
#   - master mirrors upstream/master
#   - stable/{tag} is created for the latest v8+ release tag (if missing)
#
# Usage:
#   ./scripts/sync-fork.sh
#   ./scripts/sync-fork.sh --dry-run

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

run() {
  if $DRY_RUN; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

cd "$(git rev-parse --show-toplevel)"

if ! git remote get-url upstream &>/dev/null; then
  echo "Error: 'upstream' remote not found." >&2
  echo "Add it with: git remote add upstream git@github.com:openedx/frontend-platform.git" >&2
  exit 1
fi

echo "Fetching from origin and upstream..."
run git fetch --all

echo ""
echo "Syncing master with upstream/master..."
run git checkout master
run git merge upstream/master

if $DRY_RUN; then
  echo "[dry-run] git push origin master"
else
  git push origin master
fi

# Latest semver tag v8 and above (v8.x, v9.x, v10.x, ...)
LATEST_TAG="$(git tag --sort=-v:refname | grep -E '^v(8|[1-9][0-9]+)\.' | head -1 || true)"

if [[ -z "${LATEST_TAG}" ]]; then
  echo ""
  echo "No v8+ tags found locally. Fetch tags with: git fetch upstream" >&2
  exit 1
fi

STABLE_BRANCH="stable/${LATEST_TAG}"

echo ""
if git show-ref --verify --quiet "refs/heads/${STABLE_BRANCH}"; then
  echo "Stable branch ${STABLE_BRANCH} already exists — skipping"
else
  echo "Creating ${STABLE_BRANCH} at tag ${LATEST_TAG}..."
  run git branch "${STABLE_BRANCH}" "${LATEST_TAG}"
  if $DRY_RUN; then
    echo "[dry-run] git push -u origin ${STABLE_BRANCH}"
  else
    git push -u origin "${STABLE_BRANCH}"
  fi
fi

echo ""
echo "Done."
echo "  master        → mirrors upstream/master"
echo "  ${STABLE_BRANCH} → pinned at ${LATEST_TAG}"
