# Issue 003a: Redaction Capability

Sub-issue of `003-implement-privacy-features`: this is the "stripping system"
that issue asks for, widened from transcripts to any text the repository
publishes. Builds on `036-transcript-patches.md`.

## Current Behavior

Nothing is built. Planned 2026-10-01.

Today the only way to change published text and keep the change is a
transcript patch (issue 036). Each patch is a folder of three tracked files:
`find`, the exact text to cut; `replace`, the exact text to put in its place;
and `about`, the date and reason. Because `find` is committed, a patch that
removes a secret commits that same secret. So the patch system cannot redact
anything.

What prompted this: on 2026-10-01 the mail tool's state folder was found in
git history, on GitHub since 2026-09-09. It held the home network's public
address and the forwarded mail port. This conversation's own transcript then
quoted the address while the problem was being looked into. The address has
to come out of the transcript, and out of the history rewrite in
delta-version issue 063, without the tool that removes it writing it back
into git.

## Intended Behavior

### Two operations, one set of patches

A **patch** changes text, exactly as issue 036 describes. A **redaction** is a
patch whose cut text must never be published. The two share one patch set
and one apply step. The only difference is where the cut text is stored:

- **Ordinary patch:** stays exactly as it is now, all files tracked in git.
  An example is translating commit ids after a history rewrite. Nothing in it
  is secret, so its whole content sits in history where anyone can read it.
- **Redaction:** split into two layers.
  - **The notice (tracked).** It says *that* something was cut and *what kind*
    of thing it was, with the date and the reason: "home network address and
    mail port, cut 2026-10-01, personal information". It also holds the exact
    replacement text, which carries the redaction's number, e.g.
    `[redacted 001: home network address]`.
  - **The detail (never tracked).** The exact bytes that were cut. It lives
    in a private store outside git.

Applying happens in two stages:

1. **Patch the patches.** Each redaction's notice is joined to its detail,
   giving a complete ordinary patch (`find`, `replace`, `about`). The result
   is written to RAM (`tmp/shared-memory/`), never to disk inside the
   repository.
2. **Patch the text.** The completed patches and the ordinary ones apply in
   name order, through the same idempotent apply that issue 036 built.

### Reversible by construction

Each replacement carries its own redaction number, so it appears nowhere
except where that redaction put it. Swapping every replacement back for its
detail therefore restores the original exactly. That swap is the
"unredact" switch: it produces a full original for the person who holds the
private store, written to RAM or standard output and never over the redacted
file.

### Missing detail is an error

If a notice's detail is missing from the private store (a new machine, a
lost store), the text it governs cannot be redacted. Every export or rewrite
that needs that redaction stops, names it, and changes nothing. A missing
detail must never mean the cut text silently goes out uncut. This is the
"stale patch is an error" rule from issue 036, made stricter.

### What counts as a redaction

The rule the RGPL will state (written when the RGPL is worked on):

- **Every redaction says what was cut and why.** That covers the kind of
  thing (an address, a name, a token, a picture) and the reason for cutting
  it.
- **Redactions are limited to what redaction is for:** personal information,
  credentials, matters of security, and anything else of that kind.
- **Text that merely says "redacted" as part of its own content is not a
  redaction** and is none of this system's business.

### Where it is used

Each place below gets its own work item; this issue builds the mechanism and
the skill.

- **Transcripts:** the exporter applies redactions on every re-render, as
  it already applies patches.
- **Git history:** delta-version issue 063. Stage 1 also writes git
  filter-repo's replace-text file (`literal==>replacement` lines) in RAM, so
  the history rewrite cuts exactly what the transcripts cut.
- **neocities-modernization:** the anonymised fediverse usernames (its
  completed issues 6-027a and 6-030) and the pictures withheld from the
  website could become redactions with notices, instead of rules buried in
  the generator.
- **Issue 003's audit:** a person reads a project's transcripts, and each
  name they find becomes a redaction.

### The skill

A skill named **redaction-capability** teaches the method. It takes most of
its design from **upstream-patch-system**:
- the patch as an exact, reversible function over text;
- guards that make an already-applied patch change nothing;
- stale patches as loud errors;
- a registry generated from patch headers.

It adds the two layers, the private store, the numbered replacement, the
unredact switch and the rule on what counts as a redaction.

## Suggested Implementation Steps

1. **Private store:** `/home/ritz/backups/RGPL-redaction-records/`, overridable
   by an argument as the house script rule asks. Settle its backup and layout
   (open questions below) before creating it.
2. **Notice format.** Add a fourth patch kind to `transcript-patches`,
   *redaction*: `about` (date, category, reason) and `replace` (numbered),
   tracked; `find` is read from the private store by the notice's id.
