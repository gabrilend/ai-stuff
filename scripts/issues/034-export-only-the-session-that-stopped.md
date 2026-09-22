# Issue #034: Export only the session that stopped, and fail out loud

## Current Behavior

`backup-conversations` runs as Claude Code's Stop hook — after every reply the
model finishes — and in two hand-run forms. What each form does:

| How it is run | What it exports |
| --- | --- |
| `backup-conversations --hook` (the Stop hook) | the one session Claude Code names on stdin, then that session's helper conversations (issue 025) |
| `backup-conversations [--all] [project-dir]` | every conversation Claude has for the project — a sweep |
| `backup-conversations --session <id> [project-dir]` | one conversation and its helpers, by id |

With no project named, the project is Claude Code's `CLAUDE_PROJECT_DIR` when
running under Claude Code, and the current folder otherwise. Older tools that
source the file and call `backup-conversations <project>` as a function get the
sweep, through a small wrapper that runs the script itself.

### Why the hook exports one session

The Stop hook used to sweep the whole project after every reply. Re-reading
every session log costs time in proportion to the project's history, not to
what changed: measured on minimal-soramech (18 sessions, 74 MB of logs), a
sweep takes about 10 seconds even when every transcript is already up to date,
because each log is re-parsed to learn that. A session whose log ends on an
unanswered user message also costs three more parses and 0.6 seconds of
waiting, on every reply, forever. The hook's time limit is 30 seconds, so a
project about three times that size would be cut off part-way.

Claude Code hands every Stop hook a JSON record on stdin carrying
`session_id` and `transcript_path` (checked against the hooks reference at
code.claude.com/docs/en/hooks, September 2026). The hook now reads it and
exports only that session and its helpers: 0.75 seconds on the same project.
The sweep produces byte-identical transcripts to the old exporter (checked on
all 18 minimal-soramech sessions, "Generated on" stamp aside).

The hook refuses, loudly, if the log Claude Code names is not in the session
folder the script expects: that disagreement means Claude Code changed its
layout, and the sweep would be missing the same files.

### Finding the session folder

Claude Code names a project's session folder after the project's path, with
every character that is not a letter or digit turned into a dash:
`/mnt/mtwo/.config/nvim` becomes `-mnt-mtwo--config-nvim`. The exporter used to
turn only slashes into dashes, so every project with a dot in its path
(`.config/nvim`, `.dominions6`, ...) was never backed up. The project's path is
resolved through symlinks first, because Claude Code records the resolved path
(`/home/ritz/programming` is a link to `/mnt/mtwo/programming`, and every
folder name uses the latter).

The project's `llm-transcripts/` folder is created only once the session
folder has been found, so a lookup that misses no longer leaves an empty
folder behind.

### Failing out loud

Every failure ends the run with exit status 1 and a message on stderr, which
Claude Code shows the person as a non-blocking hook error. The run never exits
with 2: for a Stop hook that means "do not stop, keep working".

What used to hide failures, and what replaced it:

- The sourced entry point ran the exporter as `... 2>/dev/null || echo "(No
  new transcripts to backup)"`, which threw every error message away and
  relabelled every failure — missing session folder, a crashed parser, a
  missing library — as "nothing new". The script then ended with `exit 0`
  regardless. Both are gone.
- Running the main routine on the left of `||` also switched bash's
  stop-on-error off for everything inside it, so unchecked failures part-way
  through were skipped over silently. The main routine now runs in a subshell
  with stop-on-error on, and every file operation in the per-log export checks
  its own result.
- A log the parser cannot read fails that log, names it, and the export
  carries on with the others; the run as a whole still ends in failure.
- Missing tools (`lua`, `jq`, `flock`, `md5sum`) are named as errors rather
  than turned into a skipped backup.

The only remaining `|| true` guards are on reads where "nothing found" is a
normal answer (a husk session has no dates; a conversation may have no
transcript yet), each commented where it stands.

### Two runs at once

Two sessions in the same project stopping at the same moment both run the
hook. Previously both wrote the same fixed temp file name, and both could see
a transcript name as free and both take it. Now:

