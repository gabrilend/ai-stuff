---
name: QuickDraw II native — text rendering
phase: 6
status: pending (pending soramech)
blockedBy: [604a, 604c]
parent: 604
---

# 604d — QuickDraw II native: text rendering

Native ARM implementation of QuickDraw's text-drawing operations:
font management, glyph rendering, text measurement.

## current behavior

Text rendering runs in emulation. Each call to `DrawString` or
`DrawText` lands a non-trivial loop in the 65C816 interpreter.

## intended behavior

- Native implementations of: `DrawChar`, `DrawString`, `DrawText`,
  `TextWidth`, `CharWidth`, `MeasureText`, `MeasureChar`, plus the
  font selection ops (`TextFont`, `TextFace`, `TextSize`,
  `TextMode`).
- Font Manager integration: glyph data comes from loaded fonts via
  the Font Manager. The native QuickDraw text path calls the Font
  Manager natively too (once that's native).
- Style support: bold, italic, underline, outline, shadow, condense,
  extend. All implemented per QuickDraw's rules.
- Pixel-exact equivalence with the emulated version.

## suggested implementation steps

1. Study QuickDraw's text-drawing routines and the font-data
   interaction.
2. Implement `DrawChar` first as the simplest case.
3. Extend to `DrawString` / `DrawText`.
4. Implement style application (bold = double-strike, italic =
   shear, etc.).
5. Implement measurement routines (these are surprisingly subtle
   when style and kerning are involved).
6. Regression-test: render strings in every font + style
   combination; compare byte-for-byte.

## related documents

- `issues/604-quickdraw-ii-native.md` — parent issue
- `issues/604c-quickdraw-blits.md` — uses blit primitives

## notes

- Text rendering is heavily used by the Finder and every dialog.
  After this sub-rewrite, the system fonts render in
  small-fraction-of-a-millisecond timescales.
