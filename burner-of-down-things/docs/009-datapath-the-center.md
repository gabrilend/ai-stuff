# 009 — Datapath: the center

> Then give it a personality that depends on it's interactions with those
> around it, and guide it's actions from that only
>
> at least then, the evil singularity is predictable in kind.

The machine's personality is a small table computed from the ledger and from
nothing else. It decides two things: which waiting work is done first, and a
paragraph every turn is handed so the model knows what this person has been
attending to. Anyone with the ledger can recompute it exactly.

```
  ledger ──read every line──► weights per issue, per request, per kind
                                   │   each event adds weight to what it is about,
                                   │   and every earlier weight shrinks a little per line
                                   ▼
                              the center (in memory; also written to center.txt)
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
         order of waiting requests       a paragraph in every turn's instructions
         and of issues within a wave      "lately the person has been asking about …"
```

## The arithmetic

Walking the ledger from the first line, each line does two things:

1. Every weight so far is multiplied by the **keep** factor (0.97): the
   gyroscope's spin, so old attention fades unless it is renewed.
2. The line's `about` gains the weight its `kind` gives, from the weight
   table:

| Kind | Adds to its `about` | Why |
|---|---|---|
| `request-received` | 3 | the person pointed at it |
| `graded` | 1 per touched issue, to each | the request touched them |
| `build-failed`, `describe-failed` | 2 | trouble draws attention |
| `breach` | 2 | same |
| `built`, `described` | 0.5 | settled things still count a little |
| everything else | 0 | |

The numbers live in one table in the source. When they change, the change
and its reason go in `docs/balance-updates.md`.

## What it is not

It is not a model, holds no text a model wrote, and cannot be edited: the
only way to move the center is to do something that is recorded in the
ledger. That is the whole of *guide its actions from that only*. It is
predictable in kind because it is a function of a public record.

## The center file

`center.txt` in the case folder is the view of the center, rewritten after
every run: the ten heaviest things with their weights, the ledger line count
it was computed from, and the ledger's head hash. It is a view — deleting it
changes nothing, and the machine never reads it back.

## Ordering

A waiting request's score is its own weight plus the weights of the issues
its `graded` line touched (nothing, until it is graded). Since a request's
own weight fades from the moment it is noticed, the most recently noticed
request goes first — what the person just asked for — unless an older one
touches issues that weigh more. Issues within a wave are started heaviest
first. Every step of a run takes its order and its paragraph from the center
through one function, recomputed from the ledger each time it is asked.

| Decision | What each path leads to |
|---|---|
| Two waiting requests weigh the same | The older one (smaller ledger seq of its `request-received`) goes first |
| Two issues in a wave weigh the same | Id order |
| A ledger with no lines past `case-opened` | Every weight is zero; order falls back to age and id, and the paragraph says nothing has been asked yet |
