# 040-test-turn — info

Tests for the voice's side of the relay (037, 038, 039), in a throwaway
project with a voice mailbox (hook `turn`) and a guide mailbox made by
`scripts/make-mailboxes`, every hook called through the mailbox's own
config line as rmail calls it:
- one canvas: the hook returns at once, printing nothing, while a
  one-second turn runs; the lock held during the turn and let go after;
  `outbox/canvas` addressed to the guide, voice/turn/base/size right, the
  stand-in's word in place; the turn counter; the events; the receipt;
- two canvases during one turn: the older replaced, never taken; the hook
  sees the runner busy and starts no second one; one runner runs both;
- locks: a dead process's, a reused number's (another start time), a live
  one's (respected; a hand-started runner leaves), one with no number; take
  once only, release only one's own;
- turns that fail (exit, wrong base), a turn program named by the setting
  and the arguments it gets, an unchanged turn, a waiting text that is not
  a canvas; the stand-in writing in each voice's third, cut to fit;
- what the hook leaves alone or refuses: another subject or sender, a bad
  call, an unreadable or out-of-mailbox file, bad settings; the body on
  standard input; a relative inbox path;
- the voice's canvas as sent, blitted by kuvalu's blitter into version 2.

    luajit src/040-test-turn.lua [--dir ROOT]
