# 404 — Running the pictures

## Current behavior

Six thousand recipes and no kitchen. Every claim this project makes about the
illusion is an argument from how the machinery works, and not one image has ever
been made from any of it.

## Current behavior

The install script is done and `src/044-run-the-pictures.lua` is written. With
nothing listening it says so and gives the line that starts one, which is the
case that will actually happen.

**The node catalogue has been checked against ComfyUI's own source** for the
first time, because installing it inside this project put that source on disk.
All eleven node types exist; `ControlNetApplyAdvanced` declares exactly the
sockets `301` claims; and the trap `docs/005` spends a paragraph predicting is
real and is exactly where it said — the sampler's seed is declared with
`control_after_generate` set, which is the flag that makes the editor draw an
extra selector after it.

**The card check had to stop reading a list and ask the card.** The published
build of the arithmetic library reports being made for `sm_50 sm_60 sm_70 …`,
and this card is `sm_61` — so an exact-match check declared it unusable while it
was sitting there working, because compiled CUDA code runs on any device of the
same major version with an equal or higher minor one.

## Intended behavior

**A ComfyUI on this machine, and something here that feeds it.**

The card in this machine is a GTX 1080 Ti with eleven gigabytes, which is why
the checkpoint named in the settings is an SD 1.5 one — that generation fits
comfortably, its illusion control nets are the best understood, and the newer
generation would be slow and tight on this architecture. The guess in the
settings turns out to be the right one for the hardware, which was luck as much
as judgement and is worth writing down before somebody "upgrades" it.

**The submitter is the only part of this project that talks to another
machine.** It posts a workflow to the endpoint, waits, and collects what comes
back into the pool. It is an HTTP client and nothing else, and it must not grow
into anything else — everything about *what* to render was decided before it ran.

**It must survive the far end being absent, busy, or wrong.** No ComfyUI
listening is the normal state of this repository, and the submitter says so and
stops rather than failing obscurely. A model name that installation does not
have comes back as an error from the far end, and that error is the answer to a
question nothing on this side could ask (`docs/007` Q9) — so it is reported in
full rather than summarised.

**One rendering per submission, and the seed comes from the recipe.** The same
character submitted twice produces the same picture, which is what makes a tier
mean something later and what makes elaboration possible at all.

**The queue is polite.** Generating is the graphics card's work rather than the
processor's, so `307`'s governor does not apply — but a card at full load for an
hour is the same kind of wear, and the same courtesy is owed. One submission at
a time, a rest between them, and the card's temperature watched where it will
say.

## Suggested implementation steps

1. **Install ComfyUI and fetch the two models.** Done, by
   `src/043-install-the-kitchen.sh`, entirely inside `libs/kitchen` so that
   removing it is removing one folder. ComfyUI is a clone, which is its source;
   the arithmetic library is a published build and the script says why, and
   offers `--build-torch` for anybody who wants the several hours; the models
   are weights and have no source at all.

   **The card check had to stop reading a list and start asking the card.** The
   published build reports being made for `sm_50 sm_60 sm_70 …` and this card is
   `sm_61`, so an exact-match check declared it unusable — while it was sitting
   there working, because compiled CUDA code runs on any device of the same
   major version with an equal or higher minor one. It now does a real
   multiplication and reports what happened.

2. **The submitter posts the API-format workflow** — that format exists for
   exactly this and needs no editor. It then polls history for the result and
   copies the finished picture into the pool.

3. **Copying the inputs is part of submitting.** The workflow names its two
   pictures by filename because the far end looks in its own input folder; the
   submitter puts them there. Getting this wrong produces a workflow that is
   correct and cannot find its own pictures, which `302` already warns about.

4. **Test the client against a far end that is not there**, which is the case
   that will actually happen, and assert that it says which command starts one.

## Related

`docs/005` — the format it posts. `docs/042` — where the results go.
`docs/007` Q9 — the question this answers.
