# 809b — Concurrent append

The second piece of 809.

## Current Behavior

Built. `src/076-the-pool.lua`'s `rate(asset_path, tier, by, note)`
appends one rating — `tier` 1-5, `by` `person` or `machine`, the time, an
optional note — as one tab-separated line (014's escaping) to
`<asset>.ratings` beside the card: an O_APPEND file, written unbuffered in
a single write() of at most 1024 bytes, so the kernel never splits it
between two writers. It never reads or rewrites the card. `ratings`
reads them back (refusing a torn or malformed line, naming it), and
`read_card` now returns the card's own `ratings` followed by every one
appended. Checked by `tests/125-checking-concurrent-ratings.lua`: two
processes started together each append 300 ratings to one asset, and all
600 read back whole, none lost or interleaved. (Splitting the write in
two, tried by hand, makes that check fail — it has teeth.)

Decisions: ratings live in their own append-only file rather than inside
the card, because a card is a Lua record written whole (014), and any
append to it would be a read-modify-write, the very race this piece
exists to remove. What ratings resolve to as one tier — the question
809c's own note left to this piece — is the latest rating by a person;
with none, the latest by a machine; unrated otherwise (docs/067: a person
first, a machine grader only once its agreement is measured). With that
decided, the per-tier half of 809c's count utility is built here too:
`tier_counts(pool_dir)`, per category per tier plus `unrated`, read from
cards and ratings files alone.

## Intended Behavior

Ratings (and any other repeated field) append as one line at a time,
safe under two writers at once — the card's own version of the ledger's
append-only discipline (016).

## Suggested Implementation Steps

1. An atomic-append primitive (open-append-close, one line, no
   read-modify-write race). **Test:** two appends issued at once both
   survive — neither line is lost or interleaved. Done:
   `076-the-pool.lua`'s `rate`.

## Blocked by

- 809a
