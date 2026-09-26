# Conversation Summary: agent-a5fab98d8e3793acb

Generated on: 2026-09-26 12:47:37
Models: claude-haiku-4-5-20251001

--------------------------------------------------------------------------------

### User Request 1

I need a status report on the project at /mnt/mtwo/programming/ai-stuff/soren-ds
(note: it may also be accessible at /home/ritz/programming/ai-stuff/soren-ds).

Please explore and report back on:
1. The project's vision — read notes/vision (or notes/ directory) and
   summarize what this project is trying to be.
2. The roadmap and phases — find the roadmap document (likely in docs/) and
   list the phases.
3. Issue status — count and summarize issues in issues/ vs issues/completed/.
   What phase are we currently in? What issues are open/in-progress?
4. The phase progress files — read any issues/phase-X-progress.md files and
   summarize.
5. Recent work — based on git log and the most recently modified files, what
   was the last thing worked on? The recent commits mention
   "first-person-spellcraft" — find and summarize what that is.
6. Docs table of contents — read docs/table-of-contents.md if it exists.

Do NOT modify anything. Report back a concise but complete status summary
organized by the above points. Include specific file paths and issue
names/numbers where relevant. Quote short excerpts from vision/roadmap where
they capture the essence.

--------------------------------------------------------------------------------

### Assistant Response 1

> I'll explore the project systematically and gather the status information you
> need. Let me start by checking the structure and key files.

> Now let me read the vision documents and check for roadmap and phase progress
> files:

> Now let me read the key files:

> Now let me check the issues directory structure and progress files:

> Let me read the phase progress files, starting with the latest phases:

> Let me search for the first-person-spellcraft issue:

> Let me check what those commits are about in more detail:

> Now let me get a better summary of the phase progress and issues:

> Now let me check the recent-most progress on other phases:

> Let me get a summary of the completed issues and overall status:

> Let me search for more information about the current projects:

> Let me check git for the first-person-spellcraft work in more detail:

> Perfect! Now let me read the first-person-spellcraft issues to understand it
> better:

> Let me check what actually exists in that directory:

> Let me gather a final summary with the information I have:

> Now let me do a final check on the issue counts in open vs completed:

Perfect! Now I have enough information to compile the report. Let me create a
comprehensive summary:

## Soren DS Project Status Report

## 1. PROJECT VISION

**Location:**
`/mnt/mtwo/programming/ai-stuff/soren-ds/notes/vision/000-vision.md`

Soren DS is a custom operating system for the Anbernic RG DS handheld device.
The vision encompasses:

- **Four main launch applications:**
  1. A Soramech-based programming language runtime
  2. An i3-style dual-pane text editor with vim-like input (L+R toggles
     cursor/insert mode; text via radial menu)
  3. Pictochat-style messenger with image attachments
  4. Paint application (stylus-based drawing on touch screens)

- **Core design principles:**
  - Apps link to each other like soramech boxes (no back button, only forward
    links)
  - No history stack — background apps retain state; returning follows
    inter-app links
  - Four center buttons on bottom screen open context drawers (radial menu
    interface for 32-character input per mode)
  - Radial menu: D-pad direction + face button chords; 8 directions × 4 buttons
    = 32 chars per mode
  - Entire OS above the C layer is a soramech map (dataflow-driven,
    multithreaded)
  - Never runs stock OS — developer iteration loops exclusively over custom
    USB debug paths

- **Post-launch extension:**
  - Phase 10 adds the modeller: on-device 3D vertex-grid editing, face coloring,
    dynamic model merging (LEGO-like assembly)

## 2. ROADMAP & PHASES

**Location:** `/mnt/mtwo/programming/ai-stuff/soren-ds/docs/002-roadmap.md`

Ten phases ordered by dependency. Phases 1-9 build the launch system; phase 10
is the first post-launch app (proof-of-platform).

| Phase | Name | Goal | Status |
|-------|------|------|--------|
| 1 | Hardware bring-up | Kernel boots, both screens light, USB debug works | Active (20 completed issues; 30+ open) |
| 2 | Threading core | Worker pool, ring-buffered tasks, atomic gathering, ARM memory ordering | Not started (all issues open) |
| 3 | Soramech runtime | Box loader, wire connector, runtime for statically-linked boxes | Not started (all issues open) |
| 4 | Filesystem | SD card driver, FAT filesystem, compile pipeline, artifact system | Not started (all issues open) |
| 5 | Input drivers | Button/stick/touch polling map, radial-menu chords | Not started (all issues open) |
| 6 | Compositor & links | Display surfaces, drawer overlays, inter-app linkage system | Not started (all issues open) |
| 7 | Ad-hoc radio & rmail | WiFi IBSS, link-local IP, peer discovery, USB-C virtual ethernet, rmail port | Not started (all issues open) |
| 8 | Four apps | Programming env, text editor, messenger, paint | Not started (all issues open) |
| 9 | Memory protection & background lifecycle | MMU protection mode, per-app memory regions, app lifecycle (foreground/background/asleep) | Not started (all issues open) |
| 10 | Modeller | On-device 3D vertex-grid editing, face coloring, model merging | Planned (10 issues, all open) |

## 3. ISSUE STATUS

**Totals:**
- **Open issues:** 122 (across phases 1-10)
- **Completed issues:** 25
- **Current phase focus:** Phase 1 (Hardware bring-up)

