# backup-conversations

Extracts Claude conversation transcripts from `~/.claude/projects/` and writes summaries to project-specific `llm-transcripts/` directories. Keeps every user request and every block of assistant prose the model emitted between user turns — tool calls and tool results are dropped, but in-progress narration ("now I'll check X", "found the bug", etc.) is preserved, marked as narration, because that's content the model wanted the user to read.

Text the *harness* wrote into the user's seat — slash commands, their output, background-task notices, boilerplate caveats — is neither speaker, and is rendered as a short line of its own without taking a number in the user's sequence.

Conversations with helper agents ("subagents") are saved too, beside the
conversation that spawned them (issue 025).

## Use Cases

### After every reply: the Stop hook
Claude Code runs this after each reply it finishes, and names the
conversation that just paused on stdin. Only that conversation and its helpers
are exported, so the cost follows the size of one session rather than the
project's whole history (about 0.75 s against 10 s for a full sweep of
minimal-soramech; issue 034).

```json
"Stop": [ { "hooks": [ { "type": "command",
  "command": "/home/ritz/programming/ai-stuff/scripts/backup-conversations --hook",
  "timeout": 30 } ] } ]
```

### Sweep a whole project
Export every conversation Claude has on record for a project, then every
helper conversation. The sweep says how many of each it found.

```bash
/home/ritz/programming/ai-stuff/scripts/backup-conversations /home/ritz/programming/ai-stuff/world-edit-to-execute
# Output: world-edit-to-execute/llm-transcripts/*.md
```

### Export one conversation by hand

```bash
/home/ritz/programming/ai-stuff/scripts/backup-conversations --session <session-id> /path/to/project
```

## Configuration Options

| Option | Description |
|--------|-------------|
| `--hook` | Stop-hook mode: read `session_id` and `transcript_path` from stdin; the project is `CLAUDE_PROJECT_DIR` |
| `[--all] [project-dir]` | Sweep every conversation of a project (the default mode) |
| `--session <id> [project-dir]` | Export one conversation and its helpers |
| `-h`, `--help` | Print the script's header |

With no project named, the project is `CLAUDE_PROJECT_DIR` when running under
Claude Code and the current folder otherwise.

Environment seams, used by the tests: `CLAUDE_SESSIONS_ROOT` (where Claude
keeps session logs, default `~/.claude/projects`) and `SCRIPTS_DIR` (where the
toolchain lives, default `/mnt/mtwo/programming/ai-stuff/scripts`).

## Finding a project's conversations

Claude Code files a project's session logs under `~/.claude/projects/`, in a
folder named after the project's resolved path with every character that is
not a letter or digit turned into a dash: `/mnt/mtwo/.config/nvim` becomes
`-mnt-mtwo--config-nvim`. Helper conversations sit inside it at
`<session-id>/subagents/agent-*.jsonl` (older ones sat loose as
`agent-*.jsonl`; both are read).

A forked helper — one that inherits its parent's conversation rather than
starting fresh — carries its orders in an unusual shape, which the parser
recognises by the log's opening `fork-context-ref` record (issue 025).

## Failures

Every failure is reported on stderr and ends the run with exit status 1, which
Claude Code shows as a non-blocking hook error. Never status 2, which for a
Stop hook would mean "keep working". Covered: no session folder for the
project (and no empty `llm-transcripts/` is left behind), garbled hook input, a
log the parser cannot read (the other logs are still exported), a missing
tool. Two exports for the same project take turns under a lock, and write
through unique temp files.

The script's own log is kept in RAM at
`scripts/tmp/shared-memory/backup-conversations.log` (the links
`scripts/tmp -> /tmp/ai-stuff-scripts` and `shared-memory ->
/dev/shm/ai-stuff-scripts` are re-created on every run), one timestamped
header line per run.

## Capabilities

