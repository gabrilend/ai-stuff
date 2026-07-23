# 006 — Forward-stubbing

**Shape.** A later-arriving feature's *interface* is sketched as a stub
in the earlier code that will eventually consume it. The earlier code
calls the interface; the interface returns a default, no-op, or empty
result. Time passes. The later feature lands and *fills* the interface
without the earlier code having to change. The earlier code wrote
against a producer that did not exist yet — and that producer arrived
to find its receiver already prepared.

The name describes the direction: a stub is *forward*, meaning toward
the not-yet-existing producer; the receiver looks ahead at where the
producer will eventually be.

**Origin in this project.** gabrilend's framing on 2026-05-15:

> "for example, in an RPG, a character sheet must be complete before we
> implement equipment, because the equipment must provide stat bonuses
> and such. However, we could make progress on the equipment by building
> out the slots, and pointing the stat modifiers that may be applied
> toward a temporary datastructure which represents where they would be
> received."

The "temporary datastructure which represents where they would be
received" is the forward-stub. It is the consumer side of the contract,
written before the producer side exists.

**Where else it fits.**

- **Symbeline Rumble phase 4 → phase 8.** Combat damage resolution calls
  `apply_stat_modifiers(unit, &modifier_list)`. In phase 4, the modifier
  list is always empty. In phase 8, equipment produces modifiers and
  adds them to the list. Combat code is byte-identical across the phase
  boundary; only the contents of the list change.
- **Database schema evolution.** A new column lands in the schema with
  a `NOT NULL DEFAULT 0` (or similar). Application readers begin
  consuming the column from day 1, getting the default for existing
  rows. Producer code — the part that actually computes and writes the
  column — deploys in a later release. Readers and writers are
  decoupled by the default.
- **API contract evolution.** A new field is added to an API response
  schema as `optional`, with a documented "empty means not-yet-supplied"
  semantic. Clients consume the field defensively from day 1. The server
  starts populating it whenever its computation is ready. No coordinated
  release.
- **Compiler / interpreter dispatch.** A language adds support for a new
  syntactic category; the parser's dispatch table grows a slot for the
  category, pointing at a `not_yet_implemented` handler that emits a
  clear error. The dispatch infrastructure is in place; the handler
  fills in subsequently. Existing code paths are unaffected because
  they never hit the new slot.

(Four examples, three of them not from this project. The rule of three
independent instances — strategem 005 — is met.)

**Why it works.** It decouples *interface design* from *implementation
schedule*. The interface, once written, becomes a contract that the
consumer can rely on. The producer can be late, can be rewritten, can
be reimplemented, can even be replaced — as long as it eventually
arrives with the agreed signature. The consumer never had to wait for
the producer to start drafting; it only had to wait for the producer to
deliver what it had already promised.

The pattern is most valuable when the *consumer's* work is large and
the producer's work is uncertain. If you must build all the consumer
code anyway, doing it against a forward-stub means the consumer is done
when the producer arrives, instead of starting when the producer
arrives.

**Where it breaks.** Three failure modes:

1. **The stub returns lies.** If the stub returns a value the consumer
   treats as load-bearing — e.g., returns `0` when the consumer expects
   "an actual modifier sum that might be 0" — the consumer's logic
   silently passes tests against the stub and then fails when the
   producer lands with real values. Mitigation: the stub should return
   *the most clearly default-looking value* possible (empty list, null
   option, sentinel), and the consumer should be defensive about
   defaults.
2. **The contract changes when the producer is written.** The producer's
   author looks at the stub interface and decides it doesn't quite fit;
   widens it; breaks the consumer. Mitigation: write the interface as a
   contract document at the same time as the stub, so changing it
   requires deliberate two-sided revision.
3. **The stub is forgotten.** The producer never arrives because no one
   remembers there was a producer. Mitigation: every forward-stub gets
   a `// FORWARD-STUB: filled by issue N` comment with a real issue
   reference. The comment is removed at the same commit that retires
   the stub.

**In Symbeline Rumble specifically.** The roadmap calls out two
forward-stubs explicitly: the L/R menu in phase 3 (filled in phase 6)
and the stat-modifier list in phase 4 (filled in phase 8). New
forward-stubs introduced during implementation should be noted in the
relevant issue file and in the comment at the stub site.
