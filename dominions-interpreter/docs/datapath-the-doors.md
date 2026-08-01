# Datapath — the doors

*Three little machines, three standing roles, and a refusal to limp.*

## What a door is

An address that answers. What stands behind it — one machine, three little
minds, a model split across a rack — is not this program's business. The roster
lives in `input/cluster`, one line per door:

    name  host  port  kind

The format is the one `gif-generator`'s porch and `backwards-reader`'s doors
already use, because three programs on one network should not disagree about
how to name machines. Copy `input/cluster.example` and fill it in.

`kind` is `completion`, `embedding`, or `both`. One `llama-server` can answer
both.

**The roster is read first.** The vision's own rule — a program's first act is
to read `input/` — is what tells this one how to start.

## Why a cluster suits this particular workload

A turn's conversation is not one long generation. It is a few dozen short,
mostly independent calls: a scene, a voice line, a clarifying question, a
mapping from a sentence to an order, a search through the chronicle. Some of
them are needed one after another; many are not.

The parallelism worth having is the parallelism between roles. While the herald
writes a scene, the remembrancer can already be searching, because the search
does not depend on the prose. Three doors and three roles is a natural fit, and
it is a fit because of what the roles are, not because there happen to be three
machines.

## The three roles

| Role | Given | Returns | Must be able to say |
|---|---|---|---|
| **herald** | the world table, the scene selection, the court notes | prose, and voiced dialogue | — |
| **steward** | what was agreed, the world table | ledger entries, structured | "that is not an order I can write" |
| **remembrancer** | the chronicle, the current world table | cited candidate links | "nothing bears on this" |

Each role is a different prompt and a different set of permissions, not a
different model. Any door that answers completions can hold any role.

The reason to keep them apart is that they fail differently and are checked
differently. The herald's output is prose and is checked by a person reading
it. The steward's output is structured and is checked mechanically against the
world table. The remembrancer's output is citations and is checked by looking
the citation up. Merging any two of them into one call would merge three
different verification strategies into none.

### The steward refuses in a specific way

An order the steward cannot map is not approximated. It comes back as a
refusal naming what could not be mapped, and the conversation continues — the
person is told, in words, that the thing they asked for is not something the
system can currently write, and is offered what it can.

This is the fallback rule from the house standards applied where it matters
most. A silently approximated order is a turn played wrong, discovered a turn
later, unattributable.

## Assignment and pressure

Roles are assigned to doors at the start of a session and can move. A door
holding two roles is normal on a small cluster; a role with no door is a
stopped program.

Work is routed by **price**: each door quotes a price for taking one more piece
of work, computed from what it has actually been observed to do and how much is
already waiting on it, and the cheapest door wins. A door that slows down gets
expensive and stops receiving work without anyone being told. This machine is a
door too, priced the same way, which is what turns "should this run locally"
from a tuned constant into a live measurement.

The rule in general: `backwards-reader`'s
`strategems/price-as-a-load-balancer.md`. The mechanism is the same one and
should stay the same one.

## A dark door stops the session

If a named door does not answer at startup, the program refuses to start. It
does not quietly run everything locally.

The reasoning is the same as the neighbouring projects state: a cluster you
thought was helping and wasn't is worse than no cluster, because the timings
lie and the fault is invisible. If you want to run on one machine, say so out
loud in the roster.

A door that dies **mid-session** is a different situation, because a
conversation is in progress and the chronicle is open. The session pauses,
says what happened in words, and offers to continue with the remaining doors
carrying the orphaned role or to stop and keep everything written so far.
Losing a machine should never lose a conversation.

## Concurrency

LuaJIT coroutines over a shared task stack, one coroutine per in-flight call,
sockets yielding. The work is almost entirely waiting on a door to answer, so
the limit is door capacity rather than scheduler capacity, and real OS threads
buy nothing until something CPU-bound appears. A thread pool is a distributed
resolving of a stack of coroutines; that is meant literally here.

## The transport is an argument

Every part of the program that talks to a model receives its transport as a
plain function from request to reply. Tests hand in a fake.

The consequence worth stating: the entire conversation engine — scene
selection, court notes, steward mapping, refusal handling, ledger writing — is
testable on a machine with no GPU, no cluster and no model file. The real
llama.cpp adapter satisfies the same one-function signature and is deliberately
the smallest module in the project, because it is the only part hardware can
break.

## Related

- [The chronicle datapath](datapath-the-chronicle.md) — what the remembrancer searches
- [The ledger datapath](datapath-the-ledger.md) — what the steward produces
- [The court datapath](datapath-the-court.md) — what the herald voices
- `input/cluster.example` — the roster format
