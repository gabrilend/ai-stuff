# mailbox.h

Hands whole states from writers to one reader, neither ever waiting on the
other (issue 515c). Header only.

- **`mailbox`:** `bytes` (`size_t`, one buffer's size), `writers` (`int`),
  `buffers` (writers + 2 pointers to 64-byte-aligned memory), `writing`
  (each writer's buffer number, `unsigned int`), `reading` (the reader's),
  and `middle` (atomic `unsigned int`: the latest complete buffer's number,
  plus `MAILBOX_FRESH` while nobody has taken it).
- **`mailbox_create(bytes, writers) -> mailbox *`:** every buffer zeroed.
  Refuses (returns nothing) a writer count outside 1..`MAILBOX_MOST_WRITERS`
  (30) or no memory.
- **`mailbox_writing(mb, writer) -> void *`:** the buffer that writer fills.
- **`mailbox_publish(mb, writer)`:** one atomic exchange: the writer's
  buffer becomes the latest, and the writer is handed the old middle.
- **`mailbox_take(mb, *is_new) -> const void *`:** the reader's buffer
  after swapping in the latest if it is fresh (`*is_new` = 1), or the one it
  already had (0).
- **`mailbox_destroy(mb)`.**
- **One reader only;** many writers are fine.
