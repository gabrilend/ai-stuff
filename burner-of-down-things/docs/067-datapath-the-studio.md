# 067 — Datapath: the studio

Asset generation utilities, one per kind of file, all painting in the
owner's look. Pass zero of the studio (the canvas-and-paintbrush method):
every part present, none detailed; later passes lower every part together.

> my preferred look is raylib painting lines and surfaces. Usually black
> background, or gray. Sometimes white and vibrant colors, but only if it's
> mostly not for night. lots of texturing tricks, like drawing a slightly
> different color, lighter in 1 quadrant, half and half in two others, and
> darker in a fourth. But just the line around the middle, as a visual
> flair. Lots of charts and diagrams with lines drawn and arrows pointed
> there - here.
>
> — the owner, 2026-09-29

## The words

| Word | Here |
|---|---|
| **canvas** | what is asked for: a description file, plain Lua data, one per asset |
| **paintbrush** | what it may be made with: a closed list of legal words per file kind, published in a document and enforced by a table — a word not on the list is refused, with the nearest legal word named |
| **the look** | the owner's style as data (below), read by every paintbrush |
| **category** | what kind of asset: `diagram`, `chart`, `card`, `still`, `clip`, `note`, `source` … — quality is discussed per category |
| **tier** | 1–5, how good one asset is, by a person or a machine |
| **the pool** | every asset ever made, each beside a `.card` of facts about it; nothing deleted |

## One spine, four ends

```
  canvas (description.lua) ──► the wall ──► compiled draw list ──┬──► .png   raylib paints, off screen;
   plain data, one asset        closed words,  names → numbers,   │          pixels read back; our own PNG writer
                                every error    flat arrays         ├──► .mp4  the .png painter, frame by frame;
                                at once,                          │          frames handed to ffmpeg (a decision:
                                nearest word                      │          below) — and a .gif by our own encoder
                                named                             ├──► .txt  text assets: tables, lists, ascii
                                                                  │          diagrams, prose from templates
                                                                  └──► .src  source files, written by a turn
                                                                             through the hands; first line names
                                                                             the language and version
        every asset ──► the pool: asset + card (what, category, params, seed, paintbrush, canvas, ratings)
        the viewer ──► reads only finished files and cards; shares no code with any maker
```

## The look, as data

One table every paintbrush reads, so the style lives in one place:

| Setting | Values | Default |
|---|---|---|
| `ground` | `black`, `gray`, `white` | `black` |
| `palette` | `night` (bright on dark) or `day` (vibrant on white — only when the asset is not mostly for night) | follows `ground` |
| `flair` | on or off: the midline of a surface drawn in four quarters — one lighter, two split half and half, one darker | on |
| `line_weight` | pixels | 2 |
| `arrow` | `there-here` (a line drawn from the source, an arrowhead at the target, a small label at each end) | `there-here` |

**The flair, exactly:** a surface's middle line — only that line, not the
fill — is split into four quarters around its centre. Quarter one is
drawn a little lighter than the line's colour, quarter four a little
darker, and quarters two and three each half lighter, half darker. It
reads as light falling across the middle of the shape. How much lighter
and darker is a setting, recorded in `docs/balance-updates.md` when it
changes.

## Each end

| Kind | Canvas speaks | Painted by | Encoded by | Proven by |
|---|---|---|---|---|
| `.png` | `line`, `surface`, `arrow`, `label`, `chart`, `diagram`, `grid`, `ground` | raylib in a hidden window, drawing into a render texture; the pixels read back as raw bytes | our own PNG writer (uncompressed deflate blocks; the one in delta-version's readme-gallery is the model) | an independent decoder in the checks reads the file back to the same pixels; the same canvas and seed give the same bytes |
| `.mp4` | the `.png` words, plus `frames`, `rate`, and `move` (a word's position or colour over time) | the `.png` painter, one frame at a time | frames handed to `ffmpeg` (H.264); the same frames also written as a `.gif` by the house GIF encoder | `ffprobe` reads frame count and rate back; the `.gif` round-trips through the house GIF decoder |
| `.txt` | `table`, `list`, `tree`, `box-diagram` (ascii lines and arrows), `prose` (a template with slots) | Lua | the file as written | the same canvas gives the same bytes; widths line up in characters, not bytes |
| `.src` | `language`, `version`, `purpose`, `prompt` | a turn of a model through the hands (a new turn kind), confined to one file | the file as written; its first line names the language and version in that language's comment form | the language's own parser accepts it (`luajit -bl`, `cc -fsyntax-only`, `bash -n`, …) |

## Charts and diagrams

The owner's second request inside the first: *lots of charts and diagrams
with lines drawn and arrows pointed there — here*. So `chart` and `diagram`
are words of the `.png` and `.txt` paintbrushes, not separate tools:

- **`chart`**: bars, lines, dots over axes; data given as arrays in the
  canvas; the flair on each bar's midline.
- **`diagram`**: boxes (surfaces) and arrows between them, each arrow
  `from` one box `to` another, with a label at either end; laid out by
  levels, like the blueprint graph (043) — which makes the machine's own
  graphs, ledgers and centers the first things to draw.

## Decisions, and why

| Decision | Because |
|---|---|
| raylib paints; our code encodes | raylib draws anti-aliased lines and surfaces well and is already built in the shared C libraries. Its own image export is left alone: a borrowed encoder fails silently, ours fails in code we can read |
| `.mp4` goes through `ffmpeg` | Owning an H.264 encoder is not a few hundred lines; it is a codec. The frames are ours and byte-reproducible; the container and compression are ffmpeg's, and the same frames are also written as a `.gif` by our own encoder so there is always one path with no borrowed bytes. The owner is asked to confirm (docs/010) |
| raylib needs a window | It draws through OpenGL, which needs a display; the window is hidden. On a machine with no display the `.png` end refuses, naming why — it does not fall back to another painter |
| The maker and the viewer share no code | The viewer is a raylib program too, but it reads only finished files and cards, like a stranger would |
| The pool lives in the project, not in RAM | Ratings are judgment and cannot be regenerated |
