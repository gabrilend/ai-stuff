# film-matcher.lua

Chooses a film for every message by meaning, keeps neighbours different, and writes each choice down for good.

Part of the films (see README.md here). Read this file rather than the source.
function is misbehaving; this is for everything else.

## What it is for

Each film's description and each message's words become lists of 768 numbers
from the same model. A message gets the film whose list points most nearly the
same way (the highest cosine), unless that film is on the message just before
or after; then the next nearest. The choice is written into the conversation's
choices file and never worked out again.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `cosine(a, b)` | two lists of numbers, same length | a number, 1 for the same direction, 0 for unrelated |
| `rank(vector, films)` | a list of numbers; a list of `{ hash, vector }` | every film, nearest first, as `{ hash, score, order }` |
| `choose(keys, stored, films, vectors, reach)` | see below | the film for every position, and the new choices as a list of `{ key, hash }` |
| `message_keys(conversation, scratch)` | a conversation from the transcript reader, a RAM folder | one entry per exchange: a key string, or false for a recap or harness turn |
| `read_choices(path)` | a path | table: key -> film fingerprint; empty if no file |
| `add_choices(path, fresh)` | a path, a list of `{ key, hash }` | nothing; appends, never rewrites |
| `choices_path(settings, transcript_name)` | the film settings, a file name | the choices file's path |
| `films_for_page(conversation, keys, choices, names)` | as named; `names` is fingerprint -> file name | the film file name or false for each exchange, and how many filmed messages have no choice yet |
| `run(settings, conversations, scratch)` | a films settings table (paths absolute); a list of `{ name, conversation }`, read by the caller; a RAM folder | nothing; describes new films, matches new messages, prints what it did. Reads no transcript itself |

`choose` is the rules with no files and no models:

| argument | type | what it is |
| --- | --- | --- |
| `keys` | list of strings | message keys in page order, filmed messages only |
| `stored` | table: string -> string | choices already written |
| `films` | list of `{ hash, vector }` | every film that can be chosen |
| `vectors` | table: string -> list of numbers | numbers for every key not stored |
| `reach` | whole number | neighbours on each side that must differ |

## A message's key

The SHA-256 of who said it and what they said. The same words said twice in
one conversation get ":2", ":3" on the end, so each is chosen for separately
and two twins can never sit side by side with one film. An edited message has
a new key and is matched again.

## The choices file

The settings' `choices_folder`, `<transcript name>.tsv`, one line per message:
`key <tab> film fingerprint`. Only ever added to. It sits under
`llm-transcripts/` so it travels to the public mirror with the words it belongs
to; it holds only fingerprints, so nothing private can cross through it.
