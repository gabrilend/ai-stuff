# strategem — the tree is a build artifact

*Version the intent. Regenerate the result.*

A data-flow pattern that showed up here as "how do we change a server we did not
write," and turns out to be the same shape in half a dozen unrelated places.

---

## The pattern

You depend on something large you do not own. You need it different. The two
obvious moves both rot:

- **Edit it in place** — your changes get clobbered on update, or silently
  survive and are forgotten. Within a month nobody can point at which lines are
  yours.
- **Fork it** — every update is a merge conflict across a diff that grows until
  "what did we change and why" stops having an answer.

The move that does not rot: **stop treating the modified thing as the artifact
you keep.** Keep the *transformation* instead. The modified thing becomes a
deterministic function of `(upstream state, transformations)` and is regenerated
on demand — which means it can be thrown away at any moment without loss, which
means it stops being something to protect.

```
    kept:       upstream ref  +  a directory of reversible transforms
    derived:    the modified tree                     ← throw away freely
    guarantee:  apply → use → unapply  returns the tree byte-identical
```

---

## The three properties that make it hold

**Reversibility.** Each transform has an exact inverse. Not "approximately
undoes"; byte-identical. This is what makes the derived thing genuinely
disposable rather than merely rebuildable-with-effort.

**Idempotency, enforced by a guard rather than by discipline.** Apply checks for
the un-transformed shape before acting; unapply checks for its own marker.
Running either twice is inert *by construction*, so retries, traps firing over
explicit calls, and half-finished runs are all safe.

**A witness that is also the handle.** The transform leaves a unique marker
behind. The marker is simultaneously how you ask "is this applied?" and how the
inverse finds what to undo — so the probe and the inverse cannot disagree, since
they are looking at the same string.

The fourth thing, which is not a property but a consequence: because the derived
tree is regenerated, **any surviving modification in it is by definition a bug**.
That turns a whole class of "did someone hand-edit this?" questions into a single
mechanical check.

---

## Where else this is the same shape

Once you see it, the pattern stops being about source code:

- **A dotfiles repository** — the home directory is the derived artifact,
  generated from a repository plus a machine profile. Never edit `~` directly.
- **Database schema migrations** — the schema is derived from an ordered set of
  transforms. Nobody versions the schema dump; they version the migrations, and
  each one has a `down`.
- **Infrastructure as code** — the running fleet is derived; the declaration is
  kept. "Somebody changed it in the console" is detectable precisely because the
  real state is supposed to be a function of the declaration.
- **Generated documentation and indexes** — a registry built by reading headers
  cannot drift from what it describes; one maintained by hand always does.
- **A recording and its edit decisions** — keep the source footage and the list
  of cuts, not the rendered file.
- **Anything you asked a model to write** — keep the prompt and the context, and
  treat the output as derivable. This is the same claim, and it is the least
  commonly acted on.

The tell is always identical: *you are carefully preserving something you could
recompute, and paying for that care with merge pain.*

---

## The cost, stated honestly

Regeneration is not free. Every build re-derives, which costs wall-clock time.
The transforms have to be written with anchors tight enough not to hit the wrong
place, and that is real craft. And there is one failure mode the pattern
introduces that editing in place does not have:

> An inverse matches the *post-transform shape*. It cannot distinguish "we did
> this" from "upstream now ships this." Run defensively against a tree you did
> not transform, it will cheerfully revert clean upstream work into false dirt.

The fix is not vigilance — it is wiring. The inverse runs **only** to reverse
transforms the same run applied, where authorship is certain. Every defensive
and pre-flight position instead gets a reset that goes to a known reference and
therefore *cannot* manufacture dirt. The call site picks the safe mechanism; the
operator is never asked to.

---

## Why it is worth the cost

The thing you actually buy is that **upstream moving stops being a crisis.**
Re-derive; a transform whose anchor moved fails loudly and names itself. One
thing to re-target, not a fork to reconcile.

And the record comes free. Each transform carries a header saying what upstream
did, what we made it do, and why — so "what did we change and why" is answerable
years later, by reading a directory, in the order the changes happened.

## Related

- `docs/datapath-the-patch-machine.md` — this pattern, fully assembled
- `docs/architecture.md` — the three trees and their different lifetimes
