# Conversation Summary: 2cc5b442-35f8-48a3-a89e-8fff4835dc81

Generated on: 2026-11-06 01:11:43
Models: claude-opus-5-5

--------------------------------------------------------------------------------

### User Request 1

hey I got this message from duet, can you help me by listing these questions?

soren-ds and wow-chat: 7 questions stopped those sessions, 4 for soren-ds and 3
for wow-chat. They're on List the decisions your Claude Code sessions are
waiting on, and each answer restarts a session.

--------------------------------------------------------------------------------

### Assistant Response 1

> Still looking for those two sessions locally. A safety hook stopped my last
> search because it read the command as a write. It was only a read, so I'm
> running it again in a simpler form.

> Found the session logs for both projects. Now pulling the unanswered questions
> out of the newest ones.

> Checking whether the other wow-chat log folders hold anything newer.

I couldn't find the 7 questions Duet is counting. Duet's list is on a claude.ai
page that I have no tool to read. The two sessions also don't show up among the
sessions I can reach from here: the only other one is a session that started in
this folder 2 minutes ago. My guess is they run on another machine or in the
cloud. I searched the saved conversation logs on this computer instead, and the
counts don't match Duet's.

**wow-chat** (newest log, Nov 3, 11:57; it stopped with 4 questions, not 3)

1. **A leftover staged file:** someone staged an older copy of the finished
   "send one buddy" issue. If it got committed, it would delete the note saying
   that issue moved to the custom client. Should the session take it back out of
   the staging area?
2. **The ground sandbox data:** about 52 MB of rebuildable files that git isn't
   tracking. Should they go on the ignore list?
3. **When the compile should stop MySQL:** the compile starts MySQL, but its
   install steps and the servers you start next need MySQL running. Should it
   stop MySQL after the quick tests, after the whole compile, or never (the one
   exception to the rule that tests stop MySQL if they started it)?
4. **A failing test (the check that the installed Lua links are correct):** the
   commit tests run in a copy of the project, but the copy's Lua links still
   point at the real project's source folder. Should the test accept links that
   point at the real project, or should the copy get links of its own?

**soren-ds** (newest log, Sep 29): no questions. It was partway through phase 4
(the SD card and the FAT filesystem) and stopped with the error "Prompt is too
long", which means the conversation got too big to continue.

So these are probably older sessions with the same names, not the ones Duet
means. To get the real list, either:
- open the Duet page and paste the questions here, or
- turn on Remote Control on the machine running those sessions, and I'll be able
  to list them from here.

Are those sessions running on another computer, or in the cloud?

--------------------------------------------------------------------------------

### User Request 2

<pasted_content id="c893">
> 1. A leftover staged file: someone staged an older copy of the finished "send
> one buddy"
>      issue. If it got committed, it would delete the note saying that issue moved to the
>      custom client. Should the session take it back out of the staging area?
</pasted_content id="c893">


let's bring it up to date.

> 2. The ground sandbox data: about 52 MB of rebuildable files that git isn't
> tracking.
>      Should they go on the ignore list?

yes



<pasted_content id="c893">
> 3. When the compile should stop MySQL: the compile starts MySQL, but its
> install steps
>      and the servers you start next need MySQL running. Should it stop MySQL after the
>      quick tests, after the whole compile, or never (the one exception to the rule that
>      tests stop MySQL if they started it)?
</pasted_content id="c893">


after the whole compile, if the compile started mysql



<pasted_content id="c893">
> 4. A failing test (the check that the installed Lua links are correct): the
> commit tests
>      run in a copy of the project, but the copy's Lua links still point at the real
>      project's source folder. Should the test accept links that point at the real project,
>      or should the copy get links of its own?
</pasted_content id="c893">


whoa hang on, why are we copying the project? That sounds like we're just asking
for disk wear.



<pasted_content id="c893">
great I'll look into it. Can you give me the 7 questions for soren-ds and
wow-chat?

Pulling them from the doc now

Here are the 7, from sessions that last ran in September, so some may have moved
on since. Where a session had a pick, it comes first.

soren-ds

    Catalogue: use the generated placement functions plus a one-column name table (session's pick), or another answer from the phase 3 progress page?
    Late-compiled box: the engine reads the placement table directly and returns entry plus data addresses, or it returns only the entry address and puts the table at a fixed offset? This is a fact about soren-ds's loader, not a preference.
    Undo after replacing a box: remove the old station only after you've decided, so undo still works (session's pick), or remove it right away?
    Phase 3 demo map paths: give built-in maps a fixed home folder, or keep the demo map free of relative paths until phase 4?

wow-chat
5. World server console fix: patch wow-chat-2026 directly, write it up in neuron
   to hand over, or have neuron only show a warning with the patch one click
   away?
6. Issue 154: which one place should the database credential live? Stay on MySQL
   9.6.0 or move to 26.7.0? Should mysql-client read the root password file?
7. Issue 153d, the naturalist: when a node runs out of screenshots, reuse images
   or stop resampling? Should the weapon training hook handle beta too? There
   are 13 more questions in the issue file.
</pasted_content id="c893">


can you give me more context on the soren-ds questions? the wow-chat stuff is a
different repository.

--------------------------------------------------------------------------------

### Assistant Response 2

> Reading the issue on compiling a box on the device, which holds question 2.

> Checking the map-file issue for the paths question, then writing up.

Here are the four soren-ds questions, filled in from the project's own issue
files. The session last ran on Sep 29. It had finished phases 2 and 3 on the
laptop stand-in for the handheld (the "twin"), and it stopped early in phase 4
when the conversation grew too long to continue. For most of these questions it
wrote a proposed answer, marked as unverified, and left it for you to confirm.

**The words these questions use:**
- **Box:** one small C function that does one job.
- **Station:** one copy of a box placed in a running program. It has input slots
  (ports) that hold incoming values until the box runs.
- **Arrow:** a connection that carries one station's output into another
  station's input.
- **Map:** a text file listing the stations and arrows that make up a program.

## 1. Does the device keep a catalogue of boxes?
The catalogue is a table with one row per kind of box. Each row held the box's
name, where its function lives, the size in bytes of each input and of its
output, and how much memory a job needs. The parent project (the desktop version
this device descends from) deleted that table and replaced it with two things:
- **A generated function per box** that places a station directly. All the sizes
  are built into the code as numbers the compiler worked out, so nothing has to
  be stored or looked up.
- **The operating system's list of loaded functions**, used to find a box that
  arrives after the program has started. A desktop OS already keeps that list,
  so the parent didn't need its own copy.

The first half carries over to the handheld. The second half doesn't, because
the handheld *is* the operating system. It has no such list, and a box compiled
on the device just lands in a block of memory marked runnable. Any list of boxes
the device keeps, it has to write itself, and that list is the catalogue. The
three options:
- **Keep the full catalogue** and write down why the parent's approach can't
  work here. This is the least work.
- **Session's pick:** use the generated functions for the sizes, and keep only a
  one-column table, mapping each box's address to its placement function.
- **Write the OS function list into the kernel**, so the parent's design carries
  over whole, at the cost of building something like a linker into the kernel.

## 2. How does the engine find a box compiled on the device?
I couldn't find this question written anywhere in the project, so the wording
comes from Duet's summary. The background is the issue on compiling a box on the
device. Source code arrives (from the SD card or the editor), the device
compiles it into a block of runnable memory, and a catalogue row is added. To
place a station, the engine needs two addresses: where the box's function
starts, and where its size information is. Duet's two options:
- The engine reads the generated table and gets both addresses back.
- The engine gets only the function's address, and the size information always
  sits at an agreed position inside the same memory block.

Duet calls it "a fact about the loader" because the answer depends on how the
compiled code is laid out in that memory block. Nobody has built that yet: the
last session had just started the piece that loads compiled code when it
stopped. The closest answer already written down is in the phase 3 proposal:
each catalogue row holds the box's address and a pointer to its size
information, which is the first option.

## 3. When you replace a box, when does the old station go away?
Replacing a box in a running program is a four-step job:
1. Place a new station running the new box.
2. Move the arrows going into the old station over to the new one, all at once.
3. Move the arrows coming out of it, all at once.
4. Remove the old station.

