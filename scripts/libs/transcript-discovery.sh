#!/bin/bash
# transcript-discovery.sh - the single rulebook for finding and naming Claude
# conversation transcripts. Meant to be *sourced*, not run.
#
# In plain terms: every transcript summary begins with a fixed header line that
# records which conversation it came from. This library treats that header - not
# the file's name - as the source of truth. That lets us rename the files to
# whatever we like (date ranges, in our case) while the rest of the toolchain
# keeps finding them and recovering their conversation id. It also owns the
# rules for turning a pair of dates into a filename and for resolving
# name collisions, so the producer, the one-time migrator, and the analytics
# consumers can never drift out of agreement.

# The header line the parser stamps at the top of every transcript. Anything in
# an llm-transcripts/ folder that does NOT start with this is derived output
# (word clouds, analytics, verbosity exports) or a hand-written note, and is
# left alone.
TRANSCRIPT_HEADER_PREFIX="# Conversation Summary: "

# {{{ transcript_is_summary()
# Answer "is this file a real transcript?" by peeking at its first line only.
transcript_is_summary() {
   local file="$1"
   [ -f "$file" ] || return 1
   local first_line
   IFS= read -r first_line < "$file" || return 1
   case "$first_line" in
      "${TRANSCRIPT_HEADER_PREFIX}"*) return 0 ;;
      *) return 1 ;;
   esac
}
# }}}

# {{{ transcript_conv_id()
# Recover the conversation id recorded in the header (e.g. a uuid, or
# "agent-<hash>" for a sidechain). Prints nothing and fails on a non-transcript.
transcript_conv_id() {
   local file="$1"
   local first_line
   IFS= read -r first_line < "$file" 2>/dev/null || return 1
   case "$first_line" in
      "${TRANSCRIPT_HEADER_PREFIX}"*)
         printf '%s\n' "${first_line#"${TRANSCRIPT_HEADER_PREFIX}"}"
         ;;
      *) return 1 ;;
   esac
}
# }}}

