# 612 — Looks: the same state, drawn the way the user chooses

## Origin

The owner, 2026-10-17, in the wow-chat-2 project, answering a proposal
that every generator there should read one shared set of style rules
(palette, silhouettes, how ornate, how the light falls) so the game
doesn't drift toward generic fantasy:

> players will be able to provide their own and modify it as they
> please. If the same simulation is running in the background, they can
> render it however they'd like and it'll display the same information.
>
> This, by the way, is the core of the soren-ds UI system.
>
> can you add an issue file in that project to build infrastructure for
> as such?

## Current behavior

An app owns surfaces (601) and draws pixels into them itself; the
compositor copies dirty surfaces to the screen (602, 603). What an app
*knows* and how it *looks* are the same code: to change how the editor
looks, the editor's boxes are rewritten. Nothing lets a user bring their
own way of drawing an app, and nothing checks that two ways of drawing
one app show the same things.

## Intended behavior

**Every app is split in two: its state and its look.**

- **The state** is what the app knows, published as a *view record*: a
  fixed list of named fields, each with its type and width (the same
  widths stations' ports are sized from, 208), e.g. the editor's panels,
  each panel's text lines, its cursor's row and column, its mode. The
  app's own boxes write the record; they never draw. This is the
  "simulation running in the background".
- **The look** is a map of boxes the user supplies (or the device ships
  as a default) that reads the view record and draws into the app's
  surfaces. A look is an ordinary soramech map, written and edited in the
  programming environment like any other, compiled by the same pipeline
  (409).
- **Style rules** sit beside a look as a plain file the look reads:
  colours, spacing, glyph sizes, borders. A user can change a look's
  rules without touching its boxes, or swap the whole look.

**Same information, any look.** A look declares which fields of the view
record it draws. The loader refuses a look that leaves out a field the
app marks as must-show (the cursor, an error, an incoming message), and
names the missing fields. No look silently hides what the app is saying;
a look may *add* things (decoration, its own animation), never remove
what must be shown.

**Swapped while running.** Changing an app's look uses 411's replacement:
the new look's stations placed, the arrows from the view record drawn
into them as one batch, the old look's stations removed. The app's state
boxes are not touched and lose nothing; the next frame is drawn by the
new look.

**One state, many looks at once.** Because the view record is data, two
looks can read the same record at the same time: the same app drawn on
both screens two ways, or the record sent over rmail (710) to a peer
whose device draws it with *its* owner's look. Two people looking at one
conversation each see it their own way, and both see the same messages.

View record: the app's name (text), a version number (integer, bumped
when fields change), and its fields, each a name (text), a type tag
(small integer, from the box-source types, 303), a width (bytes,
integer), and a must-show flag (one bit).

Look: its name (text), the app it draws (text), the fields it reads (a
list of field names), its map (the boxes and arrows, as any map), and its
style-rules file (a path).

## Suggested implementation steps

1. The view record: its declaration beside each app's `links.json` (609),
   read at map load, and the write path from an app's state boxes.
2. The look: a map that reads the record and draws into the app's
   surfaces (601); the editor split first (its state boxes and a default
   look), since it is the simplest app with the most state.
3. The must-show check at load, with an error that names the app, the
   look, the missing fields, and which fields it did find.
4. Swapping a look in a running app through 411's replacement; a test
   that swaps looks every frame for a minute and counts that no state
   was lost (the editor's text and cursor unchanged).
5. Style rules: the file format, read by the default look; a second look
   for the editor with different rules, to prove the split.
6. Two looks at once: the same editor record drawn on both screens.
7. (After 710) a view record sent to a peer and drawn by its look.

## Related documents

- `docs/005-display-and-compositor.md` (surfaces, foreground, drawers).
- `docs/008-apps-overview.md` (the four apps whose state gets split).
- `docs/012-soramech-runtime.md`.
- In the wow-chat-2 project: its custom client draws the game server's
  simulation (the same split, at the scale of a game), and its planned
  shared style rules for generated art, which this replaces with
  user-supplied ones.

## Blocked by

601, 603, 609, 409, 411.

## Blocks

805 (the messenger's interface is its first look over a shared record),
801 (the editor's rendering becomes its default look).

## Open questions

1. Should the four launch apps ship split from the start (each with a
   default look), or is the split built on the editor first and the
   others moved over later?
2. Who marks a field must-show: the app's author only, or can a user's
   look mark extra fields it promises to show?
3. Does a look get its own work queue and memory region (902, 905), so a
   broken look a user wrote takes only itself down (904) and the app's
   state keeps running?
