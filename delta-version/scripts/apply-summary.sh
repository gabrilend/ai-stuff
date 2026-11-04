#!/bin/bash
# apply-summary.sh - folds a transcript's summary into its folder: an entry
# in the folder's table of contents, a short block at the top of the
# transcript, and, only when the configuration turns it on, a new file name.
#
# In plain terms: summarize-transcript.lua (issue 056b) reads a saved
# conversation and prints a record with a title, a slug and a paragraph. This
# takes that record and:
#   1. adds or updates the conversation's entry in
#      llm-transcripts/table-of-contents.md (title, link, paragraph);
#   2. puts the paragraph at the top of the transcript, under its header line,
#      marked so a second run replaces it instead of adding another;
#   3. renames the transcript to <slug>-<date>.md, but only with
#      "rename=on" in the configuration's [apply] section, and only once the
#      shared transcript rulebook accepts such names. Until then the exporter
#      would rename the file straight back, so the rename is held back and
#      the run says why.
# Issue 056c. Renames are off by default.
#
# Usage:
#   apply-summary.sh TRANSCRIPT RECORD [--dir MONOREPO] [--config FILE] [--dry-run]
#     RECORD     the plain record summarize-transcript.lua wrote
#     --dir      the monorepo (default below); the shared rulebook is read from
#                MONOREPO/scripts/libs unless SCRIPTS_DIR is set
#     --config   default MONOREPO/delta-version/config/transcript-summary-repos.conf
#     --dry-run  say what would change and change nothing
#
# Exit status: 0 applied (a held-back rename still counts), 1 a write or a
# move failed, 2 usage error, unreadable input, or a record for another
# conversation.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"

SUMMARY_MARKER="<!-- transcript-summary v1 -->"
SEPARATOR="--------------------------------------------------------------------------------"

# -- {{{ fail
function fail() {
    echo "apply-summary: $2" >&2
    exit "$1"
}
# }}}

# -- {{{ parse_arguments
function parse_arguments() {
    TRANSCRIPT="" RECORD="" CONFIG="" DRY_RUN=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir)     [[ -n "${2:-}" ]] || fail 2 "--dir needs a folder"; DIR="$2"; shift 2 ;;
            --config)  [[ -n "${2:-}" ]] || fail 2 "--config needs a file"; CONFIG="$2"; shift 2 ;;
            --dry-run) DRY_RUN=true; shift ;;
            --help|-h) sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
            --*)       fail 2 "unknown option $1" ;;
            *)
                if [[ -z "$TRANSCRIPT" ]]; then TRANSCRIPT="$1"
                elif [[ -z "$RECORD" ]]; then RECORD="$1"
                else fail 2 "too many arguments"; fi
                shift ;;
        esac
    done
    [[ -n "$TRANSCRIPT" && -n "$RECORD" ]] || fail 2 "usage: apply-summary.sh TRANSCRIPT RECORD [--dir MONOREPO] [--config FILE] [--dry-run]"
    CONFIG="${CONFIG:-$DIR/delta-version/config/transcript-summary-repos.conf}"
    SCRIPTS_DIR="${SCRIPTS_DIR:-$DIR/scripts}"
}
# }}}

# -- {{{ config_value
function config_value() {
    # Key $2 in section [$1] of the configuration, or $3 when absent.
    local wanted="$1" key="$2" default="$3" line in_section=false k v
    if [[ -f "$CONFIG" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
            if [[ "$line" =~ ^\[([^]]+)\][[:space:]]*$ ]]; then
                [[ "${BASH_REMATCH[1]}" == "$wanted" ]] && in_section=true || in_section=false
                continue
            fi
            if [[ "$in_section" == true && "$line" =~ ^[[:space:]]*([^=[:space:]]+)[[:space:]]*=[[:space:]]*(.*[^[:space:]])?[[:space:]]*$ ]]; then
                k="${BASH_REMATCH[1]}" v="${BASH_REMATCH[2]}"
                [[ "$k" == "$key" ]] && { printf '%s\n' "$v"; return; }
            fi
        done < "$CONFIG"
    fi
    printf '%s\n' "$default"
}
# }}}

# -- {{{ is_on
function is_on() { case "${1,,}" in on|yes|true|1) return 0 ;; *) return 1 ;; esac; }
# }}}

