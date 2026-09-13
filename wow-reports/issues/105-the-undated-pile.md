# 105 - The undated pile

| | |
|---|---|
| Phase | 1 - the patch spine |
| Blocked by | 104 |
| Blocks | every extractor that reads a source which does not state its own patch |
| Confirmed by owner | not yet - see open questions, item 4 |

## Current behaviour

Nothing has been extracted, so nothing is undated yet. The rule is being written
before the first undated thing arrives, because the wrong rule is much harder to
remove once a thousand artefacts have been filed under it.

## Intended behaviour

An artefact whose patch cannot be established is recorded with its patch unknown
and shown as unknown. It is never placed on the timeline at a guessed position.

The temptation this issue exists to refuse: a spreadsheet fetched today is
probably about the patch that is live today, and stamping it with that patch
would make the timeline look complete. It would also be a fabrication, and it
would be indistinguishable from a real observation the moment it was written
down. A theorycrafting spreadsheet is frequently months stale, often describes a
patch that has not shipped yet, and sometimes covers several at once.

The consequence has to be accepted deliberately: the viewer gets a visible pile
of undated artefacts sitting permanently beside the timeline, and that pile is
not a defect to be reduced to zero. It is the honest size of what we do not
know.

Three dating states, and they are different claims:

| State | Meaning |
|---|---|
| stated | the artefact itself says which patch it is about |
| derived | a rule established from the artefact's own content, with the rule recorded alongside so it can be re-examined |
| unknown | neither; the artefact goes in the pile |

The fetch date is never any of these. It is provenance, not dating, and the
distinction is the whole point.

## Suggested implementation steps

1. Add the dating state to the fact record, alongside the build.
2. Make the extractor interface require a dating state to be supplied. An
   extractor that cannot determine one must say unknown explicitly rather than
   omitting the field, so that silence is never mistaken for a claim.
3. Make the viewer render the three states differently, and make the undated
   pile a place someone can actually go and look at, since it is where the
   project's ignorance is kept.
4. Test that an artefact fetched with no patch information survives a full round
   trip through extraction and into the viewer still marked unknown.

## Related documents

- The shape of a fact - the `confirmed_at` field, which is this same principle
  applied to gaps between observations rather than to artefacts
