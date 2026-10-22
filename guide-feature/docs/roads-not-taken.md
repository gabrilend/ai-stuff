# Roads not taken

The first design, written on 2026-10-21 and committed once, misread the
vision in several places. The owner corrected it the same day
(`notes/first-answers.md`, "The second round"). The ideas are recorded here
so the reasoning is not lost and is not rebuilt by accident. The full first
version is in git history, in the commit that created the project.

## Thoughts as lines, matched by shared words, fading by a number

**What it was.** Each voice sent a list of one-line "thoughts". kuvalu
matched each new thought to older ones by the angle between their word counts
(cosine similarity) and gave every thought a relevance number that fell each
frame it was not repeated. Thoughts below a level left the page.

**Why not.** The vision's page is one shared two-dimensional grid of
characters that all three voices write onto ("they're all blitting to the
same 2d character array"). Fading happens because something is written over
it, not because a number decays. What the viewer needs to see is what
*changed*, so they can skim. Now: `docs/datapath-blit.md`.

**What may still be useful.** Word-count similarity is a cheap stand-in for
embeddings, and the "look" tool's focused and broad searches need some
similarity measure (`docs/datapath-looking-into-the-project.md`).

## Each voice owns a share of the rows

**What it was.** The display box was split into equal row shares, one per
voice, plus fading rows. Each voice's frame had to fit its share.

**Why not.** "each machine gets access to all of the rows. and columns. They
are all working with the same canvas size." The pressure on a voice is not
space but restraint: change as little as possible, single words before
sentences. Now: `docs/fit-check.md`.

## The box follows the smallest viewer

**What it was.** Viewers sent their screen size, and the page shrank to the
smallest.

**Why not, for now.** With one shared canvas, resizing it rewraps or crops
every voice's words at once. That deserves its own design. The canvas size
is a setting, and how it changes is an open question
(`docs/open-questions.md`).

## Remote models as a separate kind of backend

**What it was.** A table with local llama.cpp, remote llama.cpp, and hosted
service backends.

**Why not.** The owner: "let's implement this using llama.cpp ... make sure
there's a config file in the project root that allows us to set multiple
endpoints that can be selected from at runtime." One kind of client, many
named endpoints, chosen in one file. Now: `docs/endpoints.md`.

## Random excerpts from a context folder

**What it was.** Each turn picked files at random and filled the model's
context with excerpts.

**Why not.** The model asks for context itself, through a tool call that
says how focused or broad it wants to be, searched by embeddings of the
project's names (variables, structures, functions). The project is the one
being worked on, cloned onto each mini-computer. Now:
`docs/datapath-looking-into-the-project.md`.
