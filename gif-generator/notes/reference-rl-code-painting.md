# Reference: teaching a model to paint by writing code

External source material. Not our design, not our claims — a record of
someone else's machine, kept because it sits one layer above ours and we
may want that layer.

- **Source**: https://surya.website/rling-qwen-to-paint-with-code
- **Author**: Surya Narreddi
- **Read on**: 2026-08-25
- **Status at reading**: ongoing work. A final training run and a full
  technical report were still pending, report promised for 2026-06.
- **Everything below is paraphrase.** No text is copied from the source.
  Numbers are the source's reported figures, not measurements of ours.

---

## Why this note lives in a particle-sim project

Our generator and theirs are the same species of thing: **a program that
draws, rather than a model that draws.** In both, the artifact that
produces the picture is source code — ours is a scene script compiled to
a timeline, theirs is a JavaScript sketch. Neither uses diffusion. The
vision note for this project is explicit about that preference, and this
is the same preference arrived at independently.

Where they go further: they do not write the drawing program by hand.
They train a language model to write it, and the training signal comes
from *looking at the rendered picture*. The picture is the grade.

That is the layer we do not have. Our scene scripts are written by hand,
or (phase six, the listening porch) translated from prose by a local
model that has never been told whether its translations look good. This
note is here in case we ever want to close that loop.

---

## The shape of the machine

Four stages, run in a cycle thousands of times. Each stage's output is
the next one's input.

```
  text prompt  ("draw a peach hibiscus in watercolour")
       │
       ▼
  [1] the model writes a complete sketch
       │        JavaScript source, using the p5.brush library
       ▼
  [2] a headless browser runs it
       │        Puppeteer sandbox → one PNG image
       ▼
  [3] the picture is graded
       │        gates + preference model + pairwise comparison
       ▼        against paintings drawn from a curated pool
  [4] GRPO updates the model's weights
       │
       └──────► back to [1]
```

**Stage 1 — generation.** The model emits a whole sketch, not a fragment
and not a description of a picture. The output is text that happens to be
executable.

**Stage 2 — rendering.** The sketch is executed inside a sandboxed
headless-browser environment (Puppeteer). Sandboxing does two jobs at
once here: it contains code that might be hostile, and it contains code
that is merely broken, which during early training is nearly all of it.
The stage produces a PNG or it produces a failure.

**Stage 3 — grading.** The PNG is scored. This is the whole difficulty of
the project and is broken out below.

**Stage 4 — update.** GRPO — a reinforcement-learning algorithm that
scores a *group* of rollouts for the same prompt and pushes the model
toward the ones that scored better relative to their group-mates. The
relative framing matters: there is no absolute target to hit, only "this
one beat its siblings."

---

## The reward function, and why the first one failed

The author's central point: reinforcement learning wants a **verifiable**
reward. Arithmetic has one — the answer is right or it is wrong. A game
has one — you won or you lost. *Whether a painting is good* has no such
thing. So the reward function stops being a measurement and becomes a
piece of design work, authored as deliberately as the program itself.

### First attempt — nine signals, stacked

| Signal | What it checked |
|---|---|
| Compilation gate | did the sketch run at all |
| Library-usage gate | did it actually call p5.brush, not plain p5 |
| Code length | aimed at roughly 3,000 tokens |
| HPSv3 | a learned human-preference model, scores images |
| Prompt adherence | judged by two large models (GPT-5.4, Gemini) |
| Recognisability | quality judge |
| Aesthetics | quality judge |
| Technique | quality judge |
| Depth | quality judge |

**It plateaued at 0.65 reward and stopped, and every output looked the
same** — the author describes the collapsed output as a flat, clip-art
sort of flower with five rounded petals, over and over.

The post-mortem is the useful part, and it has three findings:

1. **Correlated judges are one judge wearing five hats.** The four
   quality dimensions plus prompt adherence moved together at 0.85–0.95
   correlation. Five signals, one measurement, five times the weight.
   Stacking them did not add information, it added volume.

2. **A saturated signal contributes no gradient.** Code length was about
   a third of the total reward, but the model learned to hit the target
   length almost immediately and then every rollout scored the same on
   it. A third of the reward budget was spent on a term that could no
   longer distinguish a good rollout from a bad one. Weight without
   variance is dead weight.

3. **The one signal with real variance was starved.** HPSv3 actually
   spread the rollouts apart, and it was carrying 0.10.

### Second attempt — four signals, weighted by where the variance is

| Signal | Weight | Form |
|---|---|---|
| Compile + library-usage gate | 0.05 | binary pass/fail |
| Length check | 0.05 | binary pass/fail |
| HPSv3 human-preference model | 0.30 | continuous score |
| Pairwise judge vs reference pool | 0.60 | fraction of comparisons won |

The two gates were demoted to what they always were — **hygiene, not
quality.** A sketch that does not run should score zero, but a sketch
that runs deserves no credit for the achievement. Binary, cheap, 0.05.

---

## The pairwise trick

The single largest change was not *what* was judged but *how the question
was asked.*

**Before**: show a judge one image, ask it to rate the image 0–10. The
ratings compressed toward the bottom of the scale, so nearly every
rollout received nearly the same number, and a reward that gives every
rollout the same number teaches nothing.

**After**: show the judge three images — the rollout, and two paintings
pulled at random from a curated reference pool — and ask which is the
better watercolour hibiscus. The reward is **the fraction of those
comparisons the rollout wins.**

Two things improve at once:

- **Dynamic range comes back.** Win-fraction naturally spreads across
  the full 0-to-1 interval, because the opponents vary from one
  comparison to the next.
- **The judge is asked something it is good at.** Models are unreliable
  at assigning an absolute aesthetic number and considerably more
  reliable at picking the better of two things put side by side. The
  redesign moves the judge onto its competence.

