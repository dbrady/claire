# claire

A CLI for keeping track of the time you actually worked, so you can fill in
your Clarity timesheet on Friday afternoon without crying.

claire takes the messy reality of your week — coworker pings you with a GitHub
PR to review, you spend 45 minutes on it, an hour later you switch to your own
JIRA ticket, on Friday you can't remember which review took 30 minutes and
which took 90 — and turns it into a clean Sunday-to-Saturday grid of hours per
Clarity project code, ready to transcribe.

The whole point: minimum friction between "I worked on this thing" and "this
hour is logged against the right project." If logging time costs more than 5
seconds, you don't do it, and you guess on Friday.

## How it works (in 30 seconds)

When you tell claire `log MP-820 30`, it:

1. Reads the JIRA ticket `MP-820`.
2. Walks up its parent chain (sub-task → story → epic) looking for the
   "Project Code" custom field — Clarity-managed values like `PR00151`.
3. Appends a single JSONL row to `~/.local/share/claire/entries.jsonl` recording
   the minutes, the date, the ticket, and the project code.

When you run `claire report`, it reads that JSONL file and shows you the
week's hours per project code. You read the cells off the screen and into
Clarity. Done.

PR numbers and GitHub URLs work too — claire shells out to `gh pr view`,
scrapes the PR description for a JIRA key, then walks the chain. Raw Clarity
project codes (`PR00151`) skip the JIRA round trip entirely.

## Installation

You'll need Ruby 3.1+ (3.3+ for sortable UUIDs in the log; older Ruby falls
back to v4 UUIDs and still works), the `gh` CLI authenticated to your work
GitHub org, and an Atlassian API token.

```sh
git clone git@github.com:dbrady/claire.git
cd claire
bundle install
ln -s $(pwd)/bin/claire ~/bin/claire     # or wherever's on your PATH
claire init
```

`claire init` reads your Atlassian credentials from `~/.claude/.mcp.json` (the
config file used by the `atlassian-confluence` MCP server), writes them to
`~/.config/claire/config.yml`, and pings JIRA's `/myself` endpoint to confirm
they work:

```
$ claire init
Wrote /Users/you/.config/claire/config.yml
Authenticated as: Your Name
```

If you don't already have the Atlassian MCP server set up, drop your site
name, email, and API token into `~/.config/claire/config.yml` by hand — the
file is plain YAML, takes about 30 seconds.

## The work loop

It's Thursday afternoon. A coworker DMs you a PR to review:

> Hey, can you take a look at https://github.com/acima-credit/merchant_portal/pull/17343

Check what bucket the time goes in before you start:

```
$ claire check 17343
MP-796 -> MP-445 -> project code: PR00151
PR URL: https://github.com/acima-credit/merchant_portal/pull/17343
Clarity: https://cppm10270.clarityppm.saas.broadcom.com/pm/#/projects/common
        !! manual mode: confirm you're approved for PR00151 before logging time.
```

The arrow chain shows the JIRA walk: PR 17343 mentions ticket MP-796, MP-796's
parent epic MP-445 has the Project Code `PR00151`. (When Clarity's API key
arrives, that "manual mode" line becomes an automated green-check / red-stop.)

You review the PR. 30 minutes. Log it:

```
$ claire log 17343 30
logged 30m to PR00151 (MP-796) on 2026-05-14
```

A couple hours later you switch to your own ticket and grind on it for 90
minutes:

```
$ claire log MP-820 1:30
logged 90m to PR00151 (MP-820) on 2026-05-14
```

Or `1.5` or `90m` — claire understands all three.

Heading out for the day, you realize you forgot to log the spike you did on
Monday:

```
$ claire log COR-1234 45 --on mon --note "investigating webhook retries"
logged 45m to PR00188 (COR-1234) on 2026-05-11
```

`--on` accepts `today` (the default), `yesterday`, weekday names (most recent
occurrence — never future), ISO dates (`2026-05-11`), and US `M/D` (`5/11`).
Notes are optional but they're how future-you survives Friday.

Friday afternoon, time to fill in the Clarity timecard:

```
$ claire report
+---------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+--------+
|         | Sun 05/10 | Mon 05/11 | Tue 05/12 | Wed 05/13 | Thu 05/14 | Fri 05/15 | Sat 05/16 | TOTAL  |
+---------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+--------+
| PR00151 |         0 |         0 |         0 |         0 |         2 |         0 |         0 |      2 |
| PR00188 |         0 |      0.75 |         0 |         0 |         0 |         0 |         0 |   0.75 |
+---------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+--------+
| TOTAL   |         0 |      0.75 |         0 |         0 |         2 |         0 |         0 |   2.75 |
+---------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+--------+
```

Decimal hours, Sun–Sat. The 30-minute PR review and the 90-minute ticket work
collapsed into 2 hours on Thursday under `PR00151` (same project code, same
day). Transcribe the numbers into Clarity, submit, go home.

If you typo'd something, `claire edit` opens `$EDITOR` (or emacs) on the JSONL
file. Fix the row, save, done — no claire-managed edit UI, no audit-log
ceremony. It's a personal log on your laptop.

