#!/usr/bin/env bash
# Symlink this repo's skills and agents into ~/.claude so Claude Code picks them up.
# Existing non-symlink copies are moved aside to <name>.bak first.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.claude/skills ~/.claude/agents
link() { # link <src> <dest>
  if [ -e "$2" ] && [ ! -L "$2" ]; then mv "$2" "$2.bak"; echo "moved existing $2 -> $2.bak"; fi
  ln -sfn "$1" "$2"; echo "linked $2 -> $1"
}
for s in "$here"/skills/*/; do link "${s%/}" ~/.claude/skills/"$(basename "$s")"; done
for a in "$here"/agents/*.md; do link "$a" ~/.claude/agents/"$(basename "$a")"; done
