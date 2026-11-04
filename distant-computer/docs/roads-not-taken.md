# Roads not taken

Designs considered and set aside, and why. Kept so they are not reconsidered
from nothing.

## The distant computer dials in to kuvalu

It would make the courier simpler (the steward could push whenever it liked),
but the distant computer would then hold a key that reaches kuvalu. The gate
would then be a rule the steward is asked to follow, not a wall it cannot
cross. It would also mean opening a port on kuvalu to the internet. Set
aside for both reasons.

## An HTTP API for the gate

The vision says "a permissions system harness like an API". The design meets
that with a file-based API: a request is a file in a known format, and the
answer is a file too. An HTTP server would add a listening port, a process
that has to stay up, and its own authentication, and it would buy nothing
the courier does not already do. If something outside these two computers
ever needs to file requests, an HTTP front that writes the same files can
be added in front of the gate without changing it.

## Anthropic's cloud sessions as the steward

The vision says "a claude-cloud session". Cloud sessions run on Anthropic's
machines, not on the Linode, so they could reach the Linode only through
credentials handed to them. That is the "distant computer holds keys"
problem again, one step further out. Claude Code installed on the Linode
and run headless is the same model working in the same way, on the machine it
is meant to run. It is kept as an open question (`docs/open-questions.md`) in
case the owner meant the cloud specifically.

## Git LFS for large files

Git LFS needs a server that speaks its protocol, and it keeps large files in
history forever. Twinning by checksum manifest with rsync keeps large files
out of history and needs nothing but SSH.

## Letting the steward act outward on its own

Asked for in the vision ("it can hire lawyers... sell it"). Declined as a
default, for the reasons in `docs/architecture.md`, "Lines this design will
not move". The path toward it is a funding goal: hire a person who answers
outward requests.
