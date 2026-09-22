# Progress reports

Periodic reports on what happened across the projects in this repository, one
per stage of work.

**The method lives in the `progress-report` skill**, not here — how a window's
boundaries are found, what to read and in what order, the house style with its
before-and-after pairs, and the number-honesty rules. This file covers only what
is specific to this directory: the layout, how to rebuild, and what has been
written so far.

## Start here

    index.html

Open it in a browser. It lists every report, newest first, and links to each
one and to its plain-text twin. No server, no network, no account — these are
files on this disk.

## Do not edit the .md or .html files

They are generated. The series is one essay in numbered parts, plus an opening.
The words live in exactly one place — the data files in `reports/` — and
everything else falls out of them:

| File | What it is |
| --- | --- |
| `reports/000-opening.lua` | **The opening** (`part = 0`). Becomes `index.html`. The build stops with `no opening found` if no data file carries `part = 0`. |
| `reports/<first-day>-through-<last-day>.lua` | **One part.** The data file is named by its window; the outputs are named by its part number and slug. This is the only kind of file to edit. |
| `index.html` | Generated from the opening: the essay's front door, linking every part. |
| `part-<N>-<slug_name>.html` | Generated. A standalone styled page. **This is the deliverable.** |
| `part-<N>-<slug_name>.md` | Generated. The same part flattened for a terminal. |
| `artifact/part-<N>-<slug_name>.html` | Generated. The same page with its outer document wrapper removed, for a host that supplies its own. Probably no longer needed: the current publishing tool takes the complete standalone page. Kept until a publish of the full page is confirmed to work. |
| `build-reports.lua` | The program that turns the data files into all the others. |

To rebuild everything after an edit:

    luajit build-reports.lua

It takes an optional argument overriding the directory it works in; with no
argument it uses the hard-coded path at the top of the file. It loads every data
file in `reports/`, orders them by `part`, rewrites every output, regenerates the
index, and prints each path it wrote. Previous and next links between parts are
computed from the part numbers, so they never need editing by hand.

There is exactly one generator. Changing how a report looks means editing
`build-reports.lua`, never writing a second program beside it.

## The pages are files, and a link is an extra

Each report page carries its own stylesheet and its own charts inline. The one
thing it fetches is a webfont stylesheet, and every family behind it has a real
fallback, so a report opened with no network reads correctly in Georgia, Arial
and the system monospace.

A report may **also** be published somewhere with a shareable link. That is worth
doing and it is never a substitute: a report that exists only as a URL is a
report you do not have. If the hosting goes away, everything here still opens.

## Why it is split this way

A progress report exists partly to point out that a fact stored in two places
goes stale in one of them. Keeping a hand-written Markdown copy beside a
hand-written HTML copy would be that mistake, committed inside the document that
names it.

The split is also the rule these projects already follow for data: write the
thing that generates, write the thing that views, and keep them apart. The data
file knows nothing about headings, colours or charts. `build-reports.lua` knows
nothing about what happened in August.

## Writing a part

Prose is written as ordinary strings with Markdown's emphasis marks — `**bold**`,
`*italic*` and `` `code` `` — because Markdown is one of the outputs and passes
them through untouched, while the HTML output converts them to tags.

### The fields of a part

A part's data file returns one table. `build-reports.lua` is the authority; this
list is what it reads today.

| Field | Shape | What it is |
| --- | --- | --- |
| `part` | integer | Its place in the essay. `0` is the opening. Output files are named from this. |
| `slug_name` | string | The dash-separated tail of the output filename. |
| `title` | string | The part's name. |
| `eyebrow` | string | The line above the title: part number and window. |
| `compiled` | string | When it was compiled, and any later correction. |
| `dek` | string | The one-paragraph summary under the title. |
| `totals` | list of `{ value, label }` | The figures under the title. Free-form, because what is worth counting differs by part; issue files written and completed are the usual headline. |
| `days` | list of `{ label, value, month?, emphasis? }` | The per-day chart. `value` is a count; `month` prints once where a month begins; `emphasis` marks a tick. |
| `chart_alt`, `chart_caption` | strings | The chart's text alternative and caption. |
| `intro` | blocks | Why the window's boundaries are where they are. |
| `work_caption`, `work`, `work_note` | string, list of `{ name, commits, added, removed }`, blocks | The work table. In the current parts `added` and `removed` count issue files written and completed, not lines, and the caption says so. |
| `projects_caption`, `projects` | string, list of sections | One section per project; fields below. |
| `patterns` | list of strings, optional | Retired in most parts: recurring observations are now `thread` blocks marked where they happen. |
| `open` | list of `{ project, state, tone, waiting }` | The standalone "what is open" table. `tone` is `blocked`, `open` or `built`. |
| `tree` | blocks | Notes on the working tree at the time of compiling. |
| `colophon` | string, optional | Sources, caveats on the numbers, neighbouring stages in prose. |
| `published_url` | string, optional | The address a copy was published to, so a later re-cut republishes there. The generator ignores it; it is kept here so it has one home. |

