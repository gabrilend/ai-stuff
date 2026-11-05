# 068-test-distill — info

Tests distill mode (issue 601): 067, the blitter's distill mode (016), the
stand-in distiller (047), and both modes in one rehearsal (043).

    luajit src/068-test-distill.lua --dir ROOT

Its servers and the rehearsal's mailboxes listen on 127.0.0.1 only. About
45 seconds, most of it the rehearsal.

- **The distiller's words**: the project's file reads; refusals (an unknown
  marker with its line, a missing part, `[user]` without `{{voices}}`, an
  unknown part naming this file's parts); the turn's file still has its own
  parts. The changed-word lines; the conversation (size, counts, voice
  count, the current canvas first in its ruler, each voice in order with
  its turn, base and words).
- **The stand-in distiller**: every voice's changes applied; an old change
  and a contested place passed over; wide replies.
- **The blitter in distill mode**, with the distiller in-process: newest
  mode keeps each voice's newest; arrivals held, a second from one voice
  replacing the first; one distill for all of them, shown every voice's
  newest; blitted on the current canvas with kuvalu's marks and the
  `distill` mode header; a reply past the edge asked again with the fit
  report; a distiller that is down retried at the next step; a distill
  that changes nothing; a look call answered as past a limit of 0;
  switched back, the next arrival blitted under its
  voice's name; the log and the receipt.
- **Over 127.0.0.1**: the endpoint `use.distiller` names, asked with the
  distiller's prompt, named in the log.
- **The owner's rule**: a rehearsal with the stand-in turn, switched from
  newest to distill after four versions and back after three distilled
  ones. Every version reads back as viewers read it, in order, naming the
  mode it was made in; the timings show turns blitted and distilled; the
  blitter's log shows both switches and no refusal; a distiller reply past
  the edge was asked again; the voices received distilled versions.
