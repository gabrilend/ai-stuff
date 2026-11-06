# test_w3i_random_tables.lua

Tests `war3map.w3i`'s random unit and item tables (issue 103b):
Conquest-v8-fix's ten item tables read (names, the first item, every ID
and chance plausible) and written back byte for byte; a unit table and an
item table built here written in the files' layout, read back and written
again the same. Then what follows the forces on every test map (issue
103c): either all four sections (upgrades, tech, random unit and item
tables) with nothing after, or a lone 0xFF in their place; and
Master-Crafters' random item table count of 0, the file's last 4 bytes,
read as a section.

Run: `luajit src/tests/test_w3i_random_tables.lua [DIR]`
