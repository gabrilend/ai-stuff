# 043-rehearsal — info

The whole round on kuvalu with three stand-in voices (issue 305). Run it
as `scripts/rehearse [ROOT] [--minutes M] [--keep]`, or as a library with
`rehearsal.run(opts)`.

**Setup**
- It makes a workspace in RAM, `tmp/shared-memory/rehearsal/`, holding a
  copy of the project with its own `input/` and RAM tiers, plus four
  mailboxes made by `scripts/make-mailboxes` on 127.0.0.1:
  - the guide, with the arrival hook;
  - `fg-sora-1` to `-3`, each with the turn hook.
- It runs the blitter in-process with the to-voices publisher.
- The mail is carried by the stand-in carrier (041), or by real rmail
  daemons when `carrier = "rmail"`.

**What it times, per voice turn:** published, received, taken, finished,
delivered, arrived, blitted, back.

**Outcome of each turn**
- `blitted` or `unchanged`;
- `superseded`: the voice's next canvas replaced it before it was carried;
- `in-flight`: still on its way when the rehearsal ended.

**What stays afterwards** (everything else is removed unless `--keep`):
- in `tmp/shared-memory/`: `rehearsal-timings`, `rehearsal-events` and
  `rehearsal.log`;
- `output/goodbye-rehearsal`, which counts, per voice, the canvases
  received, waited, replaced and sent and the turns run, plus the
  versions made.

**Stopping:** the turn runners (and their turns) and any daemons are
stopped by process group. `scripts/rehearse` does this again on any exit.

**Settings** (`input/rehearsal`): `minutes`, `carrier`, `first-port`,
`pace`, `jitter`, `rmail`.

| Function | Meaning |
|---|---|
| `run(opts)` | `root`, `minutes`, `keep`, `on_version(record, voice, blitter, row)`; returns turns, events, versions, per-voice counts |
| `workspace(root, values, base)` | makes the copy and the mailboxes |
