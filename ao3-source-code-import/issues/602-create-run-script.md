# 602: Create Run Script

## Status
- [ ] Not started

## Current Behavior

No run script exists.

## Intended Behavior

A bash wrapper script that:
- Sets up environment
- Updates transcripts before archiving
- Runs the main Lua program
- Handles errors gracefully
- Can be run from any directory

## Script Template

```bash
#!/bin/bash
# ao3-source-code-import run script
# Archives source code repositories to AO3 for preservation
#
# Usage: ./run [--project PATH] [--dry-run] [--update] [--self]

# {{{ Configuration
DIR="${1:-/home/ritz/programming/ai-stuff/ao3-source-code-import}"
SCRIPTS_DIR="/home/ritz/programming/ai-stuff/scripts"
PROJECT_DIR="${DIR}"
# }}}

# {{{ update_transcripts
update_transcripts() {
    local target="$1"
    echo "Updating transcripts for: ${target}"
    "${SCRIPTS_DIR}/backup-conversations" "${target}"
    "${SCRIPTS_DIR}/claude-conversation-exporter.sh" -v4 "${target}"
}
# }}}

# {{{ main
main() {
    local project="${PROJECT_DIR}"
    local dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project) project="$2"; shift 2 ;;
            --dry-run) dry_run=true; shift ;;
            --self) project="${DIR}"; shift ;;
            *) shift ;;
        esac
    done

    # Update transcripts
    update_transcripts "${project}"

    # Run main program
    if $dry_run; then
        luajit "${DIR}/src/main.lua" "${project}" --dry-run
    else
        luajit "${DIR}/src/main.lua" "${project}"
    fi
}
# }}}

main "$@"
```

## Suggested Implementation Steps

1. Create run script at project root
2. Add transcript update integration
3. Add argument parsing
4. Make executable (chmod +x)
5. Test with dry-run
6. Document usage

## Related Documents

- 601-build-main-cli.md
- 205-include-llm-transcripts.md
- /home/ritz/programming/ai-stuff/scripts/backup-conversations

## Notes

This is the one command to run it all. Must be robust.