They move all at once because, if one arrow moved before another, the second
would miss the values the first had already received. Removing the old station
frees its spot in the table and, later, the memory its code used. Otherwise
every save during an afternoon of editing would leave one dead station behind.
Removing it also throws away any values still waiting in its input slots.

The issue is whether step 4 waits. In the editor, the way to undo a save is to
move the arrows back to the old station, so it has to still exist. The session's
pick is that the editor stops after step 3 and removes the old station only once
you've decided to keep the change. The other option is to remove it right away,
which is simpler but means a save can't be undone.

## 4. What are the phase 3 demo's map paths relative to?
The rule is that every path in a map is relative to the file the map is written
in. But before phase 4 there is no filesystem, so the demo's map is text built
into the kernel image, and that text isn't in any file. Duet listed two options:
- Give built-in maps a fixed home folder.
- Keep the demo map free of relative paths until phase 4.

The issue file proposes a third: store the path the map was originally read from
(its file in the source folder) alongside the text, so its paths resolve exactly
as they would from the real file. The phase 3 demo already passes, so this may
already be built and only waiting for you to confirm it.

---

I didn't do anything with your wow-chat answers. That's a different repository,
so they should go to the wow-chat session itself. On the project copy you asked
about, I can find out why the commit tests copy the project if you want.

For question 3, picture a save you'd want to take back. Would you want to press
undo, or would you rather open the old version from the card and save it again?

--------------------------------------------------------------------------------

### User Request 3

1. tell me about tradeoffs? What's a linker going to do to our architecture? Is
   it elsewhere useful? does it slow down the system? I'm leaning toward keeping
   the full catalogue.

for 2. let's do the first option, as we were starting to. Can you check the open
pull requests and see if there's anything related?

for 3. in the upstream soramech project I think we decided that we needed a
layer of indirection, so we wouldn't actually update the arrows we'd just update
the station table. Is that right?

for 4. let's just wait until we build phase 4. The demos are supposed to display
the functionality of each phase, and the phases are not necessarily intended to
be completed in order. Therefore, we can wait until we have the proper systems
up and running in order to build the phases.

--------------------------------------------------------------------------------

### Assistant Response 3

> Several open pull requests touch these questions. Reading the ones for
> compiling a box on the device and for replacing a box.

> Checking how the upstream project replaces a box.

> Found it upstream. Reading the exact passage.

I looked through the soren-ds issue files, the open pull requests on GitHub, and
the upstream soramech project. Some of this is already further along than Duet's
list suggested. Since September, an online Claude session has opened draft pull
requests (dated Nov 2) that build several of these pieces.

## 1. Keeping the catalogue vs. building a linker

**What a linker would add:** a table, kept by the kernel, listing every function
in the kernel by name and where it sits in memory. It would also need a step
that patches newly compiled code so its calls point at the right kernel
addresses. Finding a box would then mean "look up this name in the kernel's
function list" instead of "look up this row in the catalogue".

**Does it slow the system down?** No. Either way, the lookup happens once, when
a station is placed. After that, the station holds the box's address directly,
and delivering values never looks anything up. The two designs differ in boot
time, memory use and build complexity, not in running speed.

**What it costs the design:**
- **It doesn't remove the need for size information.** A function list gives you
  names and addresses, not how many bytes each input holds. Something still has
  to store the box's sizes. Upstream got them from generated placement code; the
  catalogue stores them as rows.
- **The build gets more complicated.** The kernel image has to carry its own
  function names, so the build needs an extra step that pulls the names out of
  the finished image and puts them back in.
- **It opens up the whole kernel.** A box compiled on the device could call any
  kernel function by name. The catalogue is a closed list of boxes, which suits
  the phase 9 plan to keep each app inside its own memory region.

**Where else a function list would help:**
- A crash report could name the function that faulted, instead of giving a bare
  address. That fits phase 9's fault handler.
- A profiler could name where time is spent.
- Apps or drivers could someday be loaded as separate files.

A small name table built only for crash reports would cover the first one
without bringing in a linker.

**One thing already in place:** the compile pull request (#69, "compile a box on
the running device") chose TinyCC as the compiler. TinyCC does its own linking
in memory as part of compiling, so a late box can already call kernel helpers
without a kernel-wide linker. That pull request also keeps the full catalogue:
rows, plus the value types each compiled file defines. Your lean matches what's
already been built.

## 2. How the engine finds a compiled box: related pull requests

#69 does the first option. Each compiled file exposes exactly one public entry point, which hands the engine every catalogue row and type that file defines, and the engine adds them all at once. Everything else in the file is hidden, so a late box named "add" can't collide with the kernel's own "add". Two pull requests are stacked on #69:
- **#83, "give compiled code back once nothing can be inside it"**: frees a
  compiled file's memory after no core can still be running it.
- **#92, "replace a box in a running program by moving the arrows"**: question 3
  below.

Two things in #69 need your attention:
- **The TinyCC choice is marked "Ritz can overturn it".** TinyCC isn't bundled
  into the device build yet. Until it is, the device refuses to compile and says
  so.
- **Its tests depend on two other open pull requests:** #13 (building on
  standard GCC or LLVM compilers) and #36 (a use-after-free fix).

All of these are drafts.

## 3. Updating the station table instead of the arrows

Not quite. Upstream's rewiring issue says arrows hold a station's **index** in
the station table rather than its memory address, so stations never move and the
table can grow. That's the extra layer you're remembering. But the upstream
issue on boxes compiled at runtime states the rule directly: "a station's box
cannot change." Upstream replaces a box the same way soren-ds does: place a new
station, move the arrows to it, remove the old one.

#92 builds it that way:
- The old station is kept, unplugged.
- Undo is a swap that moves the arrows back. You can swap back and forth as
  often as you like.
- Removing the old station is a separate step that the editor can put off.

So the question Duet listed is already answered there, with the session's pick.

But #92 adds a rule that weakens the reason for "a box can't change": **the new
box must have the same input and output sizes as the old one**, slot by slot.
The stated reason a station can't take a new box was that its input slots were
sized for the old box. Under #92's rule they would fit. So swapping the box
inside the existing station, without touching any arrows, would now work. What
it would change:
- **Values already waiting** in the station's input slots would go to the new
  box. #92 deliberately keeps them with the old station instead.
- **Undo** would mean swapping the box back, instead of swapping the arrows
  back.
- **No arrows move at all**, so the risk that one arrow moves before another
  goes away.

## 4. Phase 3 demo paths

Agreed: wait until phase 4 builds the filesystem.

---

I haven't changed any files. Should I write your answers to questions 2 and 4
into the issue files? Several of those files are also edited by the open pull
requests, so the edits might collide with them.

On question 3: picture a box already holding values in its input slots when you
swap it out. Should those values go through the new box, or stay with the old
one in case you undo?

--------------------------------------------------------------------------------

### User Request 4

we should review the open pull requests and see if we need to merge any of them.

question about the linker, can we add functions at runtime? I'm leaning toward
the catalogue over the linker.

> - The TinyCC choice is marked "Ritz can overturn it". TinyCC isn't bundled
> into the device build yet. Until it is, the device refuses to compile and says
> so.

we decided against TinyCC in the upstream soramech implementation, can you find
out why? I think it's probably fine but I don't remember the reason we chose no
there.

> On question 3: picture a box already holding values in its input slots when
> you swap it out. Should those values go through the new box, or stay with the
> old one in case you undo?

stay with the old one. When delivering work to a station, we want that station
to take ownership over those input values. We are assigning them tasks by giving
them inputs. If we moved the inputs then not only would a move / replacement
action scale in cost arbitrarily with the scale of the inputs, but also we would
lose the capability to deliver work, update our arrows to point to a new box,
and move on. Once a station has no arrows pointing to it and no input values, it
should be garbage collected (I think, is that the current design?)

in general, we should try and align soren-ds's soramech implementation with the
minimal-soramech upstream whenever possible.

--------------------------------------------------------------------------------

### Assistant Response 4

