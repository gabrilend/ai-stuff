# 035d — The Films Join the Library

| | |
| --- | --- |
| Parent | 035 — share the transcript HTML renderer |
| Blocked by | 035a |
| Blocks | 035e |
| Replaces | 038 — a gif for every turn (its first algorithm) |
| Status | complete, 2026-10-04 |

The film system built in double-diaper-dungeon (its completed issue 10-007)
becomes the library's third part, `films/`, for any project that asks for it.

## Current behavior

Built as intended below, with one change found while building: **the two
commands sit at the library's top, not in `films/`.** Choosing films means
reading transcripts, and reading transcripts is the conversation part's
job; a command inside `films/` would have had to load it, which is the one
thing a part may not do. So `film-matcher.lua`'s `run` is handed the
conversations, and `build-site.lua`'s `assign_films` (behind the
`assign-films` command) reads and shapes them first, the same way the build
does. `start-the-film-models` reads only the settings. `films/README.md` is
the guide; the matcher's rules are tested without a model. The game's 34
films are copied byte for byte as before.

Before, the films existed only in double-diaper-dungeon: `src/063-model-server.lua`
(talks to a local Ollama), `src/064-film-describer.lua` (a six-frame strip
of each gif, described once by a vision model, kept by the gif's SHA-256),
`src/065-film-matcher.lua` (message and description each become 768 numbers;
each side measured from its own middle; nearest film wins; neighbours
differ; each choice written to a per-transcript choices file and never
worked out again), `assets/062-films.lua` (the knobs),
`scripts/assign-films`, `scripts/start-the-film-models`. Each file reaches
for the game's root and the game's settings table by path.

Issue 038 here planned a different system — gifs matched by file name, one
drawn at random weighted toward the nearest. The owner chose the built one
on 2026-10-04; 038 is marked replaced, not deleted.

## Intended behavior

- `films/model-server.lua`, `films/film-describer.lua`,
  `films/film-matcher.lua`: the game's three, with the root and the settings
  table handed in rather than reached for. Paths in the settings that are
  not absolute are read from the project folder.
- `assign-films [project-dir]` and `start-the-film-models [project-dir]`, at
  the library's top: the game's two commands, reading the project's
  settings (035e).
- **Only a project whose settings carry a `films` table gets films.** The
  owner's choice: no setting, no films, and no push ever waits on a model.
- The harness turn gets no film, written as a row in the matcher's table of
  filmed kinds rather than left to a missing entry.
- The game's `dkjson.lua` joins `libs/`.

The settings table's shape is the game's `assets/062-films.lua`, field for
field (`film_folder`, `descriptions_file`, `message_centre_file`,
`choices_folder`, `server`, `vision_model`, `embedding_model`,
`strip_frames`, `message_characters`, `vision_prompt`, `neighbour_reach`,
`square_px`), documented in `films/README.md`.

## Suggested implementation steps

1. Copy the three files and two commands in; replace each reach for the
   game with an argument.
2. Bring the game's matcher tests (`tests/066-film-matcher.lua`) over as
   checks that need no model: cosine, ranking, the neighbour rule, keys for
   repeated words, the choices file only growing.
3. Mark issue 038 replaced, naming this issue and the owner's choice.
