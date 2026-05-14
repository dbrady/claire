# PRD: claire — Clarity Time Tracker CLI

## Problem Statement

I am a W-2 software engineer at Acima. I am required to enter my billable
hours into Clarity (an enterprise PPM tool from Broadcom) every Friday on
a timecard that runs Sunday–Saturday. The hours must be logged against
Clarity **project codes** (opaque strings like `PR00151`), not against
the JIRA tickets or GitHub PRs I actually work on.

To find the right project code for a given task today, I have to:

1. Open the JIRA ticket I worked on.
2. Walk up its parent chain (sub-task → story → epic) looking for a
   custom field called "Project Code" that may or may not be populated.
3. Open Clarity and confirm I'm approved to log time against that code.
4. Hand-enter the hours.

This is annoying when I'm doing my own tickets and worse when a coworker
hands me a GitHub PR to review — I have to scrape the PR description for
the JIRA link, then start the chain above. By Friday I've forgotten which
review took 30 minutes and which took 90.

Clarity's API key is not yet available to engineering. JIRA's REST API
and the GitHub `gh` CLI are both available right now.

## Solution

A standalone Ruby CLI named `claire` that lives outside the
merchant-portal Rails app. It accepts JIRA tickets (`MP-820`), GitHub PR
numbers (`17343`), full GitHub PR URLs, or raw project codes
(`PR00151`) as input. It resolves any of those to a Clarity project
code via JIRA's REST API and the `gh` CLI, then either prints the
resolution (`claire check`) or records a billable-time entry to a local
append-only JSONL log (`claire log`). A `claire report` command renders
the week's hours by project code as a Sun–Sat table, ready to be
hand-entered into Clarity each Friday.

The same CLI is invokable from a Claude skill, so when a coworker pings
me with a PR URL, I can paste the URL into Claude and the skill will
shell out to `claire` to surface the project code and log the time.

When Clarity's API key arrives, the `claire check` and `claire log`
commands will gain a real automated approval check; until then,
approval checking is an informational print of the Clarity project URL.

## User Stories

1. As a Merchant Portal engineer, I want to run `claire check MP-820`
   and see the resolved Clarity project code, so that I know which
   bucket to log my time against.

2. As a Merchant Portal engineer, I want to run `claire check 17343` on
   a coworker's GitHub PR number, so that I can find the project code
   without manually opening the PR and clicking through to JIRA.

3. As a Merchant Portal engineer, I want to run
   `claire check https://github.com/acima-credit/merchant_portal/pull/17343`,
   so that I can paste a full URL from Slack without trimming it.

4. As a Merchant Portal engineer, I want to run
   `claire check https://upbd.atlassian.net/browse/MP-820`, so that I
   can paste a JIRA URL directly.

5. As a Merchant Portal engineer, I want `claire check PR00151` to
   short-circuit JIRA lookups and just confirm the project code is
   valid input, so that I can verify a code I was given verbally.

6. As a Merchant Portal engineer, I want `claire log MP-820 15` to
   record 15 minutes against the resolved project code for today,
   so that I have a one-liner for the most common case.

7. As a Merchant Portal engineer, I want `claire log MP-820 1:30` to
   record an hour and a half, so that the H:MM format I think in works.

8. As a Merchant Portal engineer, I want `claire log MP-820 1.5` to
   record 1.5 hours, so that the decimal format Clarity expects also
   works as input.

9. As a Merchant Portal engineer, I want `claire log MP-820 90m` and
   `claire log MP-820 2h`, so that I can be explicit when the bare
   number is ambiguous.

10. As a Merchant Portal engineer, I want `claire log MP-820 30 --on
    2026-05-12`, so that I can log time for a past day when I forgot.

11. As a Merchant Portal engineer, I want `claire log MP-820 30 --on
    yesterday` and `--on mon`, so that I don't have to compute dates by
    hand.

12. As a Merchant Portal engineer, I want
    `claire log MP-820 30 --note "review of MP-796"`, so that next
    Friday I can remember what 30 minutes on Tuesday was for.

13. As a Merchant Portal engineer, I want
    `claire log PR00151 30` to record time against a raw project code
    without hitting JIRA, so that I can still log time when JIRA is
    down or when finance hands me a code without a ticket.