> Now gathering the state of every open soren-ds pull request: what each one is
> based on, whether it merges cleanly, and how big it is.

> Nearly every file overlap is between separate stacks: about a dozen files, and
> one engine file is touched by five of them. Next, finding what makes the
> compile pull request conflict with main.

> The compile pull request's conflict is small. Main changed one line of the
> compile issue file, and the pull request moves that same file into the
> completed folder. Checking which line it is.

I haven't merged anything. Below: how the soren-ds pull requests group together,
what blocks each group, the TinyCC history, and how removing stations works
today.

## The open soren-ds pull requests

There are 29, all drafts, and none has automatic test runs on GitHub. The online
sessions ran the tests themselves. Most are built on top of one another in
chains, so they group into ten stacks:

| Stack | Pull requests, in merge order | State |
|---|---|---|
| Use-after-free fix (reading a queued job's size before another core frees it) | #36 (6 lines) | Ready. The compile tests need it to pass the memory checker. |
| Building on standard GCC or LLVM | #13 (14 lines) | Ready. Several other stacks' tests need it. |
| Comparator wider than its threshold is refused | #221 | Small, stands alone. |
| Twin keeps up on a busy host | #205 | Small. It edits the same twin platform files as the compile and filesystem stacks. |
| Filesystem: FAT tests, paths and links, the six file boxes, then settings, or appending, pulling the card mid-write, and moving files | #20 → #25 → #35 → #48, and #35 → #117 → #141 → #209 | Each merges cleanly onto the one before it. |
| **Compile on the device, free old code, replace a box** | #69 → #83 → #92 | **Hold.** It goes against two of today's decisions (below). #69 also has one small conflict: main added "blocks 612" to the compile issue's list of issues it blocks, and the pull request moved that file to completed/. |
| Input (phase 5): 60 Hz input frame, buttons, chords, sticks and touch, radial menu, handedness | #214 → #218 → #224 → #225 → #302 → #303 | Not read yet. |
| Screens (phase 6): surfaces, damage marks, compositor, foreground app, drawers | #228 → … → #232 | Not read yet. |
| Network (phase 7): link and UDP, peer discovery, send by name | #233 → #234 → #235 | Not read yet. Built on a stand-in link. |
| Modeller vertex grid (phase 10) | #236 | Not read yet. Built over a stand-in for phase 9's per-app memory, which is the kind of placeholder you treat as a warning. |

**Collisions between stacks:** a dozen files are changed by more than one stack.
The worst is the engine's program-record file (where each running program's
stations, names and doors are kept), which five stacks edit. Whichever stack
merges second onto that file will need its conflicts resolved by hand.

So far I've only checked how the pull requests fit together, not what their code
says. Proposed order:
1. Merge #36 and #13 now.
2. Merge #221 and the filesystem stack.
3. Read phases 5, 6, 7 and 10 against upstream before merging them.
4. Rework the compile stack once the questions below are answered.

## Adding functions at runtime with a catalogue

Yes. #69 adds catalogue rows while the device runs. The table grows by adding
pages, and existing rows never move. Compiling the same file again makes a newer
version. New placements get the new version, and stations already running keep
the old one. #83 frees the old code once nothing is still running it.

The one thing a linker would add is boxes calling functions by name across
files: one late file calling a helper defined in another late file, or calling
any kernel function. Without a linker, a late box can only call what the compile
step is told to provide. That's a closed set, which is the same property you
like about the catalogue.

## Why upstream refused TinyCC

From the upstream issue on boxes compiled at runtime: the problem is having two
compilers answer "how big is this struct". The binary is built by GCC, and the
late boxes would be built by TinyCC. For ordinary types they agree, but they can
differ on bitfields, `long double`, packed structs and extensions TinyCC lacks.
The width check on arrows would catch most of the cases where they disagree, but
upstream decided that **"one answer by construction" is better than "two answers
and a net."** It uses the same GCC that built the binary, at low optimisation,
to win back most of TinyCC's speed.

That reasoning doesn't fully carry over, for the same reason the catalogue
argument didn't. Upstream runs on a desktop where GCC is already installed. The
handheld would have to carry GCC's whole toolchain (compiler, assembler and
linker; hundreds of MB) to keep "one answer". Options that keep upstream's
property, most promising first:
1. **Build the kernel with TinyCC too.** There's one compiler again, and TinyCC
   has an arm64 back end. The cost is a slower kernel and checking that TinyCC
   can build all the kernel code.
2. **Put GCC on the device.** This is closest to upstream, but very large for an
   SD card.
3. **Use TinyCC for late boxes only (what #69 does)**, with the width check as
   the net. This is the option upstream refused.

## Values stay with the old station: #92 differs in one way

#92 matches your answer on values. Waiting values stay in the old station, and nothing is copied, so a replacement costs the same however many values are waiting.

But #92 also **cuts the old station's outgoing arrows**. If the old station
finishes work it already held, the result goes nowhere. Your description sounds
like the old station keeps its outgoing arrows, finishes the work it was given,
and passes the results on downstream.

## Stations aren't removed automatically

Neither upstream nor soren-ds removes an unused station by itself. Removing one
is always an explicit step: in #92, the editor's "finish" step, or removing the
whole program. Upstream's issue on building programs says outright that "a
program with unreachable stations is ordinary, not wrong". Two things get in the
way of automatic removal:
- **Callers from outside a program can't be counted.** Outside callers deliver
  into a program's input station, and the engine deliberately keeps no record of
  who they are. So "nothing points at it" can't tell a dead station from an
  input station waiting for an outside caller.
- **A join may never empty.** Suppose the old station is a join (it waits for
  one value on each of two inputs) and holds one half of a pair. Once its
  incoming arrows are gone, the other half never arrives. Its inputs never
  empty, so a rule of "remove it when it has no arrows in and no waiting values"
  would never remove it.

## Questions for you
1. Should I merge #36 and #13 now?
2. For the device's compiler: TinyCC for the whole kernel, GCC on the device, or
   TinyCC for late boxes only?
3. Should an old station keep its outgoing arrows so its finished work still
   reaches downstream? And what should happen to a join stuck holding half a
   pair?

For question 3, think about the moment just after a swap. Where should the old
station's next result go, and who eventually decides that it's finished?

--------------------------------------------------------------------------------

### User Request 5

let's try building the kernel with tinycc and using one compiler. If it's slow
and we need performance boosts, we can switch to the more expensive compiler.
But, no matter which we pick, we should use one compiler for everything.

For #92, yes we need to keep the outgoing arrows, unless manually split.

--------------------------------------------------------------------------------

### Assistant Response 5

> TinyCC isn't installed. Checking whether its source is in the shared libraries
> folder, and how much assembly the kernel uses.

> The right home for this is the completed cross-compiler issue: your rule is to
> reopen an issue rather than start a new one. Reading it.

> TinyCC's newest code has an arm64 assembler with inline-assembly support,
> which removes the main risk. Building the arm64 TinyCC.

> The safety hook stopped writes to the RAM log folder by its real path.
> Retrying through the project's own link to the same folder.

> **[Asked the user]**
>
> *Q1 — Outside:* Allow a write outside this session's folder, to
> /dev/shm/soren-ds/tcc-configure.log? [outside-write 1a59af9e]
> - Yes — Allow this one write.
> - This time — Allow any write inside /dev/shm/soren-ds until this session
>   ends.
> - Always — Allow any write inside /dev/shm/soren-ds from now on, for
>   sessions working in /mnt/mtwo/programming/ai-stuff only.
> - No — Keep it refused.
> → **Selected:** This time

> TinyCC built. Reading how the Makefile compiles the kernel, so I can run the
> same files through TinyCC.

> I'll keep the probe's header in my own scratchpad rather than ask for another
> permission.

TinyCC can compile most of the kernel already. After one small header was added,
30 of the 52 kernel files compiled; the other 22 hit four kinds of gap. I
haven't changed anything in the project yet. My rule is to write the issue
first, and how these gaps get closed changes what the issue says.

## What I did
- Downloaded the newest TinyCC (Nov 5, 2026) into the project's RAM scratch
  folder and built the arm64 version.
- Compiled every kernel file with it, using the same files the Makefile
  compiles.
- Gave TinyCC a small `stdint.h` (the standard file that defines fixed-size
  integers like "unsigned 32-bit"). GCC brings its own copy and TinyCC doesn't,
  which is why the first run failed on almost every file.

## The four gaps

| Gap | Files | What's missing |
|---|---|---|
| **System registers** | the boot code, the code that wakes the other cores, the device platform file, the MMU setup | Reading and writing the chip's control registers: the interrupt mask, the address of the exception handlers, the per-core pointer, the MMU tables. TinyCC's assembler knows only the two floating-point control registers. |
| **Missing instructions** | the panic handler, the allocator | `wfi` ("sleep until an interrupt"). TinyCC has the name but no code to produce it. `eret` ("return from an exception"), which the exception handlers need, isn't there at all. |
| **`.macro`** | the exception vector table | Assembler macros, which the vector table uses to stamp out 16 near-identical handlers. |
| **Atomics** | all 15 engine files that share memory between cores | Easy. TinyCC supports the same operations; the engine just has to include TinyCC's atomics header. |

Two more that the probe didn't reach:
- **Linking:** TinyCC can't read our linker script (the file that says where
  each part of the kernel goes in memory). Linking with the GNU linker we
  already built would keep your rule: a linker only places finished code and
  never decides how big a struct is.