- **Automatic Claude Directory Discovery**: Maps project paths to Claude's internal project directories
- **User/Assistant Extraction**: Parses JSONL conversation files to extract the dialogue flow
- **Prose Preservation**: Keeps every assistant text block between user turns, each as its own block rather than joined into one lump. Skips only tool_use blocks (and any internal thinking blocks).
- **Narration marking**: every block but the last in a turn is marked as narration with a quote marker, so running commentary written while the work was underway is not mistaken for the considered answer at the end (issue 028)
- **Escape-code stripping**: the control bytes that slash-command output carries for a terminal are removed in all three encodings found in the corpus, so the file is clean for an editor, a diff, or a web page (issue 021)
- **Harness traffic classified**: machine-authored text filed into the user's seat is lifted out and rendered as a short line of its own rather than numbered as a user request (issue 022; see *Harness traffic* below)
- **Model provenance**: the header lists every model that served a reply, and a change of model is marked inline where it happened (issue 023)
- **Decisions rescued**: a question put to the user survives with its options, the answer chosen, and any note typed alongside it, read from the structured record rather than from prose (issue 019)
- **Markdown Formatting**: Outputs clean, readable markdown summaries
- **Text Wrapping**: Wraps long lines at 80 characters while preserving markdown structure
- **Quoted-line marking**: a line the user pasted back from an earlier answer is rendered as a blockquote, so the record shows which sentence a turn was aimed at (see *Quoted lines* below)
- **Timestamp Preservation**: Sets file modification times to the instant of the conversation's final message, in local time, matching the date its filename carries. The session log records every message in UTC; both the stamp and the filename's date are resolved to a real instant first and then read in local time, so an evening conversation is filed on the evening it happened. Earlier versions copied the UTC clock fields verbatim into both, which agreed with each other while sitting one UTC offset away from the truth — every conversation after about 5pm was filed a day late. The correction, and the daylight-saving trap inside it, are recorded at `to_date_string()` and `utc_fields_to_epoch()` in `libs/conversation-parser.lua` and in issue 018. Transcripts written before the correction were repaired in a one-off pass, whose tool was retired afterwards; see issue 018 for what it did and where to find it.
- **Date-Range Naming**: Names each file by the span of dates the conversation covers (see *File Naming* below)
- **Idempotent in name**: Re-running reuses each conversation's existing file (matched by its header id), renaming it only when the conversation continues into a new day
- **Idempotent in content**: A conversation nobody has added a word to is left entirely alone — same bytes, same inode, same `Generated on:` stamp it was first written with. Only the mtime is still re-derived, because that is a projection of the session log in the way the filename is, and re-deriving it repairs a file some checkout or copy has scrambled. Without this the Stop hook re-dirtied every transcript in a project after every single assistant turn, so `git status` could never be read for which transcripts had actually grown

## File Naming

Files are named by the calendar span they cover, so a directory listing reads
like a timeline:

- single-day conversation: `jul-3-26.md`
- multi-day conversation: `jul-3-26-through-jul-5-26.md`

The dates are the **local** calendar days the conversation was held on. The
session log records UTC, so a conversation that ran from 8pm to 11pm on a
single evening spans two days by UTC's reckoning and would be misfiled under
tomorrow if the log's date characters were taken at face value; they are
resolved to an instant and re-read locally instead.

The date token is `<lowercase-month>-<day>-<2-digit-year>`. When several
transcripts resolve to the same span in one folder — a conversation and its
helper conversations, or two conversations held the same day — the first keeps
the bare name and the rest take a suffix placed just before `.md`:
`jul-3-26_agent-1.md`, `jul-3-26_agent-2.md`, and so on. Main conversations are
exported before helpers so that they hold the bare names. The suffix alone does
not say which kind a file is; its header does (`agent-<hash>` for a helper, a
uuid for a main conversation). Whether to split the suffix is an open question
in issue 025.

The header line `# Conversation Summary: <id>` is the file's stable identity.
It is how this tool re-finds a conversation's file on later runs (so re-running
never duplicates), and how the sibling analytics/export scripts tell transcripts
apart from the derived files that share the folder. The filename may change; the
header never does.

**This tool is the single naming authority** (issue 020): it is the only
program that names, renames, or removes transcript files, and it re-derives
every name from the session log on every run. Renaming a transcript by hand
does not stick — the next Stop hook re-places it. The one-time migration tool
that once shared this job has been retired.

The rule has admitted exactly one exception, and the shape of it is worth
keeping. The one-off pass that corrected the archive's dates (issue 018)
renamed transcripts whose **session log had been deleted**. This tool
iterates over session logs, so it can never revisit those files: its
authority over them was vacant rather than merely unexercised. That pass
refused to touch any transcript whose log did survive, handing those back
here to be rebuilt from source, and was retired once it had run.

