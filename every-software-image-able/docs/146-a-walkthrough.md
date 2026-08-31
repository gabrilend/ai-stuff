# 146 — A walkthrough

Seven things in this project can be run by a person. This says what each one is,
what it asks, what comes back, and roughly how long you will be sitting there.

Everything here runs from any directory. Every one of them takes the project
root as an argument if the hard-coded path at the top of the script is wrong,
and none of them needs a computer plugged in.

## The seven

| | What it is for | Waits on you? |
|---|---|---|
| `./run-tests` | ask whether everything this project claims is still true | no |
| `./run-demo` | show what a finished phase produces, in numbers | one question |
| `luajit src/145-make-an-image.lua` | make a seed: a bootable image, from a recipe and a board | no |
| `luajit src/018-launch-board.lua` | boot an image, or a payload, on an emulated computer | no |
| `./watch-a-machine` | sit and watch one of those computers live, with a screen | several questions |
| `luajit src/147-describe-the-source.lua` | give every source file the companion page it should have | no |
| `luajit src/149-the-documentation-site.lua` | build everything written here into a site you can click through | no |

The first is what you run after being away. The fifth is the one worth doing
first if you have never seen the thing move. The last two rebuild the
documentation and are the fastest thing here.

---

## Ask whether everything still holds

```
./run-tests            everything
./run-tests --quick    skip the parts that boot emulated machines
```

It runs every test program in the project, prints a heading per program and a
count of what held inside it, and ends on one line saying whether anything
broke. It also writes that line to `output/goodbye`, because the last thing a
program should do is say goodbye somewhere a person can find it.

**The quick run takes a couple of minutes; the full run takes considerably
longer**, because the second half boots real firmware on three processor
architectures and waits for each machine to say something. The count of programs
is not the count of checks — each program holds many, and prints its own tally.

If something fails, the failing programs are named at the bottom. Run one on its
own the same way the script does: `luajit src/<name>.lua --dir <project root>`.

## Show what a phase produces

```
./run-demo          asks which one
./run-demo 5        goes straight to the fifth
./run-demo 5 --quick
```

It lists the demonstrations that exist, one per completed phase, with a line
each saying what it shows. The list is read from the demo files themselves, so
it is never out of date with them.

These are part of the deliverable rather than a development artifact, and they
are built to print real numbers — how fast the engine ran on a given board, how
many bytes of engine each architecture costs, how long from power to the first
word — rather than to describe features. Some take several minutes because they
boot machines; `--quick` after the number skips those parts.

## Make a seed

```
luajit src/145-make-an-image.lua --board qemu-uefi-x86-64
```

This is the front door, and it is the newest thing here. **A recipe, a board and
a model go in; an image, a manifest and an identity come out.** The image is the
thing you would put on a card.

| Option | Value | What it does |
|---|---|---|
| `--board` | name | which computer this image is for; required |
| `--recipe` | file | what the seed is; `input/example-recipe.lua` when unnamed |
| `--model` | file | a packed model; the fixture stands in and says so |
| `--to` | file | where the image goes; the RAM tier when unnamed |
| `--dir` | path | project root override |

It prints where every region landed, measured from the code's first byte,
because that is what the machine measures from — and then it prints the exact
command that will boot what it just made, which is the difference between a tool
that produced a file and a tool you can follow.

**Three files always, never only the image.** The manifest says what went into
it: the recipe, the board, the path the firmware will look under, the model, the
instruction and patterns, the random number and its seed, which engines rode
along, and the offsets. The identity is a short number anybody can arrive at
again from the same inputs — same recipe and same seed, same machine exactly.

**It decides nothing itself.** Every decision belongs to something else — the
part that writes out the machine, the compiler, the part that lays out where
things go, the part that puts the code in the envelope firmware will start, and
the part that writes a medium firmware can open. The front door exists so they
meet, and before it existed they could not.

## Boot what you made

```
luajit src/018-launch-board.lua <board> --medium <image> --memory plenty --seconds 120
```

