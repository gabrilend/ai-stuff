# 408 -- The phase four demo

**Phase:** 4, people connect
**Blocked by:** every other issue in phase 4.
**Blocks:** nothing. The capstone.
**Documents:** [the roadmap](../docs/015-roadmap.md)

## Current behaviour

`./run-phase-demo` offers phases 1 through 3.

## Intended behaviour

Several participants connect at once, one of them deliberately asks for something
it must not have, and the leak test sweeps every outbound stream.

The participants in this phase are **test programs, not browsers**. That is the
point: the security claim is about bytes on a socket, and proving it needs a
client that can be made to misbehave, which a browser cannot.

### What it shows

**Connecting.** Three participants through the door, each given a port, each
connecting to it. Report the door port, the range, and which port each got.

**A refusal in words.** One participant asks for something it cannot have and the
sentence comes back. Show the sentence, not a code.

**The leak sweep.** For each participant, for a body they must not know about,
search their raw outbound bytes and report found-or-not. Then move the body into
view and search again, and report found -- because a test that cannot detect what
it is looking for is not testing anything.

**And the numbers:**

| Reported | Why |
| --- | --- |
| Bytes per viewer per tick | What the wire actually costs. Phase 5 has to fit a browser inside it. |
| How much of that is walls, and how much bodies | Walls come from memory and are mostly sent once; bodies come from sight and are sent constantly. |
| Time to build all outbound updates | The seventh pass of the tick, measured. |
| Ports in use, and the range's size | So a host can see what to forward. |

### And it should show the cost, not only the claim

The port range is this design's real price: a host behind a home router forwards a
range rather than a port. The demo should **print the exact range** so that cost
is a concrete number somebody sees rather than a paragraph in a document.

## Suggested implementation steps

1. Write a test client that speaks the wire format and can be told to misbehave.
2. Run the server in-process with several clients rather than as separate
   programs -- a demo that needs three terminals is a demo nobody runs.
3. Report timings and byte counts from the run.
4. Ensure `tmp/shared-memory/` exists before writing anything.
5. Confirm `./run-phase-demo 4` finds it.
