# claude-conversation-exporter.sh

Full-featured conversation export with per-project output paths, multiple verbosity levels, and TUI-based project selection. Stores per-project configuration that persists across runs.

## Use Cases

### Interactive Project Browser
Browse and select conversations with TUI interface.

```bash
./claude-conversation-exporter.sh
```

### Export Specific Project
Browse conversations for a named project.

```bash
./claude-conversation-exporter.sh handheld-office
```

### Export Specific Conversation
Export a single conversation by ID or partial match.

```bash
./claude-conversation-exporter.sh handheld-office c0567703
```

### Export All Conversations
Dump all conversations for a project.

```bash
./claude-conversation-exporter.sh handheld-office all > backup.md
```

### Minimal Output for Code Extraction
Strip everything except code blocks and essential content.

```bash
./claude-conversation-exporter.sh -v0 project-name conversation-id
```

### Complete Debug Output
Include all LLM execution details and intermediate steps.

```bash
./claude-conversation-exporter.sh -v4 project-name all > debug.md
```

### Raw Unfiltered Export
Include absolutely everything from the conversation.

```bash
./claude-conversation-exporter.sh -v5 project-name all
```

## Verbosity Levels

| Level | Flag | Description |
|-------|------|-------------|
| 0 | `-v0, --minimal` | Code and essential content only |
| 1 | `-v1, --compact` | Skip user sentiments, show responses |
| 2 | `-v2, --standard` | Include everything (default) |
| 3 | `-v3, --verbose` | Include context files and expansions |
| 4 | `-v4, --complete` | Everything + LLM execution details + vimfolds |
| 5 | `-v5, --raw` | ALL intermediate LLM steps and tool results |

## Configuration Options

| Option | Description |
|--------|-------------|
| `-v0` to `-v5` | Set verbosity level |
| `--minimal` | Alias for `-v0` |
| `--compact` | Alias for `-v1` |
| `--standard` | Alias for `-v2` |
| `--verbose` | Alias for `-v3` |
| `--complete` | Alias for `-v4` |
| `--raw` | Alias for `-v5` |
| `-h, --help` | Show help message |

## Capabilities

- **TUI Selection**: Interactive browsing of projects and conversations
- **Partial Matching**: Find conversations by partial ID
- **Per-Project Paths**: Remembers output paths for each project
- **Self-Modifying Storage**: Stores configuration within the script itself
- **Verbosity Control**: Fine-grained control over output detail

## Usage Patterns

### Direct Export Mode
```bash
./claude-conversation-exporter.sh handheld-office c0567703
./claude-conversation-exporter.sh --compact handheld-office all > backup.md
./claude-conversation-exporter.sh -v1 /path/to/project conversation.md
```

### File Export
```bash
./claude-conversation-exporter.sh -v3 handheld-office 3 > conversation.md
./claude-conversation-exporter.sh --complete handheld-office all > full-backup.md
```

## Stored Configuration

The script stores per-project output paths in a special section within itself:

```bash
# STORED_PROJECT_PATHS_START
# handheld-office|/path/to/handheld-office/context.txt
# delta-version|/path/to/delta-version/README.md
# STORED_PROJECT_PATHS_END
```

These paths are automatically loaded on startup and updated when you specify new output locations.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `PROJECTS_BASE_DIR` | Override default projects directory |
| `VERBOSITY` | Override default verbosity level |
| `OUTPUT_FILE` | Override output file path |
| `MENU_RESULT` | TUI selection result |

## Comparison with backup-conversations

| Feature | backup-conversations | claude-conversation-exporter |
|---------|---------------------|------------------------------|
| Verbosity control | No | Yes (6 levels) |
| TUI interface | No | Yes |
| Per-project paths | No | Yes (persistent) |
| Partial matching | No | Yes |
| Output formats | Markdown only | Markdown with levels |
| Speed | Faster | More features |

## Related Scripts

- `backup-conversations` - Simpler alternative for basic backups
- `issue-splitter.sh` - Uses similar TUI patterns