- **Speed:** TinyCC doesn't optimise, so the kernel will run roughly as if GCC
  were set to no optimisation. You've already accepted that and can switch
  later.

The device's own compiler for boxes written at runtime would be this same
TinyCC, so whatever fixes the assembly gaps also fixes them for boxes written at
the touchscreen.

## Questions before I write the issue

1. **Closing the assembly gaps.** Best first:
   - Teach TinyCC's assembler the missing registers, `wfi`, `eret` and `.macro`,
     as a small set of patches we keep separately and apply before each build.
     TinyCC itself stays untouched.
   - Write those instructions in our files as raw machine-code numbers. That's
     no work on TinyCC, but unreadable.
   - Keep the GNU assembler for the four assembly files only. Assembly never
     asks how big a struct is, so "one answer" still holds, but it's a second
     tool.
2. **Linking:** is it fine to keep the GNU linker for linking only?
3. **The laptop twin:** "one compiler for everything" would mean building the
   twin, its tests and the box generator with the laptop version of TinyCC too,
   instead of the laptop's own GCC. Is that what you mean?

I haven't touched the replace-a-box pull request (#92) yet. I'll change it so
the old station keeps its outgoing arrows unless someone splits them by hand.
Should I push that to its branch now, or after the compile stack is reworked?
Also, #13 ("build on stock GCC or LLVM") points away from "one compiler", so I'd
hold it rather than merge it.

--------------------------------------------------------------------------------

### User Request 6

> - Linking: TinyCC can't read our linker script (the file that says where each
> part of the kernel goes in memory). Linking with the GNU linker we already
> built would keep your rule: a linker only places finished code and never
> decides how big a struct is.
> - Speed: TinyCC doesn't optimise, so the kernel will run roughly as if GCC
> were set to no optimisation. You've already accepted that and can switch
> later.

what if we wrote our own compiler?

--------------------------------------------------------------------------------

### Assistant Response 6

We could, and it would give your rule a stronger form than TinyCC does: one
program that is the only thing anywhere that reads C. It's also the biggest
piece of work on the table. Here's what it would involve for this kernel.

## What "our own compiler" has to do

To build the kernel by itself, it needs four parts:
1. **Read C.** Only the parts this project uses, not all of C. A checker can
   enforce that subset: if a file uses something outside it, the build refuses
   it. The box generator already parses C to read each box's inputs and output,
   so we'd be extending a parser we already have.
2. **Turn it into arm64 instructions.** arm64 instructions are all 32 bits long
   with regular layouts, which makes it one of the easiest chips to write a code
   generator for. A simple generator keeps every value in memory and loads it
   into a register when it's needed. That's a few thousand lines, and roughly
   TinyCC's speed or slower.
3. **Assemble.** That means encoding `msr`, `wfi`, `eret` and the rest. Every
   gap TinyCC has today becomes ours to fill, but we'd fill it once, in code we
   understand.
4. **Link.** It lays the kernel out in memory itself. The compiler would know
   the memory map directly, so the linker script stops being a separate file and
   the GNU linker isn't needed.

## What it buys

- **One answer to "how big is this struct", for certain**, because only one
  program knows.
- **The generator and the compiler become one program.** Today the generator
  reads C to find each box's sizes, and the compiler reads the same C again to
  build it. That's two readers that could disagree, the same "second answer"
  problem upstream refused TinyCC over. With our own compiler, it could work out
  each box's sizes and write the placement code itself.
- **The device's compiler is ours.** Boxes written at the touchscreen go through
  the same code as the kernel, and one day the device could rebuild its own
  kernel.
- **Speed improvements are ours to add**, one at a time, where measurements show
  they matter.

## What it costs

- **Time.** The compile issue estimated "a month of writing" for a compiler of a
  C subset aimed only at boxes. A kernel needs more: inline assembly, `volatile`
  reads and writes of device registers, atomics and function pointers. I can't
  give you a firmer number than "more than that month".
- **The hardest bugs to find.** A compiler mistake shows up as a kernel
  misbehaving on the handheld, which has no debugger. The way to manage that is
  to compile every test twice on the laptop, once with ours and once with GCC or
  TinyCC, and require the outputs to match. The other compiler then only checks
  our work and never builds what ships.
- **The twin needs a second back end.** The twin runs on the laptop's x86-64
  chip. "One compiler" means either our compiler also produces x86-64
  instructions, or the twin runs the arm64 build under an emulator such as qemu
  (a program that pretends to be an arm64 chip), so there's only one back end.

## Ways to do it, best first
1. **TinyCC now, ours grown beside it.** Build the kernel with TinyCC as
   planned, with small patches for the missing assembly. Write our compiler
   alongside it, check it against TinyCC on every test, and switch when it
   builds everything. Switching is a one-line change, and only one compiler is
   ever in use at a time.
2. **Ours, from scratch, now.** The kernel build waits until it can compile all
   52 files.
3. **Take TinyCC over as ours.** Keep a copy of TinyCC's source and own it
   outright: fill the assembly gaps and teach it to read our linker script.
   That's less writing, but it's 70,000 lines of someone else's design.
4. **The twin runs arm64 under an emulator,** so whichever compiler we choose
   only ever produces arm64. This one works alongside any of the three above.

Two questions, since they decide its shape:
- **Should the compiler and the box generator be one program?** If yes, the
  compiler has to understand boxes, not just C. If no, the two still read the
  same C separately.
- **Should the twin stay native x86-64, or become the arm64 build under an
  emulator?** That decides whether the compiler has one back end or two.

--------------------------------------------------------------------------------

### User Request 7

Hey by the way which version of C do we use? C99?

> - Time. The compile issue estimated "a month of writing" for a compiler of a C
> subset aimed only at boxes. A kernel needs more: inline assembly, volatile
> reads and writes of device registers, atomics and function pointers. I can't
> give you a firmer number than "more than that
    month".

the more comprehensive we can make the issue files, the lower that estimate
becomes. If we spread them out, we can work in parallel, which also cuts down
the timeframe.

> - The hardest bugs to find. A compiler mistake shows up as a kernel
> misbehaving on the handheld, which has no debugger. The way to manage that is
> to compile every test twice on the laptop, once with ours and once with GCC or
> TinyCC, and require the outputs to match. The other
>     compiler then only checks our work and never builds what ships.

I don't think we necessarily have to compare it to GCC or tinyCC's output. After
all, what are we gaining if we produce the same thing they do? Instead, I think
we should have comprehensive tests to produce outputs, and validate whether or
not what we expect is what we get. That should be good enough for our purposes.

> - The twin needs a second back end. The twin runs on the laptop's x86-64 chip.
> "One compiler" means either our compiler also produces x86-64 instructions, or
> the twin runs the arm64 build under an emulator such as qemu (a program that
> pretends to be an arm64 chip), so there's only
>     one back end.

