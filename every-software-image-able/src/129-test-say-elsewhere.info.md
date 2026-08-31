# 129-test-say-elsewhere — info

Saying something, as a routine, on all three machines. Issue 403.

Every payload this project boots already says things, but each one spells its words out inline as it is built. That is no use to an engine, which will say whatever a model produces and cannot know it in advance. This checks the callable version -- hand it bytes and a length, and the words come out -- on real emulated machines of all three kinds.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `129-test-say-elsewhere.lua` and run the sweep again.*

## Invocation

```
luajit 129-test-say-elsewhere.lua [--dir ROOT] [--seconds N]
```

## What is checked, beyond

"SOMETHING APPEARED". Three things that a routine which merely looked right would fail:

## Worth knowing

  A message longer than the scratch it is given, so the chunking is   exercised rather than assumed. A routine that wrote past its buffer   would corrupt whatever sat after it, and the message that provokes it is   exactly the long one somebody is reading after a crash.

  A message said in several calls, with the pieces required to arrive in   order and joined, so a routine that returned early or restarted is   caught.

  Bytes that are not letters -- a tab, and the two that end a line -- since   widening is where a routine that sign-extends instead of zero-extending   turns anything past 127 into a very different character.

## Where it sits

**Belongs to** `403`.