3. **Stage 1** (`transcript-patches complete`): joins notices to details in
   RAM. A missing detail is an error naming the notice.
4. **Stage 2:** the existing `apply` reads the completed set; the exporter
   (`backup-conversations`) calls stage 1 before it.
5. **`new --redact`:** records a redaction. It writes the notice into the
   tracked folder and the cut bytes into the private store, and refuses a
   replacement without a number and a category.
6. **`unredact <file>`:** the reverse swap, to standard output or RAM.
7. **`replace-text-file`:** writes filter-repo's input from the completed
   redactions, for issue 063.
8. **Tests** (`tests/test-transcript-patches.sh`):
   - a redaction applies and reverses exactly;
   - a missing detail stops the export;
   - the cut bytes appear in no tracked file and in nothing `git add` would see;
   - a notice without a category is refused;
   - ordinary patches behave as before.
9. **The skill:** `~/.claude/skills/redaction-capability/SKILL.md`, with a
   reference copy of the tool.
10. **First use:** redact the network address from
    `llm-transcripts/oct-1-26.md` (this conversation) before that transcript
    is committed.

## Open Questions

1. ~~**Where does the private store live?**~~ Settled 2026-10-01 by the
   owner: outside every repository, at
   `/home/ritz/backups/RGPL-redaction-records/`. No ignore rule guards it,
   so none can be lost. A clone on another machine has no details until the
   store is copied there, and its exports refuse to run until then.
