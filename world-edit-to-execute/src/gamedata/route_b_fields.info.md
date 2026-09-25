# route_b_fields.lua

Data only. A table maps each infobox template name (string) to its fields,
and each field to its stock column: infobox field name (string) →
`"Table.column"` (string).

- `Infobox unit` (and `Infobox building`, the same table) maps onto
  UnitBalance (costs, life, mana, sight, bounty, stock), UnitWeapons (both
  weapons) and UnitData (turn rate, priority, cargo size).
- `Infobox item` maps onto ItemData (level, costs, charges, stock).

Fields that aren't listed (text, art, requirements) aren't compared. Each
change is written here with its reason, and the comparison follows it.

Issue: `issues/112e-route-b-published-values-cross-check.md`
