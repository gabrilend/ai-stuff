# 039 — What should be better

Not tickets. Tickets describe work somebody has decided to do. These are the
places where this project is weaker than it looks, written down while they are
still fresh.

## Nothing here has ever seen a generated picture

Every claim about the illusion is an argument from how the machinery works. The
fields look right, the reasoning reads right, the prompts say the right things,
and not one image has been made from any of it. The whole project is a recipe
for a dish nobody has cooked.

This is by design — `docs/001` refuses to ship a diffusion model — and it is
still the largest thing wrong. `docs/007` Q1 is the closest thing to a plan.

## The stroke roles repeat, and it shows

Each world has one phrase per stroke shape, so three verticals in a character
are three cedar trunks. They are told apart by where they are, which was the
cheap fix and is not the good one. A world with two or three alternatives per
shape, chosen by something stable, would read far less like a template — and
would triple the amount of hand-written English in `024`.

## A third of everything is a person in a room

The commonest radicals are mouth, person, eye, hand and heart, so the *person*
world wins constantly. It is not wrong and it will make a set of six thousand
images feel much more samey than the seventeen worlds suggest.

## The written half of the lexicon has no author

A hundred and seventy rows saying what a shape depicts, written by someone
working from dictionary glosses and etymology, not by someone who knows kanji.
Some of them are certainly wrong in ways that will only be visible to a reader
who knows better — and there is currently no way for that reader to fix one
without editing Lua.

## The thumbnail test is done by eye, once, by whoever ran the demo

`docs/003` says the test is a person squinting. In practice that person was
whoever last ran the phase-two demonstration, looking at six characters. There
is no record of what they saw, no way to compare it against last week, and no
way for two people to disagree productively.