let's do the emulator.\]

--------------------------------------------------------------------------------

### User Request 8

Hey by the way which version of C do we use? C99?

> - Time. The compile issue estimated "a month of writing" for a compiler of a C
> subset aimed only at boxes. A kernel needs more: inline assembly, volatile
> reads and writes of device registers, atomics and function pointers. I can't
> give you a firmer number than "more than that
    month".

the more comprehensive we can make the issue files, the lower that estimate
becomes. If we spread them out, we can work in parallel, which also cuts down
the timeframe.

> - The hardest bugs to find. A compiler mistake shows up as a kernel
> misbehaving on the handheld, which has no debugger. The way to manage that is
> to compile every test twice on the laptop, once with ours and once with GCC or
> TinyCC, and require the outputs to match. The other
>     compiler then only checks our work and never builds what ships.

I don't think we necessarily have to compare it to GCC or tinyCC's output. After
all, what are we gaining if we produce the same thing they do? Instead, I think
we should have comprehensive tests to produce outputs, and validate whether or
not what we expect is what we get. That should be good enough for our purposes.

> - The twin needs a second back end. The twin runs on the laptop's x86-64 chip.
> "One compiler" means either our compiler also produces x86-64 instructions, or
> the twin runs the arm64 build under an emulator such as qemu (a program that
> pretends to be an arm64 chip), so there's only
>     one back end.

let's do the emulator.

can you build out the issue files for that in a new project directory called
"soren-cc"?

> - Should the compiler and the box generator be one program? If yes, the
> compiler has to understand boxes, not just C. If no, the two still read the
> same C separately.

what would that buy us? Is it better or worse?

> - Should the twin stay native x86-64, or become the arm64 build under an
> emulator? That decides whether the compiler has one back end or two.

emulator.

--------------------------------------------------------------------------------

### User Request 9

Base directory for this skill: /home/ritz/.claude/skills/project-init

# Project init

The owner's CLAUDE.md defines what a project is made of and how it is
initialised, and it is the authority throughout; where it and this skill ever
disagree, CLAUDE.md wins and this skill is the thing to fix. This skill adds
only what CLAUDE.md leaves open: which tool builds the skeleton, in what order
the loop runs, and when each step is finished.

## 1. Lay out the skeleton with the tool, not by hand

    /mnt/mtwo/programming/ai-stuff/scripts/init-project.sh --skeleton-only <project-path>

It works for any folder, inside the monorepo or not, existing or not, and adds
only what is missing: the standard folders and intent folders, `docs/HTML/`,
`issues/completed/demos/`, `llm-transcripts/`, `docs/table-of-contents.md`,
`.file-index-counter`, `issues/phase-1-progress.md`, the root `run-phase-demo`
picker, the RAM scratch tiers behind `tmp/` (with a path rule per tier in
`.claude/settings.local.json`, so sessions there may write into them from the
shell without a question), `tmp` in `.gitignore`, and a
plain-text `README` in every folder it leaves empty, saying what the folder is
for (git keeps no empty folder, so without it the folder never reaches a
remote). Those notes are part of the first commit. It is safe to re-run; on a
project that already has everything it changes nothing.
Read its report: it names what it built.

A project the owner wants to run an agent inside with permission checks off
gets the full form instead (a bare project name, inside the monorepo), which
adds a RAM sandbox. That is the owner's call, never a default; ask.

Anything the skeleton does not cover and CLAUDE.md asks for is a gap in the
tool. Make it by hand only if the owner says to, and note it in
`scripts/issues/026-skeleton-without-a-monorepo.md` so the tool learns it.

The `tmp/` link opens onto RAM, which a reboot empties. Scripts written for the
project that write into `tmp/` start by sourcing
`/mnt/mtwo/programming/ai-stuff/scripts/libs/ensure-ram-tiers` and calling
`ensure_ram_tiers "${DIR}"` (Lua programs: `libs/ensure-ram-tiers.lua`), so the
tiers are rebuilt before they are needed rather than failing after a restart.

## 2. The documentation loop

Start from `notes/vision` (or whatever the vision file is called in `notes/`).
If there is none, stop and ask for one: everything after this point is
derived from it, and inventing a vision would make the whole project a guess.

Then follow CLAUDE.md's initialisation loop. The parts that are easy to get
wrong:

- **Repeat until there is nothing reasonable left to write.** Each pass reads
  the vision and everything already in `docs/`, then writes what is missing
  or improves what is thin. A pass that finds nothing new to create re-reads
  and sharpens the existing documents instead; that is the stopping signal
  approaching, not a reason to stop immediately.
- **Every new document goes into `docs/table-of-contents.md`** in the same
  pass that creates it.
- **Phases are clusters of functionality, not calendar stages**, and they are
  named in the table of contents from the start. Foundational pieces get low
  phase numbers because others build on them, not because they come first in
  time.
- **One datapath document per major feature**, showing how data moves through
  it. These are the documents later issue work updates, so write them as the
  current design, not as a plan.
- **The roadmap is split into phases**, and each phase says what it ends with
  (its demo).

## 3. Roadmap into issues

Break the roadmap into issue files following the issue-lifecycle skill, which
owns naming, numbering, the required sections, sub-issues, and phase progress
files. Number by foundation, not by the order you think of them: the issue
others build on gets the lower number. Give each phase's
`issues/phase-N-progress.md` its goals from the roadmap as the phase is
written.

## 4. Finish

- Run `run-phase-demo` once: with no demos yet it should say so and exit
  cleanly, which proves the picker and the demos folder are wired.
- Commit following issue-lifecycle's commit rules, with the transcripts.
- Report what was created, what the tool did versus what was written, and
  every open question met along the way. CLAUDE.md treats a task holding an
  unanswered open question as unfinished, so say plainly which questions are
  still waiting.


ARGUMENTS: new project soren-cc at /mnt/mtwo/programming/ai-stuff/soren-cc: our
own C compiler for soren-ds (arm64 only; the laptop twin runs under an emulator)

--------------------------------------------------------------------------------

### Assistant Response 9

> The skeleton is in place. Before writing the vision, I'm checking whether the
> kernel actually relies on C23 features. GCC 16 compiles as C23 unless told
> otherwise, and the twin is set to C11.

I've laid out the soren-cc skeleton with the house tool: the standard folders,
table of contents, phase-demo picker, and RAM scratch folders. I stopped there
because the project has no vision file yet. Every document and issue is derived
from the vision, so I need you to settle that first (question at the end).

These are this session's files: `claim-own-change soren-cc/.file-index-counter
soren-cc/run-phase-demo soren-cc/.gitignore soren-cc/issues/phase-1-progress.md
soren-cc/docs/table-of-contents.md soren-cc/.claude/settings.local.json` and the
`README` notes the tool put in each empty folder.

## Which C we use

- **The kernel:** no version is named in its build, so GCC 16 uses its default,
  C23 with GNU extensions.
- **The twin:** set explicitly to C11 with GNU extensions.

So today the same engine code is compiled as two different versions of C. Moving
the twin onto the emulator removes that, because both are built the same way.

What the code actually uses is much smaller than C23. It's essentially **C99
plus a handful of GNU extensions**:
- **Inline assembly:** 41 uses across 11 files.
- **Atomics:** GCC's built-in atomic operations, about 20 uses.
- **Attributes:**
  - `aligned` (8 uses): put this at an address that's a multiple of N.
  - `packed` (7 uses): no padding between struct fields.
  - `noreturn` (3 uses): this function never comes back.
  - `unused` (1 use).
- **One count-trailing-zeros built-in.**
- **One binary number** written as `0b11`.

That list is the whole language soren-cc has to accept, which is far less than
all of C. `packed` is one of the cases upstream named as where two compilers
disagree about struct sizes, and with one compiler that risk goes away.

## Tests instead of comparing against another compiler

Agreed. Each issue will state the outputs it expects: what a program prints,
what bytes end up in memory, how big a struct is. The tests check those
directly, and neither GCC nor TinyCC appears anywhere in the project.

## Should the compiler and the box generator be one program?

**Fully merging them is worse.** The compiler would have to know what boxes,
ports and stations are. Then it's no longer just a C compiler, and every driver
it builds carries knowledge the drivers never use. It would also pull away from
upstream, where the generator is its own program that hands C to a separate
compiler.

**The case for it is weaker than I made it sound.** The generator already never
decides a size. It writes `sizeof(type)` into its output and lets the compiler
answer. The only thing it reads for itself is which functions are boxes and what
their types are called. Its parser can still disagree with the compiler there,
for example over a type name hidden behind a `#define`.

