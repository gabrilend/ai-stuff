# 101 - Harvest the build history

| | |
|---|---|
| Phase | 1 - the patch spine |
| Blocked by | nothing; this is the first thing that runs |
| Blocks | every issue that stamps an artefact with a version, which is all of them |
| Source needed | the open build index; no account, no secret |

## Current behaviour

Nothing exists. There is no list of game versions in the project, so there is no
way to say when anything was true.

## Intended behaviour

A single harvest brings back the publisher's complete build history and puts it
in the archive unmodified, with its provenance beside it.

The build history is one document listing, for every product line the publisher
ships, every version ever released and the date it went up. A product line is a
separate history: retail, the public test realms, and each Classic line are
distinct, and the same version number in two lines means two different things.

A version string is four numbers. The first three are the patch a person would
name out loud. The fourth is the build number, and it is the only part that is
both unique and reliably ordered - patches get re-released and shipped out of
sequence across regions, but build numbers only ever increase.

## Suggested implementation steps

1. Add the build index to the source registry as its first entry, with its
   address, the shape it answers in, how often it may politely be asked, and
   its licence state. Until someone reads that licence, the state is unchecked,
   which behaves the same as forbidden - the bytes stay out of the history
   branch.
2. Fetch it through the fetch layer and write the response into the archive
   exactly as received, with a provenance record stating what was asked, of
   whom, when, and what came back.
3. Because the response arrives as one document of roughly half a megabyte and
   the archive wants small specific files, register it with the splitting pass:
   the seam is product line, then year.
4. Write the demonstration that this worked: print how many product lines were
   found, how many builds in each, and the oldest and newest date in the file.
   Those numbers are not to be copied into any document - the demonstration is
   how anyone finds out what they currently are.

## Related documents

- The archive and its branches - why the response gets split and where it lives
- Where the numbers live - what this source is and why it is trusted
