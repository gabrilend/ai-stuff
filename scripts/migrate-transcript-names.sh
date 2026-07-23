#!/bin/bash
# migrate-transcript-names.sh - one-time (and safe-to-repeat) renamer that
# brings every already-written Claude transcript onto the date-range naming
# scheme.
#
# The big picture: older transcripts were named after opaque conversation ids.
# This walks every llm-transcripts/ folder under a root, recognises the real
# transcripts by their header line (so hand-written notes and derived analytics
# in the same folders are left alone), and renames each to the calendar date it
# ended on - taken from the file's mtime, which the backup utility stamped from
# the last message's time. The source JSONLs are mostly gone, so the earlier
# start date is unrecoverable; a single end-date is the honest best we have.
# Files already in the new format are skipped, so re-running is harmless.
#
# Usage:
#   migrate-transcript-names.sh [root-dir] [--dry-run]
#   DIR=/some/root migrate-transcript-names.sh --dry-run
set -euo pipefail

# Hard-coded default root, overridable by env or a positional argument, so the
# script runs the same from any working directory.
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
DRY_RUN=0

for arg in "$@"; do
   case "$arg" in
      --dry-run) DRY_RUN=1 ;;
      --apply)   DRY_RUN=0 ;;
      -*) echo "Unknown option: $arg" >&2; exit 1 ;;
      *)  DIR="$arg" ;;
   esac
done
DIR="$(realpath "$DIR")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/libs/transcript-discovery.sh"

# The whole tree is one git repository; renames go through git so both the old
# and new paths are recorded (house rule: never move a tracked file outside of
# git). Files git does not track yet are moved plainly.
REPO_ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || echo "")"

RENAMED=0
SKIPPED=0

# Names claimed so far this run. Lets the dry run show the true "_agent-N"
# collision numbering (nothing is on disk yet) and keeps apply mode honest too.
declare -A CLAIMED

# {{{ reserve_name()
# Pick and reserve the destination for a span base in a directory: the first
# claimant gets "base.md", the rest "base_agent-1.md", "base_agent-2.md", ...
# A slot is taken if reserved earlier this run or (when actually moving) already
# present on disk. The result is returned in the global RESERVED_PATH rather
# than printed, because a command-substitution subshell would discard the
# reservation we just recorded in CLAIMED.
RESERVED_PATH=""
reserve_name() {
   local dir="$1"
   local base="$2"
   local n=0 cand
   while :; do
      if [ "$n" -eq 0 ]; then
         cand="$dir/$base.md"
      else
         cand="$dir/${base}_agent-${n}.md"
      fi
      n=$((n + 1))
      [ -n "${CLAIMED[$cand]:-}" ] && continue
      if [ "$DRY_RUN" -eq 0 ] && [ -e "$cand" ]; then
         continue
      fi
      CLAIMED["$cand"]=1
      RESERVED_PATH="$cand"
      return 0
   done
}
# }}}

# {{{ move_transcript()
# Rename one transcript, preferring git so history follows the file. Honors the
# dry-run switch by only narrating what it would do.
move_transcript() {
   local src="$1"
   local dest="$2"

   if [ "$DRY_RUN" -eq 1 ]; then
      printf '   would rename  %s  ->  %s\n' "$(basename "$src")" "$(basename "$dest")"
      return 0
   fi

   if [ -n "$REPO_ROOT" ] && git -C "$REPO_ROOT" ls-files --error-unmatch "$src" >/dev/null 2>&1; then
      # Tracked: move through git so history follows. If git balks for any
      # reason, fall back to a plain move rather than aborting the whole run.
      git -C "$REPO_ROOT" mv "$src" "$dest" || mv "$src" "$dest"
   else
      mv "$src" "$dest"
   fi
   printf '   renamed  %s  ->  %s\n' "$(basename "$src")" "$(basename "$dest")"
}
# }}}

# {{{ migrate_one_dir()
# Rename every not-yet-migrated transcript in a single llm-transcripts/ folder.
# Files are handled oldest-first (by mtime, then name) so the earliest-ending
# conversation on a shared day claims the bare date and later ones take the
# "_agent-N" collision slots deterministically.
migrate_one_dir() {
   local dir="$1"

   # Seed reservations with transcripts already on the new scheme, so their
   # slots are respected and a same-day newcomer lands on the next free suffix.
   local f
   while IFS= read -r f; do
      [ -n "$f" ] || continue
      if transcript_is_new_format "$f"; then
         CLAIMED["$f"]=1
      fi
   done < <(transcript_list_files "$dir")

   # Build "mtime<TAB>path" lines only for genuine transcripts, then sort.
   local sorted
   sorted=$(
      while IFS= read -r f; do
         [ -n "$f" ] || continue
         printf '%s\t%s\n' "$(stat -c '%Y' "$f")" "$f"
      done < <(transcript_list_files "$dir") | sort -k1,1n -k2,2
   )
   [ -n "$sorted" ] || return 0

   local mtime path base end_date dest
   while IFS=$'\t' read -r mtime path; do
      [ -n "$path" ] || continue

      # Already on the new scheme? Leave it; keeps the pass idempotent.
      if transcript_is_new_format "$path"; then
         SKIPPED=$((SKIPPED + 1))
         continue
      fi

      # End date from the file's own timestamp -> single-day base name.
      end_date=$(date -d "@${mtime}" '+%Y-%m-%d')
      base=$(transcript_span_basename "$end_date" "$end_date")
      reserve_name "$dir" "$base"
      dest="$RESERVED_PATH"

      move_transcript "$path" "$dest"
      RENAMED=$((RENAMED + 1))
   done <<< "$sorted"
}
# }}}

# {{{ main()
main() {
   echo "Migrating transcript names under: $DIR"
   [ "$DRY_RUN" -eq 1 ] && echo "(dry run - no files will be moved)"
   echo ""

   local td
   while IFS= read -r td; do
      local count
      count=$(transcript_list_files "$td" | wc -l)
      [ "$count" -eq 0 ] && continue
      echo "-> $td  ($count transcripts)"
      migrate_one_dir "$td"
   done < <(find "$DIR" -type d -name llm-transcripts | sort)

   echo ""
   echo "Done. Renamed: $RENAMED   Already-formatted (skipped): $SKIPPED"
}
# }}}

main