# -- {{{ read_record
function read_record() {
    # Sets REC_CONVERSATION, REC_TITLE, REC_SLUG and REC_BLURB from the record.
    [[ -r "$RECORD" ]] || fail 2 "cannot read the record $RECORD"
    [[ "$(head -1 "$RECORD")" == "transcript-summary v1" ]] \
        || fail 2 "$RECORD is not a transcript-summary v1 record"
    REC_CONVERSATION=$(sed -n 's/^conversation: //p' "$RECORD" | head -1)
    REC_TITLE=$(sed -n 's/^title: //p' "$RECORD" | head -1)
    REC_SLUG=$(sed -n 's/^slug: //p' "$RECORD" | head -1)
    REC_BLURB=$(awk '/^## Blurb$/ {on = 1; next} /^## / {on = 0} on' "$RECORD" \
        | sed -e '/^[[:space:]]*$/d' | tr '\n' ' ' | sed -e 's/[[:space:]]*$//')
    [[ -n "$REC_TITLE" && -n "$REC_SLUG" && -n "$REC_BLURB" ]] \
        || fail 2 "$RECORD lacks a title, a slug or a blurb"
    [[ "$REC_SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail 2 "the record's slug '$REC_SLUG' is not lowercase words joined by -"
}
# }}}

# -- {{{ update_table_of_contents
function update_table_of_contents() {
    # Adds or replaces this conversation's entry, keyed by its id, so the
    # entry follows the file through a rename and a rerun never doubles it.
    local toc="$1" link="$2" entry tmp
    entry=$(printf '<!-- transcript-summary: %s -->\n## [%s](%s)\n\n%s\n' \
        "$REC_CONVERSATION" "$REC_TITLE" "$link" "$REC_BLURB")
    if [[ "$DRY_RUN" == true ]]; then
        if [[ -f "$toc" ]] && grep -qF "<!-- transcript-summary: $REC_CONVERSATION -->" "$toc"; then
            echo "would update the entry in $toc"
        else
            echo "would add an entry to $toc"
        fi
        return 0
    fi
    if [[ ! -f "$toc" ]]; then
        printf '# Table of Contents\n\nOne entry per summarised conversation in this folder, written by\ndelta-version/scripts/apply-summary.sh. Each title links to its transcript.\n' > "$toc" || return 1
    fi
    tmp=$(mktemp "$toc.XXXXXX") || return 1
    # Drop the old entry (its marker line up to the next marker), then append.
    awk -v marker="<!-- transcript-summary: $REC_CONVERSATION -->" '
        $0 == marker { skipping = 1; next }
        skipping && /^<!-- transcript-summary: / { skipping = 0 }
        !skipping { print }
    ' "$toc" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$tmp" || { rm -f "$tmp"; return 1; }
    printf '\n%s\n' "$entry" >> "$tmp"
    mv "$tmp" "$toc" || return 1
    echo "table of contents: $toc"
}
# }}}

# -- {{{ update_inline_block
function update_inline_block() {
    # The paragraph goes right under the header line, between the marker and
    # a separator, replacing any block an earlier run left.
    local transcript="$1" tmp
    if [[ "$DRY_RUN" == true ]]; then
        if grep -qxF "$SUMMARY_MARKER" "$transcript"; then
            echo "would replace the summary block in $transcript"
        else
            echo "would add a summary block to $transcript"
        fi
        return 0
    fi
    tmp=$(mktemp "$transcript.XXXXXX") || return 1
    awk -v marker="$SUMMARY_MARKER" -v sep="$SEPARATOR" -v blurb="$REC_BLURB" '
        NR == 1 {
            print
            print marker
            print "## Session Summary"
            print blurb
            print ""
            print sep
            next
        }
        NR == 2 && $0 == marker { skipping = 1; next }
        skipping { if ($0 == sep) skipping = 0; next }
        { print }
    ' "$transcript" > "$tmp" || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$transcript" || return 1
    echo "summary block: $transcript"
}
# }}}

# -- {{{ rulebook_accepts_slug_names
function rulebook_accepts_slug_names() {
    # The exporter re-derives every transcript's name and puts back any name
    # the rulebook does not recognise. Ask the rulebook itself.
    transcript_is_new_format "$REC_SLUG-$(transcript_strip_suffix "$1").md"
}
# }}}

# -- {{{ rename_transcript
function rename_transcript() {
    # Prints the transcript's path after this step (renamed or not).
    local transcript="$1" folder base target file
    folder=$(dirname "$transcript")
    base=$(transcript_strip_suffix "$transcript")
    if [[ "$base" == "$REC_SLUG"-* ]]; then
        echo "$transcript"; return 0                     # already carries its slug
    fi
    if ! rulebook_accepts_slug_names "$transcript"; then
        {
            echo "rename held back: the shared rulebook ($SCRIPTS_DIR/libs/transcript-discovery.sh)"
            echo "  does not accept '$REC_SLUG-$base.md' as a transcript name, so the exporter"
            echo "  would rename it back. The scripts project has to widen transcript_is_new_format"
            echo "  and the exporter's claim comparison first (issue 056, step 3)."
        } >&2
        echo "$transcript"; return 0
    fi
    target=$(transcript_pick_free_name "$folder" "$REC_SLUG-$base" "$transcript") || return 1
    if [[ "$DRY_RUN" == true ]]; then
        echo "would rename $(basename "$transcript") to $(basename "$target")" >&2
        echo "$transcript"; return 0
    fi
    if git -C "$folder" ls-files --error-unmatch "$(basename "$transcript")" > /dev/null 2>&1; then
        git -C "$folder" mv "$(basename "$transcript")" "$(basename "$target")" || return 1
    else
        mv "$transcript" "$target" || return 1
    fi
    echo "renamed: $(basename "$transcript") -> $(basename "$target")" >&2
    # Links to it from the other files in its folder follow it. Mentions
    # anywhere else are listed, not edited: another project's folder can
    # hold a different transcript with the same date name.
    for file in "$folder"/*.md; do
        [[ -f "$file" ]] || continue
        if grep -qF "]($(basename "$transcript"))" "$file"; then
            sed -i "s|]($(basename "$transcript"))|]($(basename "$target"))|g" "$file"
            echo "  link updated in $(basename "$file")" >&2
        fi
    done
    local top prefix
    top=$(git -C "$folder" rev-parse --show-toplevel 2>/dev/null)
    prefix=$(git -C "$folder" rev-parse --show-prefix 2>/dev/null)
    if [[ -n "$top" ]]; then
        git -C "$top" grep -l -F "$(basename "$transcript")" -- . ":(exclude)${prefix}*" 2>/dev/null \
            | sed 's/^/  still mentions the old name (not edited): /' >&2
    fi
    echo "$target"
}
# }}}

# -- {{{ main
function main() {
    parse_arguments "$@"
    [[ -r "$TRANSCRIPT" ]] || fail 2 "cannot read the transcript $TRANSCRIPT"
    local rulebook="$SCRIPTS_DIR/libs/transcript-discovery.sh"
    [[ -r "$rulebook" ]] || fail 2 "cannot read the shared rulebook $rulebook"
    # shellcheck source=/dev/null
    source "$rulebook"
    transcript_is_summary "$TRANSCRIPT" || fail 2 "$TRANSCRIPT does not open with a conversation header"
    read_record
    local id
    id=$(transcript_conv_id "$TRANSCRIPT")
    [[ "$id" == "$REC_CONVERSATION" ]] \
        || fail 2 "the record is for conversation '$REC_CONVERSATION', the transcript is '$id'"

    local transcript="$TRANSCRIPT" toc_name
    toc_name=$(config_value apply table_of_contents table-of-contents.md)
    [[ "$DRY_RUN" == true ]] && echo "dry run: nothing is changed"

    if is_on "$(config_value apply rename off)"; then
        transcript=$(rename_transcript "$transcript") || fail 1 "the rename failed"
    fi
    if is_on "$(config_value apply inline_blurb on)"; then
        update_inline_block "$transcript" || fail 1 "could not write the summary block into $transcript"
    fi
    update_table_of_contents "$(dirname "$transcript")/$toc_name" "$(basename "$transcript")" \
        || fail 1 "could not write the table of contents"
}
# }}}

main "$@"
