# Datapath: looking into the project

A voice's model can ask to see parts of the project being worked on, through
a tool call. The owner:

> the tool call should be able to adjust an embedding priority. Each part of
> the codebase will have an embedding generated dynamically upon git commit,
> and the tool call the LLM emits will find similar token labels, like
> variable names, class names, structs, etc. It ignores syntax.
>
> the tool call will be able to say "I want a highly focused insight" or "I
> want a broad reaching exploration." and it'll deliver more or less similar
> or related pieces of architecture.

## The project on each voice

"whatever we're working on at the time". kuvalu names the project and its
commit in the `project:` header of every canvas it sends. Each voice keeps a
git clone of that project, fetched from kuvalu over SSH (allowed between the
four machines, `docs/network.md`): "I think we'd git clone a project into the
mini-computer if we were gonna work on it. To RAM if it fits."

- The clone goes in RAM when the project's size, plus room for the
  model's working memory if the model runs locally, fits a setting's share
  of the machine's free memory. Otherwise it goes on disk. Which one was
  chosen is written to the log, since a disk clone is a slower path.
- When the `project:` header names a different project, the voice clones it.
  When it names a newer commit, the voice fetches before its turn.

Built in issue 501 (`src/058-project-clone.lua`, run at the start of every
turn, and by hand as `scripts/project-clone`). Its settings are
`input/project-clone`:

- **Where a project comes from**: `repository.NAME` (kuvalu's checkout as
  `HOST:/PATH`, reached over SSH with `BatchMode`, so it never stops to ask
  for a password; or a path on the same machine) and `folder.NAME`, the
  project's folder inside it (`.` for the whole repository). guide-feature
  lives in a monorepo, so its folder is `guide-feature`.
- **What is fetched**: one commit at a time, with no history (`--depth 1`),
  only the project's folder checked out (sparse), and only that folder's
  files fetched (the blob filter, asked of kuvalu's own `upload-pack` with
  `uploadpack.allowFilter`, so kuvalu needs no setting changed). Each new
  commit is fetched by its full name, which the keeper asks the source for,
  since the canvas carries a short one. For guide-feature's monorepo (735
  MiB of packs) one commit fetched this way is about 7 MiB of git store,
  where a whole clone would be all of it.
- **Where it goes**: `ram-folder` (`tmp/shared-memory/clones`, the RAM tier,
  which is `/dev/shm`) when that folder can be made and written, is a tmpfs,
  and the project's estimated size with `working-room` MiB beside it fits
  `ram-share` of the memory available (`MemAvailable`). The estimate is the
  project folder's files at the commit, counted twice (checked out, and in
  git's store), read from the source with `git ls-tree`. The clone is
  measured again once made, and a RAM clone bigger than the share is moved
  to `disk-folder`. Otherwise it goes in `disk-folder` (`clones/`, ignored by
  git), and the log says why. A clone stays where it was made.
- **One clone per project and voice**, under `<folder>/<voice>/<project>`:
  the voice is in the path because the rehearsal runs all three voices on
  one machine. Returning to an earlier project is a fetch into the clone
  kept for it. A RAM clone emptied by a reboot is made again.
- **The log line**, in `turn-<voice>.log`, for example
  `turn 1 on version 4: project guide-feature at 9f2c1e0: cloned in RAM at
  .../clones/fg-sora-1/guide-feature, 7.1 MiB, because 2.6 MiB and 512.0
  MiB of working room fit 50% of the 6.2 GiB of memory available`. The
  receipt counts `clone-ram` or `clone-disk`, `clone-made`, `clone-fetched`,
  `clone-moved` and `clone-milliseconds`, or `clone-failed`.

On the voices this needs `git` 2.25 or later (sparse checkout and the blob
filter) and SSH from each voice to kuvalu by key (`docs/open-questions.md`,
question 1; issue 701's survey).

## The embedding index

Each project has an **embedding index**: one entry per piece of the codebase
(a function, a structure, a block), holding the names in that piece and the
embedding vector of those names. It is rebuilt when commits are made. It is
built by a tool that belongs to the project-development tooling, not to
guide-feature. The owner: "We'll have a tool file that explains how to build
that functionality, because we'll build it once for each project. I guess
maybe it could be part of delta-version?"

guide-feature only reads the index. What it needs from one is written down
in `docs/embedding-index-contract.md`, so any project's builder can produce
something the look tool understands. How to build one is
`docs/embedding-index-build-guide.md` (issue 502), followed for guide-feature
itself: `scripts/build-embedding-index` builds `.embedding-index/` from the
checked-out commit, `scripts/check-embedding-index` says whether it can be
used, and `scripts/install-index-hooks` keeps it built after every commit,
pull and checkout on kuvalu. guide-feature reads other projects' indexes
and builds only its own.

**On the voices** the index is copied, not built (issue 503). After the
clone keeper brings the clone to the canvas's commit, it reads the meta of
the index in the source's project folder (over the same SSH as the clone)
and, when that index is at the clone's commit, copies it whole into the
clone's project folder as `.embedding-index/` (`tar` over SSH, into a
`.part` folder, checked with `src/060-embedding-index.lua`, then renamed
in). An index at another commit whose project folder has the same `tree`
is the same index, and is copied with its commit renamed. The log's next
line, and the receipt, say which of these it was:

