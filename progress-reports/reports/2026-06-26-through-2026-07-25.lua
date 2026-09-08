-- Part 7: 26 June through 25 July 2026.

return {

  part = 7,
  slug_name = "the-metal-and-the-ember",
  title = "The Metal and the Ember",
  eyebrow = "Part 7 · 26 June – 25 July 2026",
  compiled = "compiled 6 Sep 2026",
  dek = "The handheld's storage controllers come up on real silicon and its flash "
    .. "reads ten times faster with the bytes proven identical. Three weeks later "
    .. "an animation studio is built from nothing in three days, and proves its "
    .. "own parallelism the same way.",

  totals = {
    { value = "198", label = "issues written" },
    { value = "41", label = "completed" },
    { value = "8", label = "projects" },
  },

  -- {{{ days
  days = {
    { label = "26", value = 15, emphasis = true, month = "June" },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "29", value = 6 },
    { label = "30", value = 3 },
    { label = "01", value = 7 },
    { label = "02", value = 3 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "07", value = 1 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "14", value = 1 },
    { label = "15", value = 1 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "",   value = 0 },
    { label = "21", value = 3 },
    { label = "22", value = 5 },
    { label = "23", value = 8, emphasis = true },
    { label = "24", value = 7, emphasis = true },
    { label = "25", value = 17, emphasis = true, month = "July" },
  },
  chart_alt = "Commits per day from 26 June to 25 July 2026: a cluster of 15, 6, 3, "
    .. "7 and 3 at the start, then seventeen near-silent days carrying one commit "
    .. "each on the 7th, 14th and 15th, then a rising run of 3, 5, 8, 7 and 17.",
  chart_caption = "Commits per day. Two clusters with seventeen quiet days between "
    .. "them. Those quiet days carry three commits, and two of them start projects "
    .. "the second cluster builds.",
  -- }}}

  -- {{{ intro
  intro = {
    { kind = "lead", text = "The window runs 26 June to 25 July. The commit history "
      .. "would cut it in two — there are seventeen near-silent days in the middle — "
      .. "but one of the three commits in that gap starts a project the second half "
      .. "spends four days building, so the cut would separate a founding from its "
      .. "construction." },
    { kind = "p", text = "**26 June to 2 July**: the poetry website's last big push "
      .. "ends with a deploy script, and soren-ds brings up storage, power and "
      .. "lighting on the Anbernic RG DS itself." },
    { kind = "p", text = "**7 to 15 July**: two projects are seeded. A first-person "
      .. "game aimed with two mice, and a USB-C cable that moves data without the far "
      .. "end being able to execute it." },
    { kind = "p", text = "**21 to 25 July**: the game engine's dataflow substrate is "
      .. "built, an animation studio goes from nothing to five of six phases in three "
      .. "days, and 823 files of working transcripts are filed under readable names." },
  },
  -- }}}

  work_caption = "Issue files, 26 June – 25 July",
  -- {{{ work
  work = {
    { name = "games/first-person-spellcraft", commits = 94, added = 3,  removed = 0 },
    { name = "gif-generator",                 commits = 33, added = 23, removed = 0 },
    { name = "roms",                          commits = 21, added = 0,  removed = 0 },
    { name = "soren-ds",                      commits = 13, added = 7,  removed = 0 },
    { name = "usb-c-universal-encoder",       commits = 12, added = 2,  removed = 0 },
    { name = "neocities-modernization",       commits = 9,  added = 4,  removed = 0 },
    { name = "delta-version",                 commits = 4,  added = 1,  removed = 0 },
    { name = "scripts",                       commits = 3,  added = 1,  removed = 0 },
  },
  -- }}}
  work_note = {
    { kind = "p", text = "Columns are issue files written and completed. The "
      .. "first-person game writes 94 and completes 3: its substrate was built "
      .. "against two of them while the other ninety-one describe the game that "
      .. "substrate is for." },
  },

  projects_caption = "What happened",
  projects = {

    -- {{{ soren-ds
    {
      id = "soren", name = "soren-ds", short = "soren-ds",
      commits = 13, slug = "13 issues written, 7 completed",
      identity = "Storage, power and light brought up on the device, and a discipline "
        .. "about leaving hardware as you found it.",
      stats = {
        { key = "Flash read", value = "1 → 8", note = "bit" },
        { key = "Clock", value = "24 → 200", note = "MHz" },
        { key = "Power rails", value = "9", note = "addressable" },
        { key = "Bring-ups confirmed", value = "6" },
      },
      blocks = {
        { kind = "p", text = "**Bringing a block up** means writing the registers that "
          .. "turn its clock on, release it from reset and configure it, then proving "
          .. "on the actual hardware that it does what the manual says. Every item "
          .. "here was confirmed on the device." },

        { kind = "findings", items = {
          "**The internal flash climbed its whole speed ladder.** It had been read one "
            .. "bit wide at 24 MHz; it now reads eight bits wide at 200 MHz, and then "
            .. "in a double-rate mode sampling on the strobe the card itself returns.",
          "**The power chip can now be written to as well as read from**, and its nine "
            .. "voltage rails set by millivolt. Proved without disturbing anything "
            .. "live: read a safe register, write a marker, read it back, restore it — "
            .. "and separately, program a rail to the voltage it is already at.",
          "**A read-only look at the clock tree turned up that the cores already run "
            .. "near a gigahertz.** The device's slowness is the caches being switched "
            .. "off, not the clock speed.",
          "**The slow whole-disk safety copy came out of the boot path**, where it had "
            .. "been grinding for minutes on every boot. It is now an off-by-default "
            .. "diagnostic copying just the bootloader region rather than a blind 200 "
            .. "megabytes.",
        } },

        { kind = "thread", name = "Proof by identity",
          text = "The bytes were proven identical at every rung: **a fingerprint of a "
            .. "known non-zero block, taken at all three speeds, matching every "
            .. "time** — with the controller's error flag now actually inspected, so a "
            .. "corrupt fast read can no longer masquerade as a clean one. This is the "
            .. "first appearance of a technique four projects use within six weeks: "
            .. "prove a change correct by running both versions and comparing the "
            .. "output, rather than by measuring that the new one is faster." },

        { kind = "h", text = "1–2 July · putting things back as you found them" },

        { kind = "pull", text = "A diagnostic that ungated a clock or released a reset "
          .. "used to leave it that way, so each probe inherited the previous one's "
          .. "leftovers and the kernel booted on through a hardware state nothing had "
          .. "asked for." },

        { kind = "p", text = "Every diagnostic now brackets its own writes: it "
          .. "snapshots each register before touching it and writes **that exact "
          .. "value** back on the way out — not a fixed reset value, the state it "
          .. "actually found. A diagnostic running after a legitimate bring-up hands "
          .. "the block back still running. All the restores funnel through one place, "
          .. "**because the clock-tree registers need a write-enable mask set or the "
          .. "restore silently does nothing.**" },

        { kind = "findings", items = {
          "**The new arrival check immediately caught itself being wrong.** The "
            .. "display probe declared the wrong power-on values for that block's "
            .. "clock-gate and reset registers — it assumed the block resets gated and "
            .. "held, while the manufacturer's own tables show both reset to all-zero. "
            .. "On a clean boot it reported *not at default* when the registers were "
            .. "exactly at default.",
          "**A write aimed at the boot partition was aimed at the bootloader.** The "
            .. "address was a placeholder from before the partition layout was known, "
            .. "and a probe reading the device's own partition table showed it pointed "
            .. "at the u-boot region — **where a write drops the device into the "
            .. "hard-brick zone, reachable only through deep recovery.** Repointed at "
            .. "the address the partition table names, so a bad write can only land "
            .. "somewhere restorable by booting from SD.",
          "**A script that wrote to a carry-over drive never flushed it.** It ejected "
            .. "only the SD card it had read from, so nothing guaranteed its writes had "
            .. "left the operating system's cache before the operator pulled the drive "
            .. "out. Its sibling got this for free from unmounting; this one did not.",
        } },

        { kind = "transcripts", project = "soren-ds", items = {
          { file = "jun-16-26-through-jul-1-26.md", label = "16 Jun – 1 Jul" },
          { file = "jun-29-26.md", label = "29 Jun" },
          { file = "jul-1-26.md", label = "1 Jul" },
          { file = "jul-1-26-through-jul-2-26.md", label = "1 Jul – 2 Jul", agents = 2 },
          { file = "jul-2-26-through-jul-3-26.md", label = "2 Jul – 3 Jul", agents = 1 },
          { file = "jul-11-26-through-jul-12-26.md", label = "11 Jul – 12 Jul" },
          { file = "jul-24-26-through-jul-25-26.md", label = "24 Jul – 25 Jul" },
        } },
      },
    },
    -- }}}

    -- {{{ gif-generator
    {
      id = "gif", name = "gif-generator", short = "gif-generator",
      commits = 33, slug = "33 issues written, 23 completed",
      identity = "Nothing to five of six phases in three days, 23 to 25 July.",
      stats = {
        { key = "Phases", value = "5", note = "of 6" },
        { key = "Colours", value = "256" },
        { key = "Speed-up", value = "3.08", note = "× on 4 threads" },
        { key = "Capstone", value = "333,536", note = "bytes, twice" },
      },
      blocks = {
        { kind = "p", text = "A **score** is a flat list of strokes, each one a "
          .. "declarative sentence — *at 0.0 seconds, lasting 2.0, an ember-coloured "
          .. "arc from twelve o'clock to seven, fading in, eased like a brush "
          .. "stroke*. It compiles into a timeline that can answer, for any moment, "
          .. "where every particle source is and how hard it is emitting. Particles "
          .. "drift, age and die; each stamps a small radial glow onto a "
          .. "floating-point light buffer; glows **add**, so where particles crowd, "
          .. "the light saturates toward white." },

        { kind = "findings", items = {
          "**The 256 available colours are spent deliberately rather than sampled.** "
            .. "Seven named hues, each with a ramp whose steps crowd the dark end "
            .. "where a fading tail would otherwise band. Black alone at seat zero, a "
            .. "grey ramp on top for white-hot cores. **Finding a pixel's seat is "
            .. "arithmetic, never a search**: saturation decides whether it is grey, "
            .. "the hue angle picks the ramp, a curve picks the step.",
          "**The GIF89a encoder is written by hand, including its LZW compression**, "
            .. "whose dictionary is kept flat so the hot loop never builds a string.",
          "**The particle pool refuses to grow.** Particles live in flat parallel "
            .. "arrays where the living ones form a solid run at the front; a death is "
            .. "a swap with the last living particle. When a stroke asks for more than "
            .. "its estimate the run stops with an error naming that stroke.",
          "**Fade is computed when asked and never stored**, with the reason written "
            .. "at the loop: stored derived state is state waiting to fall out of step "
            .. "with what it came from.",
        } },

        { kind = "thread", name = "Fallbacks hide bugs", first = 2,
          text = "Silently dropping particles would silently change the picture, so "
            .. "the pool stops the run instead. A misspelled field in a particle-source "
            .. "recipe is refused with the list of legal ones rather than meaning a "
            .. "default. **A picture that is quietly wrong is worse than a run that "
            .. "stops.**" },

        { kind = "pull", text = "The encoder's round-trip test earned its keep on "
          .. "first contact. An independent decoder caught it growing its code width "
          .. "one emission early — a decoder runs one dictionary entry behind, so the "
          .. "bump belongs before the add. That is the kind of off-by-one that "
          .. "corrupts playback in every browser while looking fine from the inside." },

        { kind = "h", text = "The language, and what it refuses" },

        { kind = "p", text = "Score files are read inside a sandbox offering exactly "
          .. "the stroke vocabulary and nothing else, so **a score that tries to "
          .. "compute anything is refused**. That keeps scores comparable line by "
          .. "line and writable by a small language model constrained to a grammar. "
          .. "The compiler refuses everything at once rather than one error per run, "
          .. "and teaches every misspelled word its nearest legal neighbour by edit "
          .. "distance — *ebmer* learns *ember*, *strok* learns *stroke*." },

        { kind = "thread", name = "Proof by identity", first = 7,
          text = "Two capstones, both byte comparisons. The vision written as a score "
            .. "renders through the front door to **the same 333,536 bytes** as the "
            .. "version staged by hand in code. And workers roll no dice while addition "
            .. "commutes, so one worker, three workers and the sequential runner all "
            .. "emit byte-identical files — 4.8 seconds by one hand and 1.6 by four, "
            .. "**with the proof of parallelism being an identity rather than a "
            .. "benchmark.**" },

        { kind = "p", text = "Two honest fixes made the first of those possible: two "
          .. "independent pieces of trigonometry differed in their last bits, and a "
          .. "frame count was being rounded down where floating-point had shaved 4.6 "
          .. "times 25 to 114.999." },

        { kind = "transcripts", project = "gif-generator", items = {
          { file = "jul-24-26-through-jul-25-26.md", label = "24 Jul – 25 Jul" },
        } },
      },
    },
    -- }}}

    -- {{{ spellcraft
    {
      id = "spellcraft", name = "games/first-person-spellcraft", short = "spellcraft",
      commits = 94, slug = "94 issues written, 3 completed",
      identity = "The dataflow substrate, built headless and proven before any window "
        .. "existed to draw into.",
      blocks = {
        { kind = "p", text = "Two mice are read as separate devices, each driving one "
          .. "animated hand on a wand, and **the geometry between the two grips is the "
          .. "aim direction**. That aim becomes a source-agnostic state the spell "
          .. "system, renderer and computer-controlled characters all read without "
          .. "knowing a mouse existed." },
        { kind = "findings", items = {
          "**Three shapes of buffer carry values between units of work**, each a "
            .. "thread-safe fixed-cell ring: one a reader drains completely, one where "
            .. "the latest value wins and the whole structure is copied under a lock so "
            .. "it can never be read half-written, and one handing out increasing index "
            .. "numbers atomically.",
          "**A unit of work can put itself back on the queue**, which is how the frame "
            .. "heartbeat and any looping work keep going without a scheduler that "
            .. "knows about either.",
          "**The rule that turns the graph is made race-safe by two mechanisms**: a "
            .. "gate allowing one attempt at a unit in flight at a time, and a "
            .. "clear-then-recheck closing the window where a wake-up could arrive "
            .. "between a unit deciding it has nothing to do and going to sleep.",
        } },
        { kind = "thread", name = "Proof by identity", first = 7,
          text = "Random position changes are pushed through the real pipeline, "
            .. "drained, and summed into a position — then compared against an "
            .. "authoritative total computed separately. **The two can only agree if "
            .. "nothing was lost, duplicated or read half-written across any "
            .. "interleaving of the threads.** It held 40 times out of 40 under "
            .. "repeated stress." },
        { kind = "p", text = "**The one thread that is not a unit of work is the "
          .. "renderer**, because a graphics context belongs to a single thread: a "
          .. "dedicated never-blocked drawer owns it, reads the latest thing to draw, "
          .. "and is content to lag the workers by a frame or two. One practical thing "
          .. "was learned and written down — the memory-backed scratch storage is "
          .. "mounted with execution forbidden, so the binary builds into the other "
          .. "temporary tier instead." },

        { kind = "transcripts", project = "games/first-person-spellcraft", items = {
          { file = "jul-7-26.md", label = "7 Jul" },
          { file = "jul-21-26-through-jul-22-26.md", label = "21 Jul – 22 Jul", agents = 1 },
        } },
      },
    },
    -- }}}

    -- {{{ the record
    {
      id = "record", name = "the transcript filing", short = "the record",
      commits = 7, slug = "7 issues written, 2 completed",
      identity = "823 files filed under readable names, and the naming given one "
        .. "owner.",
      blocks = {
        { kind = "p", text = "Every project keeps its own folder of working "
          .. "transcripts, so reading the collection's history meant visiting a dozen "
          .. "folders and interleaving their dates in your head — and the files were "
          .. "named after opaque session identifiers. A script now rebuilds a shelf of "
          .. "symbolic links named with sortable date prefixes, so a plain directory "
          .. "listing reads as the storyline from beginning to end, with sessions from "
          .. "different projects interleaving on the days they overlapped. **It only "
          .. "ever deletes its own symbolic links, and halts if it finds anything else "
          .. "in the directory.**" },
        { kind = "thread", name = "One owner for the shared thing", first = 4,
          text = "File names were always a projection of the session log, re-derived "
            .. "after every reply — and a separate one-shot renaming tool had been "
            .. "sharing the job, **so its renames were reverted on the next reply**. "
            .. "The exporter became the single naming authority and the other tool was "
            .. "retired. The same trap was found waiting in a ticket that had not been "
            .. "built yet." },
        { kind = "findings", items = {
          "**A race guard, because the hook and the log are siblings rather than a "
            .. "sequence.** The export runs after a reply and the log's final write "
            .. "happens independently, so the exporter could read a conversation before "
            .. "its last reply landed and produce a transcript ending on an unanswered "
            .. "question. The parser now recognises that shape, waits, and re-reads a "
            .. "few bounded times before surrendering loudly.",
          "**The line-wrapping rule caught the wrong things and missed the fragile "
            .. "ones.** It exempted any line starting with a dash or asterisk — a net "
            .. "cast for bullets that also caught every paragraph opening in bold — "
            .. "while code fences and table rows, the two shapes that genuinely break "
            .. "when wrapped, had no protection at all. Rewritten with the distinction "
            .. "stated: **prose wraps, structure passes through.**",
        } },

        { kind = "transcripts", project = "delta-version", items = {
          { file = "jul-24-26-through-jul-25-26.md", label = "24 Jul – 25 Jul" },
          { file = "jul-25-26-through-jul-26-26.md", label = "25 Jul – 26 Jul" },
        } },
      },
    },
    -- }}}

  },

  -- {{{ open
  open = {
    { project = "gif-generator", state = "Waiting on hardware", tone = "open",
      waiting = "The last phase turns spoken prose into scores using small models "
        .. "running locally, with a grammar generated from the same vocabulary tables "
        .. "the validator uses so **misspelling is physically impossible**. "
        .. "Everything provable without those machines is built. What remains is a "
        .. "network adapter for the day they exist." },
    { project = "games/first-person-spellcraft", state = "Debug view only", tone = "open",
      waiting = "The world is drawn top-down as a debug view and a stand-in player "
        .. "wanders it bouncing off solid tiles. **The first-person renderer the game "
        .. "is named for does not exist**, and 91 of its 94 new issue files describe "
        .. "the game rather than the substrate." },
    { project = "soren-ds", state = "Guarded", tone = "blocked",
      waiting = "The writer that puts a boot image onto internal flash now points at "
        .. "the right partition but **stays dormant and uncalled**: it needs an A/B "
        .. "slot scheme and a boot-success flag before it is safe to enable." },
    { project = "usb-c-universal-encoder", state = "Designed", tone = "open",
      waiting = "Mounting a connected peer as a folder, and a cable-as-courier "
        .. "storage model that fills newest-first and evicts oldest when two slots "
        .. "overflow their union. Both written down, neither built." },
  },
  -- }}}

  -- {{{ tree
  tree = {
    { kind = "p", text = "The transcript filing is one commit of 823 files whose "
      .. "message is written in the voice of somebody tidying a child's room. Nearly "
      .. "every changed file in it is a rename from an opaque identifier to a date." },
  },
  -- }}}
}
