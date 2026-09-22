# init-project.sh

Lays out a project's standard skeleton anywhere, and - for a project inside the
monorepo - gives it a workspace an agent cannot escape from.

## The two halves

The **skeleton** is wanted by every project: the standard folders, the intent
folders (`input output desire faith strategems`), `docs/HTML/`,
`issues/completed/demos/`, `llm-transcripts/`, the table of contents, a
`.file-index-counter` starting at `000`, an `issues/phase-1-progress.md` stub,
the root `run-phase-demo` picker, the RAM scratch tiers, and `tmp` in
`.gitignore`. Each is written only when absent, so re-running over a project
that has been worked in changes nothing. It needs only coreutils.

The **sandbox** (everything below "What it is for") needs a monorepo git
checkout to clone from, and bubblewrap.

`--skeleton-only <path>` builds the first half alone, in any folder. A bare
project name builds both. Asking for a sandbox where the monorepo root is not a
git checkout is refused with a message naming `--skeleton-only`, rather than
quietly delivering the skeleton instead.

The RAM tier layout is not defined here: `link_ram_directories` calls ensure
mode of `libs/ensure-ram-tiers`, the same definition the session-start hook
`restore-ram-tiers` uses to rebuild the tiers after a reboot (issue 033). An
existing `tmp` link is honoured, not re-pointed.

## What it is for

Running an AI agent with permission checks turned off is only reasonable if the
blast radius is bounded. This script bounds it. It builds a copy of a project in
RAM and hands the agent a private view of the filesystem in which that copy is
the only writable thing, the rest of the home directory does not exist, and the
system directories are read-only. Damage is undone by rebooting.

The containment is a Linux mount namespace, not a convention or a policy file.
An agent cannot decline to be contained by it, because the paths it would need
are not present in the namespace to begin with.

## What it does not do

**It does not contain the network.** The agent must reach the API to function,
so the wire stays open. Anything that leaves over the network - a push, an API
call, a file uploaded somewhere - happens for real and is not undone by a
reboot. The wall is around the disk only.

**It does not decide when work is finished.** Committing is what carries work
out of RAM and onto the disk; see `carry-back.info.md` for that half. Until a
commit happens, the work exists only in memory.

## Commands

    init-project.sh <name>
        Create the project folder, its skeleton, its sandbox, and its launcher.

    init-project.sh --skeleton-only <path>
        Lay out the skeleton in <path> (created if missing), inside the
        monorepo or not. No clone, launcher, or sandbox notice. Refused
        together with --refresh, --writable, or a project name.

    init-project.sh --refresh <name>
        Rebuild the sandbox and launcher from current disk state. Leaves the
        project's own files alone. Refuses if the sandbox holds work that is
        not on disk, and prints the file list so the refusal is actionable.

    init-project.sh --writable <path> <name>
        Mount one gitignored path read-write instead of read-only. Repeatable.
        Path is relative to the project root; a trailing slash is optional.
        Each use is a hole in the wall - writes through it reach the real disk.

    init-project.sh --branch <name> <project>
        Work on a branch other than master. The sandbox is an execution
        environment, not a maturity level: work done inside it is ordinary
        work, belonging on whatever branch it would have belonged on anyway.
        Branch when you actually want to experiment, same as outside.

    init-project.sh --dir <path> <name>
        Point at a different monorepo root. Intended for testing against a
        throwaway tree rather than the real one.

    init-project.sh --help

## What gets created

| Path | Kind | Notes |
|---|---|---|
| `/tmp/claude-sandbox/<name>/` | RAM | the sandbox — a real git repository, rooted at the monorepo level |
| `/tmp/claude-sandbox/<name>/<name>/` | RAM | the project itself, and where the agent works |
| `<monorepo>/<name>/scripts/enter-sandbox.sh` | on disk | the launcher; gitignored, rewritten on every run |
| `<monorepo>/<name>/tmp` | on disk | symlink to the two RAM scratch tiers; gitignored |
| `<monorepo>/<name>/` everything else | on disk | **written only by carry-back**, never by this script |
| `/tmp/<name>/`, `/dev/shm/<name>/` | RAM | the project's normal two-tier scratch space |

Enter the sandbox by running the launcher. Nothing else needs to be invoked —
it starts the carry-back watcher, runs the session, and catches up on the way
out.

## The single-writer rule

The real project directory has exactly one writer: `carry-back.sh`. This script
writes tracked content into the **sandbox** and lets it reach disk by being
committed.

This is not tidiness, it is a bug fix. When the skeleton was written to disk
untracked and the agent then edited those same files in the sandbox and
committed them, the incoming version differed from the untracked copy sitting in
its way — and git will not fast-forward over an untracked file it cannot vouch
for. Every new project stalled on its first carry. Giving the directory one
writer removes the collision entirely.

The launcher and the `tmp` symlink are the exceptions, and they are safe ones:
both are gitignored, and git cannot conflict over what it does not track.

## Behaviours worth knowing before changing anything

**The sandbox is a real repository that borrows the object store.**
`git clone --shared` writes a repository whose object store is a one-line
pointer at the real one instead of a copy: 4 GB of history becomes a 108 KB
clone in about eight milliseconds. New objects go into the sandbox's own store
in RAM, so the borrowed one can be mounted read-only and committing still works.
The read path and the write path are physically different directories, which is
the whole trick.

Two consequences follow. First, `git gc --prune` on the real repository while a
sandbox is live could delete objects the sandbox still references — survivable,
since sandboxes are disposable, but it is the failure that would look
inexplicable at 2am. Second, the borrowed store contains **every** project's
committed history, so other projects' files are absent from the filesystem but
readable through `git show`. The generated notice states this precisely rather
than claiming an isolation that does not hold.

