# Where the numbers live

A survey of the places on the internet that hold what players have worked out
about how World of Warcraft behaves, and what it costs to get each one.

Reachability claims below were established by hand once. They are not
maintained by hand - once the harvester exists, the source of truth for "is this
still reachable and what shape does it return" is a reachability probe that can
be re-run, not this document. Treat any status word here as a starting
hypothesis with a date on it, checked 2026-09-12.

## The spine: a table of every version the game has ever been

**wago.tools** publishes the game's own internal database tables, extracted
from the client, for every build Blizzard has ever shipped. Its build index is a
single unauthenticated request returning roughly half a megabyte of JSON: for
each product line (retail, the public test realm, each Classic line), every
version string and the date that build went up.

A version string looks like `12.1.5.69594`. The first three numbers are the
patch a player would name, the fourth is the build number, which is the only
identifier that is genuinely unique and genuinely ordered. Dates come attached.

This is the patch axis. Everything else in the project hangs off it. It is free,
it needs no account, and it is the same underlying data Wowhead is built on top
of, which is why going here instead of there is not a compromise.

## The evidence: what actually happened in real fights

**Warcraft Logs** is where raids upload the combat log the game writes to disk.
It has an official GraphQL interface. Access is by registering an API client on
their site, which yields a client identifier and a secret; those are exchanged
at a token endpoint for a bearer token, which is then sent with each query. The
token endpoint is live and answers, but it will not talk to an anonymous
caller - *this source is gated on the project owner registering a client.*

What makes it the most valuable source in the project: for any fight it has
stored, it will return a table of every aura on every player and **the fraction
of the fight that aura was present**. That fraction is the N% in "assume all
characters have N% uptime". It does not have to be guessed or assessed by
playing - it is measured, per player, per fight, per patch, going back years.

Budget is metered as points per hour rather than requests per hour, with the
cost of a query scaling with how much data it touches. A harvester must
therefore pace itself by cost, not by count.

## The authority: what the game says about itself

**Blizzard's own game data service** serves spells, items, talents, and
encounter definitions. Same authentication shape as above - register a client,
trade the secret for a token. Live, and refuses anonymous callers, so *this is
also gated on registration.*

Its distinguishing feature is that every request carries a namespace that can
name a specific build, so the same spell can be asked about as it existed in two
different patches and will answer differently. That is the only source in this
list that will retroactively tell you what a number *used to be* from the
publisher's own mouth.

## The largest theorycrafting artefact that exists

**SimulationCraft** is an open-source event-driven simulator of the game,
maintained continuously since 2011, and it is the reason this project should not
try to re-write an event simulator from scratch. Two things matter about its
shape:

- Its early history is tagged: 201 release tags running from patch 4.0.3 in
  Cataclysm through patch 8.3.0. Each tag is a frozen, complete statement of how
  every ability in the game worked at that patch, in source code.
- Its modern history is organised as one long-lived branch per expansion -
  Shadowlands, Dragonflight, The War Within, Midnight - plus working branches
  named directly after build numbers.

So the expansion-grouping the viewer is asked for already exists as this
repository's branch structure. It does not have to be invented, it has to be
read.

It also carries, in-tree, the gear profiles and the action priority lists - the
written-down decision procedure for "what should this specialisation press
next". Those priority lists are the closest thing in existence to a machine-
readable record of how players believed the game should be played, versioned by
patch. Getting them costs one clone and then `git log`, with no rate limit and
no terms problem.

## The spreadsheets themselves

The literal request - theorycrafting spreadsheets - almost always means a Google
Sheet that someone shared a link to. Any sheet whose sharing is set to
link-visible can be exported without an account by asking for it in comma-
separated or workbook form; a sheet that is not shared answers "not found"
rather than redirecting to a sign-in, which confirms that anonymous export is
permitted and that only the sheet's own permissions gate it.

The difficulty is not fetching. It is **discovery**. There is no index of
theorycrafting spreadsheets. Their identifiers are passed around in Discord
servers, forum posts, and class guides. Any harvester that wants them must first
harvest *links to them* from places that talk about them, and the quality of the
whole spreadsheet arm of this project depends entirely on how good that
link-harvesting is.

## Ordinary open interfaces

**Raider.IO** answers without any account and publishes the structure of every
competitive season - which dungeons, which modifiers, when each season started
in each region. That is a second, independent time axis that can be cross-checked
against the build dates, and a cheap way to know what content was current.

## What is deliberately not being scraped

**Wowhead** is the obvious place to look and is the wrong place to go. Its terms
forbid automated collection, it sits behind a challenge layer that will refuse a
script, and a first request already answers with a redirect rather than content.

More to the point, it is not a primary source. The spell and item data it
displays is extracted from the same client database tables that wago.tools
serves openly, and the fight statistics it shows are derived from the same
uploaded combat logs that Warcraft Logs serves through an official interface.
Both of its ingredients are available upstream, without a fight and without
breaking anyone's terms. Going to the source is both more polite and more
complete.

The vision note records the asker's line, "I bet wowhead knew" - they did, and
this is where they knew it from.
