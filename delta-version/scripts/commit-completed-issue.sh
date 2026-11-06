#!/bin/bash
# commit-completed-issue.sh - closes an issue in one commit: checks the issue
# file is sound, moves it into its project's issues/completed/ folder, writes
# the line that records it in the project's progress file, and commits those
# three changes together.
#
# In general terms: every step is checked before anything changes, and if any
# later step fails (the record, the claims, the commit) the move and the
# progress file are put back exactly as they were, so the tree is left either
# with the whole closing committed or with nothing changed.
#
# Two ways to commit, chosen by who is running it:
#   - inside a Claude Code session (CLAUDE_CODE_SESSION_ID is set), through
#     the shared commit-own-changes, after claiming the move and the added
#     progress lines in the session's line ledger -- so the commit also carries
#     the session's other own lines and its transcripts, and never anyone
#     else's;
#   - by hand, with `git commit --only` on exactly the three paths, so nothing
#     else that happens to be staged rides along.
#
# Which progress file: issues/phase-N-progress.md when the issue is in phase N
# (as the shared issue-name reader judges it) and that file exists, otherwise
# issues/progress.md; with neither, it refuses.
#
# Usage:
#   commit-completed-issue.sh <issue-file> [message-file] [--dir <monorepo>] [--dry-run]
#
#   message-file  the commit message; without one it is the issue's title and
#                 a line saying the issue moved to completed/
#   --dir         the monorepo whose shared scripts/ are used
#   --dry-run     check everything and say what would happen; change nothing
#
# Exit 0 when the commit was made (or a dry run found nothing wrong), 1 when it
# refused or failed and changed nothing, 2 for bad arguments.
# Design: delta-version/issues/055-commit-gated-by-issue-completion.md.

DIR="/mnt/mtwo/programming/ai-stuff"

# The text work (id, phase, title, the progress record) lives beside this
# script, so a copy run from a worktree uses its own.
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/issue-completion.lua"

ISSUE_FILE=""
MESSAGE_FILE=""
DRY_RUN=false

# Filled in as the checks run.
ISSUE_ABS=""
ISSUES_ROOT=""
PROJECT_DIR=""
REPO_ROOT=""
DEST=""
ISSUE_ID=""
ISSUE_PHASE=""
ISSUE_TITLE=""
PROGRESS_FILE=""
PROGRESS_BACKUP=""
MOVED=false

# -- {{{ show_help
show_help() {
    sed -n '2,/^# Design:/p' "$0" | sed 's/^# \{0,1\}//'
}
# }}}

# -- {{{ refuse
refuse() {
    # One line on stderr, then undo whatever was done, then exit 1.
    echo "commit-completed-issue: $*" >&2
    undo
    exit 1
}
# }}}

# -- {{{ undo
undo() {
    # Puts the issue file and the progress file back as they were. The move
    # is undone with plain mv, which keeps the file's modified date.
    if $MOVED && [[ -f "$DEST" ]]; then
        mv "$DEST" "$ISSUE_ABS" && MOVED=false
        echo "commit-completed-issue: moved the issue back to $ISSUE_ABS" >&2
    fi
    if [[ -n "$PROGRESS_BACKUP" && -f "$PROGRESS_BACKUP" ]]; then
        cat "$PROGRESS_BACKUP" > "$PROGRESS_FILE"
        touch -r "$PROGRESS_BACKUP" "$PROGRESS_FILE"
        rm -f "$PROGRESS_BACKUP"
        PROGRESS_BACKUP=""
        echo "commit-completed-issue: put $PROGRESS_FILE back as it was" >&2
    fi
}
# }}}

# -- {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --dir)
                [[ -n "${2:-}" ]] || { echo "commit-completed-issue: --dir needs a folder" >&2; exit 2; }
                DIR="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -*)
                echo "commit-completed-issue: unknown option $1 (see --help)" >&2
                exit 2
                ;;
            *)
                if [[ -z "$ISSUE_FILE" ]]; then
                    ISSUE_FILE="$1"
                elif [[ -z "$MESSAGE_FILE" ]]; then
                    MESSAGE_FILE="$1"
                else
                    echo "commit-completed-issue: one issue file and one message file at most" >&2
                    exit 2
                fi
                shift
                ;;
        esac
    done
    if [[ -z "$ISSUE_FILE" ]]; then
        echo "usage: commit-completed-issue.sh <issue-file> [message-file] [--dir <monorepo>] [--dry-run]" >&2
        exit 2
    fi
    if [[ -n "$MESSAGE_FILE" && ! -s "$MESSAGE_FILE" ]]; then
        echo "commit-completed-issue: message file $MESSAGE_FILE is missing or empty" >&2
        exit 2
    fi
}
# }}}