This generalises past painting. Any time a judge's absolute scores bunch
up, the question is probably wrong, not the judge.

---

## The reference pool

The pairwise comparison needs opponents, and the opponents define the
target. This pool *is* the taste being taught.

| Tier | Count | Origin |
|---|---|---|
| "love" | 117 | hand-rated best |
| "okay" | 266 | hand-rated acceptable |
| colour-coverage supplement | 198 | separate run, added for palette variety |
| **pool total** | **581** | |

Reaching those 581 required hand-rating **1,664 images**. That is the
real cost line of the project: a person sat and looked at sixteen hundred
pictures, and the model's taste is downstream of that afternoon.

**Every image in the pool is machine-generated.** Not a stylistic choice
— p5.brush is a niche library and there was no corpus of human-made
examples to draw on. The pool was built by two pipelines, both scored by
vision-language-model judges:

- an iterative pipeline where several large models (named in the source
  as Opus 4.6, GPT-5.4, Gemini 3.1 Pro) worked against reference
  photographs under judge scoring;
- a bulk-generation pipeline run on Gemini 3.1 Pro.

So the taxonomy is: machines proposed, a person selected, and the
selection became the target. Curation was the human contribution, and
the author frames that curation as the thing standing between a reward
function that **converges** (collapses onto memorised outputs) and one
that **drifts** (never coheres at all).

---

## The documentation finding — the part I'd flag hardest

The system prompt initially carried about **400 lines of p5.brush API
documentation**. The result: the model **invented API calls that do not
exist**, and wrote them confidently and in well-formed style. More
reference material produced more hallucination.

The fix ran GEPA (a prompt-optimisation library) for **200 iterations**
against a taste-anchored 7-shot judge. What it converged on was the
opposite of what was there before:

- a strict **allowlist of eight brush methods**
- **no API documentation at all**
- **no code examples**

The author marks the first time three out of three generations produced a
visibly correct result as the version written *after* the 400-line
reference was thrown out entirely.

The lesson stated generally: **a short allowlist suppresses confabulation
better than a long specification does.** A specification tells a model
what exists and implicitly invites it to reason about what else might
exist by analogy. An allowlist is a closed set and the analogy has
nowhere to go.

This is the finding most likely to apply to us directly, and it points
the opposite direction from our instinct — we write `.info.md` files for
every source file precisely so the surface is documented. Worth knowing
that for a *generating* model, that same completeness may be a liability
where a closed vocabulary would not be.

---

## Reported results

- The redesigned reward reached the old 0.65 plateau **three times
  faster**, and then kept climbing past it instead of flattening.
- Generated sketches **shrank from about 13,500 tokens to under 2,000**
  without being told to. The model discovered that winning compositions
  did not need verbose code. Note that this happened while the explicit
  length term had been cut to a 0.05 binary gate — the compression is a
  *side effect of pursuing quality*, not a response to a length reward.
  Under the first rubric, where length was worth a third of the score,
  the code stayed long.

That last inversion is the most interesting single result in the piece:
the term that was supposed to control length was preventing the model
from finding a better length.

---

## What could transfer here

Ordered by how likely I think each is to actually pay off in this
project.

1. **Pairwise judging for the listening porch.** Phase six already
   produces three candidate readings of a prose description and asks the
   person to pick. That pick is a pairwise preference and it is currently
   thrown away. Recording it builds our own reference pool for free, out
   of work we are already doing.

2. **Render-and-look as a validation gate.** Our validation wall checks
   that a scene script is *legal*. It cannot check whether the result
   *looks like what was asked for*. A rendered frame handed to a judge
   closes that gap, and unlike the source's setup we already have the
   renderer.

3. **The allowlist finding, applied to the porch's prompt.** Our score
   format document is a complete specification of every word a score may
   speak. If we ever feed it to a generating model, this article predicts
   that will produce invented vocabulary, and that a bare allowlist would
   do better.

4. **A full training loop.** Furthest from anything we have. Requires the
   RL machinery, the compute, and above all the sixteen-hundred-image
   afternoon.

---

## Open questions

Some now answered. Kept here rather than deleted, because the answers
are only legible next to the questions that provoked them.

### Answered

1. **Is this note here as background, or as a plan?**
   *Background.* This article is filed, not adopted. The work it
   prompted went elsewhere — see below.

2. **Which layer is the "generalized function" meant to sit at?**
   *The thing that draws.* Not the writer, not the trainer. The
   declarative-description-to-encoded-file spine, with no model
   anywhere in the render path.

3. **Does the pairwise-judge idea belong to this project, or to a
   skill any project could pull in?**
   *A skill* — but the skill that got written is the layer below the
   judge, not the judge itself. It builds generators, and decides what
   kind of artifact to generate by reading the project it is invoked
   in. This project is one instance of its output rather than its
   subject. The skill lives with the other personal skills, named for
   the shape it builds: a score goes in, an artifact comes out. The
   article contributed two things to it — the closed-allowlist finding,
   which became the rule about constraining a model's vocabulary rather
   than documenting it, and the several-readings-then-a-person-chooses
   pattern, which was already the porch's design and is now written
   down as a general rule.

### Still open

4. **What would our equivalent of the reference pool be?** Ours would
   be .gif files — animations, not stills. A judge that compares two
   *motions* is a harder instrument than one that compares two
   paintings, and I still do not know what it looks like.

5. **Do we trust a judge that never sees the motion?** If comparison
   happens on a single extracted frame, then motion — the thing this
   project's founding note says particles exist to illustrate — is
   invisible to the grader. That seems fatal to a naive port and I have
   no fix.

Both remaining questions only become live if the grading layer is ever
picked up. They are parked, not abandoned.
