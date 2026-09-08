-- Part 6: 12 through 24 June 2026.
--
-- The words live here and nowhere else. build-reports.lua turns this table into
-- the standalone HTML page, the plain-text twin, the index entry and the
-- body-only copy for publishing.

return {

  part = 6,
  slug_name = "two-indicator-lights",
  title = "Two Indicator Lights",
  eyebrow = "Part 6 · 12 – 24 June 2026",
  compiled = "compiled 6 Sep 2026",
  dek = "A kernel is debugged on a handheld whose only output is two amber lights, "
    .. "and the fault turns out to be a hardware address copied from the wrong "
    .. "version of a chip manual into three files. Meanwhile a hundred and eighty "
    .. "working conversations are counted as permanently deleted.",

  totals = {
    { value = "188", label = "issues written" },
    { value = "36", label = "completed" },
    { value = "8", label = "projects" },
  },

  -- {{{ days
  days = {
    { label = "12", value = 7, month = "June" },
    { label = "13", value = 0 },
    { label = "14", value = 20, emphasis = true },
    { label = "15", value = 30, emphasis = true },
    { label = "16", value = 26, emphasis = true },
    { label = "17", value = 0 },
    { label = "18", value = 1 },
    { label = "19", value = 8 },
    { label = "20", value = 0 },
    { label = "21", value = 1, emphasis = true },
    { label = "22", value = 16 },
    { label = "23", value = 34, emphasis = true },
    { label = "24", value = 21, emphasis = true },
  },
  chart_alt = "Commits per day from 12 to 24 June 2026: 7, none, 20, 30, 26, none, "
    .. "1, 8, none, 1, 16, 34 and 21.",
  chart_caption = "Commits per day. The handheld kernel is the 14th to the 16th; the "
    .. "poetry website is the 22nd to the 24th. The single commit on the 21st is the "
    .. "one about the deleted conversations.",
  -- }}}

  -- {{{ intro
  intro = {
    { kind = "lead", text = "The window runs 12 to 24 June. Eighteen days of silence "
      .. "before it, two days after." },
    { kind = "p", text = "Two projects, in parallel. **soren-ds** goes from a "
      .. "directory of plans to a kernel that starts on the Anbernic RG DS and "
      .. "writes a log to its SD card. **neocities-modernization** moves its "
      .. "all-pairs poem comparison off CPU worker threads and onto the graphics "
      .. "card as Vulkan compute shaders, and swaps its vector backend from an "
      .. "external service to a llama.cpp server built from source inside the "
      .. "project." },
    { kind = "p", text = "A single commit on the 21st sits between them. It installs "
      .. "a hook that saves working conversations at the end of every session, and "
      .. "reports that a hundred and eighty earlier ones are already gone." },
  },
  -- }}}

  work_caption = "Issue files, 12 – 24 June",
  -- {{{ work
  work = {
    { name = "soren-ds",                commits = 153, added = 25, removed = 0 },
    { name = "words-pdf",               commits = 16,  added = 9,  removed = 0 },
    { name = "neocities-modernization", commits = 16,  added = 2,  removed = 0 },
    { name = "games/3d-rts",            commits = 3,   added = 0,  removed = 0 },
  },
  -- }}}
  work_note = {
    { kind = "p", text = "Columns are issue files written and completed. The "
      .. "handheld's 153 are phase-2 through phase-10 tickets written on 12 June, "
      .. "before any of the hardware work began." },
  },

  projects_caption = "What happened",
  projects = {

    -- {{{ soren-ds
    {
      id = "soren", name = "soren-ds", short = "soren-ds",
      commits = 153, slug = "153 issues written, 25 completed",
      identity = "The kernel goes from nothing to running on the device in four "
        .. "days, and then spends one day being debugged through the only output "
        .. "the hardware has.",
      stats = {
        { key = "Nothing to booting", value = "4", note = "days" },
        { key = "Drivers written", value = "6" },
        { key = "Visible output", value = "2", note = "LEDs" },
        { key = "Wrong address in", value = "3", note = "files" },
        { key = "Log misplaced by", value = "30", note = "GB" },
      },
      blocks = {
        { kind = "h", text = "12–15 June · from a cross-compiler to a log on the card" },

        { kind = "p", text = "In order: a cross-compiler built from source, a build "
          .. "system, the boot and reset vectors, the exception vector table, the "
          .. "physical memory map catalogued against the chip's address space, a page "
          .. "allocator, the USB controller brought up in device mode, USB "
          .. "descriptors and control transfers, a virtual serial port for debug "
          .. "output over that USB link, a driver for the internal eMMC flash, a "
          .. "driver for the removable microSD card, and a debug log written to the "
          .. "card." },

        { kind = "p", text = "**The development card is assembled from somebody "
          .. "else's boot chain.** A script downloads a pinned nightly build of "
          .. "ROCKNIX into memory, checks its hash, and carves out the three pieces "
          .. "the chip's built-in ROM expects: the Rockchip initial loader that goes "
          .. "at sector 64, the u-boot image it loads from sector 16384, and the "
          .. "device tree. Those three plus our kernel are stitched into a "
          .. "partitioned image. The kernel on its own is not bootable, so the "
          .. "flashing script was narrowed to look only for the assembled image — "
          .. "otherwise the raw kernel gets written to a card and the device does "
          .. "nothing." },

        { kind = "p", text = "The lab machine is air-gapped, so two scripts bridge "
          .. "it. The first syncs the build onto a USB drive **identified by its "
          .. "filesystem UUID rather than its device path**, so a drive enumerating "
          .. "in a different order between sessions cannot cause a write to land on "
          .. "the wrong disk. The second, running on the lab side, watches for a new "
          .. "block device to appear, refuses to continue unless exactly one new "
          .. "removable device showed up, and requires a typed full word before it "
          .. "writes." },

        { kind = "h", text = "16 June · debugging by eye" },

        { kind = "p", text = "The device came back in a reset loop. There is no "
          .. "console, no debugger, and the log does not work yet. The hardware has "
          .. "two amber indicator lights. The day is a sequence of experiments read "
          .. "off them." },

        { kind = "findings", items = {
          "**Make the first sign of life unambiguous.** The kernel's C entry now "
            .. "flashes all three LED pins together, holds, goes dark, holds, and only "
            .. "then sets its normal stage signal. That pattern appears nowhere else, "
            .. "so its absence means *the kernel never started* — rather than the "
            .. "earlier ambiguity, where a dark device could equally mean the "
            .. "bootloader never lit its own default.",
          "**Find out what the lights physically are.** The device tree claims three "
            .. "pins driving green, amber and red; the eye sees two ambers. Either "
            .. "multi-element lights behind diffusers are mixing to amber, or two "
            .. "amber LEDs share one pin and the other two pins drive hardware not "
            .. "populated on this board. A probe cycles each pin alone, then all "
            .. "three, then none, looping forever until the power is pulled.",
          "**Make the last thing you see name the failing step.** The USB bring-up "
            .. "has three sub-steps: ungate the clocks and release the resets, take "
            .. "the USB-2 PHY out of suspend, then reset and configure the controller. "
            .. "Two unused two-light combinations are painted before the first two "
            .. "and held for about half a second each. On a fault the lights freeze at "
            .. "whichever checkpoint was set just before the offending write, and the "
            .. "developer sees that pattern flash on every reset cycle.",
        } },

        { kind = "pull", text = "The USB controller was at 0xFEC0_0000 and belongs at "
          .. "0xFCC0_0000. The project's hardware document carried a base address "
          .. "copied from an older version of the chip's support package, which used "
          .. "a different bus mapping, and the driver inherited the wrong number from "
          .. "the document. Writing to an address with no peripheral behind it stalls "
          .. "the chip's internal bus, and the stall raises the exception the "
          .. "bootloader was catching and resetting on." },

        { kind = "p", text = "Earlier research had flagged the ambiguity and nobody "
          .. "acted on it, because nothing had narrowed the fault to a specific "
          .. "sub-step. **Fixing it once was not enough.** The next round showed the "
          .. "kernel reaching the endpoint-zero configuration call and dying inside "
          .. "it, and a search found two more files — the enumeration logic and the "
          .. "serial layer — each carrying its own copy of the same wrong address. "
          .. "Phase 1 has a deliberate no-shared-headers rule, so every driver file "
          .. "defines its own constants; all three were written at once against the "
          .. "document that was wrong." },

        { kind = "thread", name = "One owner for the shared thing", first = 4,
          text = "A physical address used by three files is kept in step by hand. "
            .. "The no-shared-headers rule buys independence between drivers and "
            .. "charges for it here: **correcting the document and one file left two "
            .. "latent copies**, and only a checkpoint that named the exact call site "
            .. "found them." },

        { kind = "h", text = "The instruments had to be repaired before they could be used" },

        { kind = "findings", items = {
          "**The debug log could switch itself off, and did.** After one hardware run "
            .. "the log region read back as sixteen megabytes of untouched erased "
            .. "flash. The cause was the page allocator quietly failing inside the "
            .. "log's own setup — and the channel that would have said why was the "
            .. "log. The buffer moved to a statically reserved region that is always "
            .. "present, costing one page of memory whether the log is used or not.",
          "**The log was being written 32 gigabytes into the card instead of 2.** The "
            .. "constant had an extra zero and its own comment said the right figure. "
            .. "On a smaller card that address falls past the end and every write is "
            .. "silently rejected; on the developer's 256-gigabyte card it is in range "
            .. "and collides with the region reserved for copying the internal flash.",
          "**A write test was run beneath both layers.** A known marker string is "
            .. "written directly to two card addresses, bypassing the log and the "
            .. "backup. The three possible outcomes were written down first: both "
            .. "regions marked means the writer is fine and the layers above are at "
            .. "fault; one region marked means a region-specific failure and which "
            .. "one; neither means the writer itself. Three different next steps, "
            .. "chosen before the experiment rather than after it.",
          "**During the multi-minute flash copy the amber light breathes**, advancing "
            .. "one step of real brightness per megabyte, so a developer watching the "
            .. "device can tell progress from a hang.",
        } },

        { kind = "p", text = "**The window ends with the root cause found and not "
          .. "fixed.** Reading the upstream Linux drivers established that both "
          .. "storage controllers depend on several clocks and several resets that "
          .. "the bootloader on this boot path does not configure. The first access "
          .. "then either reads a meaningless value — a held reset gives zero, a "
          .. "gated clock gives all ones — or stalls the bus long enough to trigger "
          .. "the reset. The internal flash is intermittent because u-boot happens to "
          .. "use it and leaves some of them usable; the microSD fails every time "
          .. "because the boot ROM reads the boot chain by raw offset and never "
          .. "touches that controller at all. Both tickets were reopened carrying a "
          .. "register-by-register playbook rather than a description of the symptom." },

        { kind = "transcripts", project = "soren-ds", items = {
          { file = "jun-12-26.md", label = "12 Jun" },
          { file = "jun-14-26-through-jun-16-26.md", label = "14 Jun – 16 Jun" },
          { file = "jun-16-26.md", label = "16 Jun", agents = 1 },
          { file = "jun-16-26-through-jul-1-26.md", label = "16 Jun – 1 Jul" },
          { file = "jun-17-26.md", label = "17 Jun" },
        } },
      },
    },
    -- }}}

    -- {{{ neocities
    {
      id = "neocities", name = "neocities-modernization", short = "neocities",
      commits = 16, slug = "16 issues written, 2 completed",
      identity = "The comparison arithmetic moves to the graphics card, and the "
        .. "build stops reporting success when it has failed.",
      stats = {
        { key = "Compute",    value = "CPU → GPU" },
        { key = "Backend",    value = "external → local" },
        { key = "Cache tier", value = "disk → RAM" },
        { key = "Reverts",    value = "1", note = "same day" },
      },
      blocks = {
        { kind = "h", text = "18–22 June · onto the graphics card" },

        { kind = "p", text = "Comparing every poem against every other is the "
          .. "expensive part of the build. It moved from CPU worker threads to Vulkan "
          .. "compute shaders — the all-pairs similarity and the diversity-spreading "
          .. "inner loop both — running in batches rather than one pair at a time. "
          .. "The vector-producing backend was swapped at the same time, from an "
          .. "external Ollama service to a llama.cpp server built from source and run "
          .. "inside the project, which is what later makes it possible to hold "
          .. "several models at once and compare them." },

        { kind = "p", text = "The artwork changed too: every art generator's "
          .. "parameters were wired to the poem's own vector, so what a picture looks "
          .. "like tracks what the poem says rather than being chosen by hand. And "
          .. "reshared posts were turned off by default and made opt-in — a "
          .. "collection of somebody's writing should not quietly become a collection "
          .. "of what they forwarded." },

        { kind = "h", text = "23 June · the caches move to memory, and come back" },

        { kind = "p", text = "The regenerable caches were pointed at memory-backed "
          .. "storage, which is where something that can always be rebuilt belongs. "
          .. "The full regeneration then failed, and the switch was turned off again "
          .. "the same day." },

        { kind = "pull", text = "The readers had been moved and several writers had "
          .. "not, so the readers found nothing. One step crashed on a missing "
          .. "vectors file; another quietly skipped because its colour data was not "
          .. "there. Both files were on disk the whole time." },

        { kind = "p", text = "The audit that was supposed to catch this had searched "
          .. "for one spelling of the path and missed every writer that assembles the "
          .. "path from a variable. The switch went back off so everything agreed "
          .. "again, the writers still needing work were written down at the moment "
          .. "of the revert rather than rediscovered later, and the move was redone "
          .. "properly afterwards — every cache writer routed through one location "
          .. "switch, then the vector generator, then the last similarity writer." },

        { kind = "thread", name = "One owner for the shared thing", first = 4,
          text = "Two halves of the pipeline disagreed about where a file lives, and "
            .. "nothing owned the answer. The fix is the same one the pipeline reaches "
            .. "for again six days later: **one switch that every reader and every "
            .. "writer consults**, rather than a convention each of them implements." },

        { kind = "findings", items = {
          "**A missing prerequisite now stops the build.** The page-building stage "
            .. "already checked for the similarity and diversity caches and returned a "
            .. "failure when they were absent — and the caller discarded that return "
            .. "value and exited cleanly. The run carried on, built a site whose "
            .. "navigation pages were never generated, and **reported success while "
            .. "every link on it led nowhere.** The failure is now fatal, the check "
            .. "runs before the long generation rather than after it, and the error "
            .. "prints the exact path it looked in.",
          "**A step that silently skipped now refuses.** The word-colour stage had "
            .. "been shipping colourless words when its data was missing, which hides "
            .. "an upstream problem behind an output that merely looks plain.",
          "**Cache validators became aware of which tier is switched on**, so they "
            .. "stopped reporting files as missing when they were somewhere else.",
        } },

        { kind = "thread", name = "Fallbacks hide bugs", first = 2,
          text = "The rule is standing policy in the author's conventions. What this "
            .. "window records is what it caught: a build that had been reporting "
            .. "success for an unknown length of time while shipping a site with no "
            .. "working navigation, found only because the quiet path was made loud." },

        { kind = "h", text = "24 June · sizing the work to the machine" },

        { kind = "p", text = "A memory budgeter sizes the work to the memory actually "
          .. "available, in both main memory and graphics memory. The neighbour "
          .. "caches are capped to what the pages display, and the per-poem page "
          .. "ceiling is computed from the storage quota instead of being a number "
          .. "somebody picked. Every stage records its real wall-clock time in a small "
          .. "ring buffer, and the pre-flight list shows each stage's measured "
          .. "duration — so the list of what is about to run also says how long it "
          .. "took last time." },

        { kind = "transcripts", project = "neocities-modernization", items = {
          { file = "jun-15-26.md", label = "15 Jun" },
          { file = "jun-15-26-through-jun-16-26.md", label = "15 Jun – 16 Jun" },
          { file = "jun-18-26-through-jun-19-26.md", label = "18 Jun – 19 Jun" },
          { file = "jun-19-26-through-jun-20-26.md", label = "19 Jun – 20 Jun" },
          { file = "jun-21-26-through-jun-22-26.md", label = "21 Jun – 22 Jun" },
          { file = "jun-22-26-through-jun-23-26.md", label = "22 Jun – 23 Jun" },
          { file = "jun-23-26-through-jun-24-26.md", label = "23 Jun – 24 Jun" },
          { file = "jun-24-26-through-jun-25-26.md", label = "24 Jun – 25 Jun", agents = 1 },
        } },
      },
    },
    -- }}}

    -- {{{ the record
    {
      id = "record", name = "the transcript-rescue commit", short = "the record",
      commits = 0, slug = "one commit, 21 June",
      identity = "The patch is small. The count it reports is not.",
      stats = {
        { key = "Sessions lost", value = "180" },
        { key = "Recoverable",   value = "0" },
        { key = "Projects hit",  value = "9", note = "at least" },
        { key = "Transcripts saved", value = "20" },
      },
      blocks = {
        { kind = "p", text = "**The patch.** The program that exports a working "
          .. "conversation into a readable file now keeps every block of prose "
          .. "written between one user turn and the next, rather than only the last "
          .. "passage of the last message — which is all that a single early loop "
          .. "break and a single last-index lookup had been keeping. It also became "
          .. "directly runnable rather than only loadable, which silently fixed a "
          .. "batch driver that had been doing nothing for an unknown length of time. "
          .. "And a hook was installed that fires at the end of every session and "
          .. "writes the result into the right project's folder." },

        { kind = "pull", text = "That only saves the conversations that have not "
          .. "already been taken. Going through the rest of the repository, one "
          .. "hundred and eighty sessions were found to be gone. Not paused, not "
          .. "archived, not awaiting a recovery procedure." },

        { kind = "p", text = "The count was taken project by project: fifty-three in "
          .. "the city-building modernisation, twenty-three in a realms project whose "
          .. "transcripts folder does not exist because no export was ever run there, "
          .. "seventeen in a physics simulator being worked on that week, seventeen "
          .. "in a chat-translation experiment, fifteen in the repository-management "
          .. "work, thirteen run from the repository root, and thirteen in a "
          .. "world-editing tool **that holds three hundred preserved transcripts "
          .. "from earlier eras of its own development — an old archive sitting next "
          .. "to a fresh absence.**" },

        { kind = "p", text = "The session pruner had cleaned them thoroughly. The raw "
          .. "files are in no backup, no snapshot, no subvolume, no archive "
          .. "repository, no trash, no git history and no telemetry export. The "
          .. "filesystem is a journalled one with no automatic snapshots and no "
          .. "incremental backup tool installed, and the blocks those files occupied "
          .. "were returned to the free list. What survives is the fact of each "
          .. "session, in a global command-history file recording which project it "
          .. "served, the identifier it was known by, and when it began." },

        { kind = "thread", name = "The record is load-bearing", first = 3,
          text = "Everything the later parts do about transcripts follows from this "
            .. "count: the chronological shelf, the single naming authority, the rule "
            .. "that an exported file is not a copy of the log but the only surviving "
            .. "version, and the habit of committing a founding conversation for a "
            .. "project that already has code. **The tooling deletes its own session "
            .. "logs on a schedule, so a conversation that was not exported is a "
            .. "conversation that stops existing.**" },
      },
    },
    -- }}}

  },

  -- {{{ open
  open = {
    { project = "soren-ds", state = "Root cause found", tone = "blocked",
      waiting = "Both storage controllers need several clocks ungated and several "
        .. "resets released that the bootloader does not configure. The two tickets "
        .. "were reopened carrying the exact registers, the vendor-specific writes "
        .. "the first implementation missed, the stale-interrupt clear, and the "
        .. "no-op command the controller requires between every clock change. "
        .. "**Written, not implemented.**" },
    { project = "soren-ds", state = "Skipped", tone = "open",
      waiting = "The USB controller's first endpoint command is never acknowledged, "
        .. "so that step is skipped to let the storage backup proceed. Left as a "
        .. "known gap, because storage was the path blocking progress." },
    { project = "neocities-modernization", state = "Half-done, recorded", tone = "open",
      waiting = "The move of regenerable caches into memory was reverted mid-window "
        .. "and redone, with the list of writers still needing routing written down "
        .. "at the moment of the revert. Worth checking that list was exhausted." },
    { project = "the record", state = "Unrecoverable", tone = "blocked",
      waiting = "One hundred and eighty working conversations across at least nine "
        .. "projects. The hook that prevents further loss is installed; nothing "
        .. "recovers what preceded it. What survives for the worst-hit projects is "
        .. "roughly three hundred and ninety summary files an earlier pass extracted "
        .. "while the originals still existed." },
  },
  -- }}}

  -- {{{ tree
  tree = {
    { kind = "p", text = "From 21 June the repository keeps its own conversations on "
      .. "purpose. Before that they were exported by hand when somebody remembered; "
      .. "from that day a hook fires at the end of every session, writes into the "
      .. "project the session served, and logs its own activity to a memory-backed "
      .. "audit file without ever blocking the exit." },
  },
  -- }}}
}