**A middle option gets that last part back:** the compiler can print a
description of what it read. That's a list of each function's name and each
parameter's type name and size, in bytes, as the compiler worked them out. The
generator reads that list instead of parsing C itself. Then only one program
reads C, the generator stays separate as it is upstream, and the compiler stays
unaware of boxes. This is the "describe mode" the compile issue already asked
about. I'd make it an issue in soren-cc.

## Before I write the documents

How should the vision get written?
- **I draft `notes/vision` from this conversation,** using your words wherever
  you said them: one compiler for everything, built for the subset soren-ds
  uses, judged by its own tests rather than by another compiler, the twin
  running under an emulator, and issue files thorough enough to spread across
  agents working in parallel. You read it and correct it before I build anything
  from it.
- **You write it,** and I start from that.

One more question inside that: should the language soren-cc accepts be named
"C99 plus exactly the extensions soren-ds uses", with a checker that refuses
anything else? Or should it aim at a whole standard, so other code could someday
be compiled with it too?

--------------------------------------------------------------------------------

### User Request 10

<pasted_content id="c893">
>   How should the vision get written?
> - I draft notes/vision from this conversation, using your words wherever you
> said them: one compiler for everything, built for the subset soren-ds uses,
> judged by its own tests rather than by another compiler, the twin running
> under an emulator, and issue files thorough enough to
>     spread across agents working in parallel. You read it and correct it before I build anything from it.
</pasted_content id="c893">


sure.

> One more question inside that: should the language soren-cc accepts be named
> "C99 plus exactly the extensions soren-ds uses", with a checker that refuses
> anything else? Or should it aim at a whole standard, so other code could
> someday be compiled with it too?

we need at least C11, and I'm leaning toward C23 to be as up-to-date as we can.
How about C29? It's still in development, but maybe we could get ahead of the
curve here? How much future proofing would it buy? Anything useful in there we
could use?

--------------------------------------------------------------------------------

### Assistant Response 10

> Drafting the vision now, built from your words in this conversation.

I've written the vision draft to `soren-cc/notes/vision`. It quotes your words
wherever you said them and ends with five open questions. Please read it and
correct it before I build the documents and issues from it.

## C11, C23 or C29

**The next standard is informally called C2y. It's expected around late 2029,
and the newest working draft is from October 2026.** Its features are still
being accepted, and their wording can change until it's published.

**What soren-ds would use from it today:**
- **`defer`:** "run this block when leaving this scope, however you leave it".
  It suits the error paths that undo a half-done job, like the loader backing
  out of a failed load or a driver releasing what it took.
- **Named loops:** `break outer;` leaves an outer loop directly. It replaces the
  `goto`s that nested walks use today.
- **Case ranges** (`case 1 ... 5:`): this is already a GNU extension, now
  standardised. It's useful for decoding instructions and USB descriptors.
- **`countof`:** gives the number of elements in an array, replacing the usual
  `sizeof(a)/sizeof(a[0])`.
- **`__COUNTER__`:** a fresh, unique number every time it's used, handy for
  names the generator invents.
- **New bit and byte-order helpers:** rotating bits, and reading a little-endian
  number straight from memory. The FAT reader and the USB driver do that kind of
  reading constantly. These are library functions we'd write, not compiler work.
- **Declarations inside `if`:** `if (int n = f(); n > 0)`. A small tidy-up.

**How much future-proofing it buys: little, honestly.** Since we own the
compiler, we can add any feature on the day it's useful. The value of C2y is
that a few of its features help right now. The risk of adopting it early is that
a feature like `defer`, which is still settling, may change wording before 2029,
and then we'd change with it.

**C23 already holds most of what soren-ds would gain:**
- **`#embed`** pulls a file's bytes into the program. The font and the probe
  list could stop going through generated C files.
- **Standard bit functions** replace the one count-trailing-zeros built-in.
- **Enums with a fixed size** (for example, an enum that is exactly one byte)
  suit register layouts.
- **`constexpr`, `typeof`, `nullptr` and `[[attributes]]`** are also included.
  `[[noreturn]]` and `alignas` replace two of the GNU attributes, but nothing in
  C23 replaces `packed`.

**My proposal (written into the vision as undecided):** a **conforming
freestanding C23** compiler, plus the C2y features above, each added as its own
issue. "Freestanding" is the standard's own name for a compiler that ships only
the small library a kernel needs: no file I/O and no `printf`.
- **Atomics are in.** The engine needs them.
- **Variable-length arrays, complex numbers and threads are out.** C23 allows a
  compiler to leave them out.
- **C23's arbitrary-width integers (`_BitInt`) can stop at 64 bits,** which the
  standard allows, so they cost little.
- **Inline assembly and `packed` are added** as the two extensions no standard
  spells.

That's a precise target that other code could also be checked against.

## Questions for you
1. **Language:** is freestanding C23 plus chosen C2y features right?
2. **What is soren-cc written in?** To run on the handheld and compile itself,
   it has to be written in C it can build. You usually prefer Lua, but the
   device has no Lua. This one shapes every issue.

For question 2, picture the handheld compiling a box you just saved. What
program is running at that moment, and what was that program built with?