# -- {{{ locate_issue
locate_issue() {
    # Where the issue is, which project it belongs to, and where it goes.
    [[ -f "$ISSUE_FILE" ]] || refuse "no such issue file: $ISSUE_FILE"
    ISSUE_ABS="$(realpath "$ISSUE_FILE")"

    # The issues/ folder is the nearest folder of that name above the file;
    # an issue in issues/phase-3/ still closes into issues/completed/.
    local folder
    folder="$(dirname "$ISSUE_ABS")"
    while [[ "$folder" != "/" && "$(basename "$folder")" != "issues" ]]; do
        case "$(basename "$folder")" in
            completed) refuse "$ISSUE_FILE is already in a completed/ folder" ;;
        esac
        folder="$(dirname "$folder")"
    done
    [[ "$folder" != "/" ]] || refuse "$ISSUE_FILE is not under an issues/ folder"
    ISSUES_ROOT="$folder"
    PROJECT_DIR="$(dirname "$ISSUES_ROOT")"
    DEST="$ISSUES_ROOT/completed/$(basename "$ISSUE_ABS")"
    [[ ! -e "$DEST" ]] || refuse "$DEST already exists"

    REPO_ROOT="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null)" \
        || refuse "$PROJECT_DIR is not in a git repository"
    git -C "$REPO_ROOT" ls-files --error-unmatch -- "$ISSUE_ABS" >/dev/null 2>&1 \
        || refuse "$ISSUE_FILE is not tracked by git; commit it before closing it"
}
# }}}

# -- {{{ check_issue_shape
check_issue_shape() {
    # The issue's own shape -- its name and its three required sections -- is
    # judged by the shared validator. Its other findings (links that only one
    # side writes down, another file's duplicate id) are about other files or
    # about the plan, and are shown without stopping the closing.
    local validator="$DIR/scripts/validate-issues"
    [[ -x "$validator" ]] || refuse "the shared validator is missing: $validator"

    local rel="${ISSUE_ABS#"$ISSUES_ROOT"/}"
    local output line own=0
    output="$("$validator" "$PROJECT_DIR" --file "$ISSUE_ABS" 2>&1)"
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        if [[ "$line" == "$rel: missing section"* || \
              "$line" == "$rel: issue file has no .md extension"* || \
              "$line" == "$rel: description is not"* ]]; then
            echo "  $line" >&2
            own=$((own + 1))
        else
            echo "  note: $line"
        fi
    done <<< "$output"
    (( own == 0 )) || refuse "the issue file is not ready to close (above)"
}
# }}}

# -- {{{ read_issue_facts
read_issue_facts() {
    # Id, phase and title, from the shared issue-name reader.
    local facts
    facts="$(luajit "$LIB" \
                locate "$DIR/scripts" "$(realpath "$PROJECT_DIR")" "$ISSUE_ABS")" \
        || refuse "could not read the issue's id and phase"
    IFS=$'\t' read -r ISSUE_ID ISSUE_PHASE ISSUE_TITLE <<< "$facts"
    [[ -n "$ISSUE_ID" ]] || refuse "could not read the issue's id"
}
# }}}

# -- {{{ choose_progress_file
choose_progress_file() {
    if [[ "$ISSUE_PHASE" != "-" && -f "$ISSUES_ROOT/phase-${ISSUE_PHASE}-progress.md" ]]; then
        PROGRESS_FILE="$ISSUES_ROOT/phase-${ISSUE_PHASE}-progress.md"
    elif [[ -f "$ISSUES_ROOT/progress.md" ]]; then
        PROGRESS_FILE="$ISSUES_ROOT/progress.md"
    else
        refuse "no progress file: neither issues/phase-${ISSUE_PHASE}-progress.md nor issues/progress.md exists in $PROJECT_DIR"
    fi
}
# }}}

