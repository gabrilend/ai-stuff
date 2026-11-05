# 030-test-phase-2-demo — info

Tests for the phase 2 demo (`issues/completed/demos/phase-2-demo`, with its
two readers `phase-2-file-reader.lua` and `phase-2-http-reader.lua`):
- run with `--keep --plain`: versions 1 to 8 drawn once each at the real
  size; the marks under each row by voice and kind (word marks in the
  voice's number, sentence marks in its letter), an older mark kept on a
  cell no newer voice touched, and marks gone once over the lifetime; the
  blitter's mark numbers per version and against its receipt (98 word
  cells, 48 sentence cells, 34 expired); the marks on each canvas by age;
- the readers' copies, read here: both hold versions 1 to 8, each byte for
  byte its `canvas/history` file and readable through 022; the HTTP reader
  got versions by held `?after=` requests and the files reader from
  `current`; the time to each reader shown, under two seconds;
- the server's receipt against the HTTP reader: every version sent once,
  the last held request abandoned at the stop, nothing refused; every one
  of the demo's eleven checks agrees; nothing left running;
- through `run-phase-demo`: offered as phase 2, plain when piped, the same
  canvases and marks every time, its throwaway project removed; a folder
  that is not the project refused;
- in a pseudo-terminal (`script`, skipped if missing): marks coloured by
  voice, a word mark stronger than a sentence mark, dimmed by age.

The server listens on 127.0.0.1 only. It takes about thirty seconds,
because the demo runs three times and the blitter lists arrivals once a
second.

    luajit src/030-test-phase-2-demo.lua [--dir ROOT]
