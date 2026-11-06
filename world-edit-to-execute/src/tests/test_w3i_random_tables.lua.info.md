# test_w3i_random_tables.lua

Tests `war3map.w3i`'s random unit and item tables (issue 103b):
Conquest-v8-fix's ten item tables read (names, the first item, every ID
and chance plausible) and written back byte for byte; a unit table and an
item table built here written in the files' layout, read back and written
again the same.

Run: `luajit src/tests/test_w3i_random_tables.lua [DIR]`