A project section carries `id` (the page anchor), `name`, `short` (optional
shorter name), `commits`, `slug` (optional text that replaces the commit count in
the heading when the part measures something else), `identity` (what the project
*is*, for a stranger), `stats` (a list of `{ key, value, note? }`) and `blocks`.

The opening (`part = 0`) carries `title`, `eyebrow`, `dek`, `blocks` and
`colophon`.

### Blocks

Every `blocks` list — in a project, in `intro`, `work_note`, `tree`, or the
opening — is made of these nine kinds:

| Kind | Fields | What it is for |
| --- | --- | --- |
| `p` | `text` | An ordinary paragraph. |
| `lead` | `text` | A paragraph set larger, for the opening of a section. |
| `h` | `text` | A small heading inside a section. |
| `entry` | `when`, `text` | A dated paragraph. |
| `pull` | `text` | One sentence set large against a rule, where it carries the section. |
| `findings` | `items` (strings) | A list of discoveries, each stating its mechanism. |
| `thread` | `name`, `text`, `first?` | A rule the collection learned, marked where it appears. `first` is the part that started it and becomes a link. |
| `transcripts` | `project`, `items` of `{ file, label, agents?, untracked? }` | Links to the working transcripts behind a section, on the forge. |
| `spans` | `from`, `to` (`YYYY-MM`), `caption`, `items` of `{ name, first, last, count }` | Month bars showing when each project was active. Used by the timestamp-reconstructed first part. |

Before adding a tenth kind, check whether it is one of these nine wearing a
different name. Most candidates have been.

## Existing parts

| Part | Window | Title | Covers |
| --- | --- | --- | --- |
| 0 | — | Nine Parts | The opening, and the index page. |
| 1 | 3 Sep – 14 Dec 2025 | The First Fourteen Weeks | The project's beginning, **reconstructed from file timestamps** because no commits exist for it. One afternoon of Lua grows into twenty-four projects, and the repository is specified eight days before it exists. |
| 2 | 15 Dec 2025 – 12 Jan 2026 | 29,157 Files | The founding. Forty projects enter version control in one commit of 10.9 million lines, and within two days the repository builds tools to split its own work and hand out the pieces. |
| 3 | 17 Jan – 24 Feb 2026 | A Context That No Longer Exists | A poetry website finished, then a nine-day silence after which every tool built points at the repository itself — and 7.4 million lines of vendored code and generated output leave version control. |
| 4 | 13 – 25 Mar 2026 | 167 of 167 | A physics game built to a claimed hundred percent in four days by four parallel teams, and the remediation sprint two days later caused by the parallelism. |
| 5 | 6 Apr – 19 May 2026 | Written, Not Built | 171 issue files written and twelve finished. A real-time strategy game reaches a playable phase in three days, then one day in May produces 125 blueprints for a port nobody has started. |
| 6 | 12 – 24 Jun 2026 | Two Indicator Lights | A kernel debugged on a handheld whose only output is two amber lights, a hardware address copied from the wrong chip manual, and 180 working conversations counted as permanently deleted. |
| 7 | 26 Jun – 25 Jul 2026 | The Metal and the Ember | A handheld's hardware confirmed on real silicon, three projects seeded in the quiet, then an animation studio built out of glowing particles in three days. |
| 8 | 29 Jul – 12 Aug 2026 | First Light, Three Times | A computer with no operating system reads, thinks and speaks on three processor families; three projects started; a fortnight of undocumented work written down. |
| 9 | 20 Aug – 1 Sep 2026 | The August Ledger | Nine projects. The maze's generator is condemned by arithmetic, the cube blueprint set completes and checks, the poetry site's neighbour lists are repaired. |

**The series is complete back to the project's beginning.** Nothing in this
collection predates 3 September 2025. Files with older timestamps exist — a
shared notes vault from 2021, vendored libraries reaching back to 2001 — but
they are not this project, and the first part says so and excludes them.

The series ends on 1 September 2026; later work is not yet covered. Whether the
spaces between parts leave commits uncovered is measured rather than asserted:
the coverage check in the `progress-report` skill sums the commits inside every
window and compares the total with the whole history.

Everything before June is written from commits alone. The June report counts 180
working sessions from those earlier periods as permanently gone, so the earlier
reports are thinner, and each says so where it applies.

When a part is added, removed, or re-cut, three things need updating besides
this table: any prose in the neighbouring parts' colophons that names the stages
on either side (the previous and next links themselves are generated); the
published copy, at the address recorded in the part's `published_url`; and the
skill, if the work of writing it produced a correction that generalises —
proposed to the owner rather than applied on the spot.