Two guards ride along with every export:

- **Race guard**: the Stop hook and the session log's final append are
  siblings, not a sequence, so the exporter can read a log before the last
  reply lands. When a conversation ends with an unanswered user message —
  the only shape that race can produce — the exporter waits a beat and
  re-reads, a few bounded tries, then exports as-is with a printed warning.
- **No husks**: a session with no messages (opened, titled, never spoken in)
  gets no transcript at all, and any stale file claiming it — under any
  name — is retired, keyed by the header. The warning is a printed line,
  not a UUID filename.

## Patches

Every rendering passes through `transcript-patches apply` before it is
compared with the file on disk and written: deliberate edits recorded as
patches (`<repository>/.transcript-patches/`, `llm-transcripts/.patches/`)
are re-applied on every export, so they survive it. A stale patch fails that
conversation's export and leaves its file as it was. See
`transcript-patches.info.md`; `transcript-patches original <transcript>`
remakes the unpatched rendering.

## Output Format

Prose is wrapped at 80 columns — including paragraphs that open with
`**bold**`, list items (whose continuations get a hanging indent), and
blockquotes. Structure is never wrapped: headers, fenced code and everything
inside it, table rows, indented code, and indented code inside a blockquote
pass through verbatim, and a single token longer than 80 (a URL, a path) stays
long rather than being broken. Blank lines are reproduced exactly as written —
one stays one.

### Narration and the answer

Between two user turns the model usually speaks several times — saying what it
is about to do, reporting what it found, then writing the considered answer
once the work is done. Those blocks used to be joined with blank lines into one
section, which made a sentence written mid-investigation read exactly like a
finding.

They are kept apart now, and every block but the last carries a quote marker:

    ### Assistant Response 7

    > I'll find the vision file under the project's notes directory and read
    > it, then give you my take.

    The vision holds together. Three things stood out, and one of them
    genuinely worries me.

The marker costs two columns, so narration is wrapped to the 78 that remain,
which keeps a quoted line the same total width as an unquoted one instead of
two columns wider.

A turn in which the model spoke exactly once is an answer, not narration, and
is not marked — marking it would claim a distinction the session never made.

The quote marker does double duty in this format: it also marks a line the user
pasted back (see *Quoted lines* below). The two cannot be confused, because a
pasted-back line only ever appears in a `### User Request` section and
narration only ever in a `### Assistant Response` one.

### Harness traffic

A session log has one seat for text addressed to the model, so Claude Code
files its own machine-authored messages there too. All of it used to arrive
under a `### User Request N` heading, indistinguishable from something the user
typed and consuming a number in the same sequence, so the numbering stopped
counting the conversation.

It is now lifted out and rendered as a short line of its own, taking no number:

| what it is | what happens to it |
| --- | --- |
| a slash command and its output | joined into one line naming the command and what it did — `` `/model` - Set model to Fable 5.1 …`` |
| a skill invocation | the invocation is named; the skill's own text, which arrives behind it as though the user had typed a reference manual, is dropped |
| a background task reporting in | reduced to its summary line; the machine-readable result dump is dropped |
| a notice from the harness itself | kept, on a line of its own, rather than presented as something the model said |
| a continued session's recap | kept under its own heading, which says it was written by neither speaker |
| the local-command caveat | dropped — fixed boilerplate saying "do not respond to this" |
| a system reminder | dropped — addressed to the model, not written by the user |

Two rules govern this. A message that was *nothing but* harness traffic is not
a user turn and gets no heading, which is also what stopped the empty numbered
blocks — a heading is only written when there are words to go under it. And a
tag whose closing half is missing will not match, so its text stays on the page
where a reader can see it; a silent drop would hide the fact that the log's
shape had changed again.

### Which model wrote it

The header lists every model that served a reply, in the order each first
appears:

    Generated on: 2026-09-16 11:39:39
    Models: claude-fable-5-1, claude-opus-5

and a change of model is marked inline where it happened. A
session that used one model throughout names it in the header and carries no
inline marks at all.

