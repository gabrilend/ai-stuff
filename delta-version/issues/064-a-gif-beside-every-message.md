# Issue 064: A Gif Beside Every Message

**Status**: Open
**Priority**: Low
**Created**: 2026-10-01
**Type**: New tool, run as a git hook; first used by `double-diaper-dungeon`
**Related**: `060-readme-gallery-of-interacting-shapes.md` (makes the gifs);
`062-gif-viewer-window.md`; `double-diaper-dungeon` issue 10-003 (the
transcript renderer that will draw them); `neocities-modernization` (whose
embedding pipeline is the model for the matching)

---

## Why this exists

Every message in a published conversation gets a small animated picture beside
it, like a profile picture: on the left for the person, on the right, turned
upside down, for the assistant. Which picture goes with which message is
decided once, by what the message says, and never changes. In her words:

> can you look at /home/ritz/pictures/shape-gifs/ and build a system that, for
> each transcript file, once when it's first uploaded or when it's changed and
> only for the changed responses, reads the message and assigns a gif to that
> message? They should be flipped 180 degrees for the assistant responses. We
> should put them to the left of the transcript for user messages, just a
> little box like a profile picture, and to the right for the AI responses.

> I don't have many API credits, and I don't think my computer can handle local
> generation for video... I plan to have more of them later on so ideally it'd
> be a system that just examined the video specifically.

> one per message. The same message always gets the same gif, which is why we
> only update the gifs for new or modified messages.

> can we just link to them? so the user only has to download them once, and
> then they're cached? small copies might distort or remove quality...

> can we build an issue file for a generic version of it meant to be
> implemented as a git hook, with project specific gifs?

## Current Behavior

Nothing assigns gifs. The gifs exist: 34 films, 320 by 320, made by
`scripts/readme-gallery/render-all.sh --library` (issue 060) into
`/home/ritz/pictures/shape-gifs/`, about 36 MB in all, each with a still.
Transcripts are exported as markdown by the Stop hook into each project's
`llm-transcripts/`, one `### User Request` / assistant section per exchange.
`double-diaper-dungeon` renders them to pages (its `src/050-conversation-page.lua`)
with an anchor per turn.

## Intended Behavior

Three stages, kept apart so a fault in one stays in one.

**1. Each gif is looked at once, as a filmstrip.** A gif is reduced to four to
six frames spread across its length (`ffmpeg`), laid side by side into one
image, and a small **local vision model** writes a few sentences about what
moves and how it feels. The description is stored keyed by the gif's SHA-256,
so a gif is described the first time it appears and never again, and a new gif
dropped into the folder is picked up on the next run. No video generation is
involved, and no paid API: the machine has a CUDA card, and vision models
small enough to run on one (moondream, a 3B Qwen-VL) read still images well.
Describing from frames is still looking at the actual film, which is what she
asked for, rather than at its file name.

**2. Each message is matched, not generated.** Each description and each
message become an embedding (a list of numbers placed so that similar meanings
sit close together), and a message gets the gif whose description sits
closest. One embedding per new or changed message, from a local embedding
model; no chat model writes anything. `neocities-modernization` already runs
this kind of pipeline and is the pattern to follow.

**3. The answer is written down and committed.** A sidecar file beside each
transcript maps each message's fingerprint (SHA-256 of its text) to a gif's
fingerprint. A message whose fingerprint is already in the file keeps its gif;
only new or changed messages are matched. That is what makes "the same message
always gets the same gif" true across rebuilds, machines and model upgrades:
the decision is stored, not recomputed.

**The hook.** A `pre-commit` (or `pre-push`) hook runs stages 1 to 3 for
transcripts that changed, adds the sidecars to the commit, and stops the commit
loudly if a model is unreachable rather than committing transcripts without
their gifs. Which folder of gifs a project uses is one line of project
configuration; the tool itself carries no gifs.

**Drawing them** is the renderer's job, not this tool's: a small square at the
side of each turn, the person's on the left and the assistant's on the right
turned 180 degrees with CSS (`transform: rotate(180deg)`), no re-encoding. Each
gif is linked at full size from one address, so a reader's browser downloads it
once and reuses it from cache for every message that shows it.

## Suggested Implementation Steps

1. Pick the vision model and the embedding model, and check both run on this
   machine's card at an acceptable speed for 34 gifs and a few hundred
   messages.
2. Write the filmstrip step and the description cache, keyed by gif hash, with
   a test that a second run describes nothing.
3. Write the message splitter: the same exchange boundaries the renderer uses,
   so a message here is a turn there.
4. Write the matcher and the sidecar, with a test that an unchanged transcript
   produces a byte-identical sidecar and a one-message edit changes one line.
5. Wrap it as a hook with a per-project setting for the gif folder, and plant
   it in `double-diaper-dungeon` first.
6. Teach `double-diaper-dungeon`'s conversation page to read the sidecar and
   draw the squares.

## Open questions

1. "Flipped 180 degrees": turned upside down (rotated), or mirrored left to
   right? They look different for most of these films.
2. Should the same gif be allowed beside two messages in a row, or should the
   matcher take the next-closest to keep neighbours different?
3. Where does the description cache live: beside the gifs, so every project
   shares one, or in each project?
4. The gifs need to be on the web server for the pages to link them. Copied
   into each site, or one shared folder the sites all link to?