# {{{ transcript_list_files()
# List every transcript in a directory, one path per line, in directory order.
# Callers that care about chronology sort the result themselves.
transcript_list_files() {
   local dir="$1"
   local f
   for f in "$dir"/*.md; do
      [ -e "$f" ] || continue
      if transcript_is_summary "$f"; then
         printf '%s\n' "$f"
      fi
   done
}
# }}}

# {{{ transcript_date_token()
# Turn a calendar date "YYYY-MM-DD" into the compact "mon-d-yy" token, e.g.
# "2026-07-03" -> "jul-3-26". Lowercase month, no leading zero on the day.
transcript_date_token() {
   local ymd="$1"
   date -d "$ymd" "+%b-%-d-%y" | tr '[:upper:]' '[:lower:]'
}
# }}}

# {{{ transcript_span_basename()
# Build the extension-less filename for a conversation spanning two dates.
# Same day collapses to a single token; a real span reads "start-through-end".
# A missing endpoint borrows the other, so a one-timestamp file still names.
transcript_span_basename() {
   local start_ymd="$1"
   local end_ymd="$2"
   [ -n "$start_ymd" ] || start_ymd="$end_ymd"
   [ -n "$end_ymd" ] || end_ymd="$start_ymd"

   local start_tok end_tok
   start_tok=$(transcript_date_token "$start_ymd")
   end_tok=$(transcript_date_token "$end_ymd")

   if [ "$start_tok" = "$end_tok" ]; then
      printf '%s\n' "$start_tok"
   else
      printf '%s-through-%s\n' "$start_tok" "$end_tok"
   fi
}
# }}}

# Month-name -> month-number dispatch table for the reverse parser below.
# These are the English %b abbreviations that transcript_date_token emits;
# a lookup miss means the token is not a date and the caller must not guess.
# The -g flag matters: some consumers source this rulebook from inside a
# function, and a plain "declare -A" there would silently create a LOCAL
# table that vanishes when the sourcing function returns, failing every
# date lookup afterward. -g pins it global regardless of sourcing context.
declare -gA TRANSCRIPT_MONTH_NUMBER=(
   [jan]=01 [feb]=02 [mar]=03 [apr]=04 [may]=05 [jun]=06
   [jul]=07 [aug]=08 [sep]=09 [oct]=10 [nov]=11 [dec]=12
)

# {{{ transcript_token_to_ymd()
# The mirror image of transcript_date_token: "jul-3-26" -> "2026-07-03".
# Added for the storyline library (delta-version issue 057), which needs a
# sortable ISO date where the filenames only carry the compact token. The
# century is fixed at 20xx because the token format itself only stores two
# year digits and the transcript corpus begins in 2025. Prints nothing and
# fails on anything that is not a real date token - no guessing.
transcript_token_to_ymd() {
   local token="$1"
   [[ "$token" =~ ^([a-z]{3})-([0-9]{1,2})-([0-9]{2})$ ]] || return 1
   local mon="${BASH_REMATCH[1]}"
   local day="${BASH_REMATCH[2]}"
   local yy="${BASH_REMATCH[3]}"
   local mm="${TRANSCRIPT_MONTH_NUMBER[$mon]:-}"
   [ -n "$mm" ] || return 1
   printf '20%s-%s-%02d\n' "$yy" "$mm" "$((10#$day))"
}
# }}}

# {{{ transcript_basename_start_ymd()
# Recover the ISO *start* date of a transcript from its filename alone:
# "jul-1-26-through-jul-2-26_agent-1.md" -> "2026-07-01". The date token is
# matched from the END of the name so that a future "<slug>-<date>.md" rename
# (delta-version issue 056) parses identically. Span names use the start date
# because that is when the session's story began. Fails, printing nothing,
# when no trailing date token exists (e.g. uuid-named or hand-written files).
transcript_basename_start_ymd() {
   local base
   base="$(transcript_strip_suffix "$1")"
   local tok='[a-z]{3}-[0-9]{1,2}-[0-9]{2}'
   # Span first: for "start-through-end" the start token is what orders the
   # file. The plain branch would otherwise match the span's END token.
   if [[ "$base" =~ (${tok})-through-(${tok})$ ]]; then
      transcript_token_to_ymd "${BASH_REMATCH[1]}"
   elif [[ "$base" =~ (${tok})$ ]]; then
      transcript_token_to_ymd "${BASH_REMATCH[1]}"
   else
      return 1
   fi
}
# }}}

# {{{ transcript_is_new_format()
# True when a filename is already in the date-range scheme, so the migrator can
# skip it and stay idempotent. Matches "mon-d-yy", an optional "-through-..."
# span, and an optional "_agent-N" collision suffix.
transcript_is_new_format() {
   local name
   name="$(basename "$1")"
   [[ "$name" =~ ^[a-z]{3}-[0-9]{1,2}-[0-9]{2}(-through-[a-z]{3}-[0-9]{1,2}-[0-9]{2})?(_agent-[0-9]+)?\.md$ ]]
}
# }}}

# {{{ transcript_strip_suffix()
# Reduce a transcript filename back to its span base by shedding the trailing
# "_agent-N" collision marker and the ".md" extension. Used to tell whether an
# existing file already covers the span we want, or needs re-placing.
transcript_strip_suffix() {
   local name
   name="$(basename "$1")"
   name="${name%.md}"
   if [[ "$name" =~ ^(.*)_agent-[0-9]+$ ]]; then
      name="${BASH_REMATCH[1]}"
   fi
   printf '%s\n' "$name"
}
# }}}

# {{{ transcript_pick_free_name()
# Choose the destination path for a span basename in a directory. The first
# claimant of a span gets the bare "base.md"; later ones get "base_agent-1.md",
# "base_agent-2.md", and so on. An optional third argument names a path to treat
# as available (the file we are about to move away from itself), so re-runs
# don't shove a file aside from its own rightful name.
transcript_pick_free_name() {
   local dir="$1"
   local base="$2"
   local exclude="${3:-}"

   local cand="$dir/$base.md"
   if [ "$cand" = "$exclude" ] || [ ! -e "$cand" ]; then
      printf '%s\n' "$cand"
      return 0
   fi

   local n=1
   while :; do
      cand="$dir/${base}_agent-${n}.md"
      if [ "$cand" = "$exclude" ] || [ ! -e "$cand" ]; then
         printf '%s\n' "$cand"
         return 0
      fi
      n=$((n + 1))
   done
}
# }}}

# {{{ transcript_find_claim()
# Find the transcript in a directory that already belongs to a given
# conversation id, by reading headers. This is what makes the producer
# idempotent: on every hook firing it reuses the conversation's existing file
# instead of minting a new one. Prints the first match, or fails if none.
transcript_find_claim() {
   local dir="$1"
   local conv_id="$2"
   local f id
   for f in "$dir"/*.md; do
      [ -e "$f" ] || continue
      id="$(transcript_conv_id "$f")" || continue
      if [ "$id" = "$conv_id" ]; then
         printf '%s\n' "$f"
         return 0
      fi
   done
   return 1
}
# }}}
