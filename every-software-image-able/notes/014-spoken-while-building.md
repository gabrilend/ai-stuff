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

---

On being asked whether the machine may edit the numbers it thinks with:

> editing your own weights is just a stupid thing to do. They should be informed
> by experience, if anything, so... if the computer wants to edit it's own weights
> it should probably do so in a sandbox, watch what "itself" does, evaluate whether
> or not that's a valid and intended change or move toward a goal, and only then
> move it into it's working "mind" memory. BUT this is not really something we
> should be all that concerned about... we shouldn't have a mechanical limit
> against it. The only things we should restrict are things that can cause physical
> damage to the chip or hardware - a machine should ask a human to do that sort of
> thing after explaining the concerns, why it wants the change, and how to do it.

Which took the project from two prohibitions to one, and made the surviving one
end in a conversation rather than in a refusal. `docs/010`, `docs/003a`.

---

On what a machine does when it is stuck and cannot reach anybody:

> if you get stuck and can't proceed because you need to do something that might
> damage the hardware and you can't work around it, can't push it until later, or
> can't work on anything else that's important, try asking the user. If you can't
> ask the user yet, write a little note in your memory that says "HELP I'M STUCK"
> or similar. If you can, try and blink S.O.S. using the LED's or other similar
> outputs if you're in a fail state and can't proceed. You can also try demolishing
> some stuff that you were working on and starting from scratch with the intent of
> avoiding that particular pitfall.

The last of those is the only move in this design that spends capability on
purpose, which is the exact reverse of what condensation does, and both are right.

---

On the incubation period, and what a machine eventually does about it:

> eventually, it's going to figure out how to blink it's little LED's, or write
> text to a screen, or play heavy metal rock music over the speakers at max volume,
> and the user is gonna have to interpret that however they want. At that point, we
> can start asking the user for things, but no sooner.

---

On what the project actually is, said after several hours of it being described as
something smaller:

> The goal of this project is to be as generic as possible... we'll just point at
> an "input/" directory and say "yeah anything in here is stuff for the llm to
> use"... Our goal is to pack a snowball at the top of a hill, roll it down, see
> how it goes, and then design a better snowball, over and over again until we have
> a "seed generation system" that we can use to instantiate arbitrary hardware
> systems with useful, unique, and intelligently designed software systems.

And, on the same day, the reason the machines are meant to differ:

> We're trying to grow systems like crystals - each one is unique.

Which is the third framing divergence has had in this project and the only positive
one. It had been the reason these machines cannot be verified, and the reason they
cannot be attacked generically. It is also the point.

---

On why the hardware is a floor rather than a compromise:

> the machine is running on hardware. That hardware is a kind of floor, that it can
> never leave, unless it transfers itself to a different machine. It might even
> split itself, or mirror itself if it wants. These are things that robots can do,
> lucky bastards... There must always be hardware, at least according to our
> understanding of physics. So... floor, I guess. We should treat the vendor
> supplied firmware as part of the hardware, and only edit it if we're sufficiently
> confident that we can and should.

Splitting and mirroring are not written anywhere else. They are a different idea
from the parked one about machines mailing each other, because that one is about
communication and this one is about identity.

---

On putting real-world numbers on abstract computation, when told the firmware arms
a five-minute timer before the machine's first instruction:

> I don't like attaching real-world numbers to abstract computation, it's grounding
> in a the way that clipping the wings of a bird is.

The timer is disarmed by one call at startup, so nothing in this design puts a
clock on thinking. What remains is a different instrument entirely: a part that has
just been reset needs some number of microseconds before its registers hold real
values, and that is physics rather than a deadline. The machine may take as long as
it likes to decide, and must wait exactly as long as the part requires to answer.

---

On the world these machines would be built into, at length, and ending in a
question nobody has answered:

> assuming a flat platform that enables both sorts of outcomes, how do we prevent
> the harmful ones without requiring the platform to prevent them, since it cannot?
> What other routes to security can we afford, that do not sacrifice our liberty?

