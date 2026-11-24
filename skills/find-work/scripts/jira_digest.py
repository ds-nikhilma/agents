#!/usr/bin/env python3
"""Condense a Skynet jira_search_issues result into one line per issue (drops descriptions).

Use when the search result was too large and the harness saved it to a file.
Usage: python3 -I jira_digest.py <saved-tool-result-file> [--links]
Accepts both output modes: json ({"result": "{\"issues\": [...]}"}) and markdown blocks.
"""
import json, re, sys

def load(path):
    raw = open(path).read()
    try:
        raw = json.loads(raw).get("result", raw)
    except (ValueError, AttributeError):
        pass
    try:
        data = json.loads(raw)
        return [
            {
                "key": i.get("key"), "type": i.get("issuetype"), "status": i.get("status"),
                "assignee": i.get("assignee") or "-", "summary": i.get("summary") or "",
                "epic": i.get("epickey") or i.get("needkey") or "", "sp": i.get("storypoints"),
                "updated": i.get("updated") or "", "link": i.get("link") or "",
            }
            for i in data.get("issues", [])
        ], data.get("next_page_token")
    except (ValueError, AttributeError):
        rows = []
        for b in raw.split("\n---\n"):
            g = lambda k: (re.search(rf"^{k}: (.*)$", b, re.M) or [None, ""])[1]
            if g("Key"):
                rows.append({"key": g("Key"), "type": g("Type"), "status": g("Status"),
                             "assignee": g("Assignee") or "-", "summary": g("Summary"),
                             "epic": "", "sp": None, "updated": "", "link": g("Link")})
        return rows, None

def main():
    rows, token = load(sys.argv[1])
    links = "--links" in sys.argv
    for r in rows:
        sp = f" {r['sp']:g}SP" if isinstance(r["sp"], (int, float)) else ""
        epic = f" [{r['epic']}]" if r["epic"] else ""
        line = f"{r['key']} | {r['type']} | {r['status']} | {r['assignee']} | {r['summary'][:110]}{epic}{sp}"
        print(line + (f" | {r['link']}" if links else ""))
    print(f"# {len(rows)} issues" + (" — more pages exist (next_page_token)" if token else ""))

if __name__ == "__main__":
    main()
