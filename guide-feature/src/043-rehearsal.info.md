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
- The voices run the turn `input/turn-runner` names: the real turn (405),
  with `input/turn`, `input/turn-instructions` and `input/look` copied in
  and each voice's endpoint, and the embedder's, from the copied
  `endpoints`; or phase 3's stand-in turn
  with `input/stand-in-turn`. `scripts/use-endpoint` on the workspace's
  copy switches a voice while it runs (402).
- `input/project-clone` is copied with the project named to come from the
  checkout `input/to-voices` names, here on this machine (its top and the
  project's folder in it), so each voice clones it at its first turn (501).
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
