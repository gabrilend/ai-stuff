#!/bin/bash
# summarize-overseer.sh - finds the saved conversations that have no summary
# yet, in every repository in scope, and (only when the configuration turns
# it on) summarizes each one and folds the summary in.
#
# In plain terms: Claude Code keeps every session under ~/.claude/projects/,
# and each session records the folder it ran in. Those folders say which
# repositories have conversations. For each repository in scope (inside the
# ai-stuff root, or listed in [extra_repos]), this looks at its
# llm-transcripts/ folder and picks out the transcripts no summary has been
# applied to yet. A transcript counts as summarized when its folder's table
# of contents has its entry, or it carries the summary block.
#
# By default it only says what it would do. With "run=on" in the
# configuration's [overseer] section it runs, for each transcript in turn,
# summarize-transcript.lua (issue 056b) and apply-summary.sh (056c), at most
# max_per_run of them per run. Two more settings there, both off by
# default:
#   export=on   first export each repository's sessions again
#               (scripts/backup-conversations --all REPO), for sessions the
#               reply hook missed
#   commit=on   commit the files it changed in each repository (only those
#               files), one commit per repository
# Issue 056d. Install it on a schedule by hand if wanted; it installs nothing.
#
# Usage:
#   summarize-overseer.sh [--dir MONOREPO] [--config FILE] [--repo PATH] [--dry-run]
#     --dir      the monorepo (default below)
#     --config   default MONOREPO/delta-version/config/transcript-summary-repos.conf
#     --repo     only this repository
#     --dry-run  say what would be done even when run=on
#
# EXPORTER, SUMMARIZER and APPLIER in the environment replace the three
# tools it calls (tests use this). INFERENCE_CHAT_HOST moves the model.
# Exit status: 0 done (or nothing to do), 1 some transcript failed (the rest
# were still done), 2 usage error or an unreadable configuration.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"

SUMMARY_MARKER="<!-- transcript-summary v1 -->"

# -- {{{ fail
function fail() {
    echo "summarize-overseer: $2" >&2
    exit "$1"
}
# }}}

# -- {{{ parse_arguments
function parse_arguments() {
    CONFIG="" ONLY_REPO="" DRY_RUN=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir)     [[ -n "${2:-}" ]] || fail 2 "--dir needs a folder"; DIR="$2"; shift 2 ;;
            --config)  [[ -n "${2:-}" ]] || fail 2 "--config needs a file"; CONFIG="$2"; shift 2 ;;
            --repo)    [[ -n "${2:-}" ]] || fail 2 "--repo needs a folder"; ONLY_REPO="${2%/}"; shift 2 ;;
            --dry-run) DRY_RUN=true; shift ;;
            --help|-h) sed -n '2,37p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *)         fail 2 "unknown argument $1 (see --help)" ;;
        esac
    done
    CONFIG="${CONFIG:-$DIR/delta-version/config/transcript-summary-repos.conf}"
    SCRIPTS_DIR="${SCRIPTS_DIR:-$DIR/scripts}"
    EXPORTER="${EXPORTER:-$SCRIPTS_DIR/backup-conversations}"
    SUMMARIZER="${SUMMARIZER:-luajit $DIR/delta-version/scripts/summarize-transcript.lua}"
    APPLIER="${APPLIER:-$DIR/delta-version/scripts/apply-summary.sh}"
    [[ -r "$CONFIG" ]] || fail 2 "cannot read the configuration $CONFIG"
    if [[ -n "$ONLY_REPO" ]]; then
        [[ -d "$ONLY_REPO" ]] || fail 2 "$ONLY_REPO is not a folder"
        ONLY_REPO=$(realpath "$ONLY_REPO")
    fi
}
# }}}

# -- {{{ config_value
function config_value() {
    # Key $2 in section [$1] of the configuration, or $3 when absent.
    local wanted="$1" key="$2" default="$3" line in_section=false k v
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
    printf '%s\n' "$default"
}
# }}}

# -- {{{ section_lines
function section_lines() {
    # The non-comment lines of section [$1] that are not key=value pairs.
    local wanted="$1" line in_section=false
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
        if [[ "$line" =~ ^\[([^]]+)\][[:space:]]*$ ]]; then
            [[ "${BASH_REMATCH[1]}" == "$wanted" ]] && in_section=true || in_section=false
            continue
        fi
        [[ "$in_section" == true && "$line" != *=* ]] && printf '%s\n' "$(sed 's/[[:space:]]*$//' <<< "$line")"
    done < "$CONFIG"
}
# }}}