**Phase 1 completed issues** (20) include:
- 101: Hardware specification research
- 102: Cross-compilation toolchain (GCC 16.1.0, Binutils 2.44)
- 103: Project build system (Makefile-based)
- 104: Boot and reset vector
- 105: Exception and interrupt vectors
- 106: LED earliest boot signal (PWM-driven diagnostic)
- 106a: Visible heartbeat during long operations
- 107: Flat memory layout
- 108: Flat page allocator (4 KB bitmap-backed)
- 109b: USB descriptors and endpoint-zero configuration
- 109c: USB control transfer plumbing
- 110: USB CDC-ACM debug stream
- 110b: Bootable eMMC overwrite
- 110d: Bootstrap button trigger
- 110g: SD-card debug log
- 103a: Air-gapped SD card flash workflow
- 103b: Bootable SD image assembly
- 103c: Kernel image header
- 103d: Kernel load address fix (moved to 0x0200_0000)
- 103e/f: GPIO LED probe & SIMD compiler flags

**Phase 1 reopened issues:** 109a (USB PHY), 110a (eMMC controller), 110f
(microSD controller) — all in active development.

**Phase 2-10:** All issues remain open; no work has begun.

## 4. PHASE PROGRESS FILES

**Location:**
`/mnt/mtwo/programming/ai-stuff/soren-ds/issues/phase-X-progress.md`

Each phase has a progress file documenting:
- Phase story (ordered issue walkthrough)
- Completed issues summary
- Open issues list
- Demo specification

**Phase 1 progress:** 32 KB detailed document describing every completed issue,
reopened issues, and their code locations (src/ paths).

**Phase 2-10 progress:** Template structure exists; Phase 2 notes "None yet"
under completed issues. All phases 2-10 are waiting for Phase 1 to complete
hardware bring-up.

## 5. RECENT WORK — FIRST-PERSON-SPELLCRAFT

**Latest commit:** `7b7e5d10` (Jul 22, 2026)
> "first-person-spellcraft: the room takes shape — the world model, seen
> top-down (103)"

This is a **separate game project** housed alongside the Soren DS OS. Recent
commits show:
- **Issue 103:** Square-room world data model — dual-lens representation (grid
  for rendering/collision + room table for gameplay)
- **Issue 102b:** Substrate brought to a runnable window state
- **Earlier:** Dataflow substrate (wires, threads, self-turning graph)

The commit touches `/games/first-person-spellcraft/` including:
- World data model (`src/001-world.c/h`) with collision, room dispatch
- Top-down debug renderer (not first-person yet)
- Test harness for world validation
- Platform abstraction layer
- Design lessons in `strategems/` directory (self-checking round-trips, publish
  patterns, value handoff)

**Status:** Active development; Phase 1 working on player collision and room
navigation.

## 6. DOCUMENTATION TABLE OF CONTENTS

**Location:**
`/mnt/mtwo/programming/ai-stuff/soren-ds/docs/000-table-of-contents.md`

26 core documentation files organized in reading order:

**Core architecture (001-009):**
- Architecture overview
- Roadmap (phases 1-10)
- Threading model (task firing, ring buffers, atomics, ARM memory ordering)
- Input model (touch, buttons, radial menu, drawers)
- Display & compositor (framebuffers, surfaces, damage tracking, overlays)
- Transport & networking (USB-C, ad-hoc radio, rmail, peer addressing)
- Memory model (flat → protected progression)
- Apps overview (four launch apps + links)
- Deferred work (explicit non-goals)

**App & system layers (010-013):**
- Modeller spec (3D vertex editing, face coloring, model merging)
- Filesystem (FAT reader, path boxes, compile pipeline)
- Soramech runtime (box loader, wire connector, encapsulation splicer)
- Background app lifecycle (foreground/background/asleep states)

**Hardware & low-level (014-026):**
- Hardware overview (Anbernic RG DS chip-by-chip breakdown)
- LED diagnostic codes (three-light patterns for boot stages)
- Physical memory map (3 GB DRAM + peripheral windows)
- Clocks and timers (CRU, clock gating, watchdog, PWM as timers)
- eMMC host controller (dwcmshc vendor quirks, register state from real
  hardware)
- Board pinmux (SDMMC, I²C, UART, PWM, audio, display, touch)
- SDMMC0 host controller (microSD DW MSHC specifics)
- PMIC & regulators (RK817 power rails)
- USB device controller (DWC3 + USB2 PHY)
- Display controller (VOP2 + MIPI DSI + DPHY)
- eMMC partition map (factory GPT + 15 Android partitions)
- Recovery & download modes (Maskrom, USB Maskrom, wipe-from-SD recovery)
- Chip scripts (interactive tool category + console I/O framework)

## KEY OBSERVATIONS

1. **Phase 1 is the critical path.** It's ~65% complete (20/31 estimated issues
   done). Reopened issues (109a, 110a, 110f) suggest active iteration on USB PHY
   and storage controller bring-up.

2. **The project is hardware-focused.** Much effort goes to reverse-engineering
   the Anbernic RG DS chip (eMMC, display controller, WiFi radio) via actual
   hardware testing and TRM datasheet work.

3. **Architecture is dataflow-driven.** The entire OS is a soramech map (like
   reactive functional programming). Phase 2 (threading core) is the gating
   dependency for everything that follows.

4. **Strong documentation discipline.** 26 core docs + phase progress files +
   122 open issues each with their own .md specs. Every hardware quirk is
   catalogued in docs/.

5. **Parallel project incubation.** First-person-spellcraft game is in-progress
   alongside the OS, using the OS-under-development as its platform, testing
   architecture before launch.

6. **Latest activity (Jul 22):** Spellcraft world model complete; collision and
   room navigation working. OS work staged separately (not in that commit).

7. **Recovery-first design.** Phase 1 emphasizes safe fallback paths (Maskrom
   recovery, SD-boot before eMMC takeover) before touching persistent storage.

--------------------------------------------------------------------------------

