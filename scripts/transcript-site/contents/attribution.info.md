# attribution.lua

Part of the table of contents. Decides which conversation made each commit,
by evidence, and folds the commits into groups. Reads no transcript: the
builder hands it the evidence.

## Public functions

- `attribute(commits, evidence, rules)` — sets on each commit
  `conversation` (string, a transcript key, or nil), `anchor` (string, the
  id of the line it lands on, or nil) and `how` (string, the rule's name, or
  nil). `rules` is a list of rule names, tried in order. Raises on a name it
  does not know.
- `group(commits) -> list` — consecutive commits with the same conversation
  (or none) as one group: `{ conversation, commits }`.
- `check_rules(rules)` — the refusal alone.
- `DEFAULT_RULES` — `{ "recorded", "subject", "saved" }`.

## The evidence table

| field | type | what it is |
| --- | --- | --- |
| `by_hash` | seven hex digits → `{ key, anchor, hash }` | the commit lines transcripts hold; the first transcript in name order wins a hash recorded twice |
| `by_subject` | subject → list of `{ key, anchor }` | the same lines, by subject |
| `parent_of` | helper's transcript path → its parent's | a helper's transcript stands for its parent's |
| `is_main` | transcript path → boolean | false for a helper (session id begins `agent-`) |

## The rules

| rule | the commit belongs to | lands on |
| --- | --- | --- |
| `recorded` | the transcript holding a `*[commit] <hash>...*` line for its source | that line |
| `subject` | the one transcript recording a commit with the same subject (history rewritten, hash moved) | that line |
| `saved` | the one main conversation whose transcript it touched | the page's top |

double-diaper-dungeon uses `recorded` alone, which is all it ever did.

## Why evidence

An earlier rule gave a run of commits to whatever transcript the run's last
commit touched. It clumped commits by "since a transcript was last saved",
hung one project's first 220 commits off a one-turn transcript after a bulk
import, and broke when the archive was re-dated. Groups are consecutive,
not merged, so two sessions running side by side show as taking turns.
