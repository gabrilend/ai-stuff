# 032-test-mailboxes — info

Tests for `031-mailboxes.lua` and `scripts/make-mailboxes`, in a throwaway
folder:
- the project's `input/mailboxes`: the guide mailbox on 1223, the three
  voices at their addresses and ports, three links;
- a set with a mistake refused (no folder, no address, a hook with no
  project, port 111213, an unknown hook or contact, a mailbox naming
  itself, two at one address, no links, an unknown line);
- a built set: config and contacts as rmail reads them, hook lines told
  apart by a word, one 64-digit secret per pair shared by both sides, none
  printed, contacts 600 and folder 700, the hook wrappers passing rmail's
  arguments through as given;
- a second run changing nothing; a hand-made mailbox adopted, its lines and
  secret kept; a clashing port, address or pair of secrets, a folder inside
  the project, and two mailboxes in one folder refused before anything is
  written.

    luajit src/032-test-mailboxes.lua [--dir ROOT]
