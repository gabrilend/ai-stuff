# The discovery announcement (issue 704)

Every device says "I am here" to everyone on each link that has an
address, every five seconds, as one UDP datagram from port 47100 to
`169.254.255.255`, port 47100. It is the same 56 bytes on every link;
only the hardware address and IP differ, being that link's own.

Numbers are big-endian (network order). Every byte not named is zero.

| offset | bytes | what |
|---:|---:|---|
| 0 | 4 | `SDSP`, so stray datagrams on the port are told apart |
| 4 | 1 | the version: 1. Any other is dropped. |
| 5 | 1 | 1 for "I am here", 2 for "I am leaving" (the last one, before the radio goes off) |
| 6 | 2 | zero |
| 8 | 4 | the sequence number: one more each round of announcements, the same on every link in a round |
| 12 | 6 | the hardware address it is sent from |
| 18 | 2 | zero |
| 20 | 4 | the IP it is sent from |
| 24 | 32 | the friendly name: UTF-8, at least one byte, ended by a zero within the 32 |

A receiver drops an announcement that is shorter than 56 bytes, has
another magic, version or kind, has an empty name or one with no zero
in its 32 bytes, or names a hardware address or IP other than the one
it came from. Its own announcements, heard back, are ignored.

A name is the peer: an announcement on another link with the same name
is the same peer reached another way. Two devices with one name are not
told apart; the table follows whichever was heard last, and counts it.

The name comes from `/settings/name` once 408 is in (waiting in #48).
Until then it is `soren-` and four hex digits of a hash of the radio's
hardware address.

There is no authentication, by design (see `docs/006-transport-and-networking.md`
and issue 704): anyone in range learns that the device exists and what
it calls itself.
