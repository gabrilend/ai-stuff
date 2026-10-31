# 060-porch-say — say a sentence to the real model

The porch's front door, run by `./porch`. It reads the doors in
`input/cluster` (one `name host port` line each, llama.cpp's server
behind each), sends a sentence through `032-porch.lua` to the first door
that answers, prints what the porch heard as plain lines
(`059-say-back.lua`), and writes the score into `input/`. Filming is a
separate step, `./run NAME`, so the person reads the lines first.

## Usable surface

CLI only:

- `luajit src/060-porch-say.lua DIR --check` — asks every door's
  `/health`, and says how long a context the prompt needs (the prompt is
  the whole language, read verbatim). Exits 0 when any door is up.
- `luajit src/060-porch-say.lua DIR "a sentence" [--name=NAME]
  [--door=DOOR] [--seed=N]` — writes `input/NAME.lua` (default `heard`;
  never over an existing file: `NAME-2`, `NAME-3`, ... instead). When
  the model's last reading still fails the wall, prints the wall's
  words and the draft, writes nothing, and exits 1.
