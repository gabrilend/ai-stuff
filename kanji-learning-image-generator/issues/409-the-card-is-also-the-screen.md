# 409 — The card is also the screen

## Current behavior

Done. `src/044-run-the-pictures.lua` asks the card what it has before starting,
says whether it is also drawing a screen, rests six seconds between pictures
instead of one when it is, and refuses to submit at all when free memory is
below a floor — waiting first, because the picture program frees what it held
between runs and a moment is usually all it needs.

The command for starting the picture program now carries `--reserve-vram`
everywhere it is printed: in the installer, in the walkthrough, and in the
message the submitter shows when nothing is listening. A correct default nobody
is told about is a default that gets dropped the first time somebody types the
command from memory.

## Was

`404` submitted one workflow at a time and rests a second between them, and the
comment above that rest says:

> Generating is the graphics card's work rather than the processor's, so
> `307`'s governor does not apply -- but a card held at full load for an hour is
> the same kind of wear, and the same courtesy is owed.

That reasoning is about **wear**, and it missed the thing that actually matters.
On the machine this was built on there is one graphics card, and it is drawing
the screen. Loading a four-gigabyte model onto it, repeatedly and back to back
while sweeping settings, took the machine down. From outside the program that is
not a slow computer — it is a frozen one, and the only way out is the power
button.

> hey! wait a sec! you ran some test or something that froze my computer!

`307` asked exactly the right question about the processor and nobody asked it
about the card.

## Intended behavior

**Find out whether the card is also the screen, and behave differently when it
is.**

It is answerable: the card reports how much of its memory is in use before
anything of ours has run, and a card with a desktop on it is never at zero. So
the question is asked rather than assumed, the same way `307` asks for a
temperature rather than resting on a schedule.

**Leave the desktop its memory, and say so.** The picture program takes as much
as it can get by default, which is correct on a machine with a spare card and
hostile on a machine with one. It accepts a figure to hold back; that figure
becomes a setting, and the command this project prints for starting it includes
it.

**Refuse to submit when there is not enough room**, rather than submitting and
finding out. Free memory is readable before each picture. Below a floor, wait;
still below it after a while, stop and say what is holding the memory — because
a run that wedged the display cannot tell anybody anything, and one that stopped
early can.

**Rest longer between pictures when the card is also the screen.** A second is
courtesy on a spare card. On the one drawing somebody's desktop it is not
enough, and the difference costs a few minutes across a set.

**And say all of this at the start of a run**, before the first picture rather
than in a document nobody opened. A person who does not want their machine used
this way needs to know before it is.

## Suggested implementation steps

1. **Ask the card.** Its memory in use before the run starts, its total, and
   whether anything is already holding some. One command, the same shape as
   `031a`'s reading of the temperature.

2. **The floor and the reserve go in `input/settings.lua`**, with everything
   else, and every change to them in `docs/balance-updates.md`.

3. **The start command that `043` prints, and the one in `docs/036`, carry the
   reserve.** A correct default nobody is told about is a default that gets
   dropped the first time somebody types the command from memory.

4. **Test the refusal, not the success.** That a picture gets made when there is
   room is the ordinary path. That a run stops rather than wedging the display
   when there is not is the thing this ticket exists for, and it is the one that
   will be quietly removed by a later tidy-up.

## Related

`307` — the same question, asked about the processor and answered properly.
`404` — what this governs. `docs/042` — the studio it belongs to.
