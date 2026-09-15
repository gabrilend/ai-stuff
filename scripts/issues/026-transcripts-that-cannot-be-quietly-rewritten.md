# Issue #026: Transcripts That Cannot Be Quietly Rewritten

## Current Behavior

A transcript is not a document. It is a **rendering** of a Claude session log,
produced by `backup-conversations`, and `rederive-transcripts` rebuilds the
whole file whenever the renderer learns to do something better. That is the
point of it, and it is a good thing: an improvement to the exporter reaches the
archive rather than only the next conversation.

The problem is that the rebuild is **invisible**, and lands on files that are
already committed.

### The two halves, and which one is replaceable

| | Where it lives | Can it be reproduced? |
|---|---|---|
| session log | `~/.claude/projects/<project>/<id>.jsonl` | **No.** Nothing else has it. |
| transcript | `<project>/llm-transcripts/*.md` | Only while its log survives. |

Issue #024 counted the corpus, and the ratio is the whole argument:

| measure | count |
| --- | --- |
| transcripts whose log survives — rebuildable | 128 |
| **transcripts whose log is gone — frozen** | **464** |

Re-derive with `rederive-transcripts`, which reports and writes nothing unless
told to.

So for roughly three quarters of the corpus **the committed markdown file is the
only copy of that conversation in existence.** A bad rebuild of a rebuildable one
costs a re-run. A bad rebuild of a file whose log dies later is permanent, and
the moment it becomes permanent is silent and happens long afterwards.

### How a rebuild reaches a commit without anyone looking

Every project carries a `.git/hooks/pre-commit` that runs

    git add -A llm-transcripts/

so that session transcripts ride along with whatever else is being committed.
That is a deliberate user directive and it works. It also means a rebuilt file
is staged by machinery rather than by a person, and goes into the next commit
about something else entirely, under a message about something else entirely.
Nobody reads that diff. Nobody has ever read that diff.

**This is live right now.** In `wow-chat-2026`, ten already-committed
transcripts are sitting modified, waiting for the hook to sweep them into
whatever gets committed next:

| file | lines added | lines removed |
|---|---|---|
| `jul-14-26.md` | 101 | 563 |
| `jul-15-26-through-jul-16-26.md` | 110 | 929 |
| `jul-16-26-through-jul-18-26.md` | 235 | 1222 |
| `jul-22-26.md` | 1 | 469 |
| ...and six more | | |

### What is actually in those diffs, measured

Counted in words rather than lines, because the line counts above are mostly
blank-line collapsing and say nothing about content:

| file | committed | on disk | delta |
|---|---|---|---|
| `jul-14-26.md` | 13039 | 13139 | +100 |
| `jul-22-26.md` | 4795 | 4795 | 0 |
| `aug-7-26.md` | 6931 | 6945 | +14 |
| `jul-16-26-through-jul-18-26.md` | 26172 | 26406 | +234 |

**Nothing is being lost today.** Every one of those is level or slightly up —
the renderer captures a little more than it used to. That is an outcome, not a
property: nothing checked it, nothing would have objected, and the same
machinery would have committed a rebuild that had dropped half a conversation
with exactly the same silence.

## Intended Behavior

Two different protections, because the two halves have opposite needs.

### The session logs are made hard to alter

They are the irreplaceable half and **nothing legitimately rewrites them**. That
is the profile a filesystem attribute fits: something that is written once,
appended to by one process, and never edited.

### The transcripts are made hard to alter *quietly*

They must stay rewritable, or `rederive-transcripts` — the tool built precisely
to improve them — stops working. So the protection is **detection, not
prevention**: a rebuild is allowed, a rebuild that loses content is refused, and
a rebuild that reaches a commit does so visibly.

This is the project's own stated position on memory, applied to the one corpus
where it has not been: append-only, no editing possible, verified backwards by
checksum rather than by trust.

## Feasibility of the Filesystem Approach, Measured

The idea was "uneditable except by the harness or sudo". Checked rather than
assumed:

| question | answer |
|---|---|
| filesystem under the projects | ext4 (`/dev/nvme0n1p4`, `rw,relatime`) |
| does ext4 support the attributes | yes — `+a` append-only, `+i` immutable |
| can this user set them | **no** — `chattr +a` returns `Operation not permitted` |
| what is required | `CAP_LINUX_IMMUTABLE`, i.e. root |

So "except by sudo" is not an approximation. It is exactly and only what these
attributes give you, and it holds against the owner and against root-without-the-
capability alike.

