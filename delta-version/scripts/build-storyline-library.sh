#!/bin/bash
# build-storyline-library.sh - gathers every LLM transcript across the whole
# ai-stuff collection onto one chronological bookshelf of symlinks, so the
# storyline of programming can be read from beginning to end.
#
# How, in general terms: each project keeps its own diary in llm-transcripts/.
# This script walks every project (plus any external directories registered in
# delta-version's config), recognizes real transcripts by their header line
# (never by filename), derives each one's start date from the date token in
# its name, and plants a symlink called "YYYY-MM-DD_<project>_<original-name>"
# in delta-version/library/storyline/. Because every name begins with an ISO
# date, a plain alphabetical listing IS the chronology - sessions from
# different projects interleave on the days they actually overlapped.
#
# The library is a regenerated artifact, never curated by hand: each run
# removes the previous symlinks and rebuilds from what is actually on disk,
# so new sessions, renames, and deletions all converge without cleanup.
# Files whose names carry no parseable date are reported loudly and excluded,
# never guessed into the timeline.
#
# Exit codes: 0 = clean build; 2 = build completed but some files were
# excluded or warned about (read the report); 1 = hard error, nothing built.
#
# Created by issue 057 (centralized transcript storyline library).

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"

LIBRARY_SUBPATH="delta-version/library/storyline"
CONFIG_SUBPATH="delta-version/config/external-projects.conf"
RULEBOOK_SUBPATH="scripts/libs/transcript-discovery.sh"

# Accumulators for the final report. EXCLUDED holds one human-readable line
# per file left off the shelf, so nothing ever vanishes silently.
EXCLUDED=()
LINKED_COUNT=0
EARLIEST_DATE=""
LATEST_DATE=""

# -- {{{ print_usage
function print_usage() {
    cat <<'USAGE'
Usage: build-storyline-library.sh [--dir <ai-stuff-root>] [--help]

Rebuilds delta-version/library/storyline/ - a directory of symlinks, one per
LLM transcript anywhere in the collection, named so that alphabetical order
is chronological order. Safe to re-run at any time; it converges.

  --dir <path>   Override the ai-stuff root (default: hard-coded DIR above,
                 or the DIR environment variable).
  --help         Show this text.
USAGE
}
# }}}

# -- {{{ parse_arguments
function parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            # --dir re-roots the whole run; everything downstream is relative
            # to DIR so this one assignment moves the world.
            --dir)
                [ -n "${2:-}" ] || { echo "ERROR: --dir needs a path" >&2; exit 1; }
                DIR="$2"
                shift 2
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                echo "ERROR: unknown argument: $1" >&2
                print_usage >&2
                exit 1
                ;;
        esac
    done
}
# }}}

# -- {{{ load_shared_rulebook
function load_shared_rulebook() {
    # The shared rulebook owns transcript recognition and date parsing. If it
    # is missing we stop dead rather than reimplement half of it here - two
    # copies of the rules is how toolchains drift apart.
    local rulebook="$DIR/$RULEBOOK_SUBPATH"
    if [ ! -f "$rulebook" ]; then
        echo "ERROR: shared rulebook not found: $rulebook" >&2
        echo "       (is --dir / DIR pointing at the ai-stuff root?)" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$rulebook"
}
# }}}

# -- {{{ discover_transcript_directories
function discover_transcript_directories() {
    # Emits one line per transcript directory: "<origin>\t<project>\t<path>".
    # origin is "monorepo" or "external" - the builder links the two kinds
    # differently (relative vs absolute targets), so the distinction rides
    # along from discovery.
    local d
    for d in "$DIR"/*/llm-transcripts; do
        [ -d "$d" ] || continue
        printf 'monorepo\t%s\t%s\n' "$(basename "$(dirname "$d")")" "$d"
    done

    # External roots come from the [external_directories] section of the
    # existing config (symbolic_name=absolute_path). A configured-but-missing
    # root is reported per the config's own warn_on_missing_directories rule.
    local config="$DIR/$CONFIG_SUBPATH"
    [ -f "$config" ] || return 0
    local in_section=0 line root
    while IFS= read -r line; do
        case "$line" in
            # Section fences: only lines between [external_directories] and
            # the next [section] are ours.
            "[external_directories]") in_section=1; continue ;;
            "["*"]")                  in_section=0; continue ;;
        esac
        [ "$in_section" = 1 ] || continue
        case "$line" in ''|'#'*) continue ;; esac
        root="${line#*=}"
        if [ ! -d "$root" ]; then
            EXCLUDED+=("external root missing (configured but absent): $root")
            continue
        fi
        for d in "$root"/*/llm-transcripts; do
            [ -d "$d" ] || continue
            printf 'external\t%s\t%s\n' "$(basename "$(dirname "$d")")" "$d"
        done
    done < "$config"
}
# }}}

