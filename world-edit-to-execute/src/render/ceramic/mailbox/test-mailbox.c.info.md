# test-mailbox.c

The mailbox's tests (issue 515c).

- **Usage:** `test-mailbox [STATES]` (exits 1 on a failure) or
  `test-mailbox --broken [STATES]` (prints `torn` or `out of order` when the
  broken mailbox is caught). STATES: states each writer publishes in a race
  (default 300000).
- **The plain order:** nothing new before a publish; a publish is taken
  once; of two, the newer is taken; the writer never holds the buffer being
  read; bad writer counts refused.
- **Races:** one writer, then four, against one reader. A state is 1,024
  64-bit words, all stamped `(writer << 40) | state number`. Every take is
  checked whole, and each writer's numbers must only go up.
- **The broken mailbox:** publishes without taking a new buffer, so the
  writer goes on writing the one handed over. The races must catch it.