14. As a Merchant Portal engineer, I want
    `claire log 17343 30` (PR number) to resolve through JIRA to the
    project code and record the entry, so that I can log time on a
    review using the same input I used to `check`.

15. As a Merchant Portal engineer, I want `claire log <ticket>` to fail
    loudly when the ticket can't be resolved to a project code, so that
    I never silently log time to nowhere.

16. As a Merchant Portal engineer, I want `claire log <nonexistent>` to
    fail loudly with a clear "no such ticket" message, so that I notice
    typos immediately.

17. As a Merchant Portal engineer, I want `claire report` to show the
    current Sunday–Saturday week as a 7-column grid of decimal hours
    per project code, so that I can transcribe the values into
    Clarity's weekly timecard on Friday afternoon.

18. As a Merchant Portal engineer, I want a TOTAL column on the right
    and a TOTAL row at the bottom of `claire report`, so that I can
    verify my week sums to roughly 40 hours.

19. As a Merchant Portal engineer, I want `claire report last`, so
    that I can review the previous week's hours.

20. As a Merchant Portal engineer, I want
    `claire report --week 2026-05-04`, so that I can look at a
    specific week.

21. As a Merchant Portal engineer, I want
    `claire report --start 2026-05-04 --end 2026-05-15`, so that I
    can look at an arbitrary range when needed.

22. As a Merchant Portal engineer, I want `claire edit` to launch
    `$EDITOR` (or `emacs` if `$EDITOR` is unset) on the JSONL log, so
    that I can fix a typo without claire growing an editing UI.

23. As a first-time user of claire, I want `claire init` to read my
    Atlassian credentials from `~/.claude/.mcp.json` and write
    `~/.config/claire/config.yml`, so that I don't have to find the
    token and re-type it.

24. As a first-time user of claire, I want `claire init` to ping JIRA
    once with my token and tell me "Authenticated as: David Brady" or
    fail with the actual error, so that I find out about a bad token
    on day one, not the first time I try to log time.

25. As a user of Claude Code, I want a skill that recognizes intents
    like "I'm reviewing this PR" or "log 30 minutes on MP-820" and
    invokes the appropriate `claire` command, so that I never have to
    remember the exact subcommand syntax.

26. As a developer maintaining claire, I want the resolution logic to
    be a single module callable from `check`, `log`, and any future
    verb, so that "given a thing, what project code is it" is one
    answer in one place.

27. As a developer maintaining claire, I want the report logic to
    depend only on the JSONL log and not on JIRA, GitHub, or Clarity,
    so that I can generate reports offline and the report module is
    testable without network mocking.

28. As a developer maintaining claire, I want a YAML cache of
    resolutions keyed by any of (ticket, PR number, project code), so
    that repeated lookups of the same input don't re-hit JIRA.

29. As a developer maintaining claire, I want
    `claire check --refresh MP-820` to bust that cache entry, so that
    I can pick up rare upstream changes (project code reassigned, PR
    edited to point at a different ticket).

30. As a developer maintaining claire, I want `rm ~/.config/claire/resolutions.yml`
    to be the always-available nuclear refresh, so that I don't need
    a `--clear-cache` flag.

31. As a developer maintaining claire, I want the JSONL row schema to
    include `jira_ticket`, `project_code`, and `pr_url` as
    independent breadcrumbs, so that any one of the three upstream
    systems can be reconstructed from the log alone.

32. As a developer maintaining claire, I want stored durations to be
    integer minutes and display to be the only place hours are
    computed, so that the weekly sum on Friday is exact and not
    subject to floating-point drift.

33. As a developer maintaining claire, I want every command's logic
    to live in `lib/claire/<verb>.rb` and the CLI dispatcher to be a
    thin glue layer, so that a future non-CLI consumer can call into
    the library directly without re-implementing arg parsing.

34. As a contractor at Acima who works weekends, I want the report
    week to run Sunday–Saturday, so that Saturday hours show up in
    the same week as the rest of the work that produced them.

35. As an engineer whose Clarity API access is still pending, I want
    `claire check` today to print the Clarity URL and the project
    code without prompting me to confirm anything, so that the
    command behaves the same in a terminal and as a Claude skill.

36. As an engineer whose Clarity API access will arrive someday, I
    want the eventual real Clarity check to slot in without changing
    the `check` or `log` interface, so that the future upgrade is a
    rewrite of one file rather than a refactor of the whole CLI.

