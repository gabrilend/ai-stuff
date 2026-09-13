# Vision

## The ask, in the asker's own words

> hi can you make a scraper that pulls theorycrafting spreadsheets and such from
> the internet and stores them here? Make sure to alternate between sources,
> searching for as comprehensive a picture as we can find. Make sure to sort it
> by patch, and include "meta views" when building the viewer that group patches
> by expansion. We should also have a time-scale scroller in the viewer so we can
> easily and intuitively guide through the patch note timelines. Then, we should
> have a simulator that simulates the processing of a battle in World of
> Warcraft, assuming all characters have N% uptime (which we can assess by
> viewing and gathering stats in the game, too) I bet wowhead knew - then, we can
> simulate the paths that players take and then, suddenly, we've killed the game.

Kept verbatim. The last line is the thesis and the joke at once, and the rest of
this project is an argument with it.

## The four things being asked for

1. **A harvester.** Something that goes out to many different places on the
   internet, takes turns between them rather than draining one dry, and brings
   back the numbers that players have worked out about how the game behaves.

2. **A patch axis.** Every harvested thing is stamped with the version of the
   game it was true for. Nothing in this project is allowed to float free of a
   patch, because a damage number without a patch attached is not a fact, it is
   a rumour.

3. **A viewer.** Pages that group patches into expansions the way a person
   thinks about them, and a scrubber along the bottom that drags the whole view
   through time, so that watching a number change across eight years is a
   physical motion of the hand rather than eight separate lookups.

4. **A battle simulator.** Given a set of characters, each of whom keeps their
   buffs and debuffs applied some fraction of the time, work out what the fight
   produces.

## What "killed the game" would actually require, and why the plan as stated
## does not get there

The simulator as described is an **uptime-average model**. Every ability's
damage gets multiplied by every buff's strength scaled by the fraction of the
fight that buff was active:

    damage per second =
      sum over abilities of
        ( casts per second * average hit
          * product over buffs of ( 1 + effect * uptime ) )

That formula is correct exactly when a buff's presence is uncorrelated with what
the player chose to press. It is wrong exactly when the player aims their
biggest abilities into the buff window - which is the whole of what playing a
damage specialisation well consists of. A buff that is up 30% of the fight and
doubles damage produces the same number in this model whether the player dumped
every cooldown inside it or slept through it.

So the model cannot kill the game. The game lives precisely in the correlation
the model throws away.

## The correlation term is the deliverable

The quantity worth chasing is the size of what the averaging model cannot see.
It can be obtained two different ways, and they answer two different questions.

**The empirical subtraction.** Take the damage a real raid actually did, from
the combat log the game writes, and subtract the uptime model's prediction for
the same gear and the same measured uptimes. The remainder is what real players
extracted from the ruleset. This needs an outside archive of real fights, and
that source is **out of scope by decision** - it requires registering for an
account, and this project is being built on sources that answer to anyone.

**The self-contained subtraction.** Run the event-driven simulator on a real
priority list. Measure the uptimes it produced. Feed exactly those uptimes into
the arithmetic model. Subtract. Both halves are ours, both ran on the same
ruleset with the same gear and the same character, so every confound - skill,
gear, raid composition, fight length, who happened to upload a log - is removed
by construction. The remainder is the pure correlation term: **what the ruleset
offers a player for sequencing well**, rather than what any particular player
managed to collect.

The second is the one this project computes, and it is the better fit for an
interest in design rather than product. It is a statement about the rules, not
about the population playing them. Plot it for every specialisation across
fifteen years of patches and it draws the designers' intent from evidence.

Not the kill, then, but the autopsy of the thing that would have to be killed.

## Two simulators, and why the first one needs the second

The request contains two different machines and they should not be confused.

- **The uptime model** has no clock. It is arithmetic over averages. It runs in
  microseconds, it can sweep a thousand gear configurations, and it cannot
  represent a sequence of actions because it has no sequence.

- **"Simulate the paths that players take"** requires a clock. An action at a
  time, a game state that changes, a rule for choosing the next button.

Both get built. They are not alternatives - they are wired together, and the
wiring is the point:

    priority list + character  ->  [ event simulator ]  ->  timeline
                                          |
                                          +-> measured uptimes
                                                    |
                                                    v
                                   [ arithmetic model ] -> a smaller number
                                                    |
                                    the difference is the answer

The event simulator is also the only remaining source of the N% the request asks
for. With the outside log archive declined, nothing else measures uptime - so
the machine that has a clock becomes the instrument that supplies the machine
that does not. That closes the loop entirely inside the project, which is why
the two decisions that look contradictory are in fact compatible.
