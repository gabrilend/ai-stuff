# 076-the-pool.lua

The studio's pool: a `.card` beside every asset (docs/067, issue 809a), a
`.ratings` file of every rating appended beside it (809b), and the count
utility, per category and per tier (809c), and floors (809d). The pool's own folder is `project.pool` (013,
docs/010 open question 13): inside the project, outside git, until decided.

A **card**: `what` (string), `category` (string), `params` (table, by
name), `seed` (string or number), `paintbrush` and `paintbrush_version`
(strings), `canvas` (the canvas's own path or table), `ratings` (array,
as written; `read_card` adds every rating appended since).

A **rating** (one line of `<asset>.ratings`, tab-separated, 014's
escaping): `tier` (1-5), `by` (`person` or `machine`), `time`, `note`.
Appended in one unbuffered write to an O_APPEND file, at most 1024 bytes,
so two raters at once never tear or lose each other's line.

| Function | In | Out |
|---|---|---|
| `card(fields)` | a table naming every field but `ratings` | a card table, `ratings` defaulted to `{}`; refuses a missing field by name |
| `write_card(asset_path, card)` | an asset's path; a card table | writes `<asset_path>.card` (014's record writer: neighbour file, then rename) |
| `read_card(asset_path)` | an asset's path | the card at `<asset_path>.card`, its `ratings` followed by every one appended |
| `rate(asset_path, tier, by, note)` | a pooled asset; 1-5; `"person"` or `"machine"`; optional text | appends one rating line; never reads or rewrites the card. Refuses a bad tier or rater, an asset with no card, a line over 1024 bytes |
| `ratings(asset_path)` | an asset's path | every appended rating, oldest first (`{}` for none); refuses a torn or malformed line, naming it |
| `tier(ratings)` | ratings | the latest person's tier; with none, the latest machine's; nil when unrated |
| `tier_counts(pool_dir)` | the pool's folder | `{[category] = {[1..5] = n, unrated = n}}`, from cards and ratings files alone |
| `counts(pool_dir)` | the pool's folder | `{[category] = count}`, walked from `.card` files alone — never opens an asset |
| `FIELDS` | | the closed list of a card's own field names |
| `floors(pool_dir)` | the pool's folder | `{[category] = floor}` from `<pool>/floors.table`; refuses a floor outside 0-5 |
| `floor(floors, category)` | the floor table; a category | its floor, 0 when never raised |
| `floor_report(pool_dir, category, floor)` | the pool; a category; 0-5 | the dry run: `{category, from, to, total, remain, below, unrated, line}`; writes nothing |
| `set_floor(pool_dir, category, floor)` | the pool; a category; 0-5 | writes the floor into `floors.table` and returns floor_report's report for it; never touches an asset, card or ratings file |

A **floor** is the lowest tier a category keeps in use: floor 0 (the
default) leaves nothing out; any higher floor leaves out assets rated
below it and the unrated. Nothing is deleted (docs/067).
