# backup-transcript-corpus

Takes a verified, restorable snapshot of every saved conversation on the
machine.

## What it is for

For most conversations in the archive, the original session log was deleted
long ago. The transcript is the only surviving record. Any tool that renames
or rewrites them is therefore operating on something irreplaceable, and this
is what you run first.

## The one design decision worth knowing

**The snapshot is read back and compared before it is called a backup.**

The failure this exists to catch is not a copy that errors — that one
announces itself. It is a copy that reports success and wrote something
incomplete. So after writing the archive, the tool extracts it again, and
checks every file's contents and modification time against a manifest built
from the originals. Nothing is called verified on the strength of an exit
code.

## Why the modification times get special treatment

They are evidence, not decoration. For most of this archive the file's
timestamp is the only surviving trace of when the conversation happened. An
ordinary `cp -r` replaces every one of them with the time of the copy and
looks like it worked — which is exactly how one folder in this corpus came to
have 297 files sharing a single second.

So the times are carried two ways: inside the archive, where `tar` records
them as data, and again as plain numbers in the manifest, so a restore can be
checked rather than trusted.

## Commands

    backup-transcript-corpus
        Snapshot into /tmp, then verify it. Prints where it went.

    backup-transcript-corpus --to <dir>
        Somewhere else. Use ordinary storage if the snapshot needs to
        survive a reboot.

    backup-transcript-corpus --no-verify
        Skip the read-back. Faster, and worth much less.

    backup-transcript-corpus --dir <path>     where the scripts live
    backup-transcript-corpus --help

## What a snapshot contains

| file | what it holds |
| --- | --- |
| `transcripts.tar.gz` | every transcript folder, times and permissions recorded inside |
| `manifest.tsv` | per file: path, modification time in epoch seconds, SHA-256, conversation id |
| `folders.txt` | every folder covered |
| `history.jsonl` | the prompt history as it stood — the evidence any date repair reasons from, and a file that is appended to continuously, so it cannot be recovered later |
| `intended-plan.tsv` | what the repair tool was about to do, if a plan existed |
| `restore.sh` | puts it back |
| `README.md` | the above, written for whoever finds the folder cold |

## Restoring

    restore.sh                      say what would happen, change nothing
    restore.sh --confirm            restore everything
    restore.sh --confirm --only <path>    one subtree

Rehearsing is the default because putting files back is the dangerous
direction. Every restored file is checked against the manifest afterwards.

## Scope

Deliberately wider than any single repair: worktrees and backup directories
are included, because a safety net with holes chosen by reasoning is not one.

## Related

- `repair-transcript-timezone` — the thing you are usually protecting against
- `issues/018-date-range-transcript-naming.md` — the ticket
