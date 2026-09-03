# What this project is

Two machines' worth of idea, kept in one repository because they share a
single moving part.

Someone wants to look at files on a computer that is not theirs. They are
not given a list, not given a search box, and not given a way to ask for
anything in particular. They are given **one file at a time, chosen at
random**, and exactly one gesture to make: delete it. Deleting is how they
say *I read this, next one please*. A new file, also random, takes its
place.

There is no other verb. There is no browsing. The interface is an empty
hand that refills when you empty it.

## The two visions

They are separate, and the project keeps them separate on purpose.

**The tooling** — a sandbox someone can reach over SSH, landing in a
directory tree they cannot leave, holding files they did not choose.
This is [the jail](003-the-sandbox-jail.md). It knows nothing about mail.
It would work if the files were placed there by hand.

**The implementation** — the same idea carried by
[r-mail](../../../programs/r-mail/README.md), the file-based messaging
daemon. The server writes a message; the viewer's own machine receives
it; the viewer deletes it; the deletion travels backwards and the server
notices. This is [the refill loop](004-the-refill-loop.md). It needs no
SSH at all.

Nothing in r-mail changes to support this. The project is an
*implementation of* r-mail, not an integration *into* it. Every mechanism
it leans on — backward deletion propagation, the delete hook, per-recipient
attachments — already exists and is already documented.

## What they share

Both visions consume the same thing: a supplier that answers the question
*"give me a file, at random, that I am allowed to lend."*

That supplier is [the draw](002-the-random-draw.md), and it is the only
component both halves depend on. It is written first, and it is written
alone — the generating side knows nothing about who is going to look, and
the viewing sides know nothing about how a file got chosen.

```
                    the corpus
                        |
                   [ the draw ]          <- one generator
                    /        \
                   /          \
          [ the jail ]    [ the refill ]  <- two viewers
             (ssh)           (r-mail)
```

If the draw is wrong, both visions are wrong in the same way, which is
the argument for it being one component rather than two.

## Where the risk actually sits

Not in the password. The credential guards a room whose contents you
already chose to lend, so getting past it buys a stranger one random file
they were going to be shown anyway.

The exposure is **rate**. Deletion is the request, so anyone inside can
delete repeatedly and be fed repeatedly. A random draw, run enough times,
converges on a complete copy of whatever it draws from. The boundary of
the corpus — and whether the draw is allowed to repeat itself — is
therefore the security mechanism. Authentication only bounds how many
draws a stranger gets.

This is why the draw is phase one and the credential is not.
