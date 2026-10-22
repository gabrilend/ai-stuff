# 105 — Relevance and fading

phase 1, the fit and the fade

## Current behavior

Nothing exists. The rules are designed in `docs/datapath-relevance.md`.

## Intended behavior

The thought ledger: the page keeper's list of thought records (fields listed
in `docs/datapath-relevance.md`), and one operation on it, "a frame from
voice V arrived", which carries out the five steps in that document: match,
fresh, let go, fade, and (handing over to 106) lay out.

Settings it reads (all from the page keeper's input file, none built in):
similarity measure name, carry threshold, decay, vanish level.

It reports, per arrival, how many thoughts were carried forward (and of
those, how many crossed between voices), how many began fading, and how many
vanished. These feed the goodbye counters and the phase-1 demo.

## Suggested implementation steps

1. The ledger as a plain list of records. Each new thought takes a number
   from a counter.
2. Matching: for each new thought, its best match at or above the threshold
   among records still on the page. A record can be carried by at most one
   new thought, the most similar one, so one old thought cannot become two
   new ones.
3. Fading and vanishing as written in the datapath document.
4. Tests built from small scripted sequences of frames, each checking the
   exact relevance numbers after each arrival.

## Related documents

- `docs/datapath-relevance.md`

## Blocked by

102, 104.

## Blocks

106, 107.
