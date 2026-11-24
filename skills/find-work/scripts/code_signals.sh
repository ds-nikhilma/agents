#!/usr/bin/env bash
# Find TODO/FIXME/HACK/XXX markers in given paths of a repo's fresh remote main.
# Fetches <remote>/<branch> and greps that tree; never checks out or touches the working tree.
# Usage: code_signals.sh <repo-path> <remote> <branch> <path> [<path>...]
# Output: "<path>:<line>: <text>" (max 40 hits per path), plus a "# ref" header line.
set -euo pipefail
repo="${1/#\~/$HOME}"; remote="$2"; branch="$3"; shift 3
git -C "$repo" fetch --quiet "$remote" "$branch" 2>/dev/null || echo "# warn: fetch failed, using cached $remote/$branch" >&2
ref="$remote/$branch"
echo "# ref $(git -C "$repo" log -1 --format='%h %cr' "$ref")"
for p in "$@"; do
  p="${p#/}"
  # Match markers only inside comments (macOS git grep has no \b; also skips context.TODO()).
  git -C "$repo" grep -n -I -E '(//|#|/\*|\*) *(TODO|FIXME|HACK|XXX)' "$ref" -- "$p" \
    ':!*.pb.go' ':!*_pb2*.py' ':!*.pb.dart' ':!**/vendor/**' ':!**/generated/**' 2>/dev/null \
    | sed "s|^$ref:||" | head -40 || true
done
