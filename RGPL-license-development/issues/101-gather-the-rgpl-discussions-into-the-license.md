# Issue 101: Gather the RGPL Discussions Into the License

The RGPL ("Our Great Public Library" license) has been talked about in many
conversations across several projects. The license text holds some of what was
decided; much of the rest lives only in transcripts and in other projects'
issue files. This issue maps every place the license was discussed, says how
much of each discussion the license text reflects, and lays out the work that
brings the text up to date with what was decided.

This is the first issue of this folder. Later issues here are expected to be
split out of the "Suggested Implementation Steps" below.

## Where the license lives today

| File | What it is |
|---|---|
| `/mnt/mtwo/programming/ai-stuff/RGPL` | The license draft. Derived from the AGPLv3 text, renamed, with a new preamble, "our clause" (section 13) and, since 2026-10-05, the reports clause (section 14). Drafting note at the top lists every change and every open question. Not committed. |
| `/mnt/mtwo/programming/ai-stuff/COPYRIGHT-RGPL` | The draft replacement for the repository's `COPYRIGHT` file: what the RGPL does in plain words, the artist offer, where source comes from (a person, never a host). Not committed. |
| `/mnt/mtwo/programming/ai-stuff/LICENSE`, `COPYRIGHT` | Still the AGPLv3 and its companion. Nothing has switched yet. |
| `/mnt/mtwo/programming/ai-stuff/README.md`, line 599 | One sentence saying the RGPL draft is written to make the source request binding. |
| `/mnt/mtwo/programming/ai-stuff/scripts/issues/003a-redaction-capability.md` | Holds the redaction rules, the data-versus-source-code test, the model-weights discussion and the training-data sale terms, all marked "belongs in the RGPL's own documents". Lines 72-85 and 160-292. |
| `/mnt/mtwo/programming/ai-stuff/delta-version/issues/063-disentangle-the-author-from-history.md`, line 49 | The poems leave git history and are offered "by the same request route the RGPL will use for source code". |
| `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/docs/licensing-and-boundaries.md` | Lines 23, 49-79: why RGPL code cannot be combined with GPLv3 or AGPLv3 code, and the plan for an all-RGPL stack. Lines 247-251: two open questions about which license the client uses. |
| `/mnt/mtwo/games/azeroth-core/wow-chat-2026/notes/rgpl.md` | The owner's fan-artist idea, saved word for word. |
| `/mnt/mtwo/games/azeroth-core/wow-chat-neuron/issues/1007-the-resident-narrator.md`, lines 171-174 | Quotes the owner pointing at the RGPL as the place where intentionally placed limits are respected. |

## The transcripts

Short names used in the rest of this file:

| Name | Path |
|---|---|
| **T1** | `/mnt/mtwo/programming/ai-stuff/llm-transcripts/sep-23-26-through-sep-26-26.md` |
| **T2** | `/mnt/mtwo/programming/ai-stuff/llm-transcripts/draft-the-rgpl-license-sep-23-26.md` (the helper session that wrote the draft) |
| **T3** | `/mnt/mtwo/programming/ai-stuff/llm-transcripts/oct-1-26.md` |
| **T4** | `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/llm-transcripts/sep-23-26-through-sep-26-26.md` |
| **T5** | `/mnt/mtwo/games/azeroth-core/wow-chat-2026/llm-transcripts/oct-4-26-through-oct-5-26.md` |
| **T6** | `/mnt/mtwo/programs/rao-chat/llm-transcripts/sep-23-26-through-sep-27-26.md` |
| **T7** | `/mnt/mtwo/games/azeroth-core/wow-chat-neuron/llm-transcripts/sep-29-26.md` |
| **T8** | This conversation, 2026-10-05, in the ai-stuff root transcripts once exported. It made this issue and added section 14. |

Every transcript folder on the machine was searched on 2026-10-05 (the
`/mnt` drives, the monorepo, worktrees and backups). Copies in backups and in
the `HTML/` renderings repeat the files above and add nothing. Folders with no
mention: the tq games, the Dominions mods, steam-games, recorded videos,
r-mail, open-claw, soramech, ruby, algorism, the ai-playground projects.

