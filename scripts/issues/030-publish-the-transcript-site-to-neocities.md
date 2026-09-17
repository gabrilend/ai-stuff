# Issue #030: Publish the transcript site to Neocities

## Current Behavior

Transcripts reach two places today and neither is a reader.

The first is the project's own repository, where the exporter writes them and a
commit records them. The second, for Double Diaper Dungeon only, is a mirror
repository: `scripts/sync-transcripts-for-github` rebuilds each commit that
touched a mirrored file into a second repository beside the project, copying the
message, author, dates and committer so the rebuilt commit hashes identically.
That mirror has a GitHub remote and a `pre-push` hook, so an ordinary `git push`
in the project carries the transcripts to `DDD-transcripts` on its own.

The mirror exists because the code and the transcripts want to live in two
different places and a commit cannot be split between two servers — a commit
carries a snapshot of the whole project, so whoever receives it receives all of
it.

That mirror is the thing this issue publishes from. It is already the boundary
between what is private and what is not, so putting a second publication target
behind the same boundary costs one decision rather than two.

Nothing renders or uploads. The tooling to upload exists and is proven, in
`neocities-modernization`:

| piece | what it already does |
| --- | --- |
| `libs/neocities-api.lua` | a status-honest curl layer that returns the real HTTP code and a parsed-or-nil body, because the stock client throws the status away and crashes on a non-JSON error page. Multi-file requests go through a curl **config file**, so paths never meet shell quoting and the key never appears in a process argument list |
| `libs/neocities-sync.lua` | the diff and the control loop, as pure logic with the network and the clock injected, so it is testable offline. Diffs by content hash, so a re-run sends only what did not land; speeds up while requests succeed and backs off when the server pushes back; and distinguishes *too big* from *rate limited*, because treating them alike makes rate limiting worse — smaller batches mean more requests |
| `scripts/deploy-to-neocities` | wires those to a real key and build, and already takes a directory, `--dry-run`, `--prune` and `--only PREFIX` |

## Intended Behavior

Pushing the project publishes the reading copy, with no extra step to remember.

    git push            in the project
      -> the mirror is rebuilt and pushed          (already built)
      -> the site is generated from the mirror     (issue 029)
      -> the site is deployed to Neocities         (this issue)

Generating from the **mirror** rather than from the project is the load-bearing
choice. The mirror is what is already public; anything the mirror does not
contain cannot reach the site by accident, and the question "is this publishable"
is answered in one place instead of two.

Three properties the existing deploy already has and this must not lose: it
sends only what changed, it resumes rather than restarting after a failure, and
it never asks the server to delete a directory.

### Failure is split the way the mirror splits it

The existing hook stops a push dead if the offline rebuild fails, and lets the
push through with a loud complaint if only the network part fails — the rebuilt
commits are safe on disk and the next run carries them. Generating the site is
offline; deploying is not. The same split applies, for the same reason.

### What it means that this is public

Neocities serves to anyone. So does the GitHub mirror, which is already live.
Three consequences worth stating before the first deploy rather than after:

- **Issue #003 gates some projects and not others.** It records that
  transcripts have carried other people's usernames, and says plainly that
  those people did not consent. That risk tracks a project's subject matter:
  Double Diaper Dungeon is about its own game and contains nobody else, while
  neocities-modernization processes other people's posts and so carries them
  as ordinary content. The developer has cleared the first and not the second.
  A pattern scan supports that reading without settling it, since an address
  has a shape a search can match and a bare name does not.
- **Publishing is not reversible by deleting.** A page that was up is indexed
  and cached. This is a property of the act, not of Neocities.
- **The site and the paywall pull against each other.** If access to the source
  is being sold (DDD issue 10-001), then a development record containing that
  source undermines what is being sold. Today it barely applies: the DDD
  transcripts hold 127 fenced lines out of 8,516, mostly command names and
  algorithm outlines in prose. It will apply once implementation starts in
  earnest, which is why issue 029 carries a size guard rather than waiting for
  someone to notice.

## Suggested Implementation Steps

1. Carry a per-project permission rather than a corpus-wide audit. A project
   publishes only once somebody has said it may, and that permission is
   recorded where a later reader can find it. Double Diaper Dungeon has been
   said of: its subject matter is its own game and no third party appears in
   it. neocities-modernization has not, and should not publish until issue 003
   is settled for it, because its subject matter IS other people. The
   distinction is per project, not per corpus (see issue 003).
2. Give the generator an output directory under the mirror, ignored by the
   mirror's own git, so building never dirties the repository it read from.
3. Reuse the existing deploy rather than writing a second one. It already takes
   a directory; what it needs is a remote prefix of its own so the transcripts
   land beside the existing site instead of inside it.
4. Keep the key where the existing deploy keeps it. One key, one config file,
   one place to rotate it.
5. Extend the mirror's `pre-push` hook to generate and deploy after the mirror
   push succeeds, preserving its existing rule that a rehearsal sends nothing —
   it reads the dry-run flag off the parent's command line in `/proc`, because
   git does not tell a hook, and a rehearsal that published would be the
   opposite of a rehearsal.
6. Make the first deploy `--dry-run` and read the list before letting it run for
   real.
7. Decide whether other projects publish at all, or whether this stays DDD's.
   The generator is general; the decision to publish is per project, and should
   stay an explicit act rather than something a tool does because it can.

## Related Documents and Tools

- `double-diaper-dungeon/scripts/sync-transcripts-for-github` — the mirror, and
  the hook this extends
- `double-diaper-dungeon/test-sync-transcripts` — proves the rebuild is
  deterministic; the pattern to follow for testing this
- `neocities-modernization/scripts/deploy-to-neocities` and the two libraries
  above
- Issue #029, which generates what this publishes
- Issue #003, which gates neocities-modernization but not Double Diaper Dungeon
- `double-diaper-dungeon/issues/10-001-sell-access-through-subscribestar.md`,
  which shares this boundary from the other side

## Notes

The developer initially proposed publishing straight to Neocities and wondered
whether the mirror repository was needed at all. It is, and for a reason that
turned up in the same conversation: the mirror is where private and public are
separated, and a second publication target behind the same boundary is cheaper
and safer than a second boundary. A separate session had already built it.
