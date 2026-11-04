# films

A small looping film beside every message on a conversation page, like a
profile picture: hers on the left, the assistant's on the right and mirrored
left to right, so the two face each other. Which film goes with which
message is decided once, by what the message says, and never changes.

Built in double-diaper-dungeon (its completed issue 10-007) and moved here
on 2026-10-04 (ai-stuff scripts issue 035d). The owner chose this system
over issue 038's first plan, which matched gifs by file name and drew one
at random.

## How a message finds its film

1. **Each film is looked at once.** A gif is boiled down to a strip of a few
   frames spread across its length, laid side by side; a local vision model
   writes three or four sentences about the shapes, the motion and the mood.
   The description is kept under the film's SHA-256 fingerprint, so a film
   is described the first time it appears and never again, and a renamed
   film keeps its description. (`film-describer.lua`)
2. **Each side is measured from its own middle.** Descriptions and messages
   both become lists of 768 numbers from one embedding model. Each side's
   average is taken away first, so what every film shares, and what every
   message shares, stops deciding the match. The messages' middle is
   measured once and kept in a file, so new messages are measured against
   the same middle as old ones. (`film-matcher.lua`)
3. **The nearest film wins, and neighbours always look different.** If the
   nearest is the film just before or after, the next nearest is taken.
4. **The choice is written down for good.** One choices file per
   transcript: `message key <tab> film fingerprint`, only ever added to. A
   message's key is the SHA-256 of who said it and what; the same words said
   twice get `:2`, `:3`. An edited message has a new key and is matched
   again.

The harness's recaps and the lines above the first request get no film.

Nothing costs money: both models run on the machine's own graphics card
through Ollama, listening only on that machine.

## Turning it on

Add a `films` table to the project's settings. Every field is required.

| field | type | what it is |
| --- | --- | --- |
| `film_folder` | string, folder | every `.gif` directly in it is a candidate |
| `descriptions_file` | string, file | the kept descriptions: fingerprint, name, text |
| `message_centre_file` | string, file | the messages' kept middle; delete it to measure again |
| `choices_folder` | string, folder | one `<transcript name>.tsv` per conversation |
| `server` | string, `host:port` | the Ollama server |
| `vision_model` | string | the model that looks at the strips |
| `embedding_model` | string | the model that turns text into numbers |
| `strip_frames` | whole number | frames in a strip |
| `message_characters` | whole number | how much of a message is read |
| `vision_prompt` | string | what the vision model is asked |
| `neighbour_reach` | whole number | messages either side that must differ |
| `square_px` | whole number | the film's side on the page, CSS pixels |

double-diaper-dungeon's `assets/062-films.lua` is a worked example, with the
reason for every value.

Then:

    start-the-film-models /path/to/project
    assign-films /path/to/project
    build-transcript-pages /path/to/project

The build copies each film some message uses, whole, into `<output>/films/`,
so a reader's browser fetches each once at full quality. A message with no
film chosen yet is drawn without one and counted in the build's report; a
choice naming a film that has left the folder stops the build.

## Files

- `model-server.lua` — talks to Ollama: one picture and a question in, a
  description out; a list of texts in, a list of number lists out. Requests
  go through files in RAM, so a message's text never meets shell quoting.
- `film-describer.lua` — lists and fingerprints the films, makes strips,
  keeps the descriptions file.
- `film-matcher.lua` — the rules (`cosine`, `rank`, `choose`), message keys,
  the choices files, the kept middle, and `run`, the whole job for a list of
  conversations it is handed. It reads no transcript itself.