# -- {{{ is_on
function is_on() { case "${1,,}" in on|yes|true|1) return 0 ;; *) return 1 ;; esac; }
# }}}

# -- {{{ repo_for_cwd
function repo_for_cwd() {
    # The repository in scope that a session's folder belongs to, or nothing.
    # Inside the ai-stuff root that is the project folder (the root's child);
    # outside it, the listed repository the folder sits in.
    local cwd="${1%/}" extra rest
    if is_on "$INCLUDE_ALL" && [[ "$cwd" == "$ROOT" || "$cwd" == "$ROOT"/* ]]; then
        rest="${cwd#"$ROOT"}"
        rest="${rest#/}"
        if [[ -z "$rest" ]]; then echo "$ROOT"; else echo "$ROOT/${rest%%/*}"; fi
        return
    fi
    while IFS= read -r extra; do
        extra="${extra%/}"
        [[ -n "$extra" ]] || continue
        if [[ "$cwd" == "$extra" || "$cwd" == "$extra"/* ]]; then echo "$extra"; return; fi
    done <<< "$EXTRA_REPOS"
}
# }}}

# -- {{{ repos_in_scope
function repos_in_scope() {
    # One repository per line, sorted, from the sessions' own "cwd" fields
    # (the dashed folder names under ~/.claude/projects are ambiguous).
    local session cwd repo
    [[ -d "$CLAUDE_PROJECTS" ]] || { echo "summarize-overseer: no sessions folder $CLAUDE_PROJECTS" >&2; return; }
    while IFS= read -r -d '' session; do
        cwd=$(grep -m1 -o '"cwd":"[^"]*"' "$session" 2>/dev/null | head -1 | sed 's/^"cwd":"//; s/"$//')
        [[ -n "$cwd" ]] || continue
        repo=$(repo_for_cwd "$cwd")
        [[ -n "$repo" ]] && echo "$repo"
    done < <(find "$CLAUDE_PROJECTS" -maxdepth 2 -name '*.jsonl' -type f -print0 2>/dev/null)
}
# }}}

# -- {{{ is_summarized
function is_summarized() {
    # A transcript is summarized when its folder's table of contents has its
    # entry, or its second line is the summary block's marker.
    local transcript="$1" toc id
    toc="$(dirname "$transcript")/$TOC_NAME"
    id=$(transcript_conv_id "$transcript") || return 1
    [[ -f "$toc" ]] && grep -qxF "<!-- transcript-summary: $id -->" "$toc" && return 0
    [[ "$(sed -n 2p "$transcript")" == "$SUMMARY_MARKER" ]]
}
# }}}

# -- {{{ summarize_one
function summarize_one() {
    # Summarize one transcript and fold the summary in. Prints what changed.
    local transcript="$1" record
    record="$WORK/$(basename "$transcript").record"
    if ! $SUMMARIZER "$transcript" --out="$record" --quiet > "$WORK/out" 2>&1; then
        echo "  failed to summarize $(basename "$transcript"): $(tail -1 "$WORK/out")"
        return 1
    fi
    if ! "$APPLIER" "$transcript" "$record" --dir "$DIR" --config "$CONFIG" > "$WORK/out" 2>&1; then
        echo "  failed to apply the summary of $(basename "$transcript"): $(tail -1 "$WORK/out")"
        return 1
    fi
    TOUCHED+=("llm-transcripts/$(basename "$transcript")" "llm-transcripts/$TOC_NAME")
    local renamed
    renamed=$(sed -n 's/^renamed: .* -> //p' "$WORK/out" | head -1)
    [[ -n "$renamed" ]] && TOUCHED+=("llm-transcripts/$renamed")
    echo "  summarized $(basename "$transcript")"
}
# }}}

# -- {{{ commit_repo
function commit_repo() {
    # Commit only the files this run changed in the repository (TOUCHED,
    # relative to it), leaving anything else staged or not as it was.
    local repo="$1" count="$2" path
    git -C "$repo" rev-parse --git-dir > /dev/null 2>&1 || { echo "  not a git repository: nothing committed"; return 0; }
    local -a present=() paths
    mapfile -t paths < <(printf '%s\n' "${TOUCHED[@]}" | sort -u)
    for path in "${paths[@]}"; do [[ -e "$repo/$path" ]] && present+=("$path"); done
    if git -C "$repo" add -- "${present[@]}" \
        && git -C "$repo" commit -q -m "Session summaries for $count conversation(s)" \
            -m "Written by delta-version/scripts/summarize-overseer.sh (issue 056)." -- "${paths[@]}"; then
        echo "  committed: $(git -C "$repo" log -1 --format=%h)"
    else
        echo "  the commit failed; the changes are left in the working tree"
        return 1
    fi
}
# }}}

# -- {{{ main
function main() {
    parse_arguments "$@"
    local rulebook="$SCRIPTS_DIR/libs/transcript-discovery.sh"
    [[ -r "$rulebook" ]] || fail 2 "cannot read the shared rulebook $rulebook"
    # shellcheck source=/dev/null
    source "$rulebook"

    INCLUDE_ALL=$(config_value settings include_all_ai_stuff true)
    ROOT=$(config_value settings ai_stuff_root "$DIR")
    ROOT="${ROOT%/}"
    CLAUDE_PROJECTS=$(config_value settings claude_projects_dir "$HOME/.claude/projects")
    EXTRA_REPOS=$(section_lines extra_repos)
    TOC_NAME=$(config_value apply table_of_contents table-of-contents.md)
    local run_on export_on commit_on most
    run_on=$(config_value overseer run off)
    export_on=$(config_value overseer export off)
    commit_on=$(config_value overseer commit off)
    most=$(config_value overseer max_per_run 10)
    [[ "$most" =~ ^[1-9][0-9]*$ ]] || fail 2 "max_per_run in [overseer] must be a whole number, 1 or more"

    local acting=false
    is_on "$run_on" && [[ "$DRY_RUN" == false ]] && acting=true
    if [[ "$acting" == false ]]; then
        if is_on "$run_on"; then echo "dry run: nothing is changed"
        else echo "preview only: run=off in [overseer] of $CONFIG, so nothing is changed"; fi
    fi

    local repos
    repos=$(repos_in_scope | sort -u)
    if [[ -n "$ONLY_REPO" ]]; then
        repos=$(grep -xF "$ONLY_REPO" <<< "$repos")
        [[ -n "$repos" ]] || { echo "$ONLY_REPO has no sessions in scope"; return 0; }
    fi
    [[ -n "$repos" ]] || { echo "no repository in scope has sessions"; return 0; }

    WORK=$(mktemp -d)
    trap 'rm -rf "$WORK"' EXIT
    local repo transcript done_total=0 failed=0 left=0 todo summarized count
    while IFS= read -r repo; do
        if [[ ! -d "$repo/llm-transcripts" ]]; then
            echo "$repo: no llm-transcripts/ folder"
            continue
        fi
        if is_on "$export_on"; then
            if [[ "$acting" == true ]]; then
                "$EXPORTER" --all "$repo" > "$WORK/out" 2>&1 \
                    || echo "$repo: the export failed: $(tail -1 "$WORK/out")"
            else
                echo "$repo: would export its sessions again ($EXPORTER --all)"
            fi
        fi
        todo=() summarized=0 TOUCHED=()
        while IFS= read -r transcript; do
            [[ -n "$transcript" ]] || continue
            if is_summarized "$transcript"; then summarized=$((summarized + 1)); else todo+=("$transcript"); fi
        done < <(transcript_list_files "$repo/llm-transcripts" | sort)
        echo "$repo: $((summarized + ${#todo[@]})) transcripts, $summarized summarized, ${#todo[@]} to do"
        count=0
        for transcript in "${todo[@]}"; do
            if [[ $done_total -ge $most ]]; then
                left=$((left + 1))
                continue
            fi
            done_total=$((done_total + 1))
            if [[ "$acting" == true ]]; then
                if summarize_one "$transcript"; then count=$((count + 1)); else failed=$((failed + 1)); fi
            else
                echo "  would summarize $(basename "$transcript")"
            fi
        done
        if [[ "$acting" == true && $count -gt 0 ]] && is_on "$commit_on"; then
            commit_repo "$repo" "$count" || failed=$((failed + 1))
        fi
    done <<< "$repos"
    [[ $left -gt 0 ]] && echo "$left more left for later runs (max_per_run=$most)"
    [[ $failed -gt 0 ]] && { echo "$failed failed"; return 1; }
    return 0
}
# }}}

main "$@"