## Reference

### Commands

| Command | What it does |
|---|---|
| `claire init` | One-time setup; reads MCP config, writes claire config, pings JIRA |
| `claire check <thing>` | Resolves `<thing>` to a Clarity project code; no time logged |
| `claire log <thing> <duration> [--on DATE] [--note "..."]` | Appends a row to the JSONL log |
| `claire report` | This Sun–Sat week |
| `claire report last` | Previous Sun–Sat week |
| `claire report --week YYYY-MM-DD` | Sun–Sat week containing that date |
| `claire report --start S --end E` | Arbitrary range (max 14 days) |
| `claire edit` | Open the JSONL log in `$EDITOR` |

### `<thing>` formats

| Pattern | Treated as | Example |
|---|---|---|
| `[A-Z]+-\d+` | JIRA ticket | `MP-820`, `COR-1`, `UPP-1291` |
| Bare digits | GitHub PR number (in cwd's repo) | `17343` |
| `https://github.com/...` | GitHub PR URL | full PR URL |
| `https://*.atlassian.net/...` | JIRA URL | `https://upbd.atlassian.net/browse/MP-820` |
| Anything else | Raw Clarity project code | `PR00151` |

### `<duration>` formats

- `15` → 15 minutes (bare integer = minutes)
- `1:30` → 1 hour 30 minutes
- `1.5` → 1.5 hours (90 minutes)
- `90m` → 90 minutes (explicit minutes suffix)
- `2h` → 2 hours (explicit hours suffix)
- `0.25` → 0.25 hours (15 minutes)

Internally stored as integer minutes; the report shows decimal hours.

### `--on DATE` formats

- `today` (the default)
- `yesterday`
- `mon`, `tue`, ..., `sun` (most recent occurrence, never future)
- `2026-05-12` (ISO)
- `5/12` (US month/day, current year)

`12-05` is rejected as ambiguous. Use the ISO form if you're not sure.

### Useful flags

- `claire check --refresh <thing>` / `claire log --refresh <thing> ...` —
  bypass the resolution cache and re-resolve from JIRA / GitHub. The cache
  lives at `~/.local/share/claire/resolutions.yml`; the nuclear refresh is to
  `rm` it.

## Files

claire follows the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/).
Credentials stay in the config directory; the time log and resolver cache
live in the data directory.

| Path | Purpose |
|---|---|
| `~/.config/claire/config.yml` | Atlassian credentials, plus `data_dir` pointer |
| `~/.local/share/claire/entries.jsonl` | Append-only time log; one JSON row per entry |
| `~/.local/share/claire/resolutions.yml` | Resolution cache; safe to `rm` anytime |

Override the config directory with `$XDG_CONFIG_HOME` and the data
directory with `$XDG_DATA_HOME`. The `data_dir` key in `config.yml` (written
by `claire init`) takes priority over the env var.

### Migration from the pre-S13 layout

If you ran an older version of claire, your data files are in
`~/.config/claire/`. Running `claire init` on a fresh install detects this
and moves them automatically:

```
$ claire init
Migrating data files from legacy location:
  ~/.config/claire/entries.jsonl    -> ~/.local/share/claire/entries.jsonl
  ~/.config/claire/resolutions.yml  -> ~/.local/share/claire/resolutions.yml
Wrote ~/.config/claire/config.yml
Authenticated as: David Brady
```

If you have already initialized (config.yml exists), claire will refuse to
run `claire init` again. In that case, move the files by hand:

```sh
mkdir -p ~/.local/share/claire
mv ~/.config/claire/entries.jsonl ~/.local/share/claire/
mv ~/.config/claire/resolutions.yml ~/.local/share/claire/
```

Then add `data_dir: /Users/you/.local/share/claire` to `~/.config/claire/config.yml`.

## Claude Code skill

A model-invoked Claude Code skill ships in `skills/claire/`. Copy it into your
skills directory:

```sh
cp -r skills/claire ~/.claude/skills/
```

After that, Claude will recognize time-tracking intents and shell out to
claire automatically:

- "I'm reviewing PR 17343" → `claire check 17343`
- "log MP-820 30m" → `claire log MP-820 30`
- "show me my hours" → `claire report`
- "edit my log" → `claire edit`

You don't have to use the skill — claire is just a normal CLI. The skill is
there so that when a coworker pastes a PR link into your Claude session, you
get the resolution and logging without retyping anything.

## Status

This is a personal-productivity tool. It runs entirely on your laptop, writes
only to `~/.config/claire/` and `~/.local/share/claire/`, and has no
production dependencies beyond your JIRA and GitHub credentials.

The Clarity integration is currently manual: `claire check` prints the
project's Clarity URL with a reminder to confirm approval before logging
time. When Clarity's API key lands, that becomes a real green-check /
red-stop and the workflow stops being one-half-trust.

## Why "claire"?

It's Clarity, but more personal, and it doesn't make you log into a Java app
to enter your hours.
