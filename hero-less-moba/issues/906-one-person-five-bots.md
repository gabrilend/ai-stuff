# 906 — One Person, Five Bots

| | |
| --- | --- |
| Phase | 9 — An Opponent Worth Playing |
| Blocked by | 901, 902, 903, 904, 905, 802 |
| Blocks | nothing |
| Reads | [the roadmap](../docs/019-roadmap.md) |
| Open questions | none |

## Current behavior

Everything in this phase exists in pieces and nothing has been played.

## Intended behavior

**A person sits down alone and plays a full match: two bot teammates, three bot
opponents, lobby to library.** It is the capstone of phase 9 and it is the only
test that matters, because every question this phase raises is a question about
how something feels.

The match must go the whole distance — three surges, two calms and their boon
picks, the Pillar Orc, the Field Dragon, and a Golem that ends it — with no
special-casing anywhere for the fact that five of the six players are not people.
**A bot enters through the same door**, reads the same frame, and is refused for
the same reasons.

### What this is actually testing

Not whether the bot wins. Five specific things, none of which a batch run can see:

1. **Does the shared chest still feel shared?** Two bot teammates placing into it
   should feel like company rather than interference. This is issue 903's whole
   bet and this is where it is settled.
2. **Is losing legible?** When the bot team wins, a person should be able to say
   what they did better. If the answer is "I don't know, they just did," the
   difficulty is coming from somewhere it should not be.
3. **Does the boon pick work with a bot announcing?** It is the one blind
   negotiation, and it either becomes coordinated or it does not.
4. **Is the easy setting teaching anything?** A bad bot should be bad in the ways
   a new player is bad, which makes it a mirror.
5. **Does anybody want a second match?** The only real question, and the only one
   with no instrument.

### The demo

Phase 9's demo is a **recorded single-player match, replayed**, with the board
readings from issue 902 printed alongside so a viewer can see what each bot
thought the board was at every decision. That is more interesting than watching
it play, and it is the only phase where the demo can show a program's reasoning
rather than only its output.

## Suggested implementation steps

1. Extend the lobby from issue 802 to fill empty seats with bots at a chosen
   difficulty, without the simulation knowing which seats are which.
2. Play one. All the way through, on the easiest setting, and write down every
   moment something felt wrong before diagnosing any of it.
3. Play one on the hardest setting and check that losing is legible.
4. Record the reading dumps alongside the replay and build the demo from them.
5. Write the phase demo script into `issues/completed/demos/` and wire it into
   the root `run-phase-demo` script.
6. Only then look at the numbers.

## Related documents and tools

- [The roadmap](../docs/019-roadmap.md) — what phase 9 is for
- Issue 802 — the lobby that seats the bots
- Issue 902 — the readings the demo prints
