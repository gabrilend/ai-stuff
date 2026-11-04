# 604 — say it and see it

## Founding words

Spoken by gabrilend, 2026-10-21:

> for the gif generator, can we create a cli tool that opens up a text
> entry box that you can type in, then it'll process your text and create
> a gif for you. If it doesn't recognize any words, it'll update an issue
> file (properly handling it being in completed/ if we move it there for
> some reason, it should re-open it when there's new words added) to create
> a mapping for that word based on the context. The idea is, we create an
> error report then instantly solve it. In-fact, can we then have it open
> up a headless claude-code session, build the new functionality, then
> build the gif? So, one for each of the unrecognized words. After the
> initial text prompt, the user can message the headless AI (it displays a
> simple chat log in the terminal program) and update how it's words are
> managed - these aren't passed through the new issue pipeline, they're
> just a back-and-forth dynamic until the gif is perfect (we should have a
> small viewer open up to display the gif too)

Her answers to the questions that followed:

- the word sessions run **all at once**: "Each pattern should be it's own
  file, so they shouldn't be modifying more than one at once. Also, we'll
  add the words to the tracker issue file in one pass."
- the per-word issues live **in RAM** "until they're complete, then we just
  update the tracker issue with the ones we finished";
- the chat may change **code too**;
- the gif is shown in **the house's own LÖVE viewer**.

## Current Behavior

`./say` exists and runs end to end with stand-ins for Claude and the
viewer (`src/043-say-test.lua`, 14 checks), and every part has its own
passing tests. Word files and `pattern{}` (604a) and the unknown-word
finder (604b) are complete. The word sessions (604c), the director (604d)
and the front door with the viewer's watch mode (604e) are built and
stand-in-tested, and wait on one thing: **a first run with real Claude
Code sessions**, typed by a person, since it starts real sessions.

Before this, the porch (601) could turn prose into a score only through a
local model cluster that is not lit yet, only within the existing
vocabulary, and nothing recorded which words people reach for that the
studio cannot draw.

## Intended Behavior

`./say` in the project root opens a box in the terminal. You type what you
want to see, in plain words, and finish with an empty line.

1. **Every word is checked.** Words the studio knows (the score vocabulary,
   plain English words, and every word that has a word file) pass. Every
   other word is **unrecognized**.
2. **Each unrecognized word becomes an error report and is solved at once.**
   For each one, a brief is written in RAM (the word, the sentence it came
   from, the contract for a word file) and a headless Claude Code session is
   started on it. All the sessions run at the same time. Each one writes
   exactly one new file, `words/<word>.lua`, saying what the word means:
   either a **pattern** (a small recipe that expands into strokes the score
   already knows) or a **plain** word (understood, nothing new to draw, with
   a sentence on how to read it). Because every word owns its own file, no
   two sessions ever edit the same thing.
3. **The tracker is updated in one pass.** When the sessions finish, every
   word that now has a working file is added to the tracker issue (605) in a
   single write. If the tracker had been moved to `issues/completed/`, it is
   moved back and reopened. Words whose session failed are reported, not
   added.
4. **A director session draws the gif.** A further headless session reads
   the prose, the score format and every word file, and writes a score into
   RAM. The studio's wall checks it; its teaching is sent back to the
   director until the score passes. The score is rendered, and the gif
   opens in the LÖVE viewer.
5. **Then you talk.** The terminal shows a chat log. Each message goes to
   the same director session, which may change the score, the word files,
   or the studio's code, and writes the score again; the gif is re-rendered
   and the viewer shows the new one. These changes do not go through issue
   files; the conversation is the record (its log is kept with the gif).
   `/done` ends it.

Every gif made this way is kept, with its prose, its score and the chat log
beside it.

## Sub-Issues

| ID   | Name                       | Dependencies | Description |
|------|----------------------------|--------------|-------------|
| 604a | word-files                 | None         | The word-file contract, the loader, and `pattern{}` in the score sandbox expanding into ordinary strokes before the wall |
| 604b | finding-unknown-words      | 604a         | The lexicon (vocabulary, plain English, word files) and the finder |
| 604c | word-sessions-and-tracker  | 604a, 604b   | RAM briefs, parallel headless sessions, checking their files, the one-pass tracker update with reopening |
| 604d | the-director-and-the-chat  | 604a         | The director session writing scores, the wall's feedback loop, rendering, the chat |
| 604e | the-box-and-the-viewer     | 604c, 604d   | The terminal program tying it together, and the LÖVE viewer's reload mode |

Execution order: `604a` → `604b` and `604d` in parallel → `604c` → `604e`.

## Suggested Implementation Steps

See each part. The headless sessions are started with `claude -p`, run in
the project folder, with edits allowed; the chat continues one session with
`--resume`. A stand-in for `claude` (named by an environment variable) lets
every step be tested without spending sessions.

## Blockers

- None. 601's cluster is not needed: the director is a Claude session.

## Related Documents

- `docs/score-format.md` (gains `pattern{}`)
- `docs/datapath-prose-translation.md`
- issue 601 (the porch this generalises), issue 605 (the tracker)
- `~/.claude/skills/canvas-and-paintbrush/SKILL.md`

## Open Questions

- Should the word sessions and the director commit their work themselves,
  or leave it for a person (or a later session) to review and commit?
- Is there a limit on how many word sessions may run at once? Each one is a
  full Claude Code session; a long first prompt could start dozens.
