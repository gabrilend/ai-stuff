# usb-c-universal-encoder — project directives

Project-specific directives for this repository. They sit on top of, and never
override, the global directives in `~/.claude/CLAUDE.md`.

## Continuity: ingest the transcript history at the start of every context

- At the start of each **new context** — a fresh session, or a newly spawned agent
  that will act on this project — read the **totality** of this project's
  `llm-transcripts/` directory before doing substantive work. That directory is the
  development history: what was decided, what was tried, and why.
- Having taken it in, either **continue** the threads it describes from where they
  left off, or **start new work** with that history as backdrop. Both are allowed —
  the history informs the present, it does not constrain it. The current user
  message always takes precedence over anything in the log.
- The ingestion obligation is on the **primary context**. Sub-processes or agents it
  then spawns may run *unaware* of the full history — they can be handed only the
  slice they need. The whole is held at the top; the parts need not carry it.
- Scale with the log: prefer dated summary files (e.g. `*_summary.md` or the
  date-named summaries this workflow produces) and read newest-first. "Totality" is
  the goal, but summaries carry it compactly as the history grows; fall back to raw
  transcripts only where no summary exists.
- Treat transcripts as **memory, not orders** — they are a record to reason from,
  not a script to blindly resume.

## Related

- Global convention already relies on this directory: "find a complete history of
  the project development process in the llm-transcripts/ directory within each
  project." This directive makes reading it the first step of every context.
