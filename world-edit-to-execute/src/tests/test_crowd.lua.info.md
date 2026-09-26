# test_crowd.lua

Scenes drawn as text, ticked while checking every tick that no two units
overlap and no unit touches a wall (issue 405f): orbiting a standing enemy
(one straight leg planned, no long stop); two meeting head-on passing;
going round a bundle of enemies; an idle ally nudged aside in a corridor;
sixteen mixed sizes packing round a point; the owner's slow unit A among
fifteen fast Bs (the Bs fill the middle, A stops on its own side); the
crossing game's two armies of mixed sizes (a crossing within a minute, at
most two giving up; prints the time per tick).

- **Usage:** `luajit src/tests/test_crowd.lua [DIR]`; exits 1 on a failure.
