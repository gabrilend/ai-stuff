# Issue 105: Logging and Error Reporting

**Phase**: 1 - Foundation & Core Infrastructure
**Status**: Open
**Priority**: Medium
**Created**: 2026-01-08

---

## Current Behavior

No logging system exists. The project needs to capture events, errors, and diagnostic information to project-specific tmp/ directory.

---

## Intended Behavior

The system should:
- Log events to tmp/authorship-tool.log
- Support multiple log levels (debug, info, warn, error)
- Include timestamps and context in log entries
- Provide logging functions accessible from all modules
- Rotate log files when they get too large
- Report errors to user clearly (not just log)
- Separate user-facing errors from diagnostic logs
- Prefer breaking with clear errors over silent fallbacks
- Create issue notifications when fallbacks are used

---

## Suggested Implementation Steps

1. Create `src/logger.lua` for logging functionality
2. Implement log level filtering
3. Create log file writing functions
4. Implement timestamp formatting
5. Add context tracking (module name, function name)
6. Create logging API (log_debug, log_info, log_warn, log_error)
7. Implement log rotation (size-based)
8. Create error reporting system (separate from logging)
9. Add user-facing error display (for TUI)
10. Implement fallback detection and warning system
11. Write tests for logging functions
12. Document logging API in src/logger.info.md

---

## Related Documents

- docs/technical-design.md (Error Handling Strategy section)
- User's global instructions (prefer errors over fallbacks)
- docs/roadmap.md (Phase 1)

---

## Implementation Notes

**Log Entry Format**:
```
[2026-01-08 14:23:45] [INFO] [module-loader] Loading module: document-reader
[2026-01-08 14:23:45] [ERROR] [document-reader] Failed to read file: /path/to/file.txt
[2026-01-08 14:23:46] [WARN] [config] Using fallback value for 'theme' (FALLBACK USED - create issue)
```

**Log Levels**:
- **DEBUG**: Detailed diagnostic information
- **INFO**: General informational messages
- **WARN**: Warning messages (fallbacks, potential issues)
- **ERROR**: Error messages (failures, exceptions)

**API Functions**:
```lua
-- Basic logging
log.debug(message, context)
log.info(message, context)
log.warn(message, context)
log.error(message, context)

-- Error reporting (logs + user notification)
report_error(message, details)

-- Fallback notification (logs + creates issue reminder)
report_fallback(feature, fallback_used, reason)
```

**Log Rotation**:
- Rotate when log file exceeds 10MB
- Keep last 3 rotated logs
- Format: authorship-tool.log.1, authorship-tool.log.2, etc.

**Error Display**:
- Show errors in TUI status bar or dedicated error area
- Include actionable information (what went wrong, how to fix)
- Log full stack trace/details to file
- Allow user to view full error details on request

---

## Testing Criteria

- [ ] Logs written to tmp/authorship-tool.log
- [ ] Log level filtering works correctly
- [ ] Timestamps accurate and formatted consistently
- [ ] Context information included in logs
- [ ] Log rotation occurs at size threshold
- [ ] Errors reported to user clearly
- [ ] Fallback warnings create notifications
- [ ] API functions accessible from modules
- [ ] Log file readable and greppable

---

## Dependencies

- 104 (configuration system) - log level from config

---

## Blocks

- All other issues benefit from logging
