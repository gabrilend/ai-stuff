# Issue #038: A gif for every turn

## Current Behavior

The transcript pages (issue 035, `transcript-site/`) draw each turn — the
person's and the assistant's — as text under a small label ("she said", "the
assistant"). Nothing visual is attached to a turn.

Twenty-nine animated gifs of 3D shapes sit in `/home/ritz/pictures/shape-gifs/`
(23 MB together, 0.3–1.7 MB each), made for delta-version's front page. Their
file names are short descriptions of what they show: `breathing-moons`,
`jellyfish-drift`, `wizard-missiles`, `hill-to-the-stars`. A `stills/` folder
beside them holds one PNG frame of each.

`neocities-modernization` already turns text into embeddings — lists of
numbers (768 of them for nomic-embed-text-v1.5) placed so that texts about
similar things sit close together — with a local llama.cpp server
(`scripts/start-llamacpp-server.sh`, the `/v1/embeddings` endpoint), and
compares them by cosine similarity (`src/similarity-engine.lua`). The server
was not running on 2026-09-26.

## Intended Behavior

Asked for by the owner on 2026-09-26: at the start of every turn on a
transcript page, one of the gifs, chosen by how close its subject is to what
the turn says.

### First algorithm: the file name as the gif's meaning

1. **Embed each gif's name**, as words (`breathing-moons` → "breathing
   moons"), once, and cache it.
2. **Embed each turn's text**, cached by the text's checksum so a turn is only
   ever embedded once, however often pages are rebuilt.
3. **Score** every gif against the turn: cosine similarity, a number (float)
   from -1 to 1.
4. **Normalize** the 29 scores into a probability distribution over the gifs.
   How sharply to favour the closest gif is a setting (see open questions).
5. **Draw one gif, with replacement**: every turn draws from all 29, so a gif
   can appear on many turns. The draw is seeded by the transcript's session id
   and the turn's number, so rebuilding a page draws the same gif again; a
   turn whose text changes draws again.

### Measuring it

A report over the whole archive (817 transcripts on 2026-09-26): how often
each gif was drawn, and for each, its average score. A gif that is hardly
ever drawn is looked at before anything is changed, to tell apart two causes:

- **its name embeds far from everything** — the embedding model places the
  words themselves (say, "shell staircase") away from the language of
  software conversations, so the gif loses on the words, not the meaning;
- **nothing in the archive is about it** — a real absence.

### Second algorithm, if the first is shown to judge by the words

The owner's direction: move the connection from what the names are made of
to what the gifs mean — abstraction. A gif would be described by the ideas
it stands for (a breathing moon: patience, cycles, waiting on something) and
turns matched to those ideas, or turns classified by subject (debugging,
planning, celebration, a question) and subjects matched to gifs. Designed
once the measurements say it is needed.

## Suggested Implementation Steps

1. An embedding step in `transcript-site/`: talks to the llama.cpp server
   neocities-modernization runs (its config names host, port and model),
   sends turns in batches, and keeps a cache of checksum → embedding.
2. A gif chooser: scores, normalization, the seeded draw.
3. The page draws the chosen gif at the start of each turn; the gifs reach
   the pages through one shared folder (see open questions), not 41 copies.
4. The distribution report, and a look at any gif that is rarely drawn.
5. Tests: the draw is repeatable for the same turn; every gif can be drawn;
   a missing embedding is an error the build names, not a turn silently
   left without a gif.

## Open Questions

1. **Pages or transcripts?** The gifs go on the web pages. Should the
   markdown transcripts carry them too (an image line under each heading),
   or stay text?
2. **How do the gifs reach the pages?** Copied into each project's `HTML/`
   like the font (23 MB × 41 projects ≈ 1 GB), or one shared copy the pages
   link to (a symbolic link `HTML/gifs` → one folder; followed into real
   files when the pages are uploaded anywhere).
3. **The embedding server at push time.** Rebuilding pages before a push
   needs embeddings for any new turns. Should the push hook start the
   server when it is not running, or stop the push and say so?
4. **How strongly should the closest gif win?** From "always the closest"
   to "nearly uniform". A starting point is a softmax with a temperature
   chosen so the closest gif is drawn about a third of the time.
5. **Which model?** nomic-embed-text-v1.5 (768 numbers per text) is what
   neocities-modernization uses for poems; embeddinggemma-300m is also
   configured there.

## Related Documents and Tools

- `issues/035-share-the-transcript-html-renderer.md` — the pages.
- `neocities-modernization/src/similarity-engine.lua`,
  `src/embedding-server-manager.lua`, `scripts/start-llamacpp-server.sh`,
  `src/image-pseudo-embeddings.info.md` (a related idea: an image given an
  embedding borrowed from the poems around it in time).
- `/home/ritz/pictures/shape-gifs/`.

## Metadata

- **Status**: open — open questions to settle before building.
- **Dependencies**: issue 035.
