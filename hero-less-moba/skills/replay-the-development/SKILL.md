---
name: replay-the-development
description: Turn a working tree holding several sessions of undifferentiated work into ordered git history, by reconstructing each design iteration as it actually stood and committing them in sequence. Use when a repository has one enormous uncommitted diff spanning several rounds of design; when somebody asks to "write the old versions back out and replay the changes"; when history was rewritten or misfiled and the record no longer matches what happened; or when the development process itself is the thing worth preserving. Also fits "we lost the history", "these commits are all one blob", "I want to see how this evolved".
---

# Replay the development

Rebuilding a sequence of commits that never existed, from a working tree where the
sessions ran together, so the record shows the shape of the thinking rather than one
diff of everything.

## What this is for, and what it is not

It is for a repository where several rounds of design happened between commits, so the
history has one enormous change in it and the order things were decided in is gone.

It is **not** a way to make history look tidier than it was. What gets reconstructed is
what actually stood at each point — including things that were later reversed, because
a reversal is the most informative thing in a development record and the thing a
prettified history always loses first.

## Before touching anything

**Refuse to start if any of these are true**, and say which:

- Another session is working in the same repository. Reconstruction rewrites the index
  repeatedly and will collide with anything else staging work. Check whether commits
  have appeared or history has moved since the session began.
- The working tree holds work belonging to somebody else, or to a different project in
  the same repository. Ask before touching it.
- There is no clean point to build from. Every reconstructed state has to be
  *reachable*, which means knowing what the tree looked like before the run began.

**Take a backup that is not git.** Copy the whole working tree somewhere outside the
repository first. Every later step is recoverable from that copy and from nothing else,
because the thing being manipulated is git itself.

## Finding the iterations

An iteration is a point where the design *changed its mind*, not a point where a file
changed. The boundaries are found by reading, in this order:

1. **The transcripts.** `llm-transcripts/` holds the conversation the work came out of.
   Every place the user's instruction changed direction is an iteration boundary, and
   they are usually easy to spot because the next paragraph starts explaining something.
2. **The issue files.** A "current behavior" section rewritten mid-session is a
   boundary. So is a new open question.
3. **The append-only logs.** `docs/balance-updates.md` and anything like it are already
   a dated sequence of decisions; they are the closest thing to a ready-made list.
4. **The diff itself, last.** File-level changes suggest boundaries but mislead — one
   commit's worth of thinking often touches nine files and one file often carries three
   iterations.

Write the list down before reconstructing anything, as a file in the RAM tier, with a
one-line description of what changed at each step. **Show it to the user and get it
agreed before writing a single commit.** Getting the boundaries wrong is the only
expensive mistake here, because it is the one that is not visible afterwards.

## Reconstructing a state

For each iteration, oldest first:

- Start from the previous reconstructed state, not from the final tree. Working
  backwards from the end produces states that never existed, because a later change
  often removed something an earlier one needed.
- Write out the files **as they stood**, including comments and documentation as they
  read at the time. A reconstruction whose code is from step three and whose comments
  are from step seven is a lie in the most useful part of the file.
- **Run the tests at every step.** A reconstructed state that does not run is a
  reconstructed state that never existed. If it genuinely did not run at the time — some
  iterations are mid-refactor — say so in the commit message rather than repairing it.
- Commit with a message written in the tense of the moment: what was being tried and
  why, not what it later turned into.

## Committing them

- One commit per iteration. Not per file, and not per session.
- Messages follow the project's own conventions, which for this repository means
  describing the mechanism in plain words and by analogy rather than naming functions,
  and describing what changed rather than what was done.
- **Stage explicitly.** Never `git add -A` during a replay: the tree contains the final
  state of everything, and a wildcard add commits the future into the past. Name the
  paths, or use `git add -p` and read every hunk.
- Check after every commit that the tree still matches what was intended, with
  `git status` and `git diff HEAD`.

## After

- The final reconstructed state must be **byte-identical** to the backup taken at the
  start. Diff them. If they differ, something was lost, and the backup is the truth.
- Leave the list of iterations in the repository as a document, not only as commit
  messages. The list is the reasoning; the commits are the evidence.

## What tends to go wrong

**The boundaries are drawn where files changed rather than where minds changed.** The
resulting history reads like a build log — a fine record of activity and useless as a
record of thinking.

**Comments and documentation get carried backwards.** They are the easiest thing to
forget to revert and the most misleading thing to get wrong, because they are the part
of a file that says *why*.

**A reversal gets quietly dropped** because it is embarrassing or because the final
state does not contain it. Those are the commits worth the most. If a thing was built,
measured, and switched off, all three belong in the record in that order.

**The replay is run while the tree is dirty with somebody else's work**, and their
changes end up inside a commit describing something unrelated. This is the failure that
cannot be undone by hand afterwards, which is why the checks above come first.
