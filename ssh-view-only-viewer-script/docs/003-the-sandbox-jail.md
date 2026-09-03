# The jail

The first vision: a room someone reaches over SSH, cannot leave, and
which refills itself. It knows nothing about mail and would work with
files placed by hand.

## The shape on disk

OpenSSH's chroot has a requirement enforced by sshd itself, not by
convention: **every component of the chroot path must be owned by root
and writable by nobody else.** A session whose chroot directory fails
that check is refused, with the reason appearing only in the server's
log. So the tree has two layers — a root-owned shell, and a
viewer-owned room inside it.

```
/srv/viewing/<viewer>/          root:root  0755   <- ChrootDirectory
    reading/                    <viewer>:<viewer> 0700
        <one drawn file>                          <- hard link, not a copy
```

The viewer can list, read, and unlink inside `reading/`. They cannot
write above it, because everything above it is root's. They cannot leave
it, because chroot. That is the whole enforcement, and it is done by the
kernel and sshd rather than by anything this project writes.

## The session

```
Match User <viewer>
    ChrootDirectory /srv/viewing/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PermitTunnel no
```

`ForceCommand internal-sftp` replaces whatever the client asked to run,
so there is no shell to get. `internal-sftp` is served from inside sshd's
own process, so the jail needs no `/bin`, no `/lib`, and no copied
binaries — an ordinary chroot for a login shell would need all of them.
The three `no` lines close the side doors that a session could otherwise
use to reach the network rather than the files.

## Why the file is a hard link

The draw returns a path inside the corpus. Placing it in the room by hard
link rather than copy means:

- no second copy of the bytes exists, so the room costs nothing
- unlinking it in the room does not touch the corpus, because the corpus
  still holds a reference
- the corpus and the room must therefore be on the same filesystem, which
  is a real constraint and the reason the corpus root is a config value
  rather than something discovered

If they cannot be on one filesystem, the fallback is a copy, and then
deletion becomes genuinely destructive of nothing while costing the bytes
twice. Fallbacks are warnings here: a copy path should say so out loud.

## Deletion is the request

The viewer empties `reading/`. Something notices and puts a new drawn
file in. Two ways to notice:

- **inotify on the room** — immediate, needs a watcher process per room
- **a poll on a short timer** — simpler, adds latency equal to the period

The watcher is the same shape as the refill loop's delete hook: a signal
saying *this viewer wants another*, carrying nothing else.

## Credentials

Deliberately thin, for the reason in [the overview](000-what-this-project-is.md):
the jail is the guarantee, and the credential only bounds how many draws
a stranger gets. A persistent Unix account per viewer with a rotating
password costs less than creating and destroying accounts per session,
which is where orphaned home directories and races live. The
"temporarily" of the vision is carried by the password, not the account.

The pairing rule from [the first vision](../notes/vision) — username is
one name, password is another — is **not yet decided**, and the project
does not need it decided to build the room.

## Open questions

- **What is the pairing rule?** Unanswered. The candidates were: the name
  of another viewer currently holding a session (so nobody enters alone),
  the server's own name (one shared secret), or something carried in the
  triggering packet.
- **Is there still a knock?** The first vision opens the door on "a packet
  with a small arrangement". If the account is persistent, the knock's job
  shrinks to unlocking a password rather than minting an account. Whether
  it is worth building at all is open.
- **No logs, but sshd logs.** The project promises to keep none. sshd
  writes authentication records regardless, through the system logger, and
  silencing that is a change to the host's configuration rather than to
  anything here. The promise as written is not currently true.
- **One room or several?** Three viewers means three chroots and three
  accounts. Nothing shares, which is simple, and nothing can be observed
  by anyone but its own viewer — which forecloses vision-2's idea that
  the watchers might examine each other.
