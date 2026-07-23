# Desire — what would make this better

- Streaming the scan. Right now a root's whole `find|stat` stream is read at
  once. On the fullest drives that is a lot of memory at once; reading it in
  chunks would let the biggest drives be walked without holding the listing.
- The birth-vs-content gap (38k files here) wants its own little view — a walk
  ordered by *how far a file travelled in time* to get here.
- Policy descriptions should be draftable in bulk, not one file at a time, so the
  meaning-walks become usable on a whole drive without a day of annotation.
- A way to walk two drives against each other — the same content on `cmdo` and
  `mtwo`, found by birth time + size + policy — would turn dedup into a stroll.
