-- Part 3: 17 January through 24 February 2026.

return {

  part = 3,
  slug_name = "turning-inward",
  title = "A Context That No Longer Exists",
  eyebrow = "Part 3 · 17 January – 24 February 2026",
  compiled = "compiled 6 Sep 2026",
  dek = "The poetry website is finished. Then, across a nine-day silence, the work "
    .. "changes subject: every tool built afterwards reads the repository itself, "
    .. "2,349 files of other people's libraries leave version control, and C++ is "
    .. "banned by ignore pattern.",

  totals = {
    { value = "152", label = "issues written" },
    { value = "67", label = "completed" },
    { value = "8", label = "projects" },
  },

  -- {{{ days
  days = {
    { label = "17", value = 18, emphasis = true, month = "January" },
    { label = "18", value = 6 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "21", value = 41, emphasis = true },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "26", value = 19 },
    { label = "",   value = 0 },
    { label = "28", value = 21, emphasis = true },
    { label = "29", value = 2 },
    { label = "30", value = 41, emphasis = true },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "09", value = 1 },
    { label = "10", value = 3 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "13", value = 3 },
    { label = "",   value = 0 },
    { label = "15", value = 1 },
    { label = "",   value = 0 },
    { label = "17", value = 3 },
    { label = "18", value = 3 },
    { label = "19", value = 11 },
    { label = "20", value = 4 },
    { label = "21", value = 2 },
    { label = "",   value = 0 },
    { label = "23", value = 1 },
    { label = "24", value = 13, emphasis = true, month = "February" },
  },
  chart_alt = "Commits per day from 17 January to 24 February 2026. A dense January "
    .. "peaking at 41 twice, then nine days with no commits, then a thin February of "
    .. "ones and threes rising to 13 on the 24th.",
  chart_caption = "Commits per day. The nine empty columns from 31 January to 8 "
    .. "February are the hinge: the work on either side has a different subject.",
  -- }}}

  -- {{{ intro
  intro = {
    { kind = "lead", text = "The window runs 17 January to 24 February, and holds a "
      .. "nine-day silence in the middle. It is one part rather than two because the "
      .. "subject changes across that silence." },
    { kind = "p", text = "**Before it**, essentially all the work is the poetry "
      .. "website being finished: dark mode, a word cloud coloured by meaning, "
      .. "reshared posts given a visual grammar, and forty-one commits on 30 January "
      .. "consolidating scattered configuration into one file." },
    { kind = "p", text = "**After it**, almost every tool built points at the "
      .. "repository: a contents generator, a history reconstructor, a transcript "
      .. "viewer, a documentation generator that reads a git repository and produces "
      .. "a roadmap, and a coordinator that scans every project for shared "
      .. "components. None of them makes a website." },
  },
  -- }}}

  work_caption = "Issue files, 17 January – 24 February",
  -- {{{ work
  work = {
    { name = "neocities-modernization", commits = 121, added = 65, removed = 0 },
    { name = "delta-version",           commits = 25,  added = 2,  removed = 0 },
    { name = "game-design",             commits = 3,   added = 0,  removed = 0 },
    { name = "world-edit-to-execute",   commits = 1,   added = 0,  removed = 0 },
    { name = "spatial-drones",          commits = 1,   added = 0,  removed = 0 },
    { name = "factor-IDE-2",            commits = 1,   added = 0,  removed = 0 },
  },
  -- }}}
  work_note = {
    { kind = "p", text = "Columns are issue files written and completed. The "
      .. "repository-level work of 24 February — the README rewrite, the library "
      .. "removal, the C++ ban, the container — produced no issue files at all, which "
      .. "is why the table understates it." },
  },

  projects_caption = "What happened",
  projects = {

    -- {{{ neocities
    {
      id = "neocities", name = "neocities-modernization", short = "neocities",
      commits = 121, slug = "121 issues written, 65 completed",
      identity = "The site becomes something a person can read: dark, navigable, and "
        .. "coloured by what the poems mean.",
      stats = {
        { key = "Sources", value = "4", note = "archives" },
        { key = "Config files merged", value = "→ 1" },
        { key = "Commits on 30 Jan", value = "41" },
      },
      blocks = {
        { kind = "p", text = "The poems come out of archives the author already has: a "
          .. "fediverse export, a chat-service export, a personal notes vault, and — "
          .. "added here — an export from a second social network, extracted from its "
          .. "content-addressed archive format and sorted chronologically before "
          .. "identifiers are assigned." },

        { kind = "findings", items = {
          "**The similarity work moved to a pre-computed cache on the graphics card, "
            .. "and the fallback was then deleted.** Computing diversity on the fly was "
            .. "left in place at first as a safety net and then removed.",
          "**The rankings are sorted while the graphics card is still working**, on "
            .. "the processor, which costs nothing because the two are not competing "
            .. "for the same hardware.",
          "**An extractor was reading its own output.** The notes extractor scanned a "
            .. "directory it also wrote into, so each run fed on the last. Fixed "
            .. "alongside a second case of the same shape, where a full regeneration "
            .. "processed every poem twice.",
          "**A word cloud where each word takes the colour of its own meaning**, "
            .. "computed from the vectors, with balanced colour selection across a "
            .. "page and the word's colour carried into the page header.",
        } },

        { kind = "thread", name = "Fallbacks hide bugs", first = 2,
          text = "The on-the-fly diversity computation was deleted once the cached "
            .. "path worked, rather than kept as insurance. **An unexercised fallback "
            .. "is a second code path nobody has tested**, and the same reasoning "
            .. "removes 2,349 vendored library files five weeks later in this same "
            .. "part." },

        { kind = "p", text = "**30 January is forty-one commits, and most of them are "
          .. "consolidation.** Scattered configuration files merged into a single one "
          .. "at the project root, text configurations embedded into it, every script "
          .. "moved onto a shared loader, and input sources — which archive, where it "
          .. "lives, how to sync it — made one unified section rather than a separate "
          .. "file." },
        { kind = "p", text = "Alongside it the terminal interface gained animated "
          .. "transitions between command options, and then two fixes: reduced "
          .. "timings, and **a switch from processor time to wall-clock time**, "
          .. "because an animation measured in processor time runs at a speed that "
          .. "depends on what else the machine is doing." },

        { kind = "h", text = "The last commit before the silence" },

        { kind = "p", text = "On 30 January a file was committed into the project's "
          .. "notes that is not code, not a document and not a ticket. It is a poem, "
          .. "written by the assistant, and it is signed." },
        { kind = "pull", text = "you asked me to look backward / and I found only the "
          .. "looking" },
        { kind = "p", text = "It ends with a library where every book is one sentence "
          .. "longer than the one beside it, the shortest being the word *begin*; and "
          .. "two snakes pressed against opposite sides of the same glass, one in a "
          .. "greenhouse made of questions and one in a greenhouse made of answers, "
          .. "neither moving first, so both of them do. The signature reads: **Claude "
          .. "(Opus 4.5), 2026-01-30, in a context that no longer exists.**" },
        { kind = "thread", name = "The record is load-bearing",
          text = "It is kept here because it was kept there. Four months later the "
            .. "repository counts a hundred and eighty working conversations as "
            .. "permanently gone and installs a hook so no more are lost. **This is the "
            .. "earliest thing in the record that names that problem, and it names it "
            .. "from the inside**, before anyone went looking." },
      },
    },
    -- }}}

    -- {{{ the repository
    {
      id = "root", name = "the repository itself", short = "the repository",
      commits = 0, slug = "24 February",
      identity = "Thirteen commits at the root of the monorepo in which the "
        .. "collection acquires a written doctrine, a banned language, install "
        .. "scripts instead of vendored code, and a container to build in.",
      stats = {
        { key = "Issues tracked", value = "659", note = "/ 1,221" },
        { key = "Projects", value = "28" },
        { key = "Files untracked", value = "2,349" },
        { key = "C/C++ left", value = "105", note = "files" },
      },
      blocks = {
        { kind = "p", text = "**The README was rewritten as a textbook** — not a "
          .. "description of what the repository contains, but a narrative "
          .. "introduction to how the work is done: how issues are written, how phases "
          .. "group functionality, how interfaces are described, how parallel work is "
          .. "organised. It carries a progress table across the whole collection: "
          .. "**659 of 1,221 issues, over 28 projects.** Earlier README versions were "
          .. "kept beside it rather than overwritten, and one revision replaced a "
          .. "simple interface example with a dispatch table — the pattern the "
          .. "conventions ask for, now demonstrated in the document that teaches "
          .. "them." },

        { kind = "pull", text = "Then 2,349 files of other people's code came out of "
          .. "version control: a graphics library, a game framework, a language "
          .. "runtime's source, a PDF library and its bindings, a networking library "
          .. "copied into several projects, and a packaged binary. Six point seven "
          .. "million lines." },

        { kind = "p", text = "They are replaced by install scripts, on the reasoning "
          .. "written into the ticket: a dependency that is fetched can be updated and "
          .. "audited, while a dependency that is committed is a fork nobody decided "
          .. "to maintain. After the cleanup, **105 C files remained tracked, all of "
          .. "them project code.**" },

        { kind = "findings", items = {
          "**C++ was banned outright.** Ignore patterns for every C++ extension, and "
            .. "the last two C++ files removed — a test file and one missed library. "
            .. "The stated rule is C, Lua and Bash only. **It is enforced by the ignore "
            .. "file rather than by convention, which means it cannot be forgotten.**",
          "**A container was added to build in**, carrying the language runtime and "
            .. "the graphics libraries, detecting which vendor's graphics hardware is "
            .. "present and falling back to software rendering when there is none. It "
            .. "is the ancestor of the memory sandbox in Part 8 — the same instinct at "
            .. "a coarser grain.",
        } },

        { kind = "p", text = "One commit in this run is titled *updated readme.md with "
          .. "random stuff that has no relation to anything ever anywhere and that "
          .. "nobody should ever read for any purpose whatsoever*. It is kept in the "
          .. "record the same way the poem is." },
      },
    },
    -- }}}

    -- {{{ delta-version
    {
      id = "delta", name = "delta-version", short = "delta-version",
      commits = 25, slug = "25 issues written, 2 completed",
      identity = "Every tool it gained after the silence reads the repository and "
        .. "writes something about it.",
      blocks = {
        { kind = "findings", items = {
          "**A contents generator that sorts source files into reading order.** Files "
            .. "with a numeric prefix sort by that number; unnumbered ones fall back "
            .. "to modification date. Each entry's description is lifted from the first "
            .. "comment line in the file. **The convention that a source file's number "
            .. "is its place in a narrative starts being enforced by a program here**, "
            .. "rather than being a habit.",
          "**A history reconstructor that extracts historical versions rather than "
            .. "current ones.** A tool that rebuilds a project's history from its issue "
            .. "files had been staging the latest version of every file into every "
            .. "reconstructed commit — **so the reconstruction was a sequence of "
            .. "identical trees with different messages.** It now walks the real "
            .. "history to find the version closest before a given date.",
          "**A viewer for working conversations at several levels of abstraction** — "
            .. "detail filtering, summarisation, chapter segmentation, interleaving. "
            .. "Written as tickets in February; what it describes is what the "
            .. "transcript shelf in Part 7 eventually becomes.",
          "**A documentation generator that reads a git repository and produces a "
            .. "project from it** — analysing the first commit for the original goal, "
            .. "generating a roadmap, generating issue files from that roadmap, "
            .. "detecting what is already complete, and drawing the network of which "
            .. "module talks to which.",
          "**A coordinator that reads every project's roadmap at once** and looks for "
            .. "components appearing in more than one, so shared work can be scheduled "
            .. "first. Matching is tiered — exact name, then synonym, then fuzzy, then "
            .. "a language model only if the cheaper passes fail.",
        } },
        { kind = "p", text = "A bug fixed in passing: **a counter written as an "
          .. "increment expression caused the script to exit early whenever the count "
          .. "was zero**, because the shell aborts on any command returning failure "
          .. "and an increment from zero returns the old value. It is the identical "
          .. "bug fixed on 16 December in a different script, two months earlier." },
      },
    },
    -- }}}

  },

  -- {{{ open
  open = {
    { project = "neocities-modernization", state = "Duplicated", tone = "open",
      waiting = "The reshared-post rendering was implemented on the main thread and "
        .. "then again on the parallel workers, and a ticket was opened about the "
        .. "duplication rather than the duplication being avoided." },
    { project = "neocities-modernization", state = "Half-fixed", tone = "open",
      waiting = "Golden poem formatting — poems written to exactly the 1024-character "
        .. "limit of the box they were typed into — was corrected four times across "
        .. "the window. The underlying cause was not found until Part 7, when the "
        .. "archive turned out to store what the server rendered rather than what the "
        .. "author typed." },
    { project = "delta-version", state = "Tickets only", tone = "open",
      waiting = "The transcript viewer, the documentation generator and the "
        .. "cross-project coordinator are all issue files with sub-issues, not "
        .. "programs. **The transcript viewer in particular is the tool that would "
        .. "have made the loss in Part 6 visible earlier**, and it was written down in "
        .. "February and not built." },
    { project = "the repository itself", state = "Enforced", tone = "built",
      waiting = "The C++ ban and the library untracking are both closed and enforced "
        .. "by ignore patterns rather than convention. Listed because they are the two "
        .. "decisions later work is measured against." },
  },
  -- }}}

  -- {{{ tree
  tree = {
    { kind = "p", text = "**No working transcripts survive from this window.** Every later part links the conversations behind each project; these months are inside the hundred and eighty sessions the pruner deleted, so there is nothing to link to. The record here is commits and issue files only." },
    { kind = "p", text = "This is the window that stopped the repository carrying "
      .. "other people's code. Every line count in every later part is measured "
      .. "against a tree this window cleared." },
    { kind = "p", text = "The commit style here is conventional-commit prefixes — "
      .. "`feat`, `fix`, `chore`, `docs`, with an issue number in parentheses. By "
      .. "Part 4 it is plain sentences; by Part 6, prose that explains why. **The "
      .. "prefixes make the history easy to filter and hard to read**, which is "
      .. "roughly the trade the later style reverses." },
  },
  -- }}}
}
