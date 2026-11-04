# film-describer.lua

Looks at each film once, as a strip of frames, and keeps the description under the film's fingerprint.

Part of the films (see README.md here). Read this file rather than the source.
function is misbehaving; this is for everything else.

## What it is for

A vision model reads still pictures, and a film is about a hundred frames. So
each film becomes a strip: a few frames spread evenly across it, side by side
in one picture. The model describes the shapes, the motion and the mood in a
few sentences, and that is kept forever under the film's fingerprint (the
SHA-256 of its bytes). A renamed film keeps its description; an edited film is
a new film.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `list_films(folder)` | a path | list of `{ name, path }`, both strings, sorted by name |
| `fingerprint_films(films)` | that list | the same list with `hash` (64 hex letters) on each |
| `read_descriptions(path)` | a path | table: fingerprint -> `{ name, text }`, both strings; empty if no file |
| `write_descriptions(path, table)` | a path, that table | nothing; sorted by name |
| `make_strip(path, frames, out_png)` | a film, a whole number, an output path | nothing; raises if ffmpeg fails |
| `describe_new(settings, client, scratch)` | a films settings table (paths absolute), a model-server client, a RAM folder | the films with hashes, and how many were newly described |

## The descriptions file

The settings' `descriptions_file` (in double-diaper-dungeon, `assets/films/descriptions.tsv`), one film per line:
`fingerprint <tab> file name <tab> description`. Saved after every film, so a
run that stops partway keeps what it already did.
