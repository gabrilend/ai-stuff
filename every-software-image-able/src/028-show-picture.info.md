# 028-show-picture — info

Renders a screenshot as text, so what a machine drew can be checked without
leaving the terminal and without a viewer.

The emulated computers can be photographed while they run (`018 --screenshot`).
This turns one of those photographs into something readable on the same screen
you started the machine from.

## Invocation

```
luajit src/028-show-picture.lua PICTURE [--region X,Y,W,H] [--width N] [--colour]
```

`--region` limits what is shown; `--width` is how many characters wide the
rendering should be (default 96). For text drawn in 80x25 mode, a region of
`0,0,168,16` at `--width 168` renders letterforms close to one-to-one.

## What it reads

The plain binary PPM an emulator screendump produces — the magic `P6`, then
width, height and the largest value a colour may take, then three bytes per
pixel. Comment lines may sit between any two header fields, which is why the
header is walked by hand rather than matched with a pattern.

## How it renders

Each output character stands for a block of pixels, and the block is
**averaged** rather than sampled — a single pixel misses thin strokes
entirely, which is most of a letter. Brightness picks from ten shades, dark to
light.

Vertical sampling is twice as coarse as horizontal, because terminal cells are
about twice as tall as they are wide. Without that correction the picture comes
out stretched and letters stop being recognisable.

## What it reports

How many cells have something in them, and which colours dominate. That summary
is the machine-checkable part: a payload that drew in bright green should
produce mostly green cells, and a blank screen produces none.

## Proven on 2026-08-02

A machine with no operating system wrote `first light, drawn` into BIOS text
memory; it was captured through the emulator's monitor and read back here as
legible letterforms, 280 green cells to 19 grey.
