# Issue #039: A separate login account for Claude, so the filesystem knows who made what

## Current Behavior

Not started. Planned and parked on 2026-10-01; the owner said "we'll get
around to it eventually."

Claude Code runs as the owner's own login account (`ritz`). Every file it
creates is stamped by the kernel with the owner's user number, so on disk a
Claude-made file and a hand-written file look identical. The only record of
who wrote what is in git: commit authors and Co-Authored-By trailers. Nothing
on the filesystem stops Claude from editing a hand-written note. The only
thing protecting those notes is the instruction in CLAUDE.md.

## Intended Behavior

Claude Code runs as its own login account (working name `claude`). This does
two things:

1. **Authorship is visible on disk.** A file's owner field (an integer user
   number in the file's inode, the small record the filesystem keeps for each
   file) says which author *created* it. "Own" here means "constructed by
   this hand under joint direction", not property: everything made here is
   shared work that could not exist without both authors.
2. **Hand-written files can't be edited by automatic hands.** The kernel
   refuses Claude's writes to files the owner wrote. When a change to a
   hand-written file is asked for, it happens as **copy and update**: Claude
   reads the original (still allowed), writes a new file beside it, and the
   human-written original stays exactly as it was. The filesystem enforces
   this. It doesn't rely on anyone remembering the rule.

### The mechanism

- **Shared group** (working name `authors`) holding both `ritz` and `claude`.
  Project folders belong to this group.
- **Setgid bit on folders** (`chmod g+s`): new files inherit the folder's
  group instead of the creator's own group, so both authors can always read
  each other's files.
- **Mode bits per author**:
  - Hand-written files: `644`. The owner reads and writes; the group, which
    includes Claude, only reads.
  - Claude-made files: `664`. The group can write too, so the owner can still
    edit Claude's work (see open question 3).
  - Made automatic by the umask, the per-account mask that removes permission
    bits from every new file: `ritz` keeps `022`, which strips group-write;
    `claude` gets `002`, which keeps it.
- **Sticky bit on every shared folder** (`chmod +t`, the same protection
  `/tmp` uses). **This is the piece the scheme depends on.** Normally,
  permission to write a folder includes permission to delete or rename *any*
  file in it, whoever owns the file. Most editors and tools save by writing a
  new file and renaming it over the old one, so without the sticky bit Claude
  could replace a hand-written note it is not allowed to write. With the
  sticky bit, only a file's owner (or root) can delete or rename it.
- **No sudo for `claude`.** Root ignores every rule above, so the account
  must not be in sudoers.

## Known Difficulties

1. **Git doesn't store ownership.** Clone, checkout, stash, rebase and reset
   all recreate files as whoever ran the command. One `git checkout` by the
   owner turns every Claude file into the owner's, and the reverse is also
   true. Disk ownership is a live enforcement layer, not a durable record.
   The durable record stays in commit metadata (see open question 2).
