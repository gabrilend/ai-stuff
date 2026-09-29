# 076-the-pool.lua

The studio's pool: a `.card` beside every asset (docs/067, issue 809a).
Appending a rating safely (809b), the count utility (809c) and floors
(809d) are later pieces. The pool's own folder is `project.pool` (013,
docs/010 open question 13): inside the project, outside git, until decided.

A **card**: `what` (string), `category` (string), `params` (table, by
name), `seed` (string or number), `paintbrush` and `paintbrush_version`
(strings), `canvas` (the canvas's own path or table), `ratings` (array,
empty until 809b appends to it).

| Function | In | Out |
|---|---|---|
| `card(fields)` | a table naming every field but `ratings` | a card table, `ratings` defaulted to `{}`; refuses a missing field by name |
| `write_card(asset_path, card)` | an asset's path; a card table | writes `<asset_path>.card` (014's record writer: neighbour file, then rename) |
| `read_card(asset_path)` | an asset's path | the card at `<asset_path>.card` |
| `counts(pool_dir)` | the pool's folder | `{[category] = count}`, walked from `.card` files alone — never opens an asset. Per-tier counting waits on 809b's rating format |
| `FIELDS` | | the closed list of a card's own field names |