The command the front door prints is already this. The machine's words land in
`tmp/shared-memory/logs/<board>-serial.log` — it says *first light*, then how
many weights it found and how much memory it has, then the words it chose, one
per line, and then *finished*. Nothing appears in your terminal unless you ask,
which is deliberate: every test here boots machines unattended, and a window
nobody asked for on a build machine is a hang rather than a picture.

Worth knowing about the options: `--stdio` puts the words in your terminal
instead of the log; `--watch` shows the machine's screen, in a window where
there is a display server and in your terminal where there is not; `--seconds`
kills it after that long, which is right for anything unattended; `--dry-run`
prints the emulator command and runs nothing, which is the fastest way to find
out what a board description actually means.

## Watch one live

```
./watch-a-machine
```

Everything is asked rather than passed, and every question has a default you can
press enter through. It asks **which machine** — six of them, three processor
architectures, some with modern firmware that hands over a screen and some with
none — and then **what it should run**, offering only payloads that suit that
board's firmware, because offering the wrong one produces a machine that sits
there looking exactly like a machine that broke.

**Two windows, deliberately.** The terminal you launched from carries what the
machine *says*. A second window carries what it *draws*. Those are different
channels on a real computer and they are different channels here.

**The machine has a disk and keeps it** — one file per board, on the RAM tier,
reused every run unless you ask for a fresh one. It will tell you how much has
been written to it before asking. Without that, every boot is the machine's
first, and the thing this project is about — writing yourself somewhere and
coming back to find it — cannot happen at all.

Nothing in the test suite uses this. It exists to be watched.

## Read the documentation instead of the files

```
luajit src/149-the-documentation-site.lua
```

Builds every document, note, strategem, ticket — open and completed — and the
companion page beside every source file into one cross-linked site at
`docs/HTML/`, then tells you which file to open. It needs nothing running, no
network, and no server: it is files on a disk, and it opens from a disk.

**The thing it has that the files do not is the direction of a reference.** On
disk, a ticket names the documents it depends on and there is no way to ask what
depends on *it* without searching the whole project. Every page here ends with
what points at it, as well as what it points at.

Down the left is everything, grouped and filtered by a box at the top. The front
page is counts and charts — tickets done per phase, which documents hold the most
writing, how the companion pages came to exist — all counted during the build
rather than written down, so none of it can go stale.

**Two lists at the end of a build are worth reading.** The first is every bare
number that means two things — where a ticket and a source file share a number,
the ticket wins, and each case is named rather than settled quietly. The second is
every reference in the project that reaches nothing at all.

```
luajit src/147-describe-the-source.lua --all
```

Gives a companion page to every source file that lacks one, by lifting the prose
each file already carries in its own comments — the summary, the plain-English
paragraph, the headed sections, the exported things with what they take and
return. **It will not touch a page somebody wrote by hand**, and it knows which
are which because it stamps the ones it makes. To improve a generated page, write
more in the source file's header and run it again.

---

## Where things land

Two directories, both in RAM, both created by anything that needs them:

- **`tmp/`** → `/tmp/every-software-image-able`, the executable tier: built
  payloads and anything that gets run.
- **`tmp/shared-memory/`** → `/dev/shm/every-software-image-able`, the artifact
  tier: `logs/` (what machines said), `images/` (what the front door built, with
  each image's manifest beside it), `disks/` (one per board, sparse, so an
  untouched disk costs nothing), `payloads/`.

Neither survives the host being switched off. That is correct for something you
are watching and wrong for something you are keeping, and it is worth knowing
which of those you are doing.

## Changing what gets built

The recipe in `input/` is what a seed *is*, and it never names a machine — that
separation is enforced by a check rather than by discipline. What it holds: which
architectures carry an engine and how wide a vector arrangement each assumes,
which model, which instruction and patterns and device descriptions ride along,
and how much randomness with which seed.

A different seed is a different file beside it. Point the front door at it with
`--recipe`.

## What none of this does

No machine here has been left alone to build anything. Everything above boots a
machine that reads what it was told, thinks, and says words — which is phases one
through five working, and is not the same as the thing the project is for. The
step where a machine finds a disk and installs itself has not been attempted, and
neither has running on a computer that is not emulated.
