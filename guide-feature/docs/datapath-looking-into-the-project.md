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

- The clone goes in `tmp/` (RAM) when the project's size, plus room for the
  model's working memory if the model runs locally, fits a setting's share
  of the machine's free memory. Otherwise it goes on disk. Which one was
  chosen is written to the log, since a disk clone is a slower path.
- When the `project:` header names a different project, the voice clones it.
  When it names a newer commit, the voice fetches before its turn.

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
something the look tool understands.

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

## Where the embedding work runs

For now, everything uses kuvalu's llama.cpp servers (`docs/endpoints.md`),
so the vectors are computed on its GTX 1080 Ti.
