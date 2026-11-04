<!-- written by Claude (Opus 5.5), 2026-10-10, at the owner's request. -->

# development-history

A picture of the game at each development cycle, and beside each a notes
file (`NNN-name.info.md`) saying what made it (the commit and the run), what
the picture shows, literally, and the story so far — a short summary of the
project's arc up to that picture, so the history can be read picture by
picture without the whole conversation. Details are in llm-transcripts/;
these pictures are part of that record (the owner's RGPL transcript
requirement).

Every screenshot is kept (the owner: "each and every single one of them
should deserve a spot. show the things that change"). Any run with
`--screenshot` files its picture here by itself under the next number
(`CAPTURE_NAME=some-name ./run --screenshot 8` names it), through
`scripts/file-screenshot`, which also writes the notes' "What changed"
section: it keeps a fingerprint of every source and settings file beside each
picture (`.fingerprints/`) and compares it with the previous picture's, so
the notes list the files that changed and the settings lines before and
after. `scripts/capture-history NAME -- RUN-OPTIONS` does the same for an
older commit or a settings variant (`--source`, `--commit`). Earlier cycles
were captured by unpacking their commits and running them as they were;
fingerprints begin at picture 011.
