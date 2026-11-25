# agents

Claude Code skills and subagents I use at work.

- [find-work](#find-work--work-finder-for-diagnosis-3) — Diagnosis 3 work finder
- [one-step-skaffold](#one-step-skaffold--skaffold-and-smoketest-an-lro-in-d2) — skaffold + smoketest an LRO in d2

## find-work — work finder for Diagnosis 3

Finds work I can contribute to across Jira (DIAII), epics, architecture decisions in Confluence,
team-owned code and GitHub PRs. Read-only: it drafts ticket text but never creates, edits or comments.

| Piece | Path | What it does |
|---|---|---|
| `/find-work` skill | `skills/find-work/SKILL.md` | Answers "my open tickets", "what's open", "what can I pick up", "epics", "epic DIAII-262", "DIAII-403", "find me work" |
| `work-scout` agent | `agents/work-scout.md` | Deep scan: epic scope gaps, decision follow-ups with no ticket, TODO/FIXME in owned code, PRs awaiting review, stuck tickets, cross-project mentions. Returns a ranked list |
| Config | `skills/find-work/config.yaml` | Team, people, focus services/topics, repos, decision page IDs, extra JQL. Edit this, not the skill |
| Scripts | `skills/find-work/scripts/` | `owned_paths.sh` (live CODEOWNERS), `code_signals.sh` (markers on fresh remote main, no checkout), `jira_digest.py` (condense large Jira results) |

### Requirements

- Claude Code with the ai-toolkit plugin (Skynet MCP: Jira, Confluence, carto)
- `gh` CLI signed in to GitHub
- Local clones listed under `repos:` in `config.yaml`

### Install

```bash
./install.sh   # symlinks skills/* and agents/* into ~/.claude
```

Then ask Claude "what are my open tickets?" or run `/find-work`.

### Known limits

- No Confluence search tool without `uv` (confluence-local), so decisions are listed by page ID in the config
  and discovered through Jira text search and links in epic descriptions.
- The diagnosis repo's CODEOWNERS only names `diagnostic-apps`, so D3 directories are listed by hand.

## one-step-skaffold — skaffold and smoketest an LRO in d2

`/one-step-skaffold <service> [more...] [-a alias] [-w worker]` wraps
[one-step-skaffold.sh](https://github.com/ds-nikhilma/one-step-skaffold). The skill checks the
prerequisites (Docker, gcloud, CLIs), runs the script in the background, then diagnoses failures from
the logs (expired login, worker choice, stale codegen, build and rollout errors, timeouts, leftovers).
With several services it runs them one after another and ends with a pass/fail table. The script does
all the orchestration and teardown; the skill never repeats those steps by hand.

| Piece | Path |
|---|---|
| `/one-step-skaffold` skill | `skills/one-step-skaffold/SKILL.md` |

Requires a clone of one-step-skaffold at `~/Desktop/projects/one-step-skaffold`, a lightning-core
checkout, and `dscore`, `skaffold`, `kubectl` and Docker.