2. ~~**How is the private store backed up?**~~ Settled 2026-10-01 by the
   owner: a copy kept off this machine, on the owner's Linode server.
   A pre-push hook sends the store there on every `git push`, the same place
   the transcript-pages hook already runs (`install-pages-hook`). The Linode
   is still being set up, so the hook is built only **after the owner says
   the server works**. Until then the store is plain files on this disk
   only, and nothing checks it. Once the hook exists, a push that finds the
   copy cannot be made stops rather than going out with an uncopied store,
   since house rules treat a warning as an error. Still to be decided: whether
   that copy is encrypted (to be asked when the Linode is ready; it ties in
   with scripts issue 035's open questions about the same server).
3. ~~**Where does the skill's design live in the repository?**~~ Settled
   2026-10-01 by the owner: in both places, `~/.claude/skills/redaction-capability/`
   and `skills/redaction-capability/` in the monorepo, as upstream-patch-system
   is. The skill holds the method and no redacted text, so publishing it is safe.
4. ~~**What are the categories?**~~ Answered 2026-10-01 by the owner: no
   list of kinds. The rule is about how a redaction is done, not what it
   cuts. Every notice must say **(A) what was removed** and **(B) why**. Two
   things may not be cut:
   - **source code**, which changes what a machine does;
   - **datasets**, which change what a machine does when fed to any program,
     whether or not that program is under the RGPL.

   The line between a dataset and personal information is **why the thing
   was made**. Personal information is data, but it was not made to guide
   software; it "is inherent to me, to my physical presence in the world,
   to my spirit". A dataset of bird wing shapes and their contours was made
   to be input to a program, so it cannot be redacted under the RGPL.

   If something that may not be redacted is cut anyway, the notice must give
   a way to request it, like the poems' rmail inbox. That way must not let a
   third party (a mail provider) learn that a request was made. Network
   carriers, which the request has to travel over for now, are outside what
   the rule can promise.
5. ~~**Credentials.**~~ Answered 2026-10-01 by the owner: a credential is
   information a person uses to identify that person and only that person,
   so it counts as personal information and may be redacted. The owner's
   worry with a separate "access" kind was that a licensee would put the
   source behind a login and say "you need the credentials". So the RGPL
   must also say that the route for requesting source never requires a
   credential.
6. ~~**Personal information inside a dataset or source file.**~~ Answered
   2026-10-01 by the owner: the test applies to anything that goes into git,
   at whatever size the cut is. A name in a dataset, or an address in a
   settings line, can be cut while the dataset or code around it stays.
7. ~~**Poems, and where data ends and source code begins.**~~ Answered
   2026-10-01 by the owner:
   - **Source code determines what a system does with the data it is
     given.** Instructions written as data and passed to an interpreter are
     a script, so they count as source code.
   - **Data is interchangeable.** Its particular values may be redacted, as
     long as its *structure* is kept, so that someone else can put their own
     data into the same structure. Examples: JSON with user ids and email
     addresses removed, or the poems withheld while the format the site
     generator reads stays.

   Following from that, a working test: **if the redacted values were
   replaced with someone else's well-formed values, would the system still
   do its job?** If yes, they are data and may be cut, provided the
   structure is documented or kept. If no, they decide the outcome, and
   count as source code.
8. **Data that decides the outcome.** Trained model weights, lookup tables,
   gameplay constants (world-edit-to-execute's stock unit tables): their
   exact values *are* the behaviour, and someone else's values give a
   different system.
   - ~~Lookup tables~~ Answered 2026-10-01 by the owner: they feel like
     source code, and if they are redacted, the structure stays and the
     table becomes a stated requirement of the build. The build
     instructions must be provided too, ideally as build scripts like this
     repository's.
   - **Weights.** Still being discussed. The owner leans toward "weights are
     source code, published even when trained on withheld data". The
     world-edit-to-execute and wow-chat-2026 work is meant to show this, and
     also that generation can be run backwards
     (`world-edit-to-execute/new-vision-issue-please-sort`). Two things are
     unresolved:
     - **Memorisation.** If the weights can reproduce a withheld item
       exactly, publishing them publishes that item. The rule that weights
       are published and the rule that the data may be withheld then
       collide.
     - **Guidance.** A generator steered toward "more similar" by a score
       that looks at the original receives some of the original through that
       score. Each keep-or-discard step carries at most one bit. So a
       reconstruction shows what the weights hold only after counting what
       the guide passed in.
     - The owner, 2026-10-01: in world-edit-to-execute the similarity scores
       never steer generation toward the original. They choose which parts
       of a model are regenerated *to be made more different*, and the whole
       model is scored again afterwards. A guide that only pushes away is
       the review step of a classic clean room, not a leak of the original's
       expression. That holds as long as the step keeps the first version
       that passes; it would not hold if it kept the passing version that
       scores closest, since that is steering toward.
     - **No duty to publish what the weights memorised** (the owner: "if
       you wanted the poems, why don't you just ask for them?"). Withholding
       training data is a redaction of the weights' source. It gets a notice
       like any other: what was withheld (the kind, not the content), why,
       and the route to request it.
     - **Who picks among passing versions** (the owner, 2026-10-01): neither
       the first nor the closest. People keep the version they like most.
       They may well like the ones that look most "correct", which is
       steering toward the original through their memory of it. The project
       accepts that, because the distinctiveness line still holds. Measurable:
       compare the scores of chosen and passed-over versions. If the chosen
       ones sit closer to the line, the steering is real and can be reported.
     - **Training data offered for sale, under discussion** (the owner,
       2026-10-01): weights are free, and training data must be available,
       if not free then sold at a reasonable price, and sold in fractions for
       a proportional, fair price. The owner's terms, 2026-10-01 (these
       belong in the RGPL's own documents once that work starts):
       - **Same terms for everyone who asks,** in the spirit of FRAND (fair,
         reasonable and non-discriminatory) — including people with little
         money. Any fraction can be bought at the same fraction of the full
         price.
       - **Fractions are drawn at random,** so no part of the data is held
         back for whole-set buyers. The seller says what share of the data
         each kind makes up. Example: "up to 15% is pictures of dogs; the
         whole set is $100", so $10 asked against the dogs buys a random two
         thirds of the dog pictures.
       - **The seller picks the unit** (items, bytes, ...), the same unit for
         every buyer.
       - **Other people's personal information is redacted** before sale.
       - **Data the seller does not own** is listed with its provenance
         rather than sold.
       - **Who sets the price:** whoever trained on the data sets one price
         for the whole set. Creators cannot pull their data back out, since
         that would mean retraining whenever a creator objected. Instead the
         trainer pays creators twice:
         - properly, when the dataset is assembled;
         - as royalties on every sale, stated as "for every $N of the
           dataset sold, this piece earns its creator $M". M is the trainer's
           estimate of that piece's effect on the weights, since nobody can
           yet measure it.
       - **Provenance travels with every sale,** and could route the
         royalties to the creators.

       Mechanism notes, not yet agreed:
       - **A draw both sides can check:** the seller publishes a hash of the
         dataset's list of items in advance, and the buyer supplies the
         random seed.
       - **Repeat purchases draw only from items the buyer does not already
         hold.** Otherwise someone buying 10% ten times ends up with only
         about 65% of the set, paying more than a single full buyer for less.
9. **Keeping the structure.** When values are cut, what must remain: a
   written description of the format, one sample record with made-up
   values, or both?

## Related

- `003-implement-privacy-features` — the parent: the per-project audit this
  mechanism serves
- `036-transcript-patches.md` — the patch system this extends
- `delta-version/issues/063-disentangle-the-author-from-history.md` — the
  history rewrite that uses the same redactions
- `~/.claude/skills/upstream-patch-system/` — the design this inherits
- `README.md` (repository root), `RGPL` — where the rule on what counts as a
  redaction will be written
