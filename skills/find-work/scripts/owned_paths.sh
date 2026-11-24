#!/usr/bin/env bash
# Print paths a GitHub team owns in a repo's CODEOWNERS (live from GitHub, not the local clone).
# Usage: owned_paths.sh DS-DP-S/lightning-core [@DS-DP-S/diagnosis-3]
# Output: "<path> SOLE|shared"; team-wide infra dirs are skipped.
set -euo pipefail
repo="${1:?repo like DS-DP-S/lightning-core}"
team="${2:-@DS-DP-S/diagnosis-3}"
for f in CODEOWNERS .github/CODEOWNERS; do
  if out=$(gh api "repos/$repo/contents/$f" -H 'Accept: application/vnd.github.raw' 2>/dev/null); then
    printf '%s\n' "$out" | grep -v '^#' | grep -F -- "$team" \
      | grep -vE 'infrastructure/|common_diagnosis' \
      | awk -v t="$team" '{print $1, (NF==2 && $2==t) ? "SOLE" : "shared"}'
    exit 0
  fi
done
echo "no CODEOWNERS found in $repo" >&2
exit 1
