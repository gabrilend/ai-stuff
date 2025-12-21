# 008: Custom Signal Protocol for File Server

## Status
- **Priority**: EXPLORATORY
- **Type**: Feature / Protocol Design
- **Dependencies**: Issue 007 (completed)
- **Phase**: 2 - Custom Signals

## Vision

Extend the project file server to accept custom signals via browser links, enabling
actions like "check for updates" or "backup transcripts" triggered by clicking a link.

Instead of just HTTP GET/POST, define a custom "hand-sign" protocol where:
- User clicks a link in their browser
- Server interprets the signal and performs an action
- Response is returned (new page, status, or file)

## Current Behavior

The project-file-server generates static HTML with `file://` links. No server-side
processing. No custom actions.

## Intended Behavior

A lightweight signal server that:
1. Listens on a port (e.g., 8080)
2. Interprets URL paths as signals/commands
3. Executes corresponding actions
4. Returns results as HTML or files

### Example Signals

| Signal | URL Path | Action |
|--------|----------|--------|
| PEEK | `/peek/delta-version` | View project without logging |
| BACKUP | `/backup/transcripts` | Run `backup-conversations` script |
| GIFT | `/gift/filename` | Serve a file for download |
| REFRESH | `/refresh` | Regenerate file server HTML |
| STATUS | `/status` | Show server status and recent actions |
| WITNESS | `/witness/hash` | Confirm receipt of a file |

### Browser Integration

Users can trigger actions by clicking links:
```html
<a href="http://localhost:8080/backup/transcripts">Backup Transcripts</a>
<a href="http://localhost:8080/refresh">Regenerate File List</a>
```

## Suggested Implementation Steps

### Phase A: Design Protocol
1. [ ] Define signal vocabulary (verbs/actions)
2. [ ] Define URL schema (how signals map to paths)
3. [ ] Define response format (HTML, JSON, plain text)
4. [ ] Document security considerations (local-only, no remote access)

### Phase B: Implement Server
5. [ ] Create Lua-based HTTP server (or Python for simplicity)
6. [ ] Implement signal parser (URL path → action)
7. [ ] Create action handlers for each signal
8. [ ] Implement response generation

### Phase C: Integrate with File Server
9. [ ] Add signal links to generated HTML
10. [ ] Create status/dashboard page
11. [ ] Add "last action" logging
12. [ ] Test full workflow in Firefox

### Phase D: Expand Signals
13. [ ] BACKUP: Run transcript backup
14. [ ] SYNC: Sync llm-transcripts to git
15. [ ] SEARCH: Search across projects
16. [ ] HISTORY: Show git history for a file

## Technical Considerations

### State Machine Approach
The server can be modeled as a state machine:
- **IDLE**: Waiting for signal
- **PROCESSING**: Executing action
- **RESPONDING**: Returning result

Each signal transitions the state and produces output.

### Security
- Bind to localhost only (127.0.0.1)
- No remote access by default
- Actions limited to read-only and approved scripts
- No arbitrary command execution

### Why Not Just Use HTTP Verbs?
HTTP verbs (GET, POST, PUT, DELETE) are generic. Custom signals are:
- **Semantic**: `BACKUP` means something specific
- **Memorable**: `/backup/transcripts` is self-documenting
- **Extensible**: Add new signals without protocol changes
- **Fun**: It's your own language

## Related Documents
- `/home/ritz/programming/ai-stuff/scripts/project-file-server`
- `/home/ritz/programming/ai-stuff/scripts/libs/project-file-server.lua`
- `/home/ritz/programming/ai-stuff/scripts/backup-conversations`
- `/home/ritz/programming/ai-stuff/scripts/claude-conversation-exporter.sh`

## Philosophical Notes

> "Re-implement signals to make my own hand-sign."

This is about creating a personal protocol - a language between you and your
computer that feels natural and intentional. Not corporate HTTP verbs, but
signals that mean something to *you*.

The dragon's green boba blood flows through metallic factory-cells...
and this is how we build the veins.

---

*Quest bounty: Available for anyone who wants to explore.*
