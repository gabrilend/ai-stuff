# test_overrides.lua

The model-override file (issue 504) and the chooser that reads it (516's
stand-in):

- a good file read: names, scales, tints, team colour, scopes, paths matched
  whatever their case, slashes or extension, Windows line ends;
- a bad file refused, every problem named with its line, and nothing in it
  run as code;
- written back the same (exact text, defaults left out, awkward numbers);
- adding, replacing and removing; merging sets, the first winning, with
  conflicts listed;
- the player's file in the player data folder: missing, saved, loaded,
  broken;
- the chooser over a real store (`assets/dedup.lua`) in a folder under
  `TMPDIR`: an override drawn, an unreadable or missing one falling back,
  another map's not applying, placeholders with reasons, each path chosen
  once, uses counted.

- **Usage:** `luajit src/tests/test_overrides.lua [DIR]`; exits 1 on a failure.