## Implementation Decisions

### Modules

- **`Claire::Config`** — Loads `~/.config/claire/config.yml`,
  exposes Atlassian site name, user email, and API token. Backed by a
  plain YAML file. `claire init` writes it from
  `~/.claude/.mcp.json`.

- **`Claire::Duration`** — Parses duration strings to integer minutes.
  Bare integer = minutes; decimal = hours; `H:MM` = hours and minutes;
  `Nm` / `Nh` suffixes = explicit. Pure function; no I/O.

- **`Claire::Target`** — Classifies a string as ticket
  (`[A-Z]+-\d+`), PR number (`\d+`), GitHub PR URL, JIRA URL, or
  raw project code. Pure function.

- **`Claire::Jira`** — HTTP client around Atlassian Cloud REST API
  v3. Knows `customfield_10762` is "Project Code". Fetches an issue
  with only the fields it needs (`customfield_10762`, `parent`).
  Walks the parent chain looking for a non-empty code.

- **`Claire::Github`** — Thin wrapper around `gh pr view --json
  body,title,url`. Scrapes the body and title for the first
  `[A-Z]+-\d+`-shaped JIRA key.

- **`Claire::Resolver`** — Deep module exposing `.resolve(input)
  → Resolution(pr_url:, jira_ticket:, project_code:)`. Single entry
  point used by `check`, `log`, and future verbs. Reads/writes a
  bidirectional YAML cache at `~/.config/claire/resolutions.yml`
  keyed by any of the three identifiers. `--refresh` busts the cache
  entry (and cascades to all keys that point at the same record)
  before re-resolving.

- **`Claire::Log`** — Appends JSONL rows to
  `~/.config/claire/entries.jsonl`. Knows nothing about JIRA or
  GitHub; takes a resolved target and the parsed duration.

- **`Claire::Report`** — Reads the JSONL log, groups by date and
  project code, renders a Sun–Sat 7-column table with row/column
  TOTALs. Pure read; no network access ever.

