# The room

What the visitor can reach, and what "view-only" is actually made of.

**Not yet built.** The [arrangement](001-the-arrangement.md) decides and
the [grant](002-the-grant.md) creates, but nothing yet configures sshd,
so an armed grant today makes an account that cannot log in. That is the
safe direction to be unfinished in, and it is why arming is not yet
useful.

## Two mechanisms, both the operating system's

**A chroot the session cannot climb out of.** sshd enforces a
requirement of its own here, not a convention: every component of the
chroot path must be owned by root and writable by nobody else. A session
whose chroot fails that check is refused, and the reason appears only in
the server's log. So the tree has a root-owned shell with the visitor's
view inside it.

**sshd's own read-only mode.** `internal-sftp -R` refuses every
filesystem-changing operation inside the SFTP protocol itself — no
writes, no deletes, no renames, no new directories. This matters more
than it first appears: relying on file permissions instead would mean
every exposed file and directory had to be correct, forever, including
ones added later. The `-R` flag is one place instead of many.

```
Match User view-*
    ChrootDirectory /srv/viewing/%u
    ForceCommand internal-sftp -R
    AllowTcpForwarding no
    X11Forwarding no
    PermitTunnel no
    PermitTTY no
```

`internal-sftp` is served from inside sshd's own process, so the jail
needs no `/bin`, no `/lib`, and no copied binaries. An ordinary chroot
around a login shell would need all of them, and every one would be
something else to keep patched.

The three `no` lines close side doors: without them a session that cannot
touch files could still use the machine as a route onto its network.

## What is inside

```
/srv/viewing/view-ritz/     root:root  0755   <- ChrootDirectory
    look/                   root:root  0555   <- read-only bind mount
```

The exposed subtree arrives by bind mount, remounted read-only:

```
mount --bind        /the/shared/tree /srv/viewing/view-ritz/look
mount -o remount,ro,bind             /srv/viewing/view-ritz/look
```

Two commands, not one — a bind mount does not take its options on the
first call, and a `--bind` with `-o ro` silently produces a *writable*
mount on many kernels. That silence is the reason the remount is written
down as its own step rather than folded in.

The read-only mount and `internal-sftp -R` overlap on purpose. Either
alone would do; both together mean a mistake in one is not the end of it.

## Open questions

- **What subtree is exposed?** Undecided, and it is the whole question —
  it is the boundary of everything a visitor can reach.
- **One room per visitor, or one shared?** Separate rooms mean nobody
  sees anybody else, which forecloses the idea in
  [the second vision](../notes/vision-2) that watchers might examine each
  other. A shared room needs one mount rather than one per visitor.
- **Who makes the room, and when?** Making it at grant time means a
  mount per visit and a mount to unwind at expiry. Making it once at
  startup means the mount outlives every visitor.
- **The project promises no logs, but sshd writes authentication records
  regardless**, through the system logger. Silencing that is a change to
  the host rather than to anything here, so the promise as currently
  written is not true.
