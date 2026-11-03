# abstraction-transform.lua

Issue 049b: a transcript rewritten as documentation at one of three
abstraction levels, by the local model.

```
abstraction-transform.lua llm-transcripts/dec-10-25.md --level=high
abstraction-transform.lua cut.md --level=low --validate --cache=cut.cache.tsv --out=cut-low.md
abstraction-transform.lua llm-transcripts/dec-10-25.md --compare-levels --write
```

| Level | Writes about |
|-------|--------------|
| high | what the parts do and how they connect: inputs, outputs, routes; no code |
| medium | what features do and roughly how, key decisions, workflow steps; no code |
| low | patterns and choices a maintainer needs, in words; code only at detail level 4-5 |

- **Input** is any transcript, usually one cut down by `transcript-detail.lua`
  (049a). Each `### User Request` and the response after it make one section;
  a file without them is split at every `### ` heading. A section over about
  800 words is cut at paragraph breaks (never inside a ``` block).
- **049a's markers** (`*[N sections left out at detail level D]*`) are kept,
  after the section they followed, and D becomes the document's detail level.
  `--detail=N` overrides it; with neither, the level is 5.
- **Nothing is lost.** A chunk the model does not rewrite is kept word for word
  under `*[kept as written: REASON]*`. If the server cannot be reached, the rest
  is kept without asking again (one timeout, not one per chunk), and when no
  chunk got an answer the exit status is 1.
- **`--validate`** checks each rewrite and retries up to three times, telling
  the model why the last answer was rejected: a code block outside low (or in
  low below detail level 4), no input and output named at high, or under a
  fifth of the original words.
- **`--cache=FILE`** keeps rewrites by (text fingerprint, level) and reuses
  them, so a second run costs only the changed chunks. It only grows.
- **Output** is printed, or written with `--out=FILE` or `--write`
  (`llm-transcripts/generated/{level}-abstraction/NAME.md`, or
  `generated/compare-levels/`). Neither ever replaces an existing file.
- **Prompts** live in `config/abstraction-prompts.lua` (`--prompts=FILE` for
  another set) so the wording can be tuned without touching the script.

Tested by `test-abstraction-transform.sh` (46 checks) against the stand-in
model in `libs/stand-in-model/`.
