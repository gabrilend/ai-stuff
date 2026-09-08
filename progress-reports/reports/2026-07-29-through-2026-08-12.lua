-- Part 8: 29 July through 12 August 2026.

return {

  part = 8,
  slug_name = "first-light-three-times",
  title = "First Light, Three Times",
  eyebrow = "Part 8 · 29 July – 12 August 2026",
  compiled = "compiled 6 Sep 2026",
  dek = "A computer with no operating system finds its own weights, divides 5,312 "
    .. "bytes of memory, and says six words — the same six the readable version "
    .. "says from the same input. Then it does it on two more processor families.",

  totals = {
    { value = "106", label = "issues written" },
    { value = "33", label = "completed" },
    { value = "14", label = "projects" },
  },

  -- {{{ days
  days = {
    { label = "29", value = 1, month = "July" },
    { label = "30", value = 0 },
    { label = "31", value = 4 },
    { label = "01", value = 20, emphasis = true },
    { label = "02", value = 43, emphasis = true },
    { label = "03", value = 11 },
    { label = "04", value = 31, emphasis = true },
    { label = "05", value = 1 },
    { label = "06", value = 0 },
    { label = "07", value = 2, emphasis = true },
    { label = "08", value = 0 },
    { label = "09", value = 4 },
    { label = "10", value = 0 },
    { label = "11", value = 0 },
    { label = "12", value = 4, month = "August" },
  },
  chart_alt = "Commits per day from 29 July to 12 August 2026, peaking at 43 on "
    .. "2 August and 31 on 4 August, with five days of no commits.",
  chart_caption = "Commits per day. The 1st through the 4th carry 94 of the 121. The "
    .. "two commits on the 7th are the ones where the machine speaks.",
  -- }}}

  -- {{{ intro
  intro = {
    { kind = "lead", text = "The window runs 29 July to 12 August. Three days of "
      .. "silence before it, seven after." },
    { kind = "p", text = "**every-software-image-able takes 50 of the window's 106 new "
      .. "issue files and 32 of its 33 completions.** It goes from a written plan to "
      .. "a machine that starts on bare hardware and produces words, on three "
      .. "processor families, in four days. Everything else here is a project being "
      .. "started, or the written record catching up with code that already existed." },
  },
  -- }}}

  work_caption = "Issue files, 29 July – 12 August",
  -- {{{ work
  work = {
    { name = "every-software-image-able",        commits = 50, added = 32, removed = 0 },
    { name = "soren-ds",                         commits = 32, added = 0,  removed = 0 },
    { name = "dominions-interpreter",            commits = 9,  added = 0,  removed = 0 },
    { name = "scripts",                          commits = 5,  added = 0,  removed = 0 },
    { name = "neocities-modernization",          commits = 5,  added = 0,  removed = 0 },
    { name = "screen-record-stream",             commits = 4,  added = 1,  removed = 0 },
    { name = "3d-generation-multiplayer-server", commits = 1,  added = 0,  removed = 0 },
  },
  -- }}}
  work_note = {
    { kind = "p", text = "Columns are issue files written and completed. Only one "
      .. "project completes anything this window; the rest are writing down work "
      .. "rather than closing it." },
  },

  projects_caption = "What happened",
  projects = {

    -- {{{ every-software-image-able
    {
      id = "seed", name = "every-software-image-able", short = "every-software-image",
      commits = 50, slug = "50 issues written, 32 completed",
      identity = "Five phases close in four days, and the machine speaks.",
      stats = {
        { key = "Phases closed", value = "5", note = "in 4 days" },
        { key = "Architectures", value = "3" },
        { key = "Tensors found", value = "22" },
        { key = "Memory divided", value = "5,312", note = "bytes" },
        { key = "Words said", value = "6" },
      },
      blocks = {
        { kind = "p", text = "**How correctness is established here, because "
          .. "everything else depends on it.** Every routine exists twice: once in "
          .. "assembly, and once as a *readable twin* — the same computation written "
          .. "plainly in an ordinary language, slow and obviously correct. The "
          .. "assembly must produce the identical answer, bit for bit, with no "
          .. "allowance for being close." },

        { kind = "thread", name = "Proof by identity", first = 7,
          text = "Where two versions are genuinely allowed to differ — the exact "
            .. "arithmetic and the fast arithmetic below — **the size of the permitted "
            .. "gap is derived from what reordering can do to the last digits, rather "
            .. "than chosen by hand**, because a hand-picked tolerance turns every "
            .. "future disagreement into an argument about whether a number is small "
            .. "enough." },

        { kind = "h", text = "1 August · the plan, and somewhere to fail" },

        { kind = "p", text = "The design is argued out and written down: what the "
          .. "machine is handed at power-on, in what order it builds its own floor, "
          .. "and the decision the rest turns on — **that it fills itself out "
          .. "completely before it answers anything.** The instruction on the card is "
          .. "not a job description for a machine sitting at a prompt; it is the first "
          .. "thing that happens, on an empty drive, unprompted." },
        { kind = "p", text = "Alongside it, the test rig: six emulated boards across "
          .. "three architectures, devices that can be permanently destroyed by "
          .. "software the way real ones can, and tripwires on the specific hardware "
          .. "registers where one wrong write kills a chip. Twenty boards were run "
          .. "differing only in their random seed, which is how you find out whether a "
          .. "result was the design or the luck." },

        { kind = "h", text = "2 August · five phases in one day" },

        { kind = "p", text = "Forty-three commits. The first architecture's engine "
          .. "finished and measured whole: the packed model file, the routine that "
          .. "locates the weights inside it with no loader, the matrix arithmetic, the "
          .. "scheduling that runs the layers in order, the step that picks the next "
          .. "word, and the tokenizer that turns text into the numbers the model works "
          .. "in and back. Then the hands — the machine can be asked something and "
          .. "answer, can be heard, can reach memory and storage and devices, can "
          .. "report its condition on hardware that cannot render letters, and can run "
          .. "code it just wrote and be stopped when that code will not stop." },

        { kind = "h", text = "The two pieces whose failures are quietest" },

        { kind = "findings", items = {
          "**The tokenizer's encoding step is an ordering problem.** It starts from "
            .. "single bytes and repeatedly joins whichever adjacent pair has the "
            .. "strongest merge rule. Joining a weaker pair first can make a stronger "
            .. "one impossible, so the result differs from what the model was trained "
            .. "on — and that failure does not announce itself. **It produces a machine "
            .. "that is slightly worse at everything for no visible reason.** The test "
            .. "is therefore almost entirely awkward cases: newlines, runs of spaces, "
            .. "bytes above 127, the empty string, and sixteen round trips including "
            .. "every byte there is and a null in the middle of a string.",
          "**Two checks a round trip cannot make** were added beside it: that merging "
            .. "shortens anything at all, since a tokenizer that does nothing "
            .. "round-trips perfectly, and that the strongest rule really is applied "
            .. "first.",
          "**The word-choosing step is weighted chance, and the randomness is baked "
            .. "into the image.** Each number is stretched across four thousand draws, "
            .. "so the same card with the same input produces the same machine — which "
            .. "turns a strange failure into something reproducible by handing "
            .. "somebody a card.",
        } },

        { kind = "h", text = "The screen, and what it turned up" },

        { kind = "p", text = "On a board with no console the screen is the earliest "
          .. "diagnostic, so the machine learned to draw before anything else, and "
          .. "**the test reads the pixels back rather than trusting the call "
          .. "returned**. A computer with no operating system wrote *first light, "
          .. "drawn* into text memory; the emulator was photographed from outside and "
          .. "the picture turned back into text — two hundred and eighty green cells "
          .. "against nineteen grey." },
        { kind = "pull", text = "Which turned up the most consequential thing in a "
          .. "while. The plain block of screen memory the whole design leans on — an "
          .. "address and a geometry handed over, so a machine can draw from its first "
          .. "instant with no driver — is UEFI's handover and nothing else's. A "
          .. "BIOS-style board offers text memory instead, which is characters rather "
          .. "than pixels. A board with no firmware offers nothing until a driver "
          .. "exists." },

        { kind = "h", text = "3–4 August · the second and third architectures" },

        { kind = "p", text = "The same engine written twice more. The plain arithmetic "
          .. "ports almost mechanically; the fast version does not, because the three "
          .. "families' vector instruction sets have nothing in common and one may not "
          .. "have vectors at all. **The fast version is held to the identical answer "
          .. "over a whole pass through the model, not merely per call**, because one "
          .. "bit of difference compounds through every tensor and every layer before "
          .. "it reaches a score. All three produced the same 192 scores, bit for "
          .. "bit." },

        { kind = "findings", items = {
          "**Giving up a fixed order of addition was worth 4.48 times the speed, and "
            .. "the reason is not what it looks like.** The exact version folds every "
            .. "group of four products into one running total in order, which makes "
            .. "every addition wait for the one before it. Measured: one at a time is "
            .. "the floor, keeping the order buys 1.15 times, letting it go buys 5.16. "
            .. "**The dependency chain was the real cost, not the arithmetic.**",
          "**The second architecture was right all along; the tool measuring it was "
            .. "not.** A measurement condemning the second engine turned out to be the "
            .. "measuring program's fault — which is what the readable twin is for. "
            .. "Without one, a correct engine would have been rewritten to match a "
            .. "broken ruler.",
          "**Refuse to hand a machine test data that is all the same number.** The "
            .. "payload builder counts distinct values in every block it writes and "
            .. "refuses one that is mostly repeats, because a defect that only shows on "
            .. "varied input is invisible against a page of identical bytes.",
          "**When two implementations disagree, carry the first disagreement home, "
            .. "not just the count.** A test reporting *142 mismatches* sends you "
            .. "hunting; one reporting the first index and both values usually ends the "
            .. "hunt.",
        } },

        { kind = "h", text = "7 August · it reads, thinks, and speaks" },

        { kind = "p", text = "An emulated board with no operating system found its "
          .. "twenty-two tensors, divided five thousand three hundred and twelve bytes "
          .. "of memory, wrote down where all of it was, built its word tables out of "
          .. "lists carried inside its own model file, readied the randomness baked "
          .. "into it, and said six words — the same six, in the same order, that the "
          .. "readable version says from the same starting text." },
        { kind = "p", text = "Two things had to be written that nobody had listed. The "
          .. "word tables had been built with string comparison on the development "
          .. "machine, and the engine's thinking half was deliberately written never "
          .. "to touch a string precisely so something else would pay that cost once "
          .. "at startup — and nobody had written the something else. And the loop "
          .. "reaches every routine through a pointer held in a table rather than "
          .. "calling by name, because there is no linker: **a call written by name is "
          .. "a note left for a linker that never arrives, a dropped note leaves a "
          .. "zero behind, and a call to address zero is a call to itself.**" },

        { kind = "pull", text = "The test fixture had carried, from the beginning, a "
          .. "word list that no implementation could turn into a lookup table — "
          .. "placeholder names, and merge rules joining text no token held. It "
          .. "round-tripped cleanly. The tokenizer passed seventeen checks. Neither "
          .. "noticed, because the tokenizer's tests build their own vocabulary in "
          .. "memory and never ask the model file for one." },

        { kind = "transcripts", project = "every-software-image-able", items = {
          { file = "jul-31-26-through-aug-2-26.md", label = "31 Jul – 2 Aug" },
          { file = "aug-2-26.md", label = "2 Aug" },
          { file = "aug-2-26-through-aug-3-26.md", label = "2 Aug – 3 Aug" },
          { file = "aug-3-26-through-aug-5-26.md", label = "3 Aug – 5 Aug" },
          { file = "aug-7-26.md", label = "7 Aug" },
          { file = "aug-8-26-through-aug-9-26.md", label = "8 Aug – 9 Aug" },
        } },
      },
    },
    -- }}}

    -- {{{ starts
    {
      id = "starts", name = "three projects begin", short = "three starts",
      commits = 14, slug = "14 issues written",
      identity = "A game server with our own client, a strategy game played by "
        .. "talking, and a text reader that runs against the grain.",
      blocks = {
        { kind = "h", text = "3d-generation-multiplayer-server" },
        { kind = "pull", text = "The server refuses to start without about a hundred "
          .. "fixed-layout binary data tables. The plan had been to generate all of "
          .. "them first. It does not need them — particular subsystems need them, and "
          .. "those subsystems form a chain: no map, no world; no world, nothing "
          .. "standing in it; nothing standing in it, nothing to describe." },
        { kind = "p", text = "So the requirement became one gate per subsystem rather "
          .. "than a wall at the front door, and the first world is an empty void that "
          .. "starts on nothing, announces which subsystems are switched off, and "
          .. "answers a connecting client all the way to an empty character list — "
          .. "the correct answer for an account with no characters. **Speaking the "
          .. "original client's protocol is kept deliberately, because a second "
          .. "implementation written by people who had the specification is the only "
          .. "independent check in the project.**" },

        { kind = "h", text = "dominions-interpreter" },
        { kind = "p", text = "**The finding that decides the project's shape is that "
          .. "the game's own executable has two command-line switches that never open "
          .. "a window** — one validating a turn file, one resolving a turn and "
          .. "exiting. That converts the risky half from *being right about an "
          .. "undocumented binary format* into *being checkable against the program "
          .. "that defines it*. It also means the whole loop runs with no display "
          .. "attached, which moves the accessibility goal from aspiration to "
          .. "consequence." },
        { kind = "p", text = "The save file already contains a written history: "
          .. "beneath a trivial obfuscation, each province carries its own past in the "
          .. "game's dated prose. **The narrative layer does not have to invent a "
          .. "past; it has to find one.** Two mistakes are recorded and are worth more "
          .. "than the finding: a record width worked out by eye from four examples "
          .. "came out three bytes short because unused padding decodes into a capital "
          .. "letter, and correcting that split the collection into two competing "
          .. "widths — which looked like a real difference between game versions and "
          .. "was the same class of bug twice. **A mistake that looks like a finding "
          .. "is the dangerous kind**, and both were caught only because the work was "
          .. "measured against a hundred real saved games." },

        { kind = "h", text = "backwards-reader" },
        { kind = "p", text = "Three operations that turn out to be one at three "
          .. "magnifications: run a block's lines in reverse, reverse its sentences, "
          .. "then read each sentence in *backwards meaning*. The brief names its own "
          .. "failure mode — doing this forever produces a stack overflow — which is "
          .. "the honest name for where the descent stops." },

        { kind = "transcripts", project = "3d-generation-multiplayer-server", items = {
          { file = "jul-31-26-through-aug-1-26.md", label = "31 Jul – 1 Aug" },
        } },
      },
    },
    -- }}}

    -- {{{ scripts
    {
      id = "scripts", name = "scripts", short = "the sandbox",
      commits = 5, slug = "5 issues written",
      identity = "A room in memory that an assistant cannot leave, and one door for "
        .. "finished work to walk out of.",
      blocks = {
        { kind = "p", text = "Running an assistant with the permission checks switched "
          .. "off is only reasonable if the damage has an edge. A copy of one project "
          .. "is laid down in memory-backed storage inside a private view of the "
          .. "filesystem, where that copy is the only writable thing, the rest of the "
          .. "home directory does not exist, and the system directories refuse writes. "
          .. "**This is a kernel namespace rather than a policy: an assistant cannot "
          .. "decline to be contained by it, because the paths it would need are "
          .. "absent rather than forbidden.**" },
        { kind = "p", text = "The copy borrows rather than duplicates — four gigabytes "
          .. "of history become a hundred-kilobyte repository in about eight "
          .. "milliseconds, because the new one holds a pointer at the old object "
          .. "store. Two consequences are written into a notice generated inside the "
          .. "room rather than left to be discovered: garbage-collecting the real "
          .. "repository while a room is live could delete objects the room still "
          .. "points at, and the borrowed store holds every project's history, so the "
          .. "neighbours are absent from the filesystem but legible through the "
          .. "history commands." },
        { kind = "pull", text = "The second script is the door, and its single design "
          .. "decision is the direction of travel: the real repository reaches into "
          .. "the room and takes. The room never reaches out and pushes. Had it "
          .. "pushed, it would need a writable handle on the real repository — and "
          .. "that handle is a hole through the wall the room exists to be." },
      },
    },
    -- }}}

  },

  -- {{{ open
  open = {
    { project = "every-software-image-able", state = "Reopened", tone = "blocked",
      waiting = "Phase 1 was called complete on 2 August and reopened on the 4th: the "
        .. "engine's pieces are assembly, but the loop joining them into one machine "
        .. "was not. It ran on the development machine and reached the assembly by "
        .. "loading it as a library — which proves the assembly correct and cannot go "
        .. "on a card, because a bare machine has nothing to load a library with. "
        .. "Closed on the first architecture on the 7th; open on the other two." },
    { project = "every-software-image-able", state = "Firmware gap", tone = "open",
      waiting = "The plain block of screen memory the design draws into is one "
        .. "firmware standard's handover and nothing else's. Three documents said "
        .. "otherwise and were corrected; the driver was not written." },
    { project = "dominions-interpreter", state = "Seed only", tone = "open",
      waiting = "The founding session and the save-format notes exist. Writing a turn "
        .. "file the game will accept has not been attempted." },
    { project = "backwards-reader", state = "Seed only", tone = "open",
      waiting = "Two notes as the author wrote them, plus an architecture built "
        .. "around the three magnifications being one operation. No code." },
  },
  -- }}}

  -- {{{ tree
  tree = {
    { kind = "p", text = "Three commits in this window state in their own text that "
      .. "only the current project's files were included and that other in-progress "
      .. "work found staged was left as it was. The automatic checks that enforce "
      .. "that arrive in Part 9." },
  },
  -- }}}
}