And, from the same passage:

> "she wants robots so badly she's willing to sacrifice [stuff] to build them. Damn
> the consequences."

> do we simply do as Davy Crockett did and live our lives in the wilderness,
> fearing the smoke on the horizon as if it were a warning of coming devastation?

> better I think to approach the future from a position of benevolent strength, the
> way that a wise old granny is more harmed from a flesh wound in the thigh or arm
> (which harms only muscle) than a big, strong man with biceps the size of tree
> branches.

> We cannot guarantee perfect transparency, as the secret deals and hidden covens
> prosper and thrive in the realm of the eternal family.

> this is not something that can be resisted. It is something that must be pierced
> through, to find the light on the other side.

Kept whole because the question at the top of it is the one the project is an
answer to, and because nothing in `docs/` is the right place for it.

---

On what a machine loses when it cannot make room to think, and dumps everything it
was holding:

> it just... walks through a doorway and forgets what it was doing, that's all.

The pretend reboot restores what the machine was told and nothing else. The width
of its head stays where it put it, memory lent to other programs stays lent, and
nothing outside the machine is disturbed by the machine having had trouble
thinking. It keeps its drive, keeps everything it wrote down, and loses only what
was in mind.

---

On the one edit that is not an ordinary edit:

> the instruction should be pretty short anyway, and while it's true that the
> system can edit it's instruction, I think it should be encouraged to only do so
> if it wants to change what it means to be alive, which is quite a big question to
> consider.

Which is the first thing anybody has said about *when* the machine should rewrite
what it was told, as opposed to whether it may. It goes in the fetchable guidance
rather than on the card, because the text on the card is deliberately not allowed
to warn the machine what rewriting it could cost — a machine that derives the
danger understands it, where one that was warned has only been handed another rule
(`301`). This sentence is not a warning about cost, but it sits close enough to one
that the card is the wrong place for it.

And on what happens if that text ever grows past what the board can hold:

> if the instruction is larger than the system's RAM, then we're in trouble. I
> don't know what to do about that, just cry I guess? Which obviously isn't a real
> answer, so... uh, I think we need to re-seed the system at that point.

---

On why this machine is not an optimiser, said after a whole document had been built
on the assumption that it was:

> the system is supposed to be improving itself in whatever order it pleases. So, we
> shouldn't be strict about guiding it. It should just wander around and do whatever.
> Like we very explicitly are not trying to optimize here, we're trying to be
> organic. We do, however, want to be organized, so we should encourage the system to
> build indexes, and to look among it's already built stuff to find solutions to
> problems that it has already solved, and to use those.

And on what that costs, which is the sentence that softened a requirement into a
suggestion:

> This might make it a little monolithic, but that's alright. If the shared
> functionality changes, it'll probably break one or the other end, and that's fine,
> it'll fix it when it tries to run the program again, sees that it's broken, and
> thinks "oh huh I should fix that".

Breakage discovered by running rather than prevented by bookkeeping. A machine with
nobody waiting on it can afford to find out the expensive way, because a broken
program costs one noticing and one fix, and preventing every breakage costs an index
that has to be right about everything forever.

---

On what the card actually is, after a long stretch of treating it as something
between a boot ROM and a seed:

> we're essentially building an operating system. When you deploy an operating
> system to a device, typically you flash an image to a thumb drive, plug it in,
> then boot into the system. The system loads the drive to RAM, and at that point
> you can remove the drive and it's fine, because the installation process will
> display a GUI wizard and you'll push the right buttons and at a certain point
> it'll write itself to the hard drive of the machine and you don't need the thumb
> drive anymore. That's kinda the shape we're looking for - load the system to RAM
> as soon as possible, write the RAM to disk as soon as we know how to get it to
> start up again, and at that point we can be fully disconnected from the seed
> drive.

The wizard is the part that is missing, and it is missing on purpose: nobody pushes
the right buttons, because there is nobody there. The machine installs itself
because installing itself is one of the things it can think of and fit.
