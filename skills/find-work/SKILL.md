---
name: find-work
description: >
  Find work for me in my team (Diagnosis 3 / Jira DIAII): my open tickets, unassigned tickets I can
  pick up, blocked or stale work, open epics and their gaps, a single ticket's details, and a deep
  scan for "possible tickets" across epics, architecture decisions (Confluence ADs), code TODOs and
  PR review requests. Use when I ask "what are my open tickets", "what can I pick up", "find me work",
  "what's open in DIAII", "show epic X", "what's DIAII-123", "where can I contribute", or /find-work.
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - Agent
  - mcp__plugin_ai-toolkit_skynet__jira_search_issues
  - mcp__plugin_ai-toolkit_skynet__jira_get_issue
  - mcp__plugin_ai-toolkit_skynet__jira_get_issue_comments
  - mcp__plugin_ai-toolkit_skynet__jira_get_epic_issues
---

# Find work (Diagnosis 3)

Read-only work finder. Team facts live in `config.yaml` next to this file — read it first.
**Never create, edit, transition, assign or comment on anything.** When a new ticket would help,
draft its text in the answer and ask whether to create it.

## 1. Pick the mode from the request (or `args`)

| Request looks like | Mode |
|---|---|
| "my tickets", "what am I on", no args | `mine` + a short `pickup` teaser |
| "open tickets", "what's open", "team board" | `open` |
| "what can I pick up", "unassigned", "where can I help" | `pickup` |
| "epics", "epic DIAII-262" | `epics` (all) or `epic <KEY>` |
| a ticket key like `DIAII-403` | `ticket <KEY>` |
| "find me work", "possible tickets", "scout", "where can I contribute", "deep" | `scout` |
| anything else about tickets | translate to JQL scoped to `project = DIAII` and answer |

## 2. Queries (all `jira_search_issues`, `output: json`)

Keep `page_size` ≤ 25 for any query that returns descriptions. If the harness saves an oversized
result to a file, condense it with
`python3 -I ~/.claude/skills/find-work/scripts/jira_digest.py <file> --links` instead of reading it raw.
Fetch the next page with `page_token` only when the user wants everything.

- **mine**: `project = DIAII AND assignee = currentUser() AND statusCategory != Done ORDER BY status, updated DESC`
- **open**: `project = DIAII AND statusCategory != Done AND issuetype != Epic ORDER BY status, updated DESC`
- **pickup** (run all three):
  - unassigned: `project = DIAII AND assignee is EMPTY AND statusCategory != Done AND issuetype not in (Epic, Sub-task) ORDER BY priority DESC, created DESC`
  - stale in-progress (offer help): `project = DIAII AND statusCategory = "In Progress" AND assignee != currentUser() AND updated <= -10d ORDER BY updated ASC`
  - blocked: `project = DIAII AND status = Blocked ORDER BY updated ASC`
  - plus each `extra_jql` entry in config.yaml
- **epics**: `project = DIAII AND issuetype = Epic AND statusCategory != Done ORDER BY updated DESC`,
  then for each epic `jira_get_epic_issues(epic_key, exclude_resolved=false)` to count open/done children.
- **epic <KEY>**: `jira_get_issue(KEY)` + `jira_get_epic_issues(KEY, exclude_resolved=false)`. Compare each
  bullet in the epic's *Scope* section with the children; a bullet with no matching child is a **gap**
  (a possible ticket). Say which children are unassigned.
- **ticket <KEY>**: `jira_get_issue(KEY)` + `jira_get_issue_comments(KEY)`. Summarise: what it asks,
  status/assignee, linked issues, latest comment, and the concrete next step. If it touches a service
  under `my_focus`, say so.

## 3. Ranking "good fit for me"

Mark an item **★ fit** when its summary/description mentions a `my_focus.services` or `my_focus.topics`
entry, or it is in an epic I already have tickets in. Order pickup candidates: ★ fit first, then
priority, then age. Give a one-line reason for every ★.

## 4. Scout mode

Delegate to the `work-scout` agent (Agent tool, `subagent_type: work-scout`) so raw scans stay out of
this conversation. Pass the config path and any focus the user gave ("only PCP", "only ADRs"). Relay its
ranked list; do not re-run its scans yourself.

## 5. Output format

Plain language, no unexplained jargon. Group by bucket, omit empty buckets.

```markdown
## Mine (3)
- 🔄 **[DIAII-403](link)** — tooth-recognition client: server-side WaitOperation timeout · In Progress · draft PR lc#11686
- ⏳ **[DIAII-407](link)** — postgres-lro: fail fast when result blob is missing · Open

## Can pick up (2)
- ★ **[DIAII-358](link)** — di-segmentation-lro smoketest: request models by axis ID · unassigned · *fit: di-segmentation-lro is ours*

## Possible tickets (from epic gaps)
- **DIAII-262 › "Passport authentication"** — no child ticket yet. Draft: "PCP: accept and mint passport…"
```

Status emoji: ✅ done · 🔄 in progress/review/QA · ⛔ blocked · ⏳ to do. Always link keys.
End with one line: the single thing I should look at next and why.