To repeat the search:

    grep -rlE 'RGPL|Great Public Library|our clause' <folder>/llm-transcripts

### How the license began (T1, T2)

- **T1 207-224** — the origin, in the owner's words: "There is no such thing
  as 'private use' for a networked application, it is by definition shared
  with more than the self." The source must be freely given "by mechanisms in
  the software itself, that do not reference or notify an external other".
  "A singular link between person and receiver, hence rmail's near perfect
  encryption level." The name is asked for: "call it RGPL or something
  similar? For 'our GPL'".
- **T1 486-539** — the reply: what GPL and AGPL are, how the owner's version
  differs (unmodified use too, anyone used *with*, source travels through the
  software), why it can't be an add-on to the AGPL (section 7 lets recipients
  strip added restrictions), that it must be a separate license, and the cost
  (no combining with others' GPL code). Ends by asking whether the rule binds
  the person or the program.
- **T1 562-609** — the owner's answer: "this is the Ritz version, which adds
  'our' clause"; wants section 7 struck, believing it lets person B strip our
  clause; "RGPL ... stands for 'Our Great Public Library' which is a civic
  society of the commons"; "I wrote everything in this repository that has an
  AGPL license, so I can transition them all"; and on enforcement: "Nothing
  can stop them. I cannot control what they do on their own computer ...
  using software against the wishes of the developer is to use them against
  this will or know-about, which is manipulation at best and slavery at
  worst."
- **T2 10-52** — the drafting directive given to the helper: new name, no GNU
  or FSF stewardship, our clause in the core terms, section 7 kept with a
  note explaining why, "not reviewed by a lawyer".
- **T2 112-126** — the helper's four open questions (section 7, combining
  with GPLv3, whether outputs trigger the duty, COPYRIGHT's GitHub mirror).
- **T1 1076-1100** — the owner answers: keep section 7; "only interaction"
  (finished outputs travel free).
- **T2 133-176** — both answers applied to the draft.
- **T1 1226-1238** — the owner: drop the GPLv3 permission ("I think we have
  to"); "We shouldn't point to github as a source of source-code truth. No
  third party intermediaries."
- **T2 183-242** — the GPLv3 permission removed; `COPYRIGHT-RGPL` drafted. Two
  questions left: list vendored folders by name, or keep the "nearest
  license file" rule? Is "the mail system I am building" right for rmail?
- **T1 1335-1366, 1558-1560, 1719-1721, 1929-1930** — those two questions
  asked again three times. **Never answered.**

### The redaction rules, data versus source, weights, and training data (T3)

- **T3 52-60** — the owner sets the goal of the RGPL work: understand
  exactly how it works, and "strip out any misleading things that might
  imply that we're part of the Gnu team".
- **T3 124-125, 138-150, 197-200** — who should readers assume wrote it?
  "that we wrote it, because it's R's - ours".
- **T3 305-321** — the owner's plan for poems: an rmail inbox with a public
  key that drops everything except a few request-shaped files. "anyone who
  requests my poetry will use the same pathway mechanism ... that someone
  could use to request from anyone running RGPL software ... the
  source-code". Calls for a skill on building a system that receives a
  request for source.
- **T3 392-401** — the owner: put in the RGPL that every redaction must
  explain what was redacted and why, and be limited to things like personal
  information or national security.
- **T3 836-845** — question: a fixed list of redaction kinds, or free text?
- **T3 870-895** — the owner: "we don't want to restrict what you redact,
  only how you do it". Source code and datasets may not be redacted;
  personal information may, because it "is inherent to me, to my physical
  presence in the world, to my spirit". The bird-wing dataset example. Data
  withheld against the rule must come with a way to request it that no
  third party (a mail server) learns about.
- **T3 896-953** — three places the "why was it made" test bends:
  credentials, personal information inside datasets, poems read by a
  program.
- **T3 954-1007** — the owner: credentials are personal information
  (redactable), but a licensee must not hide the source behind a login; the
  test applies to anything that goes into git; and the key definition:
  "dataset is interchangable, source-code is what determines the outcome of
  the system".
- **T3 1008-1046** — the reply proposes one plain sentence for the license:
  the route for requesting source never requires a credential. The swap
  test: would the system still work with someone else's well-formed values?
  Where it gets hard: weights, lookup tables, gameplay constants.
- **T3 1047-1110** — the owner: a redacted lookup table leaves its structure
  and becomes a stated build requirement, with build scripts provided.
  Weights: "I'm leaning toward yes [they are source code] as well but we
  should discuss it more." Points at the world-edit and wow-chat-2026 work as
  the real test case.
- **T3 1111-1177** — memorisation: weights that can reproduce a withheld item
  contain it. Guidance that looks at the original leaks up to one bit per
  keep-or-discard step.
- **T3 1178-1259** — the owner: scores only push generation away from the
  original (a clean-room review step); "if you wanted the poems, why don't you
  just ask for them?" The reply agrees: withheld training data gets a notice
  (what kind, why, where to ask), with no duty to publish.
- **T3 1260-1339** — the owner: "training data shouldn't be freely available
  ... sold for a reasonable price ... sold fractionally". The reply brings in
  FRAND (fair, reasonable and non-discriminatory) from patent law.
- **T3 1340-1415** — the owner's terms: any fraction at the same fraction of
  the price; fractions drawn at random so nothing is held back for full
  buyers; the seller picks the unit, the same for everyone; the trainer sets
  the price and pays creators once when the set is assembled and again as
  royalties on every sale; the list of sources travels with the data.
- **T3 1416-1464** — the reply: draws both sides can check (publish a hash
  of the item list first, the buyer supplies the random seed); repeat
  purchases draw only from items not yet held; a ledger for royalties owed
  to creators who can't be reached. **Unanswered:** if a buyer resells the
  dataset, do the royalties follow it?

### The license in use (T4, T5, T6, T7)

- **T4 860, 1109-1118, 1186-1211** — the RGPL can't be combined with GPLv3
  or AGPLv3 code. The owner: "We might have to write our own lua engine...
  nuts..." and the plan to rebuild the server as a soramech that speaks the
  same protocol, so the whole stack can be RGPL.
- **T4 1497, 1521** — the extracted data tables belong to the RGPL project;
  wiki text can't be used, because it would have to be released under
  CC BY-SA.
- **T4 2164-2217** — the owner: "I would be the operator, and I'd share the
  code according to the principles set forth in the RGPL, so I would be
  considered both an operator and a distributor."
- **T4 2256-2295** — the owner's cease-and-desist plan: a takedown notice
  posted publicly *beside the source code*, "delivered alongside the delivery
  mechanism that RGPL requires". Notices handled first-in, first-out. This
  is the same shape as the reports clause: notices kept where everyone can
  see them, next to the source.
- **T4 2400-2425** — a plain factual notice linking the repository and the
  RGPL's source-request instructions.
- **T5 3873-3881** — a new idea, not discussed yet: "fan-artists and
  copyright rulebreakers should be able to sue. If the person wants to
  defend the copyright, they have to pay to make the art suitably different.
  They will be compensated with the ability to buy the artwork in question.
  at all times, it must have proper credits and references to prior art.
  fanfiction kills the copyright industry. torrenting kills the movie
  industry. Do fewer films get made? No. They are for all of us."
- **T6 2195-2200** — rao-chat borrows the RGPL's shape for something else:
  "request that others automatically send their contacts list to us, in the
  same way that the RGPL requires people to send their source-code".
- **T7 1696-1699** — "They were never intentionally placed limits, those
  must always be respected (see the RGPL)."

### The reports clause (T8)

The owner asked for a clause: everyone using the license must always be open
to issue and bug reports, delivered however they like, displayed publicly or
alongside the source code, their choice; they don't have to act on them. The
goal: "make big companies fix their software debt by publically shaming them
for faulty behavior, irresponsible architecture decisions, and lax
maintenance policies." Drafted as section 14. Later sections were renumbered
(15 versions, 16 warranty, 17 liability, 18 interpretation) and every
cross-reference was updated.

## Current Behavior

**Reflected in the license text:**
- Our clause (section 13): use *with* another person, modified or not, in
  person or over a network, owes that person the source, handed over
  directly, through no third party, with no third party told. Use inside an
  organisation counts as use with others. Use alone owes nothing. Finished
  outputs travel free.
- Section 7 kept. Our clause is in the core terms, so it can't be stripped.
- The permission to combine with GPLv3 code is dropped.
- The name, the preamble in the owner's voice, and the spirit statement
  (T1 600-609) nearly word for word.
- No GNU or FSF stewardship. Section 15 (formerly 14) names gabrilend as
  publisher of new versions.
- Section 14 (reports): anyone who conveys the work, or uses it with others,
  keeps open a free, account-free, credential-free way for anyone to report
  faults, and displays every report, unaltered and dated, publicly or in a
  `REPORTS` file that travels with the source. Acting on a report is never
  required. Things that may be held back: security flaws until fixed or 90
  days; personal information and unlawful material, cut with a marked
  notice; the reporter's name, on request; advertising and bulk mail. Counts
  of what is held back are shown.
- `COPYRIGHT-RGPL`: source comes from a person or from the program, never
  from a host; describes our clause and the reports rule.

**Decided in conversation, missing from the license** (source: T3 and
`scripts/issues/003a-redaction-capability.md`):
1. Every redaction states what was removed and why. Text that merely says
   "redacted" as its own content is not a redaction.
2. Source code and datasets made to feed programs may not be redacted. The
   test is why the thing was made. Personal information may be redacted.
3. Credentials count as personal information. The route for requesting
   source never requires a credential.
4. The test applies to anything that goes into git, at whatever size the cut
   is (a name inside a dataset, an address inside a settings line).
5. Source code is what decides the outcome; data is interchangeable. A cut
   dataset keeps its structure, so others can put their own values in.
   Instructions written as data are a script, so they count as source code.
6. A redacted lookup table keeps its structure and becomes a stated build
   requirement; build instructions (ideally scripts) must be provided.
7. Anything withheld that the rules say may not be withheld must come with a
   way to request it that no third party learns about.
8. Training data withheld from published weights gets a notice: what kind,
   why, where to ask. No duty to publish what the weights memorised.
9. Training-data sale terms: FRAND pricing, any fraction at the same
   fraction of the price, random draws, one unit for all buyers, other
   people's personal information redacted before sale, data the seller
   doesn't own listed by provenance, creators paid at assembly and as
   royalties, provenance travels with each sale.

**Not reflected at all:**
- The fan-artist and prior-art idea (T5 3873-3881).
- Whether model weights are source code (leaning yes, "we should discuss it
  more", T3 1047-1110).
- The skill and mechanism for receiving source requests over rmail
  (T3 305-321). The license points at "a command, a menu item, or a step in
  the first handshake" in its appendix, but no tool exists.

**Unanswered questions sitting in other files:** listed under Open Questions
below.

## Intended Behavior

- The license text, `COPYRIGHT-RGPL`, and any companion documents together
  state every rule the owner has decided, each traceable to the conversation
  where it was decided.
- The drafting note in `RGPL` lists no question that was answered elsewhere
  and never carried back.
- Rules that belong in the license's binding terms are separated from rules
  that belong in a companion document (the training-data market, for
  example, may be a companion rather than a license section; T3 1416-1427
  suggests "the RGPL's own documents").
- Every open question below is answered, one at a time, with the owner.
- The switch from AGPL to RGPL (LICENSE, COPYRIGHT, per-project license
  files, README) is a separate, deliberate step, taken only once the text is
  settled.

## Suggested Implementation Steps

Ordered from foundation to capstone. Each may become its own issue in this
folder (102, 103, ...), or a lettered sub-issue of this one.

1. **Settle section 14 (reports).** Work through its five open questions
   below. Consider writing the takedown-notice practice (T4 2256-2295) in as
   an example: a notice received is a report, displayed beside the source.
2. **Define data versus source code in section 1.** Extend "Corresponding
   Source" with the owner's test (outcome-deciding versus interchangeable),
   scripts-as-data, lookup tables as stated build requirements, and the
   weights decision once made. This underpins step 3.
3. **Write the redaction section.** From the nine decided rules above and
   `scripts/issues/003a-redaction-capability.md` items 4-8. Must sit in the
   core terms, outside section 7's reach, like sections 13 and 14. Include
   the sentence that the source-request route never needs a credential.
4. **Decide the weights question** (T3 1047-1259), then fold it into step 2.
5. **Decide where the training-data sale terms live**: a license section, or
   a companion document the license points to. Answer the resale-royalty
   question first (T3 1416-1464).
6. **Answer the two `COPYRIGHT-RGPL` questions** (T2 236-242): vendored
   folders listed or the nearest-license rule; the rmail wording.
7. **Discuss the fan-artist idea** (T5 3873-3881). A license binds only the
   people who accept it; it can't give a stranger the right to sue someone
   else. What it can do: promise not to sue fan artists (a covenant), require
   credit and prior-art references, and set terms for buying derived art.
   Find out which of these the owner means.
8. **Build the source-request mechanism**: the rmail request inbox and its
   skill (T3 305-321), shared with the poem requests of delta-version issue
   063. Also the place section 14's reports could arrive.
9. **Write a plain-words companion**: what each section does, mechanically,
   with an example (the `COPYRIGHT-RGPL` "what the RGPL actually does"
   section is the seed). Note the enforceability limits honestly: conditions
   on copying are strong; conditions on mere use without a copy (sections 13
   and 14) rest on contract rather than copyright in the US.
10. **Legal review**, if the owner wants one, before the switch.
11. **The switch**, as its own issue: `RGPL` replaces `LICENSE`,
    `COPYRIGHT-RGPL` replaces `COPYRIGHT`, the drafting notes are removed,
    README line 599 is updated, and world-edit-to-execute's licensing
    document answers its two open questions (lines 247-251).

## Open Questions

From section 14 (T8, also in the `RGPL` drafting note):
1. A public tracker on a hosting site puts a third party between reporter
   and maker. Section 13 forbids that for source. Allowed for reports, since
   they're meant to be public anyway?
2. Keep the 90-day hold on security reports, shorten it, or drop it?
3. Can anyone report, or only people who received or used the work?
4. Are reports kept forever, or only while the work is still passed on or
   used with others?
5. Where do reports about the owner's own repository go, and where are they
   shown?

Carried from elsewhere:
6. `COPYRIGHT-RGPL`: list the vendored folders by name, or keep the "nearest
   license file" rule? (T2 236-239)
7. Is "the mail system I am building" the right description of rmail?
   (T2 240-242)
8. Are model weights source code, even when trained on withheld data?
   (T3 1047-1110, "we should discuss it more")
9. When a dataset is resold, do the creators' royalties follow it?
   (T3 1455-1464)
10. When values are cut from a dataset, what must remain to keep its
    structure: a written description of the format, a sample record with
    made-up values, or both? (`scripts/issues/003a-redaction-capability.md`
    item 9)
11. The fan-artist idea: a promise not to sue, a credit rule, a buying
    right, or something else? (T5 3873-3881)
12. Should the RGPL drafts move into this folder, or stay at the repository
    root where `LICENSE` lives?
13. Should this folder become a full project (docs, notes, the usual
    skeleton), or stay a home for license issues only?

## Related

- `/mnt/mtwo/programming/ai-stuff/scripts/issues/003a-redaction-capability.md`
  holds the redaction rules (steps 2-5)
- `/mnt/mtwo/programming/ai-stuff/delta-version/issues/063-disentangle-the-author-from-history.md`
  shares the request route (step 8)
- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/docs/licensing-and-boundaries.md`
  waits on the switch (step 11)
- `/mnt/mtwo/games/azeroth-core/wow-chat-2026/notes/rgpl.md` holds the
  fan-artist idea (step 7)