# -- {{{ claim_lines
claim_lines() {
    # Appends "+" records for each line read on stdin to the session's ledger,
    # through the shared ledger library so its format is written in one place.
    local file="$1"
    CLAIM_SCRIPTS="$DIR/scripts" CLAIM_SESSION="$CLAUDE_CODE_SESSION_ID" CLAIM_FILE="$file" \
    luajit -e '
        package.path = os.getenv("CLAIM_SCRIPTS") .. "/libs/?.lua;" .. package.path
        local ledger = require("own-lines-ledger")
        local path = ledger.realpath(os.getenv("CLAIM_FILE"))
        local records = {}
        for line in io.lines() do records[#records + 1] = { "+", path, line } end
        local ok, err = ledger.append(os.getenv("CLAIM_SESSION"), records)
        if not ok then io.stderr:write(tostring(err), "\n"); os.exit(1) end
    '
}
# }}}

# -- {{{ closing_landed
closing_landed() {
    # True when the branch moved past the given tip and its new commit has the
    # issue in completed/ and no longer in its old place.
    local tip_before="$1" tip_now
    tip_now="$(git -C "$REPO_ROOT" rev-parse -q --verify HEAD)" || return 1
    [[ "$tip_now" != "$tip_before" ]] || return 1
    git -C "$REPO_ROOT" cat-file -e "HEAD:${DEST#"$REPO_ROOT"/}" 2>/dev/null || return 1
    ! git -C "$REPO_ROOT" cat-file -e "HEAD:${ISSUE_ABS#"$REPO_ROOT"/}" 2>/dev/null
}
# }}}

# -- {{{ write_message
write_message() {
    # The commit message, in a file of its own.
    local out="$1"
    if [[ -n "$MESSAGE_FILE" ]]; then
        cat "$MESSAGE_FILE" > "$out"
    else
        local rel_progress="${PROGRESS_FILE#"$PROJECT_DIR"/}"
        printf '%s\n\nIssue %s is complete: its file moves to issues/completed/ and\n%s records it.\n' \
            "$ISSUE_TITLE" "$ISSUE_ID" "$rel_progress" > "$out"
    fi
}
# }}}

# -- {{{ close_issue
close_issue() {
    local today added message
    today="$(date +%Y-%m-%d)"

    if $DRY_RUN; then
        echo "would move   ${ISSUE_ABS#"$REPO_ROOT"/}"
        echo "        to   ${DEST#"$REPO_ROOT"/}"
        echo "would add to ${PROGRESS_FILE#"$REPO_ROOT"/}:"
        luajit "$LIB" record \
            "$PROGRESS_FILE" "$ISSUE_ID" "$ISSUE_TITLE" "$today" --dry-run | sed 's/^/    /'
        if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
            echo "would commit through commit-own-changes (session $CLAUDE_CODE_SESSION_ID)"
        else
            echo "would commit the three paths with git commit --only"
        fi
        return 0
    fi

    PROGRESS_BACKUP="$(mktemp)"
    cp -p "$PROGRESS_FILE" "$PROGRESS_BACKUP"

    mkdir -p "$(dirname "$DEST")" || refuse "cannot create $(dirname "$DEST")"
    mv "$ISSUE_ABS" "$DEST" || refuse "could not move the issue file"
    MOVED=true

    added="$(luajit "$LIB" record \
                "$PROGRESS_FILE" "$ISSUE_ID" "$ISSUE_TITLE" "$today")" \
        || refuse "could not write the record into $PROGRESS_FILE"

    message="$(mktemp)"
    write_message "$message"

    if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
        "$DIR/scripts/claim-own-change" "$ISSUE_ABS" "$DEST" --scripts-dir "$DIR/scripts" >/dev/null \
            || { rm -f "$message"; refuse "could not claim the move in the session's ledger"; }
        printf '%s\n' "$added" | claim_lines "$PROGRESS_FILE" \
            || { rm -f "$message"; refuse "could not claim the progress lines in the session's ledger"; }
        # Judged by what happened, not only by the exit status: a commit that
        # landed is never undone, even if a later step of commit-own-changes
        # (or the LuaJIT it runs on) reports a failure.
        local tip_before coc_status
        tip_before="$(git -C "$REPO_ROOT" rev-parse -q --verify HEAD)"
        "$DIR/scripts/commit-own-changes" "$REPO_ROOT" --project "$PROJECT_DIR" \
            --scripts-dir "$DIR/scripts" -F "$message"
        coc_status=$?
        if ! closing_landed "$tip_before"; then
            rm -f "$message"
            refuse "commit-own-changes made no commit holding the move (the ledger keeps the claims; they are harmless once the files are back)"
        fi
        if (( coc_status != 0 )); then
            echo "commit-completed-issue: commit-own-changes exited $coc_status, but the commit landed; read its report above" >&2
        fi
    else
        git -C "$REPO_ROOT" add -- "$DEST" \
            || { rm -f "$message"; refuse "could not add $DEST"; }
        if ! git -C "$REPO_ROOT" commit --quiet --only -F "$message" \
                -- "$ISSUE_ABS" "$DEST" "$PROGRESS_FILE"; then
            git -C "$REPO_ROOT" rm --cached --quiet -- "$DEST" 2>/dev/null
            rm -f "$message"
            refuse "git commit made no commit"
        fi
    fi
    rm -f "$message" "$PROGRESS_BACKUP"
    PROGRESS_BACKUP=""
    MOVED=false

    echo "closed issue $ISSUE_ID: $(git -C "$REPO_ROOT" log -1 --format='%h %s')"
    echo "  ${DEST#"$REPO_ROOT"/}"
    echo "  ${PROGRESS_FILE#"$REPO_ROOT"/}: $(printf '%s\n' "$added" | grep -v '^$')"
}
# }}}

# -- {{{ main
main() {
    trap 'undo; exit 1' INT TERM
    parse_args "$@"
    [[ -d "$DIR/scripts" ]] || { echo "commit-completed-issue: no shared scripts/ under $DIR (use --dir)" >&2; exit 2; }
    locate_issue
    check_issue_shape
    read_issue_facts
    choose_progress_file
    close_issue
}
# }}}

main "$@"
