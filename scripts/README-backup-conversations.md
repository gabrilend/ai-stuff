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
- **Timestamp Preservation**: Sets file modification times to match the conversation's final timestamp
- **Descriptive Naming**: Uses local LLM (if available via fuzzy-computing) to generate descriptive filenames

## Output Format

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

- Python 3 (for JSONL parsing)
- Optional: `fuzzy-computing` for descriptive filename generation

## Related Scripts

- `claude-conversation-exporter.sh` - More feature-rich exporter with TUI and verbosity controls