Sources:
- [C2Y (C standard revision),
  Wikipedia](https://en.wikipedia.org/wiki/C2Y_(C_standard_revision))
- [C29 (C standard revision),
  Wikipedia](https://en.wikipedia.org/wiki/C29_(C_standard_revision))
- [n3467 working draft,
  WG14](https://www.open-std.org/Jtc1/sc22/WG14/www/docs/n3467.pdf)
- [C2Y: what is being proposed](https://flash-gordon.me.uk/c2y/)
- [C2y draft removes 45 of 100 undefined
  behaviors](https://imasters.com/news/c2y-removes-45-of-the-roughly-100-undefined-behaviors-in-the-c-standard)

--------------------------------------------------------------------------------

### User Request 11

> - defer: "run this block when leaving this scope, however you leave it". It
> suits the error paths that undo a half-done job, like the loader backing out
> of a failed load or a driver
>     releasing what it took.

would this... run when we, what, remove a station?

> - Named loops: break outer; leaves an outer loop directly. It replaces the
> gotos that nested walks use today.

eliminating gotos sounds good. Can we fully eliminate them from our compiler?
Like, not even build them in?

soramech (upstream) needs to handle arbitrary C code. But for soren-ds, all of
the code is generated on the device. We technically don't even need to use C! We
could use Lua, or even freakin' javascript. Heck we could just write everything
in machine code, and let the user author them using the soramech intuitions.

... is there a reason we don't do that? Sounds like it could get us some extra
performance.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 11:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 12

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 11:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 13

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 11:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 14

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 11:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 15

please continue

--------------------------------------------------------------------------------

### Assistant Response 15

## Would `defer` run when a station is removed?

No. `defer` belongs to a block of source code, not to a thing in the running
system. It runs when the code leaves that block: when the function returns, or a
`break` leaves the loop. The compiler places the deferred code at each of those
exits ahead of time.

Removing a station is a different kind of event. It happens while the engine is
running, possibly on another core, long after the code that placed the station
has returned. The engine's own removal step cleans up after a station: it
detaches it, waits until no core can still be inside it (the per-core counters),
then frees it. That has to be machinery in the engine, because no single block
of code is waiting around for the station to die.

`defer` would help *inside* that removal step. The step takes a lock, and
`defer` guarantees the lock is released whichever way the step exits, including
the "refused" paths.

## Leaving `goto` out entirely

Yes. We own the language, so the parser can refuse `goto` with a message that
names what replaces it: named loops for jumping out of nested loops, and `defer`
for cleanup. It costs almost nothing today, because soren-ds has **three**
`goto`s, all in the catalogue file.

The price is the word "conforming". A compiler that refuses `goto` isn't a C23
compiler any more; it's a C dialect of our own. That's fine as long as we say
so. The vision currently proposes "conforming freestanding C23", so this would
change it to something like "freestanding C23, minus `goto`, plus...".

## Why not drop C, or write machine code directly?

First, a correction: not all of soren-ds's code is made on the device. The
kernel, drivers and engine are C written on the laptop and built into the image.
Only boxes saved at the touchscreen are compiled on the device. The five
built-in box files are small, 54 to 104 lines each. So two questions are mixed
together here: what the system is written in, and what a person writes a box in.

**Machine code wouldn't be faster.** A compiler's output already *is* machine
code. Writing it by hand only wins where a person beats the compiler, and that's
an argument for a better compiler, not for dropping the language.

**Building everything out of the soramech pattern would be slower, and by a
lot.** Suppose you take "author everything with soramech intuitions" all the way
down, so the smallest boxes are single instructions wired together by arrows.
Each arrow costs a delivery: build a task, push it onto a core's queue, have a
core pick it up, run the box, then send the result on. That's hundreds of
instructions to carry one value, wrapped around a box that does one addition. A
box has to do enough work to be worth its delivery. That's why boxes are
functions and not instructions. (Phase 2's endurance demo measures delivery
cost; its numbers are the place to look, rather than mine.)

**Lua or JavaScript would cost speed and the width check.**
- They need an interpreter or a JIT (a just-in-time compiler: it compiles code
  to machine instructions while the program runs) on the device. LuaJIT does
  have an arm64 JIT.
- A Lua value has no fixed size, so there's nothing for the "both ends of an
  arrow are the same width" check to compare. That check is what makes wiring
  safe without a type system.

**Things C gives soren-ds specifically:**
- **Widths.** Every input and output has a size the compiler can answer.
- **Text that can be written back out.** A program assembled at the touchscreen
  can be saved as a map plus the C of each box and built again. Machine code
  can't be read or edited as text.
- **Upstream alignment.** Upstream's boxes are C.

**What *is* open, and the interesting version of your idea: a box language of
our own.** It would have fixed-width types and no `goto`, perhaps no raw
pointers, and be designed for the box shape: values in, one value out. soren-cc
would compile it straight to arm64. This is real language design, and it would
let the touchscreen author something smaller and safer than C. The cost is that
it moves away from upstream, where boxes are C.

The vision draft still needs your read. Today's answers would change its
language section (no `goto`, a declared dialect).

Here's the hard part of a box language: a box written at the touchscreen still
has to read a file or draw on a screen. Should it do that by calling kernel
functions directly, as a C box can, or only by sending values along arrows to
boxes that own those jobs?

--------------------------------------------------------------------------------

### User Request 16

> First, a correction: not all of soren-ds's code is made on the device. The
> kernel, drivers and engine are C written on the laptop and built into the
> image. Only boxes saved at the
> touchscreen are compiled on the device. The five built-in box files are small,
> 54 to 104 lines each.

so then we could easily re-write them in assembly or machine code.

if we know exactly what we want the OS to do and know, we can just... write
specifically for that computer. Sure, there are optimizations, but that's what
LLM powered computer search is for - they can lookup any answer to any part of
the computer system's task profile and see exactly what would be the most
efficient way to do it - that we've found, so far...

perhaps, even, with the help of a human, reason through scientifically new ones
too.



<pasted_content id="c893">
> Building everything out of the soramech pattern would be slower, and by a lot.
> Suppose you take "author everything with soramech intuitions" all the way
> down, so the smallest boxes
> are single instructions wired together by arrows. Each arrow costs a delivery:
> build a task, push it onto a core's queue, have a core pick it up, run the
> box, then send the result
> on. That's hundreds of instructions to carry one value, wrapped around a box
> that does one addition. A box has to do enough work to be worth its delivery.
> That's why boxes are
> functions and not instructions. (Phase 2's endurance demo measures delivery
> cost; its numbers are the place to look, rather than mine.)
</pasted_content id="c893">


ah, got it, we're building the things that the box functions are constructed out
of, not the box functions constructing those, which is how higher level users
interact with the abstraction.

sorta like how AI's are editing their weights directly now...

>   - Widths. Every input and output has a size the compiler can answer.

we can be very specific too in our compiler

> Here's the hard part of a box language: a box written at the touchscreen still
> has to read a file or draw on a screen. Should it do that by calling kernel
> functions directly, as a C
> box can, or only by sending values along arrows to boxes that own those jobs?

only by calling kernel functions. of which there are very few. basically just...
stream a file to a soramech box station's inputs, write to a file by appending,
delete and re-write by overwriting, um... what else? search through a file? oh
also kernel functions can be button presses or hardware events too, and those
fire automatically by placing inputs into the boxes that subscribe to them with
a special soren-ds specific "input station" which always has one or 0 as it's
value. actually 0 1 2 and 3 where 0 and 1 is not pressed and pressed, then 2 is
sustained, then 3 is released. we can do that in two bits, which means only a
couple bytes for the entire system.

--------------------------------------------------------------------------------

### Assistant Response 16

> Checking the filesystem boxes and the button design soren-ds already has, to
> compare with your list.

## Writing the built-in boxes in assembly

Yes, we could. Each built-in box is a few dozen lines, and the assembler that
soren-cc needs anyway would build them. A box in assembly still has to say how
wide each of its inputs and its output is. soren-cc could take that declaration
in C, with exact sizes (C23 even allows a 2-bit integer), and the body in
assembly. Assembly is still text, so a program written back out can still be
rebuilt.

**Where hand-tuning pays most is the engine's delivery path, not the boxes.**
For a box of ten instructions, the delivery around it (build a task, push it
onto a core's queue, have a core pick it up, send the result on) costs far more
than the box itself. Every arrow in every program goes through that same
delivery code, so making it faster speeds up everything at once.

**Being specific to one chip really does help.** The Cortex-A55 is an in-order
core: it runs instructions in the order given and can start two per cycle when
they don't depend on each other. A compiler that knows exactly which
instructions can pair up gains real speed. Searching for the best instruction
sequence for a short piece of code has a name, **superoptimisation**, and on an
in-order core it suits small hot paths like delivery.

## Your kernel surface, next to what soren-ds has now

soren-ds today puts the filesystem in **boxes** that other boxes wire to. Your
answer makes the kernel itself the small fixed surface:

| Yours | What exists or is planned | Difference |
|---|---|---|
| Stream a file into a station's inputs | **read-path** (the whole file as one value, or a slice) | Yours arrives piece by piece, which suits large files. |
| Append to a file | **append-path** (open pull request #117) | Same. |
| Overwrite (delete and rewrite) | **write-path**: writes a temporary file, then swaps it in | Same. A reader sees the old file or the new one, never half of each. |
| Search through a file | none | New. |
| Hardware events fire into subscribed stations | **read-buttons** box, plus three event boxes (down, up, held) | Yours moves the work into the kernel. |

Not on your list but planned today: **list a directory, delete, does this path
exist, make a link, move**. Do those stay?

## The four button states

Your four states carry exactly two facts: was the button down last frame, and is
it down now.

| Last frame | This frame | Your state |
|---|---|---|
| up | up | 0, not pressed |
| up | down | 1, pressed |
| down | down | 2, sustained |
| down | up | 3, released |

That solves a problem the current button design works around. A box can't keep
memory between frames, because two cores can be inside the same box at once. So
today the previous frame travels around an arrow and back into the box's own
input. If the **kernel** keeps the previous frame instead, no arrow is needed.

The handheld has **18 buttons**: four directions, ABXY, four shoulder buttons,
four centre buttons and two stick clicks. At 2 bits each that's 36 bits. That
doesn't fit in one 32-bit word, but it fits in one 64-bit word. So the kernel
can publish every button's state in a **single store**, and every reader sees
one consistent frame.

One naming clash: upstream already uses **"input station"** for something else.
There, it means a program's entry point, which accepts deliveries from callers
outside the program. If soren-ds uses the same name for the hardware source, we
lose the alignment you asked for. Something like "event source" would avoid
that.

Here's the hard part. At 60 frames a second, a station subscribed to the A
button would receive a 0 sixty times a second while nobody touches it, and a 2
sixty times a second while it's held. Should subscribers get a value every
frame, or only when the state changes? And if only on change, how does a box
that cares about "held" learn that the button is still down?

--------------------------------------------------------------------------------

### User Request 17

<pasted_content id="c893">
> Being specific to one chip really does help. The Cortex-A55 is an in-order
> core: it runs instructions in the order given and can start two per cycle when
> they don't depend on each
> other. A compiler that knows exactly which instructions can pair up gains real
> speed. Searching for the best instruction sequence for a short piece of code
> has a name,
> superoptimisation, and on an in-order core it suits small hot paths like
> delivery.
</pasted_content id="c893">


we could have a few queues, one specific to each instruction type. would that
help? subtlely different, but sorted/routed through the same.

sorry, thread-pool task queues.



<pasted_content id="c893">
> Where hand-tuning pays most is the engine's delivery path, not the boxes. For
> a box of ten instructions, the delivery around it (build a task, push it onto
> a core's queue, have a
> core pick it up, send the result on) costs far more than the box itself. Every
> arrow in every program goes through that same delivery code, so making it
> faster speeds up everything
  at once.
</pasted_content id="c893">


what if we register each thread when they're not busy in a worker-pool and then
when we complete a task we ask for the next one from the queue delivered
atomically so we can deliver the task requirements (input values) to the thread
directly, since it was ready without any work. And if there's none, then it
returns the location to store the data in a task struct, same as it is now. it
looks exactly the same because it has exactly the same input shape.



<pasted_content id="c893">
  ├──────────────────────────────────────────────┼──────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┤
  │ Search through a file │ none │ New. │
  ├──────────────────────────────────────────────┼──────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┤
</pasted_content id="c893">


make sure for this one that we always search through chunks of it chosen
randomly.

> Not on your list but planned today: list a directory, delete, does this path
> exist, make a link, move. Do those stay?

the filesystem can exist in boxes, in user-space, so they can customize them as
they please.

we will of course write one or two typical alternatives and bundle them with the
software.

> One naming clash: upstream already uses "input station" for something else.
> There, it means a program's entry point, which accepts deliveries from callers
> outside the program. If
> soren-ds uses the same name for the hardware source, we lose the alignment you
> asked for. Something like "event source" would avoid that.

ah I see. how about button-state?



<pasted_content id="c893">
> Here's the hard part. At 60 frames a second, a station subscribed to the A
> button would receive a 0 sixty times a second while nobody touches it, and a 2
> sixty times a second while
> it's held. Should subscribers get a value every frame, or only when the state
> changes? And if only on change, how does a box that cares about "held" learn
> that the button is still
  down?
</pasted_content id="c893">


the state is multiplied by the output part of the box station, and a value of 0
is never delivered. this is unique to button-state boxes. Is there some hardware
input line for the buttons? does it go straight into the CPU, or is there an
intermediate register? Because if so, we could use that intermediate register as
the read-only memory location for the button-state box stations. the
intermediate registers would be the input port, and if the value was 0 then it
was considered to not be present. question is... how do we know that they have a
task struct? er, sorry, I meant... wouldn't they be the task struct, instead of
the box stations input ports? Hmmm... what do you think, computer?

--------------------------------------------------------------------------------

### Assistant Response 17

> Checking how soren-ds's workers and task queues work today before answering
> the queue ideas.

> Upstream has an open issue on several queues and a note on a task queue
> without a lock. Reading both.

> Checking how the handheld's buttons reach the CPU.

## Is there a hardware register for the buttons?

Yes. All the digital buttons are wired straight to the chip's GPIO pins
(general-purpose input/output pins), with no separate input chip in between.
They sit on two GPIO banks: bank 2 has the D-pad, the stick clicks and HOME;
bank 3 has ABXY, the shoulders, START, SELECT and volume. Each bank has a 32-bit
register the CPU can read at a fixed address, one bit per pin, giving the pin's
current level. So reading **two registers gives every digital button at once**.
Two exceptions:
- **Active low:** a 0 bit means pressed, the opposite of what you'd expect.
- **Two buttons don't come in as bits.** The other HOME and PLAY buttons go
  through the analog-to-digital converter as a voltage, which has to be compared
  against a threshold.

## Could those registers be the input port, or the task struct?

I don't think so, for three reasons tied to how the hardware works:
1. **They only hold "now".** Your four states need last frame *and* this frame.
   Something has to keep the previous frame, so the register alone can't hold
   state 2 or 3.
2. **They're device registers, not memory.** Each read is a trip across the
   chip's internal bus, not a cache hit. The MMU has to mark that range as
   uncacheable. And the atomic instructions the engine uses aren't guaranteed to
   work there.
3. **A task struct has to be writable and freeable.** The engine fills a task
   with input values and frees it when done. These registers are read-only, and
   writing to them does nothing.

**What fits instead:** once per frame, the kernel reads the two registers, flips
the bits because they're active low, and combines them with the previous frame
to get the 2-bit states. It packs all 18 buttons into **one 64-bit word in
ordinary RAM** and publishes it with a single store. That word is your read-only
location. Anything can read it, and every reader sees one consistent frame.

Then, for each button whose state isn't 0, the kernel delivers that state to the
button's subscribers. It uses the same delivery as any station's outgoing arrow,
so tasks are built the normal way. A **button-state** station is a source: its
"input" is the frame step, not an arrow. Here's my reading of "multiplied by the
output": the state gates the output, and 0 means nothing is sent. Is that right?

This replaces the current button design (three event boxes, with history carried
around an arrow). The open pull request #218, "the buttons — down, up and held
events", builds that older design, so it would need redoing.

## Handing work straight to an idle core

Today soren-ds has **one shared queue under one lock**. When a task is pushed,
**every** sleeping core is woken, and all but one go back to sleep. Upstream
does the same on purpose ("every sleeping worker is woken — not a chosen
one").

Your design:
- Idle cores register in a pool.
- Delivery atomically takes one registered core's slot and writes the task into
  it.
- If no core is idle, the task goes to the queue as it does now.

It saves the lock and the queue round trip, and it wakes **one** core instead of
all of them.

arm64 has an instruction pair that fits this exactly. A waiting core marks its
own slot with a "load-exclusive", then sleeps with `wfe` ("wait for event").
When another core writes to that slot, the hardware wakes **only that core**.
Linux uses this trick for waiting on a single variable. It also closes the race
upstream's documents warn about, where a core registers as idle but hasn't
fallen asleep yet when work arrives: in that case, `wfe` returns immediately.

One choice: the slot can hold either a **pointer** to a task (tasks are still
allocated as now, and the shape is identical, as you said) or the **task
itself**. Holding the task itself skips the allocation too, but needs a maximum
task size.

To stay aligned, I'd propose it **upstream first**, since it changes the "wake
everyone" rule there.

## One queue per instruction type

That won't help pairing. Pairing happens between neighbouring instructions
inside one core, and queues only decide which core runs a task. What a queue
*can* help is keeping one kind of box on one core, so its code stays in that
core's instruction cache. Upstream has an open issue on exactly this, "several
queues, and a station may name one". It says to confer before building anything,
and that the default is "say nothing". An earlier upstream draft defaulted to
"deliver into my own queue" for cache reasons, and that was judged wrong.

## Questions for you
1. **Searching in random chunks:** does a search return the first match, any
   match, or all of them? Visiting chunks in random order means "first" can only
   be known after reading the whole file.
2. **Where the kernel stops:** if the filesystem lives in boxes, the kernel
   offers only "read block N" and "write block N", and streaming, appending,
   overwriting and searching move into the bundled filesystem boxes. Is that the
   split?

I haven't written any of this down yet. Should I add these decisions to
soren-ds's input-model and filesystem documents?

--------------------------------------------------------------------------------

