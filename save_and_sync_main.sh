# save_and_sync_main.sh
#!/usr/bin/env bash
set -euo pipefail

# Usage: ./save_and_sync_main.sh "Commit message"
MSG="${1:-Save work before flutter upgrade}"

# Ensure we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not inside a git repository." >&2
  exit 1
fi

# Ensure remote main exists
git remote show origin >/dev/null 2>&1 || { echo "Error: no remote 'origin' configured." >&2; exit 1; }

# Stage all changes
git add -A

# Commit only if there are staged changes
if ! git diff --cached --quiet; then
  git commit -m "$MSG"
else
  echo "No changes to commit."
fi

# Ensure local main is checked out
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "Switching to main branch (current: $CURRENT_BRANCH)"
  git checkout main
fi

# Fetch and rebase to make local main match remote main
git fetch origin main

# Rebase local commits on top of remote main; abort on conflict
git rebase --rebase-merges origin/main

# Push local main to remote
git push origin main

echo "Local and remote main are synchronized."