2. **Git needs configuring for two users:**
   - `core.sharedRepository=group`, so object files written into `.git` by
     one account stay writable by the other.
   - A `safe.directory` entry for the `claude` account, because git refuses
     to operate in a repository owned by a different user ("dubious
     ownership").
3. **Ownership records who created a file, not who last wrote it.** When the
   owner edits a Claude-made file in vim, the sticky bit stops vim from
   renaming a new copy over it, so vim rewrites the file in place and the
   owner field stays `claude`. A file both authors have rewritten carries
   only one name (see open question 1).
4. **The home folder blocks traversal.** `/home/ritz` is probably mode `700`,
   so `claude` can't walk into `~/programming/ai-stuff`. Either grant
   traverse-only permission (`x` without `r`) along the path, or keep the
   shared work outside the home folder (`/mnt/mtwo/programming/ai-stuff` is
   already outside it).
5. **Claude's settings live per account.** The global CLAUDE.md, skills,
   hooks, the edit ledger and the login token all sit under
   `/home/ritz/.claude/`. The `claude` account needs either its own copy or a
   readable link to them. A link means the owner's instructions stay the
   single source; a copy means the two can drift apart.
6. **Existing files are all owned by `ritz`.** Sorting today's files means
   guessing from git history (Co-Authored-By trailers, which session's
   transcript created which path). Files both authors wrote stay ambiguous.
7. **The filesystem type must support Unix owners.** ext4, btrfs and xfs do.
   NTFS, exFAT and FAT don't keep per-file owners (they fake one per mount),
   so none of this works on them. `/mnt/mtwo` hasn't been checked yet.
8. **The RAM scratch tiers** (`/tmp/<project>` and `/dev/shm/<project>`, see
   the RAM-tiers issue) are created by whichever account touches them first.
   They need the same group, setgid and sticky treatment, or one author
   locks the other out after every reboot. The tier-restoring library is the
   single place to add this.
9. **The house tools assume one user.** The edit ledger, the commit gate,
   the one-time permission tokens in `/tmp/claude-allow-*` and the transcript
   exporter all need checking. Which account writes each one, and which
   account must be able to read it?

## Suggested Implementation Steps

1. Check the filesystem type of every place shared work lives (`findmnt`).
   Stop here if any of them can't hold Unix owners.
2. Create the `authors` group and the `claude` account (no sudo, umask `002`
   in its login profile). Add `ritz` to `authors`.
3. Decide how the `claude` account gets its Claude Code configuration (copy
   or link, difficulty 5) and its login token, then run Claude Code once as
   that account to confirm it starts (`sudo -u claude -i claude`, or a
   separate terminal login).
4. Write one script, with the usual hard-coded directory and an optional
   argument, that prepares a project tree for shared authorship: group to
   `authors`, setgid and sticky on every folder, hand-written files to `644`.
   It reports what it changed and never touches `.git` internals beyond
   setting `core.sharedRepository`. Tests run it against a throwaway tree.
5. Test the enforcement directly as `claude`, each attempt expected to fail
   on a hand-written file:
   - write into it,
   - truncate it,
   - rename over it,
   - delete it,
   - change its mode.
   Then confirm reading it and creating a sibling file both succeed.
6. Test the owner's side: editing a Claude-made file in vim works and leaves
   the owner field as `claude` (difficulty 3, recorded as expected
   behaviour).
7. Teach the RAM-tier library the group, setgid and sticky treatment
   (difficulty 8).
8. Walk the house tools in difficulty 9 one at a time and fix each one's
   assumption of a single user.
9. Decide on and run the classification of existing files (difficulty 6),
   once open question 2 is answered.
10. Write the "copy and update" convention into CLAUDE.md: how a new file
    beside a hand-written one is named, and how it points back to the
    original.

## Stronger Options (most useful first)

- **The sticky-bit scheme above**: covers almost every case.
- **Access control lists** (`setfacl`): per-user rules on top of the mode
  bits, such as "user claude may never write here", which survive a careless
  `chmod` better. Default ACLs on folders apply to new files automatically.
- **The immutable attribute** (`chattr +i`) on irreplaceable human notes:
  only root can set or clear it, and while it is set nobody can modify,
  rename or delete the file, the owner included.

## Open Questions

1. When both authors have each rewritten half of a file, which name should
   it carry: the creator, the last writer, or both? The owner field holds
   one. "Both" means the record lives elsewhere: commit trailers, a sidecar
   file, or extended attributes (small name/value labels the filesystem
   attaches to a file, e.g. `user.authors`). Note that extended attributes
   are also lost on a git clone.
2. Since a clone erases ownership, what is the source of truth: the disk or
   the git history? Leaning: git history is the record, and disk ownership
   is the live enforcement layer.
3. Should the owner edit Claude's files freely (`664`), or should
   copy-and-update also apply in that direction (`644` for Claude's files
   too)?
4. What filesystem is `/mnt/mtwo`?

## Related Documents and Tools

- `issues/033-ram-tiers-rebuild-themselves.md`: the RAM scratch tiers that
  need group and sticky treatment.
- `issues/032-commit-only-your-own-lines.md` and its sub-issues: the edit
  ledger and commit gate that assume one user.
- `/home/ritz/.claude/CLAUDE.md`: where the copy-and-update convention would
  be written down.
