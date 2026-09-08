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

They are generated. The words live in exactly one place — `reports/<window>.lua`
— and everything else falls out of it:

| File | What it is |
| --- | --- |
| `reports/<window>.lua` | **The report.** A plain data table: totals, per-day commit counts, a section per project, patterns, what is open. This is the only file to edit. |
| `index.html` | Generated. The front door: every report, newest first. |
| `<window>.html` | Generated. A standalone styled page. **This is the deliverable.** |
| `<window>.md` | Generated. The same report flattened for a terminal. |
| `artifact/<window>.html` | Generated. The same page with its outer document wrapper removed, for a hosting service that supplies its own. Only needed if a report is also published to a link. |
| `build-reports.lua` | The program that turns the first into all the others. |

To rebuild everything after an edit:

    luajit build-reports.lua

It takes an optional argument overriding the directory it works in; with no
argument it uses the hard-coded path at the top of the file. It rewrites every
output for every data file in `reports/`, regenerates the index, and prints each
path it wrote.

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

## Writing a report

Prose is written as ordinary strings with Markdown's emphasis marks — `**bold**`
and `*italic*` — because Markdown is one of the outputs and passes them through
untouched, while the HTML output converts them to tags.

A project section is a list of **blocks**, and there are six kinds:

| Kind | What it is for |
| --- | --- |
| `p` | An ordinary paragraph. |
| `lead` | A paragraph set larger, for the opening of a section. |
| `h` | A small heading inside a project. |
| `entry` | A dated paragraph. Carries a `when` field. |
| `pull` | One sentence set large against a rule, where it carries the section. |
| `findings` | A list of discoveries. Carries an `items` array. |

Anything that seemed to want a seventh kind has so far turned out to be one of
these wearing a different name.

## Existing reports

| Window | Title | Covers |
| --- | --- | --- |
| 3 Sep – 14 Dec 2025 | The First Fourteen Weeks | The project's beginning, **reconstructed from file timestamps** because no commits exist for it. One afternoon of Lua grows into twenty-four projects, and the repository is specified eight days before it exists. |
| 15 Dec 2025 – 12 Jan 2026 | 29,157 Files | The founding. Forty projects enter version control in one commit of 10.9 million lines, and within two days the repository builds tools to split its own work and hand out the pieces. |
| 17 Jan – 24 Feb 2026 | A Context That No Longer Exists | A poetry website finished, then a nine-day silence after which every tool built points at the repository itself — and 7.4 million lines of vendored code and generated output leave version control. |
| 13 – 25 Mar 2026 | 167 of 167 | A physics game built to a claimed hundred percent in four days by four parallel teams, and the remediation sprint two days later caused by the parallelism. |
| 12 – 24 Jun 2026 | The Last Visible State | A kernel debugged through two indicator lights, a poetry pipeline that stops reporting success while shipping a broken site, and a count of 180 permanently lost conversations. |
| 26 Jun – 25 Jul 2026 | The Metal and the Ember | A handheld's hardware confirmed on real silicon, three projects seeded in the quiet, then an animation studio built out of glowing particles in three days. |
| 29 Jul – 12 Aug 2026 | First Light, Three Times | A computer with no operating system reads, thinks and speaks on three processor families; three projects started; a fortnight of undocumented work written down. |
| 20 Aug – 1 Sep 2026 | The August Ledger | Nine projects. The maze's generator is condemned by arithmetic, the cube blueprint set completes and checks, the poetry site's neighbour lists are repaired. |

**The series is complete back to the project's beginning.** Nothing in this
collection predates 3 September 2025. Files with older timestamps exist — a
shared notes vault from 2021, vendored libraries reaching back to 2001 — but
they are not this project, and the first report says so and excludes them.

One gap remains inside the series:
two days on the poetry website in early April, a real-time strategy game across
late April, and one day on 19 May planning a vintage-computer operating system —
three small clusters, about 33 commits between them, sitting between *167 of 167*
and *The Last Visible State*. They are three unrelated projects a few days each,
which is why they were passed over; a report covering them would be a report
about a quiet month, and is worth writing on those terms rather than pretending
to a through-line it does not have.

Everything before June is written from commits alone. The June report counts 180
working sessions from those earlier periods as permanently gone, so the earlier
reports are thinner, and each says so where it applies.

When a report is added, removed, or re-cut, three things need updating besides
this table: the neighbouring reports' colophons, which name the stages on either
side of them; the published copy at whatever address the reader already holds;
and the skill, if the work of writing it produced a correction that generalises.
