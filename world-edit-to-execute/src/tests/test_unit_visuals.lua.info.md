# test_unit_visuals.lua

Each unit type's art fields from object data (issue 503b). The real
`stock_rows.load` and `merge` run over a stand-in chain of small
hand-written tables, so the install isn't needed:

- a stock type's model, scale, tint and selection from its row; a custom
  type's from its parent with the map's changes winning and marked; a stock
  type changed in place;
- building, flyer, a grounded copy of a flyer, an empty model path;
- the placeholder shapes, and the rule alone at its threshold;
- a model path kept in a profile file;
- unknown types and codes the metadata lacks, reported once each;
- values written as text, `true`, or unreadable.

With the Frozen Throne install and the 1.29.2 layer present, three stock
types are also read through the real chain; otherwise that part is skipped
with a loud notice.

- **Usage:** `luajit src/tests/test_unit_visuals.lua [DIR]`; exits 1 on a failure.
