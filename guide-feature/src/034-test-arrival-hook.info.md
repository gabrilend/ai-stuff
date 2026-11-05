# 034-test-arrival-hook — info

Tests for `033-arrival-hook.lua` and `scripts/arrival-hook`, called as
rmail calls them, through a guide mailbox made by `scripts/make-mailboxes`
in a throwaway project:
- receive and update write the body byte for byte, named as the blitter
  takes it, print nothing, in under a second; a body only on standard input
  is read from there; two edits are two arrivals; no dot file is left;
- a subject other than `canvas` (also rmail's `canvas-2`) and a sender that
  is not a plain name are left alone and logged; an unknown first word, a
  wrong count of arguments, a missing inbox file and an empty body exit 1;
- with the RAM tiers gone, they are made again and the arrival lands in RAM;
- the real blitter takes what the hook wrote: versions 2 to 4, none refused.

    luajit src/034-test-arrival-hook.lua [--dir ROOT]
