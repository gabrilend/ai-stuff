-- The essay's opening. Rendered as index.html rather than as a part.
--
-- This file exists so that the things every part would otherwise repeat get
-- said once: what each project is, how any of this was measured, and what the
-- measurement cannot do. A part that needs to name a project names it and moves
-- on, because the reader can look it up here.

return {

  part = 0,
  title = "Nine Parts",
  eyebrow = "A record of one year, September 2025 to September 2026",
  dek = "Twenty-four projects were started in fourteen weeks, put under version "
    .. "control, and worked on for another nine months. This is what happened, in "
    .. "order, in nine parts.",

  -- {{{ blocks
  blocks = {
    { kind = "p", text = "The work is a monorepo of separate projects — games, "
      .. "operating systems, a poetry website, a computer that writes its own "
      .. "software — built by one person and an assistant, in Lua and C, on Linux. "
      .. "Every project follows the same method: the work is written down as "
      .. "numbered **issue files** before it is built, grouped into phases, and "
      .. "moved into a `completed` folder when done. An issue file is a blueprint, "
      .. "not a work log." },
    { kind = "p", text = "**That is why the figures here count issue files rather "
      .. "than commits or lines.** A commit measures where the typing went. An "
      .. "issue file measures what the project decided to build. Across the nine "
      .. "parts, 2,354 issue files were written and 1,013 moved to completed." },

    { kind = "h", text = "How to read this" },
    { kind = "p", text = "Nine parts, in order, forward in time. Each covers a "
      .. "period during which attention stayed on roughly the same set of projects, "
      .. "and each ends with a link to the next. The parts get denser as they go, "
      .. "for a reason given below." },

    { kind = "h", text = "The projects" },
    { kind = "p", text = "Named once here, and referred to by name afterwards. "
      .. "Ordered by when they first appear." },

    { kind = "findings", items = {
      "**neocities-modernization** — a poetry website. Every poem is turned into a "
        .. "vector by a language model, poems are compared by the angle between "
        .. "their vectors, and the reader moves sideways from one poem to a related "
        .. "one. Runs through all nine parts.",
      "**words-pdf** — lays the same corpus of poetry out as a printable book, with "
        .. "generated artwork whose parameters come from the poems' vectors.",
      "**handheld-office** — a text editor styled after a Game Boy Advance SP, with "
        .. "hierarchical input and networked assistance, for Anbernic handhelds.",
      "**world-edit-to-execute** — reads Warcraft III custom map files and runs what "
        .. "is inside them, without the original game.",
      "**delta-version** — the meta-project that manages the repository itself: "
        .. "project discovery, history reconstruction, gitignore unification, "
        .. "cross-project coordination.",
      "**scripts** — tooling shared by every project. Commit gates, transcript "
        .. "export, the memory sandbox.",
      "**games/physics-sim** — a pachinko machine. Balls fall through pegs into "
        .. "scoring zones, in C, with ball updates spread across worker threads.",
      "**ut2k4-symbeline-rumble** — a mod for Unreal Tournament 2004, concerned with "
        .. "hiding level geometry the player should not be able to see.",
      "**apple-IIds** — putting a modern operating system on Apple IIgs hardware by "
        .. "patching the original system's disk image rather than rebuilding it.",
      "**games/3d-rts** — a real-time strategy game with heightmap terrain, unit "
        .. "movement on a task pool, and box selection.",
      "**soren-ds** — an operating system for the Anbernic RG DS, a dual-touchscreen "
        .. "ARM handheld. A small C kernel below the waterline; above it, every "
        .. "program is a dataflow graph where a unit of work fires when all its "
        .. "inputs are ready.",
      "**gif-generator** — turns a written description of motion into an animated "
        .. "GIF. No image model: every pixel is the arithmetic consequence of a "
        .. "particle that was somewhere, glowing.",
      "**games/first-person-spellcraft** — a first-person game aimed with two "
        .. "separate mice, one per hand on a wand, built in C as a dataflow machine.",
      "**usb-c-universal-encoder** — moves arbitrary data over a USB-C cable, where "
        .. "the receiving end runs a bytecode interpreter that only stores and "
        .. "manages data, so arriving bytes can never become instructions.",
      "**every-software-image-able** — a memory card carrying a language model, an "
        .. "engine written in assembly for three processor families, and an "
        .. "instruction to build every piece of software it can fit on the drive. No "
        .. "operating system and no compiler on the card.",
      "**3d-generation-multiplayer-server** — an open-source game server cloned "
        .. "fresh on every build and never committed, with our own C client speaking "
        .. "the real wire protocol against it.",
      "**dominions-interpreter** — plays a turn of Dominions 6 by talking about it, "
        .. "with the moves written into the game's own orders file and resolved by "
        .. "the game's own executable.",
      "**backwards-reader** — reads text against its own grain at three "
        .. "magnifications: lines reversed, sentences reversed, and meaning inverted.",
      "**hero-less-moba** — a lane-pushing war game with the heroes, the jungle and "
        .. "the item shop removed, and three systems built to replace what that "
        .. "removal takes away.",
      "**six-sided-dice-layer-cake** — a computer shaped like a cube, delivered as "
        .. "eighty-four engineering blueprints whose every derivation a program can "
        .. "evaluate.",
      "**kanji-learning-image-generator** — for each Japanese character, a "
        .. "photograph whose light and dark fall exactly where the strokes fall, so "
        .. "the picture *is* the character.",
      "**my-own-custom-vtt** — a shared map for tabletop roleplaying where a wall is "
        .. "a line segment with coordinates, so the server can refuse to send a "
        .. "player what they cannot see.",
      "**jurassic-maze** — a field of stacked stone drawn corner-on, with "
        .. "increasingly alive things put inside it: balls, then people, then people "
        .. "with swords, then dinosaurs.",
      "**games/enheim-tome** — a strategy game over one painting of one city, whose "
        .. "only problem is that life in it is rigid. The map is not the city; it is "
        .. "one person's model of the city.",
    } },

    { kind = "h", text = "Where the figures come from, and what they cannot do" },

    { kind = "p", text = "**Parts 2 through 9 are built from git.** The commit "
      .. "messages carry the reasoning, the issue files carry the plan, and from "
      .. "June 2026 onward each project keeps verbatim transcripts of the working "
      .. "conversations. Where a part states a mechanism, it is because somebody "
      .. "wrote the mechanism down." },

    { kind = "p", text = "**Part 1 is built from file modification times**, because "
      .. "the repository does not exist yet. A modification time records when a file "
      .. "was last written, and nothing else — it counts only surviving files, "
      .. "records the last touch rather than the first, is overwritten by any bulk "
      .. "copy, and says nothing about what was done. Part 1 says so again where it "
      .. "matters." },

    { kind = "pull", text = "One hundred and eighty working conversations from before "
      .. "June 2026 were deleted by a session pruner and are not in any backup. Parts "
      .. "1 through 5 are thinner than the later ones for that reason, and Part 6 is "
      .. "where the loss is counted." },

    { kind = "p", text = "**The commit messages change character partway through.** "
      .. "In March 2026 they are changelogs — a subject line and a list of what "
      .. "changed. By June they are prose explaining why a thing was done and what "
      .. "it cost. That is most of why the later parts are longer: the same amount "
      .. "of work leaves a much better record of itself." },

    { kind = "p", text = "Two figures are deliberately absent. **Lines added and "
      .. "removed** appear nowhere, because a repository that vendored 2,349 files "
      .. "of other people's libraries and then removed them again produces line "
      .. "counts in the millions that measure nothing. **Commit counts** appear only "
      .. "in the daily charts, where they measure when somebody was at the keyboard "
      .. "and nothing more." },
  },
  -- }}}

  colophon = "**Sources.** The git history of the repository, each project's issue "
    .. "and phase progress files, and the verbatim transcripts of the working "
    .. "conversations where they survive. Part 1 additionally uses filesystem "
    .. "modification times.\n\n"
    .. "**On the numbers.** Where a figure could be recomputed by a program, that "
    .. "program lives in the project it belongs to and should be run rather than "
    .. "trusted from here. Issue counts exclude the founding commit, which imported "
    .. "existing files rather than writing them.\n\n"
    .. "**These pages are files.** Each part is a standalone HTML page on this disk "
    .. "that opens with no server and no network; the webfonts are the only thing "
    .. "fetched and the type falls back cleanly without them. A plain-text version "
    .. "sits beside each one. They are written by `build-reports.lua` from the data "
    .. "files in `reports/` and should not be edited directly.",
}
