# route_b.lua

Reads Liquipedia infoboxes and compares their numbers with Route A's tables.

- **`parse_infobox(text)`** takes a page's wikitext (string) and returns
  `template` (string, e.g. "Infobox unit"; `Infobox_building` is read as
  "Infobox building") and `fields` (table: field name string → trimmed value
  string). As MediaWiki does, a field ends at the next `|` outside a nested
  `{{…}}` or `[[…]]`, so a value may span lines and a line may hold several
  fields. Returns nil when the page has no infobox.
- **`number(raw)`** takes a field value (string) and returns `value` (number)
  and `decimals` (integer, the digits after the point), or nil when the value
  isn't a plain number. Comments, `&nbsp;` and thousands commas are removed
  first.
- **`load_route_a(install, layers, version)`** reads, from the chain (melee
  data set, version default "1.29.2"):
  - the stock tables the field map names;
  - the name files;
  - the race function files.

  It returns a table with these fields:
  - `version` (string);
  - `tables` (table name → the SLK parser's result, whose `rows[id][column]`
    holds a number or string);
  - `item_by_name` and `unit_by_name` (name string → four-letter id string,
    or false for a name several objects share);
  - `upgraded_from` (upgraded building id → the id it's upgraded from).
- **`cached_pages(cache)`** returns a table: title → `{text, source ("old" or
  "current"), meta, no_old}`.
  - The old revision wins where it has text.
  - `no_old` (boolean) is true when the page had no revision while 1.29.2 was
    current; today's text is then read.
- **`compare_page(route_a, text, title)`** returns a list of rows `{field,
  column, a, b, raw, form, verdict}`, then `id` and `template`. It returns nil
  and a reason (string) when the page can't be compared.
  - A page without an id is paired by its title.
  - `form` (string) is "plain", or "base / upgraded" for a value written as
    `2500 / 4000` (the base is compared).
- **`compare_all(route_a, pages)`** returns:
  - `rows`: every row, with `title`, `id`, `template`, `source`, `no_old` and,
    for an explained row, `why` (string) added;
  - `counts`: verdict → count;
  - `objects`: the number of objects compared;
  - `unpaired`: list of `{title, source, no_old, reason}`;
  - `pages_differing`: today's pages to fetch again as they stood under
    1.29.2.

**Verdicts** (strings):

| Verdict | Meaning |
|---------|---------|
| `match` | Equal within the page's own rounding. |
| `blank_is_zero` | The game leaves the cell blank and the wiki writes 0; counts as agreement. |
| `upgrade_step` | An upgraded building's cost. Proven by the sum: the game's number is the earlier building's cost plus the wiki's step. |
| `explained` | Investigated by hand; the finding is in `route_b_findings.lua`. |
| `later_page` | The page was first written after 1.30. Not checkable. |
| `mismatch` | Differs, unexplained. |
| `only_b` | Only the wiki gives a number, unexplained. |
| `unreadable` | The wiki's value isn't a number. |

Tests: `src/tests/test_route_b.lua`. Issue: `issues/112e-route-b-published-values-cross-check.md`
