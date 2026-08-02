# 068, 069, 070 — saying something — info

`068` is the font, drawn as pictures in its own source. `069` emits a payload
that asks firmware for the screen and draws with it. `070` checks both: that
the bytes derive from the pictures, and that a booted board puts the right
pixels in the right places. Issue `202`, and everything that goes wrong after
it is diagnosed through it.

## Running the checks

```
luajit src/070-test-say.lua
```

## The font is drawn, not transcribed

Each glyph is eight rows of eight, written with dots and hashes, turned into
bytes at load. A wrong hex byte in a font is a letter that looks slightly odd
forever and nobody suspects the right thing; a wrong hash in a picture is
visible while typing it. Every row is checked for width and for stray
characters — which caught a stray apostrophe in the `C` while the font was
being written.

`show` renders a glyph back **from its bytes**, and `070` requires that to
equal the source picture, so the derivation is proven rather than assumed.

## Contiguous, or the letters spell something else

`contiguous_table()` covers every code from 32 to 126, using a hollow box
where no picture exists, because a payload finds a glyph by subtracting
rather than searching. A table of only the drawn characters is smaller and
indexes wrong at every gap — and the screen fills with real letterforms
spelling something else, which is exactly what it did before this was fixed.

The stand-in is a box rather than a blank. A blank says the machine printed a
space it never printed.

## The framebuffer costs nothing and is first

Firmware already found the display, drove it, and left behind an address, a
geometry and a pixel format. `069` asks for the graphics output protocol,
reads the mode, and writes pixels. No driver, no enumeration, nothing the
machine works out for itself.

**The pixels-per-row is at offset 32, not 20.** Offset 20 is inside the pixel
bitmask; it reads zero, and every row of every letter collapses onto the
first scanline — one confident horizontal line of dashes, with the serial
port reporting success. That is the same failure mode as the header offsets
in `033`, and it was found the same way: by looking at what was drawn rather
than at what was written.

## The speaking hands

`064.offer_speaking` gives the model `say` (everywhere at once), `say_on`
(one voice), and `voices` (what there is). A machine with no voice at all is
refused when the hands are built rather than discovered in the field, and a
`say` that no voice carried is a refusal rather than a quiet zero — a machine
that believes it spoke and did not is worse off than one that knows.

## What `070` proves about the board

The payload is booted on the emulated UEFI board, the screen is photographed
through the emulator, and **every pixel of every letter** is compared against
what the font says — in both directions, since checking only the set bits
would pass a machine that filled the line solid. Then the line below is
checked to be untouched.

## Result on 2026-08-02

13 of 13. The sentence *first light, drawn from the firmware's own
framebuffer* appeared on a machine with no operating system, pixel for pixel
as the font holds it.

Only x86-64 draws so far; `401` is where the other two tongues get it.