| Count | Log line | Meaning |
|---|---|---|
| `index-already` | the embedding index is there, N pieces | the clone has it for this commit |
| `index-copied` | the embedding index was copied from the source, N pieces | copied now |
| `index-behind` | no embedding index for this commit yet: ... | the source has not rebuilt it yet; the look refuses |
| `index-none` | no embedding index: ... | the source has none |
| `index-failed` | the embedding index could not be copied: ... | unreachable, or the copy does not check |

So the vectors are made once, on kuvalu, by the same embedding model, and a
voice needs no embedding work of its own to keep its index.

## The look call

The model calls `look` with:

| Argument | Type | Meaning |
|---|---|---|
| `about` | text | what it wants to see. Names, words, or a sentence |
| `focus` | decimal, 0 to 1 | 1 = "a highly focused insight", 0 = "a broad reaching exploration" |

The look tool:

1. Turns `about` into a vector with the `embedder` endpoint, by the same
   rule the index was built with: names only, syntax ignored.
2. Measures every piece's similarity to it (the cosine of the angle between
   the vectors).
3. Chooses pieces by focus:
   - **high focus**: the most similar pieces, few of them;
   - **low focus**: pieces spread across the whole range of similarity, a
     few near, more middling, some far, so the answer reaches out into the
     architecture;
   - in between: a blend. The exact curve is a setting.
4. Fills the answer with those pieces' source text, nearest first, up to a
   token budget (the endpoint's context length minus what the turn already
   uses, counted exactly with the endpoint's token counter).

If the project has no index, the look call answers with an error saying so.
It does not fall back to random files. The error reaches the model and is
counted. A missing index is a problem to fix, not to hide.

### As built (issue 503)

`src/064-look.lua`, answered by the turn (`src/055-turn.lua`, its
`looker`). The call's form stays the plain line of issue 403, `look
focused: WORDS` or `look broad: WORDS`; `input/look` turns the two words
into focuses (`focused = 1`, `broad = 0`), so the numbers can change
without the model's words changing. A look:

1. takes the names in WORDS by `names-v1`, the index's own rule, and asks
   the embedder for their vector. The embedder is the `endpoint: embedder`
   line of the canvas (`docs/canvas-format.md`), so it is chosen on kuvalu
   like the voices' own endpoints;
2. reads `.embedding-index/` in the clone's project folder, and refuses one
   at another commit than the clone, one made by another name rule, and
   one made by another model than the embedder serves (its `/v1/models`
   name), or with vectors of another length;
3. scores every piece in one pass over the vectors, held in one block of
   memory with LuaJIT's FFI, ranking included: 0.8 ms for guide-feature's
   1,074 pieces at 64 dimensions here, 1.7 ms at 768;
4. ranks the pieces, nearest first, and chooses by focus, from
   `input/look`:
   - the number of pieces runs in a straight line from `nearest` (4) at
     focus 1 to `spread` (12) at focus 0;
   - they are evenly spaced from rank 1 down to the reach,
     `(1 - focus) ^ curve` of the way to the last rank (`curve` = 2), and
     never fewer ranks than pieces. At focus 1 that is the nearest four in
     a row; at 0, twelve from the nearest to the farthest; at 0.5, eight
     within the nearest quarter;
5. answers with the pieces' source text, read from the clone's own files,
   nearest first, each under a label

       --- src/006-canvas-text.lua, lines 150-157 (structure), similarity 0.707

   up to `budget` tokens (2000), counted with the voice's own chat
   endpoint's tokenizer. A piece that does not fit is left out, a smaller
   one after it still goes in, and the answer ends by saying how many were
   left out.

The token budget is a setting, not the endpoint's context length minus what
the turn has used: the canvas line names no context length, and with
`look-limit` 3 the looks add at most 6,000 tokens to a turn. It is set for
the real model with the owner.

A look with nothing to show answers with why, as one sentence the model
reads, and the turn counts it (`look-refused-<kind>`): `no-clone`,
`no-index`, `index-commit`, `index-model`, `no-embedder` or `no-names`
(words such as "the if end" hold no names). It never shows other files
instead. A look that cannot be asked at all (the embedder unreachable, no
`input/look`) is answered "The look failed: ..." and counted `look-failed`;
the turn goes on either way.

Run by hand against a folder with an index:

    luajit src/064-look.lua --project FOLDER --url EMBEDDER-URL \
        [--count-url CHAT-URL] --focus 0.5 canvas width

`src/065-test-look.lua` asks "canvas width" of guide-feature's own index
(at the commit of issue 502, pinned) at focus 1, 0.5 and 0, and compares
the pieces with `assets/test-looks/`. With the stand-in embedding model the
similarities only count shared names, so many pieces tie at 0; the real
model's will spread out.

## Where the embedding work runs

For now, everything uses kuvalu's llama.cpp servers (`docs/endpoints.md`),
so the vectors are computed on its GTX 1080 Ti.
