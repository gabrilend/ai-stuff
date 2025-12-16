# Project Scripts Directory

This directory contains project-specific scripts for development workflow and automation.

## Scripts

### `backup-conversations`

Local copy of the Claude conversation backup utility, customized for this project.

**Usage:**
```bash
# From project root directory
source ./scripts/backup-conversations && backup-conversations
```

**Features:**
- Extracts Claude Code conversation transcripts from `.claude/projects/` directory
- Creates markdown summaries in `llm-transcripts/` directory
- Preserves conversation context for decision-making history
- Automatically generates descriptive filenames using local LLM if available

**Dependencies:**
- `python3` for conversation processing
- Local `fuzzy-computing/` module (optional) for auto-generating descriptive names

**Output:**
- Conversation summaries in `llm-transcripts/[conversation-id]_summary.md`
- Contains user requests and final assistant responses
- Excludes intermediate problem-solving dialogue for clarity

### `fuzzy-computing/`

Local LLM interface module for generating intelligent responses and descriptive content.

**Usage:**
```bash
# From scripts/fuzzy-computing directory
source ./fuzzy-computing && echo "your prompt here" | fuzz
```

**Features:**
- Interfaces with local Ollama LLM server
- Automatically starts Ollama if not running
- Used by `backup-conversations` for generating descriptive filenames
- Supports both luajit and standard lua interpreters

**Dependencies:**
- `ollama` running on localhost:11434
- `lua` or `luajit` interpreter
- `curl` for API communication

**Components:**
- `fuzzy-computing` - Main bash script with fuzz() function
- `main_curl.lua` - Lua script for LLM API communication
- `lib/` and `share/` - Supporting libraries and resources

## Development Workflow Integration

These scripts integrate with the git commit process as specified in `/CLAUDE.md`:

1. **Backup conversations** before making commits to preserve decision context
2. **Stage changes** with proper git tracking
3. **Create commits** with standardized format and attribution

## Portability

The scripts in this directory are designed to be self-contained and portable:
- No hardcoded absolute paths to external systems
- Uses relative paths and script-directory detection for all dependencies
- Complete `fuzzy-computing/` module included with all Lua libraries
- Can be moved with the project without breaking functionality
- All external dependencies (Ollama, Lua) are gracefully handled if missing

## Maintenance

When updating scripts:
- Maintain backward compatibility where possible
- Update documentation in this README
- Test scripts in clean environment to verify portability
- Follow project conventions for git operations (`git mv` vs `mv`)