- **`Claire::Check`** — Composes `Resolver` with output formatting.
  Prints resolution + Clarity URL + "manual confirm" note. Exit
  status reserved for future real Clarity check (`0` = approved,
  `1` = not approved, `2` = couldn't determine). Manual mode always
  exits `0`.

- **`Claire::CLI::*`** — One thin glue class per subcommand
  (`Check`, `Log`, `Report`, `Edit`, `Init`). Each receives parsed
  Optimist options and ARGV remainder, calls into the corresponding
  library module, prints results. Dispatch happens in `bin/claire`
  via the documented Optimist two-pass-parse pattern.

### Interfaces

- `Claire::Resolver.resolve(input, refresh: false) → Resolution`
- `Claire::Log.append(project_code:, jira_ticket: nil, pr_url: nil,
  minutes:, worked_on:, note: nil)`
- `Claire::Report.weekly(week_containing: Date.today) → Grid`
- `Claire::Jira.fetch_issue(key, fields:) → Hash`
- `Claire::Github.scrape_jira_key(pr_number_or_url) → String|nil`

### Data Schemas

**Config (`~/.config/claire/config.yml`):**
```yaml
atlassian:
  site_name: upbd
  email: david.brady@acima.com
  api_token: <token>
user:
  email: david.brady@acima.com
```

**JSONL row (`~/.config/claire/entries.jsonl`):**
```json
{"id":"<ulid>","created_at":"<iso8601+offset>","worked_on":"YYYY-MM-DD",
 "minutes":<int>,"project_code":"<opaque>","jira_ticket":"<key|null>",
 "pr_url":"<url|null>","note":"<text|null>"}
```

**Resolutions cache (`~/.config/claire/resolutions.yml`):**
A YAML hash keyed by any input string (`MP-820`, `17343`, `PR00151`,
`https://github.com/...`, `https://upbd.atlassian.net/...`). Each
value is the same triple `{pr_url, jira_ticket, project_code}`.
Multiple keys may point at the same triple; `--refresh` rebuilds and
rewrites all keys that map to the same record.

### CLI Surface

- `claire init` — Bootstrap config from `~/.claude/.mcp.json`. Refuses
  to overwrite. Pings JIRA `/rest/api/3/myself` to verify auth.
- `claire check <thing> [--refresh]` — Resolve and print.
- `claire log <thing> <duration> [--on DATE] [--note STR]
  [--refresh]` — Resolve, append.
- `claire report [last | --week DATE | --start DATE --end DATE]` —
  Render grid.
- `claire edit` — Exec `$EDITOR` (fallback `emacs`) on the JSONL log.

### Argument Grammar

- **Duration:** bare integer = minutes; decimal = hours; `H:MM` = H
  hours and MM minutes; `Nm` = minutes; `Nh` = hours. Always stored
  internally as integer minutes.
- **Date (`--on`):** ISO `YYYY-MM-DD`; `today`; `yesterday`;
  weekday names (`mon`, `tue`, ...) resolving to the most recent
  occurrence (no future dates); US `M/D` for current year. Ambiguous
  inputs like `12-05` rejected.
- **Target classification:** structural only, no allowlist of JIRA
  project keys. `[A-Z]+-\d+` = ticket, bare `\d+` = PR number,
  starts with `https://github.com/` = PR URL, starts with
  `https://*.atlassian.net/` = JIRA URL, anything else = opaque
  project code.

### Clarity Integration

- Today: `check` prints the Clarity project URL and the resolved
  project code with an informational reminder. No prompt. Exit `0`.
- When the Clarity API key arrives: a single new module
  (`Claire::Clarity`) replaces the informational print with a real
  approval call. `check` and `log` interfaces do not change. Exit
  codes gain meaning (`0` approved, `1` not approved, `2` unknown).

### Resolution Algorithm (JIRA walk)

1. Fetch issue with `?fields=customfield_10762,parent`.
2. If `customfield_10762` is non-empty, return that value
   verbatim — no format validation.
3. Else read `fields.parent.key` and recurse. Max depth 5.
4. If walk hits the top with nothing, return `nil` and the caller
   (`log`) hard-errors. `check` reports the failure path.

### PR-to-Ticket Resolution

1. Shell out to `gh pr view <number> --json body,title,url`.
2. Concatenate title and body; regex-scan for the first
   `\b[A-Z]+-\d+\b`.
3. Pass that ticket key into the JIRA walk above.
4. Record the PR URL in the row even though it's not used for
   billing — it's a receipt.

### Out-of-Scope Architecture (Explicitly Deferred)

- No stopwatches, timers, or `start`/`stop`/`done` verbs.
- No `--force` flag on `log`. Resolution either succeeds or the
  command errors.
- No backfill / pending-resolution machinery; null project codes
  cannot be persisted.
- No format validation on project codes (the field is human-maintained
  upstream by a team that will change conventions to spite us).
- No project-code → human label mapping.
- No CSV export. Decimal hours table output is the only report format.
- No `claire delete` / `claire undo` / `claire amend`. `claire edit`
  opens `$EDITOR` and that's the editing surface.
- No multi-user features. Single user, single laptop.
- No sync. Backup is `cp -r ~/.config/claire ~/Dropbox/...` if you
  want it.

## Testing Decisions

### Philosophy

Tests target **external behavior of pure-logic modules**. A test is
worth writing when it would catch a regression that a code reviewer
might miss. Tests of HTTP wrappers ("did we call Net::HTTP.get with
the right URL") are mock theater and explicitly skipped — the real
test of those is a one-time manual smoke run against the live JIRA
and GH APIs.

Each example is a complete story (AAA: arrange, act, assert in the
`it` block, per the project's `spec-style.md`). No `let` cathedrals.
WET > DRY. The duration parser in particular benefits from a flat list
of one-line examples for each input the parser must handle.

### Modules under test

- **`Claire::Duration`** — Every documented input (`15`, `1:30`,
  `1.5`, `90m`, `2h`, `0.25`, `60`), boundary cases (`0`, large
  values), and invalid inputs (`abc`, `1:`, negative).

- **`Claire::Target`** — Each input shape returns the right
  classification. Edge cases: lowercase ticket keys, full URLs,
  URLs with trailing slashes, raw project codes that look weird.

- **`Claire::Log`** — Append round-trip: write a row, read it back
  via plain JSON parse, verify all fields. Uses a real tempfile, no
  mocks.

- **`Claire::Report`** — Grid reduction over fixture JSONL.
  Covers: empty log, single entry, multiple entries on same day,
  multiple projects, week boundary (Saturday vs Sunday), partial
  weeks, integer-minute summation correctness, decimal rendering.
  No network mocks needed because Report doesn't touch the network.

- **`Claire::Resolver`** — Cache hit (returns cached), cache miss
  (calls injected Jira and Github fakes, writes cache), `refresh:
  true` (bypasses cache), cascade on refresh (all keys for the
  triple are rewritten). `Jira` and `Github` are injected so they
  can be swapped for test doubles that return fixture JSON.

### Modules explicitly not tested

- `Claire::Jira` HTTP client — direct stubbing of `Net::HTTP`
  proves nothing. Validated by hand-run smoke tests.
- `Claire::Github` shell-out wrapper — same reasoning.
- `Claire::CLI::*` glue classes — proxying parsed options to
  library calls. Trivial, would only catch typos in `case`
  statements.
- `bin/claire` dispatcher — same.

### Prior Art

The project's [`spec-style.md`](../.claude/skills/.../spec-style.md)
governs style. The merchant-portal repo's pure-logic specs (e.g.
`spec/domains/process/tax/taxability_spec.rb` referenced in PR
17343) demonstrate the AAA pattern at scale. No external dependencies
beyond `rspec`.

## Out of Scope

- Stopwatch and timer functionality (`start MP-820` / `stop` /
  `done MP-820 [time]`). Will be added on top of `check` and `log`
  once those are stable.
- Automated Clarity approval checking. Today is a manual
  informational print; the real implementation lands when the
  Clarity API key arrives.
- Submitting hours to Clarity automatically. Today's workflow is to
  read `claire report` output and hand-enter into the Clarity web
  UI. Automated submission may come with the API key.
- Caching of JIRA issue data beyond the resolution cache. Every
  resolution walk hits JIRA fresh; Atlassian is paid to handle the
  load.
- A multi-user mode, team reporting, or sharing of logs across
  developers.
- Mobile / web UI. CLI and Claude skill only.
- Migration tooling for the JSONL schema. The schema is treated as
  forward-compatible (adding a field is safe; removing or renaming
  is a one-time migration scripted ad hoc when needed).
- Project-code-to-human-label mapping. Project codes display as
  the opaque strings finance hands us.

## Further Notes

### Why a separate tool and not a Rails app feature

Merchant Portal is a domain-specific Rails app. Time tracking is a
personal productivity concern that belongs nowhere near production
code, deployment pipelines, or the merchant-facing system. claire
runs entirely on the developer's laptop and writes only to files
under `~/.config/claire/`.

### Why no SQLite

Volume is on the order of 20 entries per workday at peak.
Append-only JSONL is grep-friendly, vim-friendly, diffable, and
human-readable when claire itself has a bug. SQLite would have
locked the data behind a tool, which is the opposite of what a
personal log should be. If volume ever justifies it (it won't),
the migration is `jq` to SQL `INSERT` and a one-time import.

### Why the "any-key → triple" cache shape

The cache becomes a small bidirectional graph: once
`(PR 17343, MP-796, PR00151)` is resolved, a later `check MP-796`
benefits even though MP-796 was never typed before. JIRA can't tell
you "what PR mentions this ticket"; GitHub can't tell you "what
project code does this PR resolve to". The cache is the only place
that knows the full mapping. Refresh cascades because the cache is
edges into the same node — refreshing the node refreshes all paths.

### Why `--force` was removed

An earlier draft had a `--force` flag to write entries past
resolution failures. The user pointed out this implied the row was
somehow special at read time, when in practice a row is just a row.
The clean rule is: `log <ticket|pr>` resolves or errors;
`log <project_code>` is unconditional. The escape hatch is to type
the project code directly.

### Why model-invoked skill (not `/claire`)

The friction claire eliminates is "translate ad-hoc human ask into
CLI command." A user-invoked `/claire` skill makes the human do the
translation, defeating the point. A model-invoked skill recognizes
intent ("I'm reviewing this PR") and runs the right `claire`
command. The CLI is also always available directly for power users.

### Open dependencies on future work

- Clarity API key delivery (blocks real approval check and any
  automated submission).
- Possible future `start`/`stop`/`done` stopwatch verbs (planned but
  out of scope for v1).
- Possible future contractor-mode reporting (e.g., 6-day or 7-day
  visible week) — Sun–Sat default already supports weekend work.
