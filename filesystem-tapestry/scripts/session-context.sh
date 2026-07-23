#!/bin/bash
# session-context.sh — pour the whole project history into a fresh session.
#
# What it is (for a general): whenever a new Claude session opens on this
# project, this gathers every saved conversation transcript in llm-transcripts/
# and hands the lot to the new session as its starting context. The session
# begins already knowing everything done here before -- so it can continue the
# prior thread, or start entirely new work, without anyone re-explaining the
# past. It is run automatically by the project's SessionStart hook (see
# .claude/settings.json); nobody has to remember to run it.
#
# Output: a single JSON object on stdout in the hook's additionalContext form.
# Override the project location with a first argument or the TAPESTRY_DIR env var.

set -u
DIR="${1:-${TAPESTRY_DIR:-/home/ritz/programming/ai-stuff/filesystem-tapestry}}"
TRANSCRIPTS="${DIR}/llm-transcripts"

# -- {{{ gather
# Concatenate every transcript, oldest first, each under a divider naming its
# file. The preamble tells the reading session what this is and how to use it:
# continue from it, or start fresh, but be aware of all of it.
gather() {
    printf '=== FILESYSTEM TAPESTRY -- COMPLETE PRIOR SESSION HISTORY ===\n'
    printf 'Everything below is the full llm-transcripts/ record of this project.\n'
    printf 'Take it in as the entire memory of what has been done here. You may\n'
    printf 'continue from where the last session left off, or begin new work --\n'
    printf 'either way, you are now aware of all of it.\n\n'

    if [ ! -d "$TRANSCRIPTS" ]; then
        printf '(no llm-transcripts/ directory yet -- this is the first session)\n'
        return
    fi

    local any=false
    local f
    # Sorted glob = chronological order, since transcripts are date-named.
    for f in "$TRANSCRIPTS"/*.md; do
        [ -e "$f" ] || continue
        any=true
        printf -- '----- transcript: %s -----\n' "$(basename "$f")"
        cat "$f"
        printf '\n\n'
    done
    if [ "$any" = false ]; then
        printf '(llm-transcripts/ is empty -- this is the first session)\n'
    fi
}
# }}}

context="$(gather)"

# Emit in the SessionStart hook's additionalContext form. jq performs the JSON
# string escaping, so a transcript full of quotes, backticks, or newlines can
# never break the envelope.
jq -n --arg ctx "$context" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
