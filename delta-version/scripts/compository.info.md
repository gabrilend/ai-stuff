# compository.lua

## Overview

Carries every one of the owner's git repositories to a marked flash drive,
and keeps the copies current. Each copy is an ordinary clone, readable on any
computer, whose upstream (`origin`) is the repository's folder on this
computer: git accepts a plain folder path as a remote. Updating is fetch, then
fast-forward only, so a copy moves forward and never backward, and work done
on the drive is never overwritten. Safe to run any number of times (issue 061).

## Commands

    compository.lua                   update every connected, marked drive
    compository.lua --drive=/mount    update one marked drive (any disk, any folder)
    compository.lua --init=/mount     mark a drive as a compository (writes .compository)
    compository.lua --list            what would be carried, what is passed over and
                                      why, and which removable drives are mounted

Options, in any position: `--dir=/path/to/delta-version`, `--workers=N`
(default: CPU cores), `--list-file=/path/list.lua` (the tests use one).

Exit status: 0 every repository current; 1 a repository refused, no marked
drive connected, or the run refused; 2 an unknown mode.

## What is carried

From `../assets/compository-list.lua`:

| Field | Type | Meaning |
|-------|------|---------|
| `repositories.roots` | list of strings | folders searched, at any depth |
| `repositories.owner_emails` | list of strings | a repository is carried when its first commit (the oldest root commit on any branch) was made under one of these |
| `repositories.never_enter` | list of strings | folder names the search does not descend into |
| `repositories.exclude` | list of strings | owner's repositories kept off the drive, as paths relative to a root |
| `selected` | list of strings | hand-picked notes, documents and tools, relative to the first root |
| `selected_repository` | string | where the selected items are gathered into a git repository of their own |

Before each update, the selected items are copied into `selected_repository`
(exactly the listed set; anything else there but `.git` is cleared) and
committed if anything changed, under the owner's git identity. That makes it
one of the owner's repositories, so it is found and carried like the rest,
and the drive plays it forward. An empty list makes no repository. A listed
item that does not exist stops the run.

Passed over: repositories with no commits, repositories whose first commit is
someone else's, and worktrees or submodules (a `.git` *file*, not a folder).

## On the drive

    <drive>/.compository                    the marker; nothing is written without it
    <drive>/compository/<relative path>/    one clone per repository, at the same
                                            path it has under its root

A repository nested inside another on the computer is cloned inside the
other's copy on the drive, so repositories are updated in layers: outer ones
first, then those nested one level down, and so on. Within a layer, one
worker per core runs in parallel.

## What one repository's update does

| Situation | Result | Report word |
|-----------|--------|-------------|
| not on the drive | `git clone --no-hardlinks` | `cloned` |
| a folder is there but holds no repository | nothing | `refused` |
| `origin` points somewhere else (the repository moved) | re-pointed, then updated as usual | noted in the line |
| tracked files changed on the drive | nothing | `refused` |
| fetched; the drive's branch can fast-forward | moved forward | `advanced` |
| fetched; nothing new | nothing | `current` |
| the drive's branch has commits the computer lacks | nothing | `refused` |
| the drive's branch no longer exists on the computer | nothing | `refused` |

Untracked files on the drive do not count as changes, because a nested
repository's copy appears as an untracked folder inside its parent's copy.

On FAT or exFAT drives, new clones get `core.symlinks=false` and
`core.fileMode=false`, since those filesystems store neither.

## Which drives are "connected"

Mounted partitions whose disk `lsblk` reports as removable or on USB. Of
those, only the ones with `.compository` at their mount point are written.

## Tests

`test-compository.sh` uses a pretend computer and drive in the RAM tier.
It passes 22 checks, including five on the selected items (gathered,
carried, no empty commits, changes played forward, a missing item refused): an unmarked drive is refused and left empty; only the
owner's repositories are carried, a nested one included; a second run
changes nothing; new commits are played forward; a drive's own commit, and
an uncommitted edit on the drive, are both left in place and reported.
