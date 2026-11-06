# test_stock_ids.lua

Base-game ids looked up in the map's stock tables (issue 112). A stand-in
chain holds small hand-written SLK tables, so the install isn't needed:

- the lookup: tables read lazily and once, ids kept exactly, a missing table
  answered with `nil` and named, the layer and data set described;
- the validator with a lookup: unlisted ids are errors naming the id and the
  layer, for unit placements, doodad placements, item drops and abilities;
  an item placed on the ground and a destructable placed as a doodad are
  valid; random placeholders are never looked up; an id a missing table
  might hold is a warning naming that table;
- the validator without one: ids assumed valid as before, with one warning
  counting them; `Map:validate` passes its options on.

With the Frozen Throne install and the 1.29.2 layer present, a few known ids
are also looked up through the real chain; otherwise that part is skipped
with a loud notice.

- **Usage:** `luajit src/tests/test_stock_ids.lua [DIR]`; exits 1 on a failure.