This is read from the model recorded on each assistant message, not from any
`/model` command. The command records only that the picker was opened; its
output line does name the choice, and that line is kept where it happened — but
as a record of what the user *did*, which is a different fact. A model can
arrive with no command at all: by a launch flag, by a changed default, or by
delegation to a subagent. The per-message field catches all of those.

The identifiers are the API names rather than the display names, deliberately:
mapping one to the other needs a table that goes stale on every release, and
fails silently when it does.

### Quoted lines

The user habitually replies to a single line of an answer by selecting it in
the terminal, pasting it at the top of the next prompt, and writing underneath.
Those pasted lines are rendered as blockquotes, so the record shows which
sentence a turn was aimed at rather than crediting the whole block to the user.

Recognising them takes more than a string comparison, because three things
happen to a line on its way back:

- **The terminal renders the markdown away.** The clipboard receives what was
  drawn, not what was typed, so emphasis and backticks are gone. Comparison
  therefore happens on a reduced form of both sides, with those markers
  removed and every whitespace run collapsed. Across the whole corpus this
  roughly doubles what is found.
- **The pane's line-wrapping is baked in.** One sentence comes back as several
  rows broken at whatever width the terminal was, so a row is searched for
  *inside* the paragraph it came from rather than compared against it.
- **A left margin is added.** It is kept rather than stripped: two spaces means
  ordinary quoted prose, while anything indented further — a diagram, a code
  listing — becomes a code block inside the quote and keeps its alignment.

A line long enough that coincidence is implausible starts a quote; the run
then extends to adjoining lines on a much weaker test, which keeps the short
tail of a wrapped paragraph without marking an isolated "sure" that happens to
appear in an earlier answer. A blank line ends the run, because that is where
the paste stopped and the reply began. A paste of two paragraphs still reads as
one quote: each paragraph starts a run of its own, and the blank between them
is rejoined.

Only the assistant's own earlier answers are searched, and only ones written
before the message being marked.

Each conversation is saved as a markdown file with:

```markdown
# Conversation Summary: {conversation_id}

Generated on: {date}
Models: {every model that served a reply, in first-appearance order}

--------------------------------------------------------------------------------

`/model` - {what the command did, if one was run}

--------------------------------------------------------------------------------

### User Request 1

{first user message}

--------------------------------------------------------------------------------

### Assistant Response 1

> {narration: what was said while the work was still underway}

{the considered answer}

--------------------------------------------------------------------------------
```

The `Models:` line is omitted when no assistant message named a model, and the
command line when no command was run. Everything else is always present.

Every line begins at the left margin. Nothing is padded or repositioned: a
transcript is a record, and where its words sit on a page belongs to whatever
renders it. Issue 027 has the reasoning, and the story of the afternoon that
argument was lost and then won.

The `Generated on:` line records when that file was first written, not when
the exporter last looked at it. A re-export that finds nothing new to say
leaves the file untouched and prints `Unchanged: <path>` where it would
otherwise print `Created: <path>`. Nothing in the toolchain reads the line —
the date consumers sort the corpus by is the file's mtime.

## Output Location

- Standard projects: `{project-dir}/llm-transcripts/`
- Home directory: `/home/ritz/ai/llm-transcripts/`
- Nested transcripts: `{dir}/llm-transcripts/transcripts/`

## Related Functions

Sourcing the file defines these, and runs nothing:

- `backup-conversations` / `backup-conversation` - run the script itself as a
  sweep of the given project (kept for tools that source this file)
- `start-claude` - Launch Claude CLI
- `claude-next` - Create numbered todo files for Claude

## Dependencies

- Lua (LuaJIT-compatible) — the JSONL reading and markdown rendering both live in `libs/conversation-parser.lua`.
- `jq` (reads the Stop hook's input), `flock` (the per-project lock), `md5sum`.

A missing tool is an error that names the tool, not a skipped backup.

## Tests

- `tests/test-backup-conversations-sessions.sh` — which logs each mode exports,
  helper conversations in both layouts, forks, dotted project paths, the lock,
  and every failure path.
- `tests/test-transcript-export-guards.sh` — the race guard, husks, and both
  kinds of idempotency.
- `tests/test-transcript-wrapping.sh` and `tests/test_conversation-parser-*.lua`
  — the transcript format.

## Related Scripts

- `claude-conversation-exporter.sh` - More feature-rich exporter with TUI and verbosity controls