**The borrowed store is reached by a path the sandbox mount does not cover.**
The sandbox is mounted at the monorepo's own path, so `<monorepo>/.git/objects`
inside the namespace resolves to the sandbox's own store — the borrowing would
quietly become self-referential. The alternate therefore lives at
`~/.sandbox-objects/<monorepo-name>`: a symlink on the host, a read-only bind
mount at the same path inside. One path, valid in both worlds, because the
carry-back runs on the host and has to read this repository too.

**Sparse checkout keeps the working tree small.** The monorepo tracks nearly
five gigabytes; one project is a few megabytes. Cone mode also brings the
repository root's files, which is wanted — the root `.gitignore` must be present
for git to agree with us about what is ignored. A project that does not exist on
the branch yet is fine: it checks out nothing, and the rsync step supplies the
files as untracked, ready for a first commit.

**Mount order is load-bearing.** Bubblewrap applies mounts in sequence and a
later one shadows an earlier one at the same path. The layout blanks the whole
data disk with a single tmpfs and then binds back only what is needed, which
gives deny-by-default for free. Reordering the arguments produces either an
empty sandbox or an open one, and neither reports an error.

**The sandbox is presented at the project's real path.** Inside the namespace,
`/tmp/claude-sandbox/foo` appears as `<monorepo>/foo`. Absolute paths in
project documentation therefore keep working, transcripts get keyed correctly,
and a mistaken reach for a neighbouring project fails loudly instead of quietly
succeeding.

**Ignored paths are asked for, not parsed.** The monorepo's ignore file runs to
hundreds of lines with negations, and each project layers more on top. Git's own
matcher is consulted rather than reimplemented. A directory that git collapsed
only because its current contents happen to be ignored is detected and descended
into, rather than mounted whole - otherwise gitignoring one generated file inside
a source directory would mount that entire directory read-only.

**The unsaved-work check compares content, not timestamps.** Copying, touching,
or regenerating a file moves its clock without changing a byte, and every one of
those would otherwise read as work in progress. The check also ignores exactly
what the copy ignores, so the empty mountpoint directories a session leaves
behind are not mistaken for something a person made.

**Re-running is the normal way to use it.** Every generated artefact is replaced
from current state; every hand-written one is left alone. The only case that
stops the script is the one where continuing would destroy something.

## Internals

Functions, in the order the work happens. All are internal; the script's
interface is its command line.

| Function | Does |
|---|---|
| `parse_arguments` | reads the command line; rejects project names that could escape the monorepo root |
| `settle_skeleton_target` | turns the `--skeleton-only` path into the project path and name; refuses a file, or sandbox-only flags given alongside |
| `main` | picks one of the two halves from a table: `run_skeleton_only` or `run_with_sandbox` |
| `run_skeleton_only` | skeleton, gitignore (`tmp` only), RAM tiers, then a report saying the sandbox was not built and why |
| `run_with_sandbox` | the original full path, now beginning with `require_sandbox_tools` |
| `require_sandbox_tools` | confirms bubblewrap, git and rsync exist, that the kernel permits unprivileged user namespaces - without which nothing here isolates anything - and that the monorepo root is the top of a git checkout |
| `create_project_skeleton` | makes the standard folder set, and seeds the table of contents, `.file-index-counter`, the phase-1 progress file and the demo picker where absent |
| `write_phase_demo_picker` | writes `run-phase-demo`, which lists `issues/completed/demos/phase-N-demo` in numeric order (so phase 10 works) and runs the one asked for |
| `link_ram_directories` | ensure mode of `libs/ensure-ram-tiers`: builds the RAM tiers and the `tmp/` link, or rebuilds behind an existing link |
| `write_project_gitignore` | adds the given missing entries only; never rewrites |
| `report_skeleton_only` | what the skeleton-only run built, and the sandbox half it did not |
| `collect_ignored_paths` | asks git what is ignored, re-expands accidentally-collapsed directories, and drops duplicates and never-bind entries |
| `is_writable_path` | whether `--writable` promoted a given path; slash-insensitive |
| `sandbox_has_unsaved_work` | uncommitted edits plus uncarried commits; ignores bare directories and the seven files this script generates or seeds, or it would cry wolf on every refresh |
| `check_sandbox_capacity` | refuses if the project would not fit in free RAM, since tmpfs exhaustion kills processes rather than slowing down |
| `provision_sandbox` | shared clone, sparse checkout, then rsync of current disk state so uncommitted work is not silently discarded |
| `write_sandbox_notice` | writes or replaces the marked block in CLAUDE.md |
| `compose_bwrap_arguments` | emits the mount plan; the security-critical function |
| `generate_launcher` | writes the launcher, embedding the mount plan and the writable overrides so a post-reboot rebuild reproduces them |
| `report` | prints what was built and what is not contained |

## Verifying the wall still holds

The containment is worth re-checking after any change to the mount plan. From
inside a sandbox, all of these should hold:

- the data disk contains only the agent binary and its settings
- other projects' files do not exist, though their history reads via `git show`
- `~/.ssh` does not exist
- writes to the project succeed and do not appear on disk
- writes to a read-only bind fail
- writes to a `--writable` bind succeed and do appear on disk
- writes to `/usr` fail
- writes to the borrowed object store at `~/.sandbox-objects/<name>` fail
- `git log` reads full history, and `git commit` succeeds

Note when testing that `<monorepo>/.git/objects` *inside* the wall is the
sandbox's own store, and writing there is correct. The borrowed one is the
path the alternates file names.
