# Issue #033: The RAM scratch tiers rebuild themselves

## Current Behavior

Implemented, apart from installing the hook (step 5, which edits
`~/.claude/settings.json` and is left to whoever holds that file) and the
follow-up list, and holding the two open questions at the end.

`libs/ensure-ram-tiers` is the single definition, sourceable or executable,
with ensure and restore modes; `libs/ensure-ram-tiers.lua` wraps it for
LuaJIT programs without restating the layout; `restore-ram-tiers` is the
session-start hook; `init-project.sh` calls ensure mode instead of carrying
its own copy. `tests/test-ram-tiers.sh` covers every case in step 6 plus the
executed, sourced and Lua forms, and a missing jq.

What follows is the problem as it was first described.

Every project keeps its scratch space in RAM, in two tiers reached through one
symlink:

    <project>/tmp                    -> /tmp/<name>            (the exec tier)
    /tmp/<name>/tmp/                    scratch that gets executed
    /tmp/<name>/shared-memory        -> /dev/shm/<name>        (the artifact tier)

Both targets live in RAM, so a reboot erases them. The symlink in the project
survives, because it is on disk, and afterwards points at nothing. On
2026-09-22 every `tmp` link checked under the monorepo was dangling, and so
were Double Diaper Dungeon's and wow-chat-2026's (for a current count, run
`census-projects.lua --conventions` in delta-version). Any
tool that writes `tmp/shared-memory/run.log` into a dangling link fails with
"No such file or directory", or worse, a tool that runs `mkdir -p tmp/...`
first gets an error about a file existing where a directory should be.

The knowledge of how to build the pair lives in exactly one place,
`link_ram_directories` in `init-project.sh`, and nothing else can call it. So
projects either rebuild their tiers by hand, or each run script carries its
own copy of the three lines, which is how the tiers drifted: two projects on
disk point their `tmp` at a name that is not their own directory name
(`wow-chat-2026 -> /tmp/wow-chat-2`, `filesystem-tapestry -> /tmp/filesystem-tapestry-tmp`).

## Intended Behavior

The tiers rebuild themselves, from two directions, both reading one shared
definition.

**Every session starts with them present.** A SessionStart hook,
`restore-ram-tiers`, reads the directory the session starts in from the hook's
input, walks upward to the nearest directory holding a `tmp` symlink, and
recreates whatever the reboot erased. It says nothing when it succeeds. It
exits 1 with a sentence naming the problem when it cannot repair them, which
Claude Code shows the person as a non-blocking error; it never exits 2, since
that would be read as a refusal.

**Every tool that needs them makes sure of them first.** A run, compile, test
or update script that is about to write into `tmp/` calls the shared library
before it does, so the tiers are present even when no Claude session has
started since the reboot. This is the standing rule, and the library is what
makes following it a one-line call instead of three lines copied and drifted.

**One definition, two modes.**

- *ensure* — used by tools and by `init-project.sh`. Creates the `tmp` link if
  the project has none, then repairs.
- *restore* — used by the session hook. Repairs a project that already has a
  `tmp` link, and never gives a directory a `tmp` link it did not have. A
  session can start anywhere, including directories that are not projects,
  and a hook that planted symlinks wherever it landed would be a hook nobody
  could trust.

Both modes honour a link that already exists and points somewhere other than
`/tmp/<name>`: the link records where the project wants its tier, so that is
where the tier is rebuilt. The artifact tier's name cannot be recovered after a
reboot, because the link that recorded it lived inside the erased exec tier,
so it is rebuilt at `/dev/shm/<project directory name>`.

Both modes refuse, with an error rather than a guess, when:

- `tmp` exists and is not a symlink. Inside an init-project sandbox this is
  normal and correct (the whole project is already in RAM), so the refusal is
  "leave it alone and say nothing" rather than an error; see the branch
  comment in the library.
- the `tmp` link, or the `shared-memory` link inside it, points anywhere other
  than under `/tmp/` or `/dev/shm/`. The convention is that these tiers are
  RAM; a link into a disk directory is either a mistake or a decision someone
  should make on purpose, and rebuilding it silently would bless it.
- something that is not a directory sits where a tier directory should be.

## Suggested Implementation Steps

1. Write `libs/ensure-ram-tiers`: a bash file that can be sourced (giving
   `ensure_ram_tiers <project-dir>` and `restore_ram_tiers <project-dir>`) or
   executed (`ensure-ram-tiers [--restore] [project-dir]`). It is the only
   place the tier layout is written down.
2. Write `libs/ensure-ram-tiers.lua`, a LuaJIT module for Lua programs, which
   calls the bash library rather than reimplementing it, so there is still one
   definition. Errors from the library become Lua errors.
3. Write `restore-ram-tiers`, the SessionStart hook: read `.cwd` from the
   hook's JSON with jq, walk up to the nearest `tmp` symlink (stopping below
   `/`), call restore mode, stay silent on success. A missing jq, unreadable
   input, or a missing `cwd` field is exit 1 with a message, never a silent
   pass.
4. Replace `link_ram_directories` in `init-project.sh` with a call to ensure
   mode (issue 026 does this as part of the skeleton split).
5. Install the hook in `~/.claude/settings.json` under `SessionStart`, with a
   short timeout; it does a handful of `mkdir` and `ln` calls.
6. Test both modes against scratch projects: a fresh directory, a dangling
   default link, a dangling custom-target link, a link that is already whole,
   a `tmp` directory (sandbox case), a link into a disk directory, a file
   where the exec tier should be, and the hook walking up from a subdirectory
   and finding nothing to do in a non-project directory.

## Follow-up (outside this repository, not done here)

The run, compile, update and demo scripts in individual projects each carry or
lack their own tier set-up. Each should source this library at its start. They
belong to their projects' own issue files, and are listed here so they are not
forgotten:

- every project's `run`/`compile`/`update`/phase-demo scripts that write to
  `tmp/shared-memory/`; `census-projects.lua --conventions` in delta-version
  already counts which projects have the tier link, and is the tool to find
  them.

## Open Questions

- Two projects with the same directory name in different places (a game under
  `games/` and one at the top level, say) would share `/tmp/<name>` and
  `/dev/shm/<name>`. No such pair exists today. Should the tier name be made
  unique (for example by including the parent directory), or is a name clash
  something to refuse loudly when it happens?
- CLAUDE.md names the exec tier as "/tmp/{project_name}/tmp/" and says the
  project's `tmp` link points at `/tmp/{project_name}`. The library follows
  that, which means code run from `tmp/` lives at `tmp/tmp/`. Is that
  double `tmp` intended, or should executables sit directly in `/tmp/<name>/`?

## Related Documents and Tools

- `init-project.sh`, `init-project.info.md` — the first caller of ensure mode.
- `issues/026-skeleton-without-a-monorepo.md` — the skeleton split that moves
  the tier set-up out of the sandbox-only path.
- `/home/ritz/.claude/settings.json` — where the SessionStart hook is
  installed.
