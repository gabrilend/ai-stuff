# 404 — Running the pictures

## Current behavior

Six thousand recipes and no kitchen. Every claim this project makes about the
illusion is an argument from how the machinery works, and not one image has ever
been made from any of it.

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

1. **Install ComfyUI and fetch the two models.** This is several gigabytes and
   it is somebody's decision to spend them, not this ticket's to assume. The
   free space on this machine is not generous.

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
