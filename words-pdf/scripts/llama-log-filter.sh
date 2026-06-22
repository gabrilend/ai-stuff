#!/bin/bash
# llama-log-filter.sh — Condense llama-server's verbose stdout into one
# concise line per completed request, plus startup and error passthrough.
#
# llama-server at -lv 1 still emits ~8-10 lines per inference request
# (slot select, prompt cache housekeeping, release, idle-slots roundup).
# Most of that is internal bookkeeping; the operator only needs to know
# "another request just finished" and the relevant stats.
#
# Usage:
#   llama-server ... | tee logfile | llama-log-filter.sh embed
#   tail -F logfile | llama-log-filter.sh embed
#
# Argument: label printed at the start of each emitted line (e.g. "embed"
# or "chat"). Defaults to "llama" if omitted.

LABEL="${1:-llama}"

# {{{ awk filter
# POSIX awk only — uses match() with RSTART/RLENGTH (not gawk's array form),
# so this works under busybox awk too.
#
# Three classes of lines surface to stdout:
#
#   1) "server is listening on http://…" — emitted exactly once at startup
#      so the operator sees the server came up.
#   2) Anything tagged with severity " E " (error) — passed through with
#      label prefix so failures aren't silently swallowed.
#   3) The "release" line per slot, which is the one llama-server prints
#      after a request completes. We pull n_tokens out of it and keep a
#      running count + token total for the session.
#
# Everything else (slot selection, prompt cache writes, update_slots
# announcements) is discarded — it goes only to the log file the caller
# is tee-ing into, not the operator's terminal.
awk -v label="${LABEL}" '
    BEGIN { count = 0; total_tokens = 0 }

    # 1) server-up announcement
    /server is listening/ {
        # Strip the leading timestamp+severity ("0.00.441.729 I srv  …")
        msg = $0
        sub(/^[0-9.]+ +[A-Z] +srv +[^:]*: */, "", msg)
        printf "[%s] ✓ %s\n", label, msg
        fflush()
        next
    }

    # 2) errors at any severity — keep with full original text
    / E +srv|^E |E srv: / {
        printf "[%s] ⚠  %s\n", label, $0
        fflush()
        next
    }

    # 3) request completion. The "release" line is the canonical end-of-task
    # marker; matching on "stop processing" filters out any other release
    # events (rare, but defensive).
    /slot +release:.*stop processing/ {
        count++
        tokens = 0
        if (match($0, /n_tokens = [0-9]+/)) {
            ntok_str = substr($0, RSTART, RLENGTH)
            sub(/n_tokens = /, "", ntok_str)
            tokens = ntok_str + 0
            total_tokens += tokens
        }
        truncated = ""
        if (match($0, /truncated = [01]/)) {
            tr_str = substr($0, RSTART, RLENGTH)
            sub(/truncated = /, "", tr_str)
            if (tr_str + 0 == 1) truncated = " TRUNCATED"
        }
        printf "[%s] #%d  tokens=%d  Σ=%d%s\n", label, count, tokens, total_tokens, truncated
        fflush()
    }
'
# }}}
