# Issue #041: The folder gate, and a folder with two names

## Current Behavior

**Built 2026-10-18 (the owner: "let's expand that functionality to allow
for directory switching when specifically allowed"); proven in the gate
tests, not yet tried live:**

- **A permission can name its folder.** An empty
  `/tmp/claude-allow-cwd-change` allows any one move; one holding a folder
  (`! echo /new/place > /tmp/claude-allow-cwd-change`) allows a move to that
  folder only, and a move elsewhere is refused with the permission kept.
  Folders are compared by real place (`realpath -e`), so an old name and a
  new name of one folder match, and a relative move is read from the folder
  the session is in (the hook input's `cwd`).
- **A permission expires** after ten minutes: an older one is removed the
  next time the gate sees a move, the refusal says when it was made, and it
  is not used.
- **A move to another name of the current folder** is recognised (both
  names resolve to one place): refused without a permission, saying it is
  the same folder under another name; allowed with one, with a notice to the
  person.
- **Every refusal says how to ask for a move that happens:** alone on its
  line, `cd /new/place`, since a chained `cd DIR &&` to the current folder
  is dropped by the harness before the gate sees it; and both forms of the
  permission.
- `scripts/test-refusal-gates`: 16 new cases (199 in all, all passing),
  built on a scratch folder reached by two names.
- `README-refusal-gates.md`: a section on moving the session's folder.

**Tried live, 2026-10-18 16:3x** (step 5): the owner first wrote the
placeholder `/new/place` into the permission; the session's `cd
/mnt/kaun/wow-chat-2026` was refused, the refusal said it was the same
folder under another name and that the permission was for `/new/place`, and
the permission was kept, as built. The owner then named the real folder;
the lone `cd /mnt/kaun/wow-chat-2026` was let through and the permission
spent (the file gone). The very next command ran at the old name again
(`/home/ritz/games/azeroth-core/wow-chat-2026`). So the gate's half works;
the fall-back is Claude Code's: it starts each command in the folder it has
on record for the session, and between two names of one real folder it
keeps the name it had (it moves its record only when the real place
changes, as far as can be seen from outside). The gate cannot change that
record. The way to a session that goes by the new name is to start one
there, and to drop the old name from the project's saved extra folders
(`/permissions`), so it is not offered again.

Left open by this (question 4): whether to ask Claude Code's makers to move
the session's record when a permitted `cd` lands on another name of the same
folder.

**The name's real source, found 2026-10-18 17:xx:** not Claude Code's record
of the folder (it was already `/mnt/kaun/wow-chat-2026`: "Shell cwd was reset
to /mnt/kaun/wow-chat-2026"), but the environment. Every command starts a
fresh shell, which inherits the `claude` program's own `PWD`
(`/home/ritz/games/azeroth-core/wow-chat-2026`, set at launch; seen in
`/proc/<claude>/environ`), and bash keeps an inherited `PWD` whenever it names
the folder bash is really in. So the shell showed the launch name whatever
Claude Code recorded.

**Built for it: `carry-working-folder-name`,** a hook on `SessionStart` and
`CwdChanged` (installed in `~/.claude/settings.json`). Claude Code gives those
two events a file, `CLAUDE_ENV_FILE`, whose shell lines run before every later
command; the hook writes one line there that re-enters the shell's own folder
by the name Claude Code has on record, guarded so it runs only when that name
is the folder the shell is in (it never moves the shell, and cannot make `pwd`
lie). Pipe-tested: in the folder entered by its old name, `pwd` changed to the
recorded name; elsewhere, nothing changed; with no file, a notice. (Exporting
`PWD` alone was tried first and does nothing: a running bash keeps its own
copy.)

**Proven live, 2026-10-18 16:49, in the session that found it** (which
could not be restarted): the line was written straight into the session's
environment folder (`~/.claude/session-env/<session>/sessionstart-hook-90.sh`,
now `carry-working-folder-name --now /mnt/kaun/wow-chat-2026`), the owner gave
one permission, and the session made one real move, into `scripts/`. Claude
Code fired `CwdChanged` (the hook wrote `cwdchanged-hook-0.sh`), re-read the
folder, reset the shell to the project folder as before, and from that
command on `pwd` and `PWD` showed `/mnt/kaun/wow-chat-2026`. Two findings on
the way: Claude Code reads those files only when one of the four hooks fires,
and keeps their lines in memory (a file written by hand does nothing until
then); and a line naming a subfolder stayed in force after Claude Code reset
the shell to its parent without an event, which is why the hook's line now
also replaces the stale launch name with the folder's real location.

**Before that, it could not be shown,** and why: after its extra
folder `/mnt/kaun/wow-chat-2026` was removed (it had become the primary),
Claude Code reset the shell to `/mnt/kaun/wow-chat-2026` after every command,
the owner's own `!` commands included, so its record never changed and
`CwdChanged` never fired (a permitted move into `scripts/` was reset too, and
no environment file appeared). The `claude` program's own folder was still the
old copy, by then inside `moved-to-kaun-2026-10-18/`, which is the likely
cause. A session started in `/mnt/kaun/wow-chat-2026` inherits the right name
at launch and gets the `SessionStart` half of the hook besides; the next such
session is the live proof (Suggested Implementation Steps, step 6).

The two-step move in the gate (out to the new name's parent, then in) stays
built and tested, but in practice the parent is often outside the session's
allowed folders (`/mnt/kaun` was), where Claude Code resets the shell on the
first step. Question 5.

**Before 2026-10-18,** the folder gate (`refuse-directory-change`, a hook in front of every shell
command; `README-refusal-gates.md`) refuses a `cd` unless the owner has made
the one-time permission file `/tmp/claude-allow-cwd-change`, and spends the
file on the `cd` it lets through.

Found 2026-10-18 in the wow-chat-2026 project, right after the project was
copied to `/mnt/kaun/wow-chat-2026` and every old folder name was turned into
a link to its new place (wow-chat-2026's issue 188). The session had started
in `/home/ritz/games/azeroth-core/wow-chat-2026`, an old name that now leads,
through two links (`/home/ritz/games` -> `/mnt/mtwo/games`, then
`/mnt/mtwo/games/azeroth-core/wow-chat-2026` -> `/mnt/kaun/wow-chat-2026`),
to the very same folder as the new name. The owner made the permission file
and asked the session to move to the new name. What happened, three times:

- `cd /mnt/kaun/wow-chat-2026 && pwd` printed the old name.
- The permission file was still there afterwards, unspent (made 16:19,
  present after the `cd`).
- The shell kept showing the old name (`pwd`), while `pwd -P` showed the new
  one and both names had the same inode (93061121).

What explains all three: the harness drops a leading `cd <the current
directory> &&` from a command before hooks see it (already noted in the
gate's own comments, "OBSERVED ON CLAUDE CODE 2.1.280"). It counts the new
name as the current directory, because both names are one folder, so it
dropped the `cd`, only `pwd` ran, and the gate never saw a `cd` to spend the
permission on. One earlier `cd`, made before `/mnt/kaun/wow-chat-2026` was
added to the session's allowed folders, did spend a permission and printed
the new name; the shell was back at the old name by a later command.

So two things are wrong, and one is missing:

1. **A permission can be left armed.** The owner made the file for one move;
   the move never reached the gate; the file stays, and the next `cd` the
   session tries, for any reason, minutes or days later, goes through
   silently and spends it. A one-time permission that outlives the request
   it was made for is a standing permission.
2. **Nobody is told.** The session saw only that the folder "didn't move";
   it took reading the gate's comments to learn why.
3. **No way to switch names.** When one folder has two names (a link left
   behind by a move), there is no way to make the session show and use the
   new name: the harness treats the move as a no-op, and its display keeps
   the name the session started with.

The gate is not the cause of 3 (the harness is), but it is where the person
asks for the move, so it is where the answer belongs.

## Intended Behavior

- **A permission dies with its request.** The permission file is good for
  one move, within a short time of its making (a number of minutes, set in
  the gate), and the gate removes a permission older than that the next time
  it runs at all, saying so ("an unused permission to move folders, made at
  16:19, was removed: no move used it").
- **A no-op move is said to be one.** When the gate can tell that a `cd`
  target is the current directory under another name (both resolve to the
  same real folder), it says so in words, and does not spend the permission:
  "the session is already in that folder; it shows the name it started with.
  To have it use the new name, start a new session there."
- **The move between names has an answer, written down.** The gate's
  documentation (`README-refusal-gates.md`) explains the case: a folder
  reached by a link shows the name the session started with, and starting a
  session at the new name is the way to change it; and that the saved list
  of extra working folders (in the project's settings) should drop the old
  name, or it will come back.

## Suggested Implementation Steps

1. Reproduce on paper: the gate's tests (beside the gate, as for the other
   refusal gates) gain a case for a permission file older than the limit
   (removed, with the message) and one for a `cd` to another name of the
   current folder (allowed as a no-op, not spent, with the message). Two
   names of one folder can be made in RAM with a link under the project's
   `tmp/shared-memory/`.
2. In the gate: before deciding, compare the permission file's age with the
   limit; remove it and say so when it is older. When the command's `cd`
   target resolves to the same real folder as the current one, say so and
   leave the permission alone.
3. Note in the gate's comments that a dropped `cd` never reaches it, so the
   age limit is what keeps an unspent permission from lingering (the gate
   cannot see the commands the harness swallows).
4. Write the folder-with-two-names case into `README-refusal-gates.md`.
5. Try it live: the owner names the new folder in the permission, the
   session runs `cd /new/place` alone, and `pwd` is read on that command,
   on the next one, and after the owner runs a `!` command. If the session
   falls back to the old name, the cause is in Claude Code, not the gate:
   write down when it happens, here and in the guide.
6. In a new session started in `/mnt/kaun/wow-chat-2026`: `pwd` shows that
   name; `~/.claude/session-env/<session>/` holds the hook's file; a
   permitted move into a subfolder and back shows each new name.

## Related

- `refuse-directory-change` (the gate), `libs/hook-gate.lua` (the shared
  refusal and permission handling, which the other gates' permissions may
  want the same age limit from), `README-refusal-gates.md`.
- wow-chat-2026 issue 188 (the move to `/mnt/kaun`) and its links.
- Issue 039 (a separate account for Claude): the same family of
  safeguards, the gates being "an honour system with a witness".

## Open Questions

1. (Answered 2026-10-18: "sure fine whatever") How long should a permission
   live? Ten minutes, as built (`PERMISSION_MINUTES` in the gate).
2. Should the age limit apply to every gate's permission file (the shared
   `hook-gate.lua`), or only to the folder gate's? Built for the folder
   gate only, since only its moves are known to be dropped unseen.
3. (Answered 2026-10-18: "let's expand that functionality to allow for
   directory switching when specifically allowed") A move between two names
   of one folder is a move: refused without a permission, let through with
   one, with a notice.
4. (Answered 2026-10-18: "fix our hook scripts please"; starting a new
   session was "not an option") Not reported: fixed in our hooks, by
   `carry-working-folder-name` and its `--now`.
5. (Settled 2026-10-18, by the owner's permission for a one-step move to the
   new name) The gate's two-step change of names was taken out: a permitted
   move to another name of the current folder goes through in one step, with
   a notice.
