# 036-test-to-voices — info

Tests for `035-to-voices.lua` and its place in the blitter, in a throwaway
project with a guide mailbox made by `scripts/make-mailboxes` and a
throwaway git checkout as the project:
- the phase 1 series into the real blitter: after every version
  `outbox/the-canvas` alone, addressed to the three voices, holding that
  version as the canvas reader reads it, with the blitter's rows and marks;
  the commit read at every version (a commit made mid-series shows);
- the cuts: `fg-sora-1 5 1 9 sat` from version 5, joined by `fg-sora-3 7 1 5
  kitten`, and fg-sora-1's gone when its next turn lands; none with
  tell-the-voice off;
- the endpoint lines (issue 402): each voice's from the `endpoints` file,
  key-file path included; a `use.` line switched between two versions shows
  in the next; a voice with no `use.` line, an endpoint with no timeout or
  no http address, each logged with no line; a file that cannot be read,
  an empty section, logged and counted;
- the receipt's `versions-to-voices` equal to the versions made;
- refusals: send off (no publisher), no mailbox, a voice with no contact, no
  `endpoints` file, an old `endpoint` setting, a folder that is not a checkout, a setting missing;
- the blitter run as a program: it mails its first version with send on,
  and with send off mails nothing and logs why.

    luajit src/036-test-to-voices.lua [--dir ROOT]