- temp files are unique per run (`mktemp`), hidden, and have no `.md` suffix,
  so the naming rulebook never mistakes one for a transcript; any left by an
  interrupted run are removed on exit;
- each project's export holds a lock (`flock`) for its duration, so runs for
  the same project take turns through the naming rules. Tested with four
  simultaneous exports of one session: exactly one file results.

### Where the log goes

The script keeps its own log in the toolchain's RAM tier:
`scripts/tmp/shared-memory/backup-conversations.log`. Per house layout,
`scripts/tmp` links to `/tmp/ai-stuff-scripts` and inside it `shared-memory`
links to `/dev/shm/ai-stuff-scripts`; the script re-creates both links (and
their targets) at the start of every run, because a reboot empties the
targets. Each run is marked in the log with a timestamped header line. The
lock files live beside the log.

It does not write into each project's own `tmp/shared-memory/`: the hook runs
in every project Claude Code is used in, including ones that are not house
projects, and creating `tmp/` links in all of them would be an unrequested
change to those projects.

The Stop hook entry in `~/.claude/settings.json` no longer needs to redirect
output to `/tmp/claude-backup-conversations.log` or end with `|| true`:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "/home/ritz/programming/ai-stuff/scripts/backup-conversations --hook",
        "timeout": 30
      }
    ]
  }
]
```

## Intended Behavior

As above. The hook's cost depends on the size of the session that just
stopped, not on the project's history; every failure is visible to the person
the moment it happens; and two sessions stopping together cannot damage each
other's transcripts.

## Suggested Implementation Steps

1. Split the exporter's work list from its per-log work: one routine lists
   logs (one session and its helpers, or the whole project), another exports a
   list of logs under a lock, another exports one log.
2. Add the three modes and dispatch on the first argument.
3. Replace the session-folder derivation with the letters-and-digits rule and
   move the `llm-transcripts/` creation after the lookup.
4. Remove the error relabelling and `2>/dev/null`; run the main routine where
   stop-on-error applies; check each file operation.
5. Unique temp files, cleanup on exit, a per-project lock.
6. Log to the toolchain's RAM tier, re-creating its links on every run.
7. Tests: `tests/test-backup-conversations-sessions.sh` — hook mode exports
   only the named session and its helpers; the sweep exports everything and
   counts helpers; four simultaneous runs leave one file; a missing session
   folder, garbled hook input, and an unreadable log each fail with a message
   and a non-zero status that is never 2; a project path containing a dot is
   found. The older suites keep passing unchanged.
8. Switch the Stop hook entry in `~/.claude/settings.json` to `--hook`.

## Related Documents and Tools

- `backup-conversations`, `README-backup-conversations.md`.
- `issues/025-capture-subagent-session-logs.md` — the helper conversations the
  hook exports alongside each session.
- `issues/completed/020-transcript-export-race-guard-and-single-naming-authority.md`
  — the race guard and naming authority, both unchanged.
- `batch-transcript-backup.sh`, `rederive-transcripts`,
  `claude-conversation-exporter.sh` — callers; they run the script with a
  project folder (the sweep) or source it for the `backup-conversations`
  function, and both still work.

## Metadata

- **Status**: step 8 is done — the Stop hook entry runs `--hook`. Open
  questions remain, so the issue stays open.
- **Complexity**: Medium.
- **Dependencies**: none.

## Open Questions

1. **Should the hook run in the background?** Claude Code supports
   `"async": true` on a command hook: it then runs without holding up the next
   prompt. At 0.75 seconds that saving is small, and it is not established that
   a failure in a background hook is shown as prominently as one in a
   foreground hook — which is the whole point of the loud-failure change. Left
   in the foreground.
2. **Should `claude-conversation-exporter.sh` stop sourcing this file?** It
   sources it for the `backup-conversations` function and wraps the call in
   `2>/dev/null ... || true`, which hides failures the same way this script
   used to. That file is outside this issue; it now gets the sweep through the
   wrapper, but its own error-hiding remains.
3. **Should `scripts/tmp` be listed in the repository's ignore file?** The
   ignore rule `tmp/` matches folders only, and `scripts/tmp` is a link, so git
   shows it as untracked.
