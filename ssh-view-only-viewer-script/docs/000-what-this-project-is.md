# What this project is

A script that lets someone send a packet to a machine and be given
view-only SSH credentials on it. Once they have them, they browse the
filesystem as they please.

That is the whole goal. Everything else in this repository is either a
part of that, or an example of something to do with it.

```
   somebody, somewhere
          |
          |  a packet with a small arrangement in it
          v
   the listening machine
          |
          +-- reads the arrangement, decides it is genuine
          +-- creates a username and a password, briefly
          |
          v
   they ssh in, and look around
```

The credentials are **made on receipt** and did not exist before the
packet arrived. They are view-only: the session can read and traverse,
and cannot write, delete, rename, or execute. They expire.

## The three parts

**[The arrangement](001-the-arrangement.md)** — what a valid packet looks
like, and how the listening machine decides a packet is genuine rather
than noise or a replay. Pure reasoning about bytes; needs no privileges
and can be tested on its own.

**[The grant](002-the-grant.md)** — bringing a credential into existence
and taking it away again. This is the part that needs root, and the part
that must never leave an account behind.

**[The room](003-the-room.md)** — what "view-only" is actually made of,
and which part of the filesystem the visitor traverses. Enforced by sshd
and the kernel rather than by anything written here.

## And then, an example of what to do with it

Once someone can be given a temporary look at a filesystem, the question
becomes what to show them. [The refill loop](004-the-refill-loop.md) is
one answer, built on [r-mail](../../../programs/r-mail/README.md): a
viewer is handed one file at a time, chosen at random, and deleting it is
how they ask for the next. [The draw](008-the-draw.md) is the piece that
chooses.

This is an **example implementation**, not the goal. It is worked on
after the script above works, and nothing in the three parts is allowed
to depend on it.

## Where the risk sits

The visitor can traverse. That is the point, and it means the boundary of
what they can reach is doing all of the work — not the password, which
only decides how many visitors there are.

Two mechanisms carry it, and both are the operating system's rather than
ours: a chroot the session cannot climb out of, and sshd's own read-only
mode, which refuses every filesystem-changing operation inside the
protocol rather than relying on file permissions to say no.

A credential that outlives its visit is the other exposure. An account
left behind after the packet's window has closed is a door with no one
watching it, which is why removal is part of the grant rather than a
tidying step afterwards.
