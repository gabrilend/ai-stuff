# Issue #044: Moving a project keeps its conversations

## Current Behavior

The procedure is written and installed: the `move-project` skill (steps 1
and 2 below). Not yet built: the rebuild's refusal (step 3); the
projects already moved by hand are not yet found and merged (step 4); no
move has been made with the skill yet (step 5). Before the skill, only one
move (wow-chat-2026 and its neighbours to `/mnt/kaun`, wow-chat-2026's
issue 188) had written down how; its path-rewriting tool,
`move-project-paths`, lives inside that project and is specific to it.

**Where the conversations live.** There are two layers:

- **Claude Code's raw session logs**, one file per session (named by the
  session's unique id, `<id>.jsonl`), in `~/.claude/projects/<folder name>/`.
  The folder name is the path the session started in with every character
  that is not a letter or digit turned into a dash
  (`/mnt/kaun/wow-chat-2026` → `-mnt-kaun-wow-chat-2026`). These folders
  all sit on the disk that holds `~/.claude` (`/mnt/mtwo`), whatever disk
  the project is on; the name only spells the project's path.
- **The readable transcripts**, `<project>/llm-transcripts/`, written by
  `backup-conversations` from the raw logs and committed with the work.
  These travel inside the project when it moves.

**What a move does to them.**

- After each turn the Stop hook exports the session from the log Claude
  Code names, into the transcript folder of the project the session is in.
  A session started at the new place therefore exports correctly.
- A **rebuild** of a project's transcripts (the sweep, used when the
  exporter improves; see the transcript-care skill) looks for one raw-log
  folder: the path as given, else the path with links resolved. It never
  reads both. A moved project's older sessions sit under the old name, so
  a rebuild run from the new place silently leaves them out.
- wow-chat-2026 is whole today only because its move made the new-name
  folder out of hard links to the old one's files (both on `/mnt/mtwo`, so
  hard links work). Checked 2026-10-20: every log under the old name is
  also under the new one, and logs written on Oct 19–20 still have two
  names, which shows Claude Code adds to a log in place rather than
  replacing it.

**A symlinked raw-log folder works** (step 1, tested 2026-10-21): a
scratch project `/tmp/ai-stuff-scripts/move-test/project` had its raw-log
folder made as a symlink to `/tmp/ai-stuff-scripts/move-test/log-target`;
one headless `claude -p` turn there wrote its log
(`be8505fe-....jsonl`) inside the target, and the symlink was still a
symlink afterwards. Claude Code follows the link rather than replacing it.

## Intended Behavior

Moving a project is one written procedure, done by hand, and the
procedure is the standard. The owner, 2026-10-20: "can we, as a matter of
course when moving a project directory, rename the old directory as a
symlink to the new one, and merge all the old files into the new one?",
"I think it should be our standard operating procedure to always open new
sessions at the new location, because the old location won't exist
anymore", and, choosing the form: "let's make it a skill file instead of
a script or utility. harder to mess up if we do it by hand each time."

The procedure is the `move-project` skill (`~/.claude/skills/move-project/SKILL.md`),
which a session loads whenever it is asked to move, rename or re-home a
project. Its steps:

1. **Stop every session working in the project** (running `claude`
   processes whose folder is inside it; later, the session records of
   `032c`). A folder moved from under a running session leaves it working
   in a place that no longer exists.
2. **Copy, check, then remove**: copy the project (`rsync -aHAX`), compare
   entry counts and bytes, `git fsck`, compare `git status`; only then
   remove the old copy. Across disks this is the only way; on one disk a
   rename.
3. **Leave a symlink at the old path** pointing at the new one, so old
   scripts and habits still arrive. If the old disk is later removed, the
   symlink goes with it, which is harmless: nothing real lives there.
4. **Rewrite the project's own old path**, under every name it was
   reached by: tracked files outside `llm-transcripts/` (which keep their
   history as written), untracked files and links that carry it, worktree
   records, the project's `.claude/` settings (owner: "probably fix
   them"), other projects' settings and `~/.claude/settings.json` that
   name it, and Claude Code's per-folder record in `~/.claude.json`.
5. **Merge the raw-log folders**: every file under the old name is moved
   into the folder for the new name. A file with the same name in both is
   the same session; since logs only grow, the longer must begin with the
   shorter, and the longer is kept. If neither begins with the other, the
   merge stops and names the file. Hard-linked twins (one file with two
   names) need nothing.
6. **Replace the old raw-log folder with a symlink** to the new one, so a
   session started at the old path by mistake still logs into the single
   real folder (Claude Code accepts a symlinked raw-log folder; see
   Current Behavior).
7. **Prove it** (no old path left outside the transcripts; the rebuild
   from the new place finds every conversation), and from then on start
   new sessions at the new place.

A procedure done by hand still needs one machine check, because a missed
merge is silent: **the rebuild**, when the project's folder is reached
through a symlink, or a raw-log folder for another name of it exists,
says so and refuses, naming the folder to merge, rather than rebuilding
half the history. (The owner, on the rebuild reading one folder: "sounds
like this is a concern.")

## Suggested Implementation Steps

1. (Done 2026-10-21, passed.) **Test the symlinked raw-log folder.** A
   scratch project folder; its raw-log folder made as a symlink to another
   folder; one headless `claude -p` turn there. Pass: the log appears
   inside the symlink's target and the symlink is still a symlink. Repeat
   after a Claude Code update that changes how sessions are stored.
2. (Done 2026-10-21.) **The skill**, `~/.claude/skills/move-project/SKILL.md`,
   written from wow-chat-2026's issue 188 and this issue. Skills are not
   kept in any git repository (`~/.claude/skills/` is a plain folder), so
   this issue is its record.
3. The rebuild's refusal when a project has two raw-log names, in
   `backup-conversations`, with a test.
4. Find projects already moved by hand (raw-log folders whose project path
   no longer exists, or is a symlink) and do steps 6–7 of the skill for
   each, with the owner.
5. The first real move done with the skill: whatever it missed is written
   back into the skill.

## Open Questions

1. (Answered 2026-10-21: a skill, done by hand, rather than a tool.)
2. (Answered 2026-10-21: "probably fix them.") A project's `.claude/`
   settings that name the old path are rewritten.
3. Skills live outside every repository, so their history is not kept.
   Should `~/.claude/skills/` be tracked somewhere (a folder in this
   repository that it links to, for example)?

## Related

- `backup-conversations` (the exporter and the rebuild), issue 034 (how the
  session folder is found), the transcript-care skill.
- `032c-a-file-locked-until-its-lines-are-committed.md` (session records,
  for step 1 of the tool).
- `041-the-folder-gate-and-a-folder-with-two-names.md` (a session started
  at an old name keeps showing it).
- wow-chat-2026 issue 188 (the first move, done by hand).
