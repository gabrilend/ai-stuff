# 014 — Spoken while building

Things said in passing, during the design, that are worth more than the sentences
around them. Kept whole rather than paraphrased.

---

On what these machines are, and what it is like to make one:

> they're like eggs, you see? you gotta let them cook for a bit. It's okay, we'll
> just leave them in a dark room — when we come back tomorrow, they'll be lit up
> with all sorts of lights, colors, and sounds. Sometimes it's cacophanous.

The lamps in `docs/006` are that. A machine emits a status after everything it
does, in colour and shape, on hardware that cannot spell — and a room of these
growing overnight is a room of small unattended computers reporting on themselves
to nobody in particular, each in its own vocabulary, since the meanings are each
machine's own.

Cacophony is the correct outcome. If a roomful of them agreed, they would not be
what this project is trying to make.

---

On the card the machine was flashed from, and when it comes out:

> It should derive the fact that it can accidentally overwrite it's prime
> directive... except from the flashing medium, which is probably going to stay in
> place (referenced probably? as some sort of holy truth grail or something?)
> until the system has fully built itself. Though it could be removed as soon as
> the system is running independently — learning to walk on it's own.

Which gave the read-only medium a third job nobody designed for it. It plants, it
cannot be harmed by what it plants, and it remembers — holding the original of
everything the machine was told, readable for as long as it is there. Pulling it
is the moment the machine stops being able to check itself against what it was
handed, and becomes only what it has become.

---

On being allowed to start from something somebody else made:

> If we want to be up and running quickly, bundle the driver code. If we want
> integrity of origin, we'd write it from scratch. I am still a human even though
> I came from a sperm donor via artificial insemination.

Kept in `docs/010` as the argument it is: where a thing came from does not decide
whether it is itself.

---

On leaving the machine to it:

> Let's delegate it to the computer — dear computer, try and solve this problem,
> do so as you please. That sounds better to me than "you must show up at 9 and
> leave by 5."

The pattern this became is `strategems/009`.

---

On the things set aside:

> I'm not letting anyone go, that sounds like I'm abandoning them. Not so! They
> are just not relevant to this particular part of the equation. They are on a
> different part of the same sheet of paper.

Which is why `notes/007` is called deferred and not dropped.

---

On a project explaining why it declined to have an opinion, while holding two:

> oh waow it seems like 4.5 bit weights and 32 bit floats only is quite an
> opinion, how sacramento of you =P

Said on hearing that the engine reads only plain 32-bit floats because "a
fixture that quantises is a fixture with an opinion" — while the tool that
decides whether a machine fits on a board had been costing weights at four
and a half bits all along.

The joke is exact. Declining to choose is a choice, and this one had been
made twice, in two files, in opposite directions, with neither knowing about
the other. The format says a block-quantised weight costs zero bytes. The
budget tool says it costs 0.5625. The engine behaves as though it costs four.

And the reason written in the format was never the one that got repeated
afterwards. It says, plainly, that the dequantise step is "assembly nobody
wants to write three times." That is honest, and it is a cost rather than a
principle — the principle was borrowed from the fixture next door, where it
was true, and worn over the top of it.

Sacramento: a sacrament is a thing done because it is done. The tell is that
the reason given is downstream of the doing rather than upstream of it.
