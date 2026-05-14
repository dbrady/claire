Clarity project tracking helper tool thinglet

## What it does

claire resolves JIRA tickets, GitHub PRs, and Clarity project codes to the right Clarity project, then logs billable time to a local JSONL file. At the end of the week you run `claire report` to get a grid showing hours per project per day, transcribe those numbers into Clarity, and go home.

## Installation

```
git clone <repo>
cd claire
bundle install
bin/claire init   # one-time credential bootstrap
```

`claire init` will prompt for your JIRA credentials and GitHub token, then write them to `~/.claire.yml`.

## Subcommands

| Command | Description |
|---|---|
| `claire check <thing>` | Resolve a ticket/PR to its Clarity project code |
| `claire log <thing> <duration> [--on YYYY-MM-DD] [--note "..."]` | Log billable time |
| `claire report [last] [--week YYYY-MM-DD]` | Show hours grid for the week |
| `claire edit` | Open the JSONL log in your editor |
| `claire init` | First-time credential setup |

`<thing>` accepts a JIRA ticket key (`MP-820`), a bare GitHub PR number (`17343`), a full GitHub PR or JIRA URL, or a raw Clarity project code (`PR00151`).

`<duration>` accepts: `15` (15 minutes), `1:30` (1h30m), `1.5` (1.5 hours), `90m`, `2h`.

## Claude Code skill

There is a model-invoked Claude Code skill in `skills/claire/`. Copy it to your skills directory so Claude will automatically shell out to claire when you mention reviewing a PR, logging time, or asking for a report:

```
cp -r skills/claire ~/.claude/skills/
```

After copying the skill, Claude will recognize intents like:
- "I'm reviewing PR 17343" → runs `claire check 17343`
- "log MP-820 30m" → runs `claire log MP-820 30`
- "show me my hours this week" → runs `claire report`
- "edit my log" → runs `claire edit`