**And it is the wrong instrument for the transcripts**, for two concrete reasons:

1. `+a` permits appending and forbids truncate, rename and unlink. The exporter
   writes whole files. Every rebuild would fail.
2. `+i` forbids all of it — including `git checkout`, `git reset` and `git
   stash`, which replace a tracked file by unlinking it and creating a new one.
   A transcript with `+i` set breaks ordinary git operations on the whole repo,
   in a way whose error message will not mention transcripts.

**It is the right instrument for the session logs.** Nothing rewrites a finished
`.jsonl`; the harness appends to the active one and then never touches it again.

## Suggested Implementation Steps

1. **Write down the two categories and which protection each gets.** One
   paragraph in the exporter's own documentation. Everything below is mechanism;
   this is the decision, and it is the part that will be forgotten.

2. **A manifest beside each `llm-transcripts/` folder.** One line per transcript:
   its conversation id, a hash of its content, its word count and its turn count.
   Written by the exporter as part of producing a transcript, so it cannot be
   forgotten separately from the thing it describes.

3. **Make `rederive-transcripts` refuse a lossy rebuild.** It already knows the
   old file and the new one. If the rebuild has fewer turns, or materially fewer
   words, it stops and says so rather than writing. `--force` exists for the case
   where the loss is intended, and says what it is about to destroy.

4. **Stop the hook staging silently.** The pre-commit hook should add transcripts
   that are *new*, and should refuse — or at minimum announce loudly — when it is
   about to stage a modification to a transcript that is already committed. A new
   conversation riding along is what the directive asked for. A rewrite of an old
   one is a different event wearing the same clothes.

5. **Freeze the finished session logs.** A small script, run under sudo, that
   sets `+a` on every `.jsonl` in `~/.claude/projects/` that is not the currently
   active session. Needs to be idempotent and needs to leave the live one alone,
   or it breaks the session that is running it.

6. **Verify backwards.** A checker that walks the manifests and reports any
   transcript whose content no longer matches its recorded hash, so that "has
   anything been altered" is a question with a one-command answer rather than an
   act of faith.

## Related Documents and Tools

- `scripts/rederive-transcripts` — the rebuilder, and its `frozen` / `repairable`
  / `headerless` classification, which is where the two categories already exist
  in code
- `scripts/backup-conversations` — the exporter; where a manifest would be written
- `scripts/libs/transcript-discovery.sh` — how a transcript is recognised, by the
  conversation id in its header rather than by its filename
- `issues/024-backfill-existing-transcript-corpus.md` — the corpus measurement,
  and the reasoning about per-transcript rather than per-project questions
- `issues/025-capture-subagent-session-logs.md` — a second source of logs that
  would inherit whatever is decided here
- `~/.claude/settings.json` — `cleanupPeriodDays`, now 7300, which is what stops
  the frozen count from growing

## Open Questions

1. **Does the manifest belong in git?** It is derived from the transcripts, so
   committing it is committing a second copy of a fact. But a manifest that is
   not committed cannot detect a change that arrived through a commit, which is
   the exact attack surface. Is the answer that it is committed *and* generated,
   like the other generated documents, with the check being that they agree?

2. **What is "materially fewer words"?** A rebuild that drops one word is
   probably a whitespace change. One that drops a thousand is a bug. The
   boundary between them is a number somebody has to pick, and picking it wrong
   in the safe direction means the refusal fires constantly and gets `--force`d
   out of habit, which is worse than not having it.

3. **Should the frozen ones be treated differently from the rebuildable ones?**
   For a transcript whose log is gone there is no legitimate rebuild at all —
   nothing can produce a better version, because nothing can produce any version.
   Should those be the ones that get `+i`, since for them the file genuinely is
   write-once?

4. **Who runs the sudo step, and when?** A freeze that depends on somebody
   remembering to run it is a freeze that protects the logs somebody remembered
   about. Is this a boot-time unit, something the exporter shells out to, or an
   accepted manual step with a checker that says how many logs are unprotected?

5. **What happens to an active session's log?** The harness appends to it for the
   life of the conversation. Setting `+a` on it would be correct in principle and
   would need testing in practice, because an appender that also seeks or
   rewrites would break. Has anybody looked at whether the harness only ever
   appends?

6. **Is git already enough?** Committed content is hash-addressed and a rewrite
   shows as a diff, so in one sense the tamper-evidence exists. The gap is that
   nobody looks, and the hook guarantees nobody has to. Is this issue really
   about hashes at all, or is it entirely about step 4?
