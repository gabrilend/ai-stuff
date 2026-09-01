# 606 — The Text Pane

| | |
| --- | --- |
| Phase | 6 — The Tome |
| Blocked by | 601 |
| Blocks | 607, 608 |
| Reads | [the tome](../docs/007-the-tome.md) |
| Open questions | **5** — what the colours signify |

## Current behavior

The scrolling region is empty.

## Intended behavior

Every word in the game lives here, because
[the map carries none](../docs/001-what-this-game-is.md).

Scrolling. Stylable and configurable by the player. For the prototype: a dark
ground with coloured words, each colour making a kind of thing leap off the page.

### The rule this pane is held to

> **Colour never carries a fact the words don't also carry.**

Every distinction a colour makes must also be present in the text. Colour exists
to make the right line leap out, never to mean something the page does not say.

Concretely: if debts are red, the line must also say *owes*. If a warning is
amber, the words must say what is wrong. Somebody reading with colour stripped
away — because they cannot distinguish it, or because they changed the theme, or
because it was printed — must lose **speed and nothing else**.

This has a real cost and it is paid deliberately.

### What the categories are is not decided

People, places, times, promises, warnings? That is a claim about what kinds of
thing exist in this game, which is mechanics, so it waits. See open question 5.

The pane should therefore be built to take **named categories from a table**
rather than having them written into it, so that deciding them later is data
rather than code.

### Stylable means stylable

The player configures it: ground, faces, sizes, and the palette. The prototype's
dark ground with coloured words is a **starting point, not the design**.

Which means the pane must not assume a dark ground anywhere — no white text hard
coded, no shadow that only works on dark. Everything comes from the theme.

### The width sets the register

Around 420 pixels. That is a narrow column, which suits short lines and lists and
punishes long paragraphs. Text written for it should be closer to a ledger than to
prose.

## Suggested implementation steps

1. A layout that takes a list of lines, each with a category, and renders them
   wrapped to the pane width.
2. Categories and their colours from a table in `assets/`, not from source.
3. A theme record for ground, faces and sizes; nothing may reach past it.
4. Scroll with the wheel when the pointer is over the pane; clamp to content.
5. Test that rendering with every category set to the same colour still
   communicates everything, since that is the test of whether the colour rule is
   actually being kept.

## Related documents and tools

- [The tome](../docs/007-the-tome.md)
- [Open questions](../docs/013-open-questions.md) — question 5
