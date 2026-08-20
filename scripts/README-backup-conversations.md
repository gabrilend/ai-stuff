# backup-conversations

Extracts Claude conversation transcripts from `~/.claude/projects/` and writes summaries to project-specific `llm-transcripts/` directories. Keeps every user request and every block of assistant prose the model emitted between user turns — tool calls and tool results are dropped, but in-progress narration ("now I'll check X", "found the bug", etc.) is preserved because that's content the model wanted the user to read.

## Use Cases

### Backup All Conversations for a Project
Extract and save transcripts from Claude Code sessions for a specific project.

```bash
./backup-conversations /path/to/project
```

### Backup Current Project
Run from within a project directory to backup its conversations.

```bash
cd /home/ritz/programming/ai-stuff/my-project
/path/to/scripts/backup-conversations
```

### Create Archive of AI Collaboration History
Useful for documenting how AI assistance was used during development.

```bash
./backup-conversations /home/ritz/programming/ai-stuff/world-edit-to-execute
# Output: world-edit-to-execute/llm-transcripts/*.md
```

## Configuration Options

| Option | Description |
|--------|-------------|
| `[project-dir]` | Project directory to backup (default: current directory) |

## Capabilities

- **Automatic Claude Directory Discovery**: Maps project paths to Claude's internal project directories
- **User/Assistant Extraction**: Parses JSONL conversation files to extract the dialogue flow
- **Prose Preservation**: Keeps every assistant text block between user turns, joined into one response section. Skips only tool_use blocks (and any internal thinking blocks).
- **Markdown Formatting**: Outputs clean, readable markdown summaries
- **Text Wrapping**: Wraps long lines at 80 characters while preserving markdown structure
- **Timestamp Preservation**: Sets file modification times to match the conversation's final timestamp. The log's UTC clock fields are read verbatim for both this and the filename's date, so the two always agree with each other — at the cost of sitting one UTC offset away from local wall time. That trade is recorded at `to_date_string()` in `libs/conversation-parser.lua`.
- **Date-Range Naming**: Names each file by the span of dates the conversation covers (see *File Naming* below)
- **Idempotent in name**: Re-running reuses each conversation's existing file (matched by its header id), renaming it only when the conversation continues into a new day
- **Idempotent in content**: A conversation nobody has added a word to is left entirely alone — same bytes, same inode, same `Generated on:` stamp it was first written with. Only the mtime is still re-derived, because that is a projection of the session log in the way the filename is, and re-deriving it repairs a file some checkout or copy has scrambled. Without this the Stop hook re-dirtied every transcript in a project after every single assistant turn, so `git status` could never be read for which transcripts had actually grown

## File Naming

Files are named by the calendar span they cover, so a directory listing reads
like a timeline:

- single-day conversation: `jul-3-26.md`
- multi-day conversation: `jul-3-26-through-jul-5-26.md`

The date token is `<lowercase-month>-<day>-<2-digit-year>`. When several
transcripts resolve to the same span in one folder — typically a conversation
and its agent sidechains — the first keeps the bare name and the rest take a
suffix placed just before `.md`: `jul-3-26_agent-1.md`, `jul-3-26_agent-2.md`,
and so on.

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

## Output Format

Prose is wrapped at 80 columns — including paragraphs that open with
`**bold**`, list items (whose continuations get a hanging indent), and
blockquotes. Structure is never wrapped: headers, fenced code and everything
inside it, table rows, and indented code pass through verbatim, and a single
token longer than 80 (a URL, a path) stays long rather than being broken.

Each conversation is saved as a markdown file with:

```markdown
# Conversation Summary: {conversation_id}

Generated on: {date}

--------------------------------------------------------------------------------

### User Request 1

{first user message}

--------------------------------------------------------------------------------

### Assistant Response 1

{final assistant response to that request}

--------------------------------------------------------------------------------
```

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

The script defines several functions that can be sourced:

- `backup-conversations` / `backup-conversation` - Main backup function
- `write-transcripts-to-project-directory` - Core extraction logic
- `start-claude` - Launch Claude CLI
- `claude-next` - Create numbered todo files for Claude

## Dependencies

- Lua (LuaJIT-compatible) — the JSONL reading and markdown rendering both live in `libs/conversation-parser.lua`. Without `lua` on the path the tool prints a notice and writes nothing.

## Related Scripts

- `claude-conversation-exporter.sh` - More feature-rich exporter with TUI and verbosity controls
