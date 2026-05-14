---
name: claire
description: Use when the user mentions reviewing a coworker's PR, logging billable time/hours, checking approval for a JIRA ticket or project code, asking about hours spent on a project, or wants a weekly hours report. Recognizes inputs like JIRA URLs (upbd.atlassian.net), GitHub PR URLs, bare PR numbers, JIRA ticket keys (MP-820, COR-1, UPP-100), or Clarity project codes (PR00151).
---

# claire — Clarity time tracker

claire is a CLI tool that resolves JIRA tickets, GitHub PRs, or project codes to Clarity project codes (via JIRA's parent-walk on customfield_10762) and logs billable time to a local JSONL file.

## When to invoke

Shell out to the `claire` CLI when the user expresses one of these intents:

| Intent | Command |
|---|---|
| "I'm reviewing <PR-or-ticket>" / "check <thing>" / "what project is X?" | `claire check <thing>` |
| "log <thing> <duration>" / "I worked N hours on X" | `claire log <thing> <duration> [--on YYYY-MM-DD] [--note "..."]` |
| "show me my hours" / "report" / "this week" / "last week" | `claire report` or `claire report last` or `claire report --week YYYY-MM-DD` |
| "edit my log" / "fix a typo in my time log" | `claire edit` |

`<thing>` can be a JIRA ticket key (`MP-820`), a bare GitHub PR number (`17343`), a full GitHub PR URL, a full JIRA URL (`https://upbd.atlassian.net/browse/MP-820`), or a raw Clarity project code (`PR00151`).

`<duration>` accepts: `15` (15 minutes), `1:30` (1h30m), `1.5` (1.5 hours), `90m`, `2h`.

## Output behavior

- **Print claire's stdout verbatim** to the user. Do NOT summarize the report table — the fixed-width format matters.
- **Surface claire's stderr verbatim** when it exits nonzero. The user needs to see the actual error to decide what to do (rerun with `--refresh`, run `claire init`, fix the JSONL with `claire edit`, etc.).
- If `claire init` is required (first-time setup), tell the user to run it themselves — don't automate the credential bootstrap.

## Common scenarios

- **Coworker pings you with a PR URL to review:**
  → `claire check <PR-URL>` to surface the project code and Clarity URL.

- **Logging review time at end of day:**
  → `claire log <PR-URL-or-MP-ticket> 30` (or whatever duration).

- **Filling out Clarity timecard on Friday:**
  → `claire report` to see this week's grid. Read the cells, transcribe into Clarity.