# -- {{{ clear_stale_links
function clear_stale_links() {
    # Regeneration is surgical: we delete only symlinks, because symlinks are
    # the only thing this script creates. A regular file in the storyline
    # directory means a human (or a bug) put something there by hand - we
    # refuse to touch the directory rather than risk destroying it.
    local library_dir="$1"
    local entry
    for entry in "$library_dir"/* "$library_dir"/.*; do
        case "$(basename "$entry")" in .|..) continue ;; esac
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        if [ -L "$entry" ]; then
            rm "$entry"
        else
            echo "ERROR: non-symlink found in the storyline library: $entry" >&2
            echo "       This directory is generated; move that file elsewhere." >&2
            exit 1
        fi
    done
}
# }}}

# -- {{{ link_one_transcript
function link_one_transcript() {
    local origin="$1" project="$2" transcript_dir="$3" filepath="$4"
    local library_dir="$5"
    local fname iso_date link_name target

    fname="$(basename "$filepath")"

    # The date comes from the filename's token, via the shared rulebook. The
    # in-file "Generated on:" line records when the EXPORT ran, not when the
    # session happened, so it would order the shelf wrongly - filename or bust.
    if ! iso_date="$(transcript_basename_start_ymd "$fname")"; then
        EXCLUDED+=("no parseable date token in name: $project/$fname")
        return 1
    fi

    link_name="${iso_date}_${project}_${fname}"

    # Two transcripts can only collide here if two discovered projects share a
    # name (e.g. a monorepo project shadowed by an external one). First
    # claimant keeps the spot; the second is reported, not silently dropped.
    if [ -e "$library_dir/$link_name" ] || [ -L "$library_dir/$link_name" ]; then
        EXCLUDED+=("shelf collision (duplicate project name?): $link_name")
        return 1
    fi

    if [ "$origin" = "monorepo" ]; then
        # Relative target: storyline/ -> library/ -> delta-version/ -> root.
        # The whole ai-stuff tree can move between machines or mounts and
        # every link keeps working, because nothing records an absolute path.
        target="../../../${project}/llm-transcripts/${fname}"
    else
        # External projects live outside the tree that moves as a unit, so a
        # relative path would encode the CURRENT distance between two
        # unrelated locations - fragile. Absolute is the honest choice here.
        target="${transcript_dir}/${fname}"
    fi

    ln -s "$target" "$library_dir/$link_name"
    LINKED_COUNT=$((LINKED_COUNT + 1))

    # ISO dates compare correctly as plain strings - that is the whole reason
    # the shelf uses them as prefixes.
    if [ -z "$EARLIEST_DATE" ] || [[ "$iso_date" < "$EARLIEST_DATE" ]]; then
        EARLIEST_DATE="$iso_date"
    fi
    if [ -z "$LATEST_DATE" ] || [[ "$iso_date" > "$LATEST_DATE" ]]; then
        LATEST_DATE="$iso_date"
    fi
}
# }}}

# -- {{{ build_links
function build_links() {
    local library_dir="$1"
    local origin project transcript_dir filepath
    while IFS=$'\t' read -r origin project transcript_dir; do
        # transcript_list_files applies the header test, so word clouds,
        # analytics exports, and hand-written notes never reach the shelf.
        while IFS= read -r filepath; do
            link_one_transcript "$origin" "$project" "$transcript_dir" \
                "$filepath" "$library_dir" || true
        done < <(transcript_list_files "$transcript_dir")
    done < <(discover_transcript_directories)
}
# }}}

# -- {{{ print_report
function print_report() {
    echo ""
    echo "storyline library rebuilt: $DIR/$LIBRARY_SUBPATH"
    echo "  transcripts shelved : $LINKED_COUNT"
    if [ -n "$EARLIEST_DATE" ]; then
        echo "  storyline spans     : $EARLIEST_DATE -> $LATEST_DATE"
    fi
    if [ ${#EXCLUDED[@]} -gt 0 ]; then
        # The loud part: every excluded file, by name, with its reason, on
        # stderr. Silence here would be a lie about coverage.
        {
            echo ""
            echo "  EXCLUDED (${#EXCLUDED[@]}) - these are NOT on the shelf:"
            local reason
            for reason in "${EXCLUDED[@]}"; do
                echo "    - $reason"
            done
            echo "  (a date-less name is a husk or straggler; re-run backup-conversations on that project to fix or retire it)"
        } >&2
    fi
}
# }}}

# -- {{{ main
function main() {
    parse_arguments "$@"
    load_shared_rulebook

    local library_dir="$DIR/$LIBRARY_SUBPATH"
    mkdir -p "$library_dir"
    clear_stale_links "$library_dir"
    build_links "$library_dir"
    print_report

    # Exit 2 distinguishes "built, but incomplete coverage" from a clean 0,
    # so cron jobs and tests can notice exclusions without parsing prose.
    [ ${#EXCLUDED[@]} -eq 0 ] || exit 2
    exit 0
}
# }}}

main "$@"
