# Conversation Summary: a8349c04-3cc4-4dac-a4bc-ea7e66a7dd07

Generated on: 2026-07-24 15:44:47

--------------------------------------------------------------------------------

### User Request 1

hi, can you build a new image for me so I can flash to the SD? We have some new
probes we need to gather info from.


--------------------------------------------------------------------------------

### Assistant Response 1

I'll help you build a new image. Let me first understand the project's build
process and what the new probes need.


Following the project convention, let me read the input files first, then
understand the build pipeline.


32 probe files are present. Now let me understand how probes get armed/embedded
and how the SD image is built. Let me look at the key scripts and check what's
changed recently.


Now I understand the full pipeline: `build --debug` embeds probes →
`build-bootable-sd` assembles the flashable image. The key detail is that probes
are **opt-in** now (issue 110n): a probe only runs if it carries `#NEEDED 1`.
Let me see which probes are "new" and which are actually armed, so the image
gathers what you expect.


The probe files are all committed (clean working tree there), so I'll build from
the current battery. One thing I want to flag up front: probes are **opt-in**
— only `#NEEDED 1` ones actually run. Seven `#AUTO` probes are currently
**de-selected** (`#NEEDED 0`) and won't gather anything: `saradc-gamepad`,
`dram-march`, `pwm-bringup`, `emmc-dll-tune`, `emmc-backup`, `emmc-dump`,
`emmc-scan`. If one of those is a "new probe" you're after, tell me and I'll arm
it.


Let me build the diagnostic kernel, then stitch the bootable SD image.


The `tmp/` symlink points to a RAM-backed dir that doesn't exist yet (a fresh
boot clears `/tmp`). Per project convention the build needs that target present.
Let me create it and retry.


The symlink target `/tmp/soren-ds` is gone (RAM-backed, cleared on reboot).
Creating it, then rebuilding.


Diagnostic kernel built — 31 probes embedded, **24 armed** and 7 de-selected.
Now stitching the bootable SD image.


Done. The flashable image is built and ready.


**`output/bootable-sd.img`** (285 MB) — a full Rockchip boot chain (idbloader + u-boot FIT + RG DS device tree) plus the diagnostic kernel with the probe battery compiled in.


**What it'll gather — 24 armed probes**, in sweep order:

`health-check · generic-timer · cpu-clock-recon · cpu-core-recon · gic ·
usb-phy · pmic-dump · pmic-write · pmic-ldo · i2c-scan · audio-codec ·
chip-otp · rng · crypto · display-presence · dram-walk · emmc-wear ·
emmc-extcsd · emmc-hs200 · emmc-hs400 · sd-capabilities · emmc-dma · sd-dma
· sd-speed`


**Two things worth a look before you flash:**

1. **One register-writing probe is armed and will run: `display-presence`**
(it's `#WRITES`). The other write-capable probes (`saradc-gamepad`,
`pwm-bringup`, `emmc-dll-tune`) are de-selected, so they stay dormant. If you
don't want any pokes this run, say so and I'll de-select it.

2. **7 probes are compiled in but de-selected** (won't gather):
`saradc-gamepad`, `dram-march`, `pwm-bringup`, `emmc-dll-tune`, `emmc-backup`,
`emmc-dump`, `emmc-scan`. If the "new probes" you're chasing are among these,
name them and I'll arm them (`#NEEDED 1`) and rebuild.


**Next step is yours** (the air-gapped part): `scripts/push-to-usb` to carry it across, then `scripts/lab-side/flash-sd` to write the microSD.


Which set matches the info you're trying to collect — is the current 24 right,
or should I arm any of the dormant ones first?


--------------------------------------------------------------------------------

### User Request 2

what does display-presence write to?


--------------------------------------------------------------------------------

### Assistant Response 2

Two writes, both to the **CRU (Clock & Reset Unit)** — not to the display
panel or any storage. It's ungating the display controller so it can then be
read:


| Write | Register | Address | Effect |

|---|---|---|---|

| `W 0xFDD20350 0x1FFC0000` | `CLKGATE_CON20` | `0xFDD20350` | Un-gates the VOP2
+ VO bus-interface clocks (bits 2..12 → 0 = on) |

| `W 0xFDD20440 0x01FF0000` | `SOFTRST_CON16` | `0xFDD20440` | Releases the VOP2
resets (bits 0..8 → 0 = released) |


Then it delays 20 µs and **reads** `VOP2_SYS_VERSION_INFO` at `0xFE040004`,
expecting `0x40158023` — that constant coming back is how it confirms the
display controller is powered, clocked, and out of reset.


A detail worth knowing about these two writes: RK3568 CRU registers use a
**write-mask convention** — the high 16 bits are a per-bit write-enable, the
low 16 bits are the values. So `0x1FFC0000` means "only touch bits 2..12, set
them to 0"; every other bit in that register is untouched. Same for `0x01FF0000`
(mask bits 0..8). So it's a surgical ungate, not a full-register overwrite.


Net effect: it turns **on** a peripheral clock domain and releases a reset. It
doesn't drive the panel, backlight, or PMIC rails, and it touches nothing on the
SD/eMMC. The reason it *must* write before reading is called out in the probe
header — the VOP2 register block hangs the AXI/AHB bus if you read it while
its bus-interface clocks are gated, so the ungate has to come first.


One thing I'd flag back to you: the probe leaves those clocks ungated and resets
released when it finishes — it doesn't restore the gated state. Given the
probes run once during bring-up and nothing after them expects the display block
to be dark, that's almost certainly fine. But if a *later* armed probe assumed a
pristine clock tree, this is the one that would perturb it. Does anything in
your sweep after priority 50 care about the display clock domain, or is it safe
to leave it on?


--------------------------------------------------------------------------------

### User Request 3

We should ensure that everything we're probing is left in the same state that it
was in when we started probing it. We should also log if it's in a state that's
not it's default state.


--------------------------------------------------------------------------------

### Assistant Response 3

This is a real design change to the probe engine — a save/restore guarantee
plus default-state detection. That needs an issue file before I touch code, and
before I can write a good issue file I need to understand exactly how the probe
language and engine work today. Let me read the engine and the DSL.


Let me read the rest — the interpreter's command dispatch and run loop.


I've read the whole engine. Here's the shape of it, and the one genuine landmine
before I write the issue and build this.


**How probes touch hardware today, two ways:**

- **Script probes** like `display-presence` use the `W`/`WH`/`WB` commands — easy to intercept.

- **C `CALL` routines** (`otp`, `rng`, `crypto`, the i2c setup) poke registers directly with hand-written `mmio_w32` and *already* leave clocks ungated when they finish.


Interestingly, the team already believes in your invariant in spots:
`pmic_write_test` reads the original byte, writes its test value, then writes
the original back; `pmic_ldo_test` reprograms LDO1 to the same voltage it read.
So "leave it as we found it" exists — by hand, per-probe. What you're asking
for is to make it **systematic**: auto-snapshot every write and replay it in
reverse at the end of the probe, so each probe hands the next one a pristine
slate.


**The landmine** is restoring the CRU/GRF "write-mask" registers — which is exactly what `display-presence` writes to. On these, the high 16 bits are a per-bit write-enable and the low 16 are the values. So if you read `CLKGATE_CON20`, you get the live state with the mask half reading `0` — and writing that straight back **changes nothing**, because you just told the hardware "enable zero bits for writing." A naive read-then-writeback restore silently no-ops on every CRU register. To actually restore you must write `0xFFFF0000 | saved_low`. But you can't just apply that formula everywhere: `I2C0_CLKDIV` at `0xFDD40000` sits in the *same* address window yet is **not** a masked register (both its 16-bit halves are real divider values), so the mask trick would corrupt it. So the engine has to *know*, per register, which kind it is — and getting that wrong pokes bad values into the clock tree.


Three decisions shape what I build. My recommendation is the first option in
each:


**[Asked the user]**


*Q1 — Default meaning:* You want to log when a register is 'not in its default state' — default relative to what?

- Chip reset value — The power-on value from the TRM. The engine can't know these itself, so each probe declares them via a new 'DEFAULT <addr> <value> [mask]' line; the engine reads at probe start and flags any mismatch. This catches the bootloader/firmware having already moved a clock or rail before we probed.

- Untouched since boot — The value a register held the first time any probe read it this boot. The engine snapshots first-seen values and flags if a later probe finds it changed. Needs no TRM values, but only catches drift our own probes (or late firmware) cause — not the boot-time starting config.

- Both — Declare reset values where the TRM gives them AND track first-seen values, logging against whichever is available. Most coverage, most machinery.

→ **Selected:** Chip reset value


*Q2 — Restore method:* How should the engine tell a write-mask CRU/GRF register (restore needs 0xFFFF0000|saved) apart from a plain register in the same window (restore raw)?

- Engine knows the windows — The engine carries a precise table of the write-mask blocks (CRU 0xFDD20000, PMU-CRU 0xFDD00000, GRF, PMU-GRF) and restores those with the mask trick, everything else raw. Existing probes need no edits; the table is a documented hardware fact, excluding I2C0 etc.

- Probe marks masked writes — Add a distinct 'WM' (write-masked) command. WM writes get restored with the mask trick; plain W restored raw. Intent is explicit in each probe and there's no table to maintain, but the CRU-writing probes must be edited to use WM.

- Probe restores itself — No auto-restore; each probe ends with its own explicit restore writes (like pmic_write_test does today). Simplest engine, but 'ensure everything is restored' then depends on the author remembering.

→ **Selected:** Probe restores itself


*Q3 — Scope:* display-presence is a script probe, so DSL-level save/restore covers it. Some probes ungate clocks from hand-written C and leave them on. Include those now?

- Script probes first — Implement save/restore + default-check for the DSL W/WH/WB path now (covers display-presence and any script probe). File a follow-up issue for the C CALL routines (otp/rng/crypto/i2c).

- Everything now — Also thread save/restore through the hand-written C routines (otp/rng/crypto/i2c) in the same change. Larger, touches more register code, higher chance of a mistake in the clock-tree pokes.

→ **Selected:** Everything now


Good — that gives me a clear, coherent design:


- **Default = chip reset value** → a new `DEFAULT <addr> <value> [mask]` command; the probe declares the TRM reset value, the engine reads at entry and logs `NON-DEFAULT` if the bootloader/firmware already moved it.

- **Probe restores itself** → no auto-journal magic; each probe (and each C routine) explicitly writes back what it changed, to as-found. The author — who knows the register — writes the correct masked restore, so the engine stays simple and can't guess wrong.

- **Everything now** → also bracket the hand-written C routines (`otp`, `rng`, `crypto`, the shared i2c0 setup) with save/restore.


Per your workflow this needs an issue file first. Let me find the right number
and match the style of the existing probe-engine issues.


The next sub-index in the probe-engine series is `110o`. Let me read the two
most recent probe issues to match their exact structure before I write mine.


Before I write the issue, let me confirm whether the lab-side tooling validates
the probe command set (in case a new `DEFAULT` command needs mirroring there).


The lab-side DSL parser is **retired** (`scripts/lab-side/retired/`), and
`embed-probes` only reads markers — so a new `DEFAULT` command lives entirely
in the kernel engine. Nothing to mirror. Writing the issue now.


Issue `110o` written. Now implementing the engine changes. First, the shared
masked-restore helper:


The shared i2c0 bring-up needs an entry snapshot and a teardown. Adding both:


Now bracketing the five i2c-using probes with the teardown. Each restores the
shared bus after it's done:


Now the OTP, RNG, and crypto C routines — save the CRU state at entry, restore
it (re-gate/re-hold) on exit:


Now the new `DEFAULT` command in the interpreter — a read-only entry check
placed between `EXPECT` and `POLL`:


Finally, updating the `display-presence` probe itself — the worked example:
check the two CRU registers are at reset before touching them, and restore them
after:


Now rebuild the diagnostic kernel and reassemble the image:


Clean compile. Reassembling the bootable image:


Let me verify the new lines actually made it into the generated probe fragment,
and that nothing produced a warning:


Clean rebuild is warning-free and the `DEFAULT`/restore lines are embedded.
Since I did a `clean` rebuild after the last image assembly, let me re-stitch so
the shipped image matches this exact build:


Done — the image is rebuilt and ready to flash. Here's what changed underneath
it.


**The image**: `output/bootable-sd.img` (285 MB), same 24 armed probes as before, but now every probe that disturbs a clock, reset, or pin puts it back. Next steps unchanged: `scripts/push-to-usb`, then `scripts/lab-side/flash-sd`.


**What "leave it as found" now means, concretely** — three places were leaking state and now don't:

- **The display probe** re-gates the VOP2 clocks and re-holds its resets after reading the version register, instead of leaving the display block powered for everything downstream.

- **The i2c0 bus bring-up** — shared by *five* probes (PMIC dump/write/LDO, the bus scan, the audio-codec dump) — gained a matching teardown. Each of those probes now brackets "bring the bus up … put it back": re-gate its clocks, re-hold its resets, and return the two GPIO pads to whatever function they had. Previously even the two probes that carefully restored their *device* register still left the *bus* re-muxed.

- **The OTP, RNG, and crypto probes** each snapshot their clock-gate/reset registers on entry and re-gate on exit.


**The masked-register trap you spotted lives in exactly one place now.** There's a single helper that does the `0xFFFF0000 | saved` write-back, with a comment explaining why writing the read-back value verbatim would silently do nothing. Every C routine restores through it; the display probe (being a script) writes its own re-gate line with the mask spelled out. Plain registers like `I2C0_CLKDIV` are restored raw — the code picks the right form per register rather than guessing from the address, which is the whole reason we went with "the probe restores itself."


**The default-state check** is a new `DEFAULT <addr> <value> [mask]` command. Put at the top of a probe, it reads the register and logs `at-reset` or `NON-DEFAULT got=… reset=…`. The display probe now opens with two of them, for the clock gate and the reset register.


**One thing I want to flag honestly, and it's your kind of question:** the script-side restore puts the display back to its *reset* state (re-gated, re-held), which only equals "as we found it" if the display was actually at reset when we arrived. That holds *only if u-boot never touches the VOP2 before handing off to us*. I don't know that it doesn't — and that's precisely what the `NON-DEFAULT` line is there to catch on the next sweep. So: **do you know whether our u-boot brings up the display at all?** If it might, the honest fix is to give the script path a save-first `SAVE`/`RESTORE` pair (restore to the actual entry value, like the C routines do) rather than restore-to-reset. I left that as a deferred note rather than build it, since you chose the simplest engine — but if u-boot is a display-toucher, it's worth doing now instead of trusting the reset assumption.


I recorded all this in a new issue file in the probe series (the `110o`
blueprint) and left it **in-progress** — the build is clean and warning-free,
but it's not "complete" until a hardware sweep confirms the `DEFAULT` lines read
`at-reset` and a re-run finds the display re-gated. I did **not** commit
anything (working tree still has your unrelated in-progress files in it). Want
me to stage just the probe-engine, the display probe, and the issue file and
commit them?


--------------------------------------------------------------------------------

### User Request 4

do you know whether our u-boot brings up the display at all?


I dunno.


we might run this probe system after the display has been turned on for other
reasons though, so we should be sure to put it in the same state we found it,
even if that state was on, and our "touches" didn't actually change anything.


--------------------------------------------------------------------------------

### Assistant Response 4

Right — that changes the correct approach. If the display might already be on
when the probe runs, restoring to *reset* would turn it off; we have to restore
to the **actual value we found**, even when our writes were no-ops. That's the
save-first path I flagged as deferred. Since you want it, I'll build it now for
the script side, matching what the C routines already do.


Let me add a `SAVE`/`RESTORE` pair to the interpreter — snapshot a register's
real entry value, then write exactly that back.


Now the `SAVE` and `RESTORE` commands in the interpreter, right after `DEFAULT`:


Now clear the save table at the start of each probe run:


Now the display probe: snapshot the real entry values with `SAVE`, and restore
*those* instead of the reset values:


Now updating the issue blueprint so it describes the save-first design I
actually built, not the restore-to-reset one:


Now rebuild and reassemble the image with the save-first restore:


Rebuilt and verified — `output/bootable-sd.img` now carries the
**restore-to-as-found** behavior. Flash steps are unchanged (`push-to-usb` →
`lab-side/flash-sd`).


**What changed from the last build.** The display probe no longer restores to the *reset* state — it restores to whatever it actually found:


- At entry it runs `SAVE 0xFDD20350` / `SAVE 0xFDD20440`, which read the two CRU registers and stash their real values.

- At exit it runs `RESTORE 0xFDD20440 0x01FF` / `RESTORE 0xFDD20350 0x1FFC`, which write those saved values back.


So the three cases all come out right: if the display was **off** when we
arrived, we ungate it, read the version, and re-gate it. If it was **already
on** (u-boot, or some later subsystem, brought it up), `SAVE` captures the
on-state, our ungate write is a no-op, and `RESTORE` writes the on-state back
— **we leave it on**. Your exact point: put it back the way we found it, even
when our touches changed nothing.


The `maskbits` argument (`0x1FFC`, `0x01FF`) does double duty — it names the
bits we touched *and* triggers the write-mask form of the write, which is the
only way to move these CRU registers. It also means `RESTORE` only puts back the
bits this probe disturbed, leaving the rest of the register alone.


**`DEFAULT` is now purely a diagnostic.** Before, I'd tied it to restore correctness ("restore-to-reset is only valid if we started at reset"). With save-first restore, that dependency is gone — the restore is correct whatever the entry state was. `DEFAULT` still logs `at-reset` / `NON-DEFAULT`, but now it's just telling you *whether something upstream had already brought the display up* — useful to know, independent of the restore.


Worth noting: the **C routines** (OTP, RNG, crypto, the shared i2c bus) already
worked this way — they read the actual entry value and write it back through
the one masked-restore helper — so they were already "was-on-stays-on"
correct. The display script probe now matches them; the whole battery is
consistent.


The issue blueprint is updated to describe the save-first design (not the reset
one), and it's still **in-progress** — the on-hardware confirmation is the
thing left: the log should show the `SAVE` values, the `DEFAULT` result, and the
block left in its entry state.


I still haven't touched git. Want me to stage just the three files I changed —
the probe engine, the display probe, and the issue file — and commit them?


--------------------------------------------------------------------------------

### User Request 5

Sure. Also can you build an image for me to flash?


--------------------------------------------------------------------------------

### Assistant Response 5

On it — I'll commit just my three files, then build you a fresh image. First,
let me see the current git state so I stage only my changes and nothing else
that's in the tree.


Good — my three files are clean and isolated, and `output/` is gitignored so
no binaries can sneak in. Staging just my changes:


Exactly my three files staged; everything else (other projects, transcripts)
left alone. Committing:


Committed to `master` as `4b6e226b` — exactly the three files, pure additions.
Now building you a fresh image from the committed source:


Both are done. Let me give you the final artifact details for the flash:


Both done.


**Committed** — `master 4b6e226b`, just the three files (probe engine, display probe, issue blueprint), 415 insertions and no deletions since it's all additive. The other modified files across your tree were left untouched.


**Fresh image built** from that committed source:

- `output/bootable-sd.img` — 285,212,672 bytes

- `sha256` `3136630e68c1b2ad435cca3a807551f934aceed3da7e408465840a81b7577b2a`

- Same 24 armed probes, now with the save-first restore compiled in.


Flash path is the usual air-gapped hop: `scripts/push-to-usb`, then
`scripts/lab-side/flash-sd`.


When you run the sweep, the `display-presence` section of the SD log is the
thing to eyeball — it'll show the two `SAVE` values, the `DEFAULT
at-reset`/`NON-DEFAULT` verdict, and the `RESTORE` writes. If `DEFAULT` comes
back `NON-DEFAULT`, that's the tell that u-boot (or something) is bringing the
display up before us — good to know, and the restore will still hand it back
correctly either way. That on-hardware read is the one thing left before issue
`110o` is complete.


--------------------------------------------------------------------------------

### User Request 6

okay logs are at /mnt/generic


--------------------------------------------------------------------------------

### Assistant Response 6

The Jul 2 (`20260702-101835`) sweep is there. Let me pull the display-presence
log — the one that exercises my SAVE/DEFAULT/RESTORE change — plus check
whether it even appears:


The mechanism worked — and it caught exactly the case you predicted. Let me
read the details and cross-check the routines I changed:


Everything I touched is healthy — I'll get to the headline in a second, but
first the important cross-checks:


- **OTP, crypto, RNG** all show their `restored … to as-found` line and none hung.

- **The five i2c probes** (dump, write, ldo, scan, audio) all completed — `pmic-write` still round-trips (wrote `0x5A`, restored `0x00`), the scan still finds the PMIC at `0x20`. The teardown runs silently, so there's no log line for it (minor — I could add one).


**The headline, from the display probe:**


```

SAVE 0xFDD20350 = 0x00000000 ← clock gate, as we ARRIVED

SAVE 0xFDD20440 = 0x00000000 ← reset reg, as we ARRIVED

DEFAULT ... NON-DEFAULT got=0x0 reset=0x1FFC

DEFAULT ... NON-DEFAULT got=0x0 reset=0x01FF

W 0xFDD20350 <= 0x1FFC0000 ← our ungate: writing 0 to bits already 0 = no-op

...

RESTORE 0xFDD20440 <= 0x01FF0000 (masked) ← put back the 0 we found

RESTORE 0xFDD20350 <= 0x1FFC0000 (masked) ← put back the 0 we found

```


The display's clocks were **already ungated and its resets already released
before we touched anything** — your "it might already be on for other reasons"
is exactly what happened. And the save-first restore did its job: it saw the
block was on, our ungate was a no-op, and it wrote the *found* state (0) back
instead of the reset state. The old restore-to-reset version I first built would
have written `0x1FFC1FFC` here and **re-gated a display something else had
turned on** — the bug your instinct killed, confirmed live.


But there's a real question in the `NON-DEFAULT` verdict, and it's yours to
reason about with me: I declared reset = *gated/held* (`0x1FFC`/`0x01FF`), and
the register read *0*. That's either (a) the boot chain genuinely ungated the
display, so `NON-DEFAULT` is a true signal — or (b) my declared reset values
are backwards and *0 is the reset default*, making the flag cry wolf. Let me
settle it against the TRM rather than guess:


`gs` is available (the same tool the probe author used). Extracting the TRM text
and searching for the two registers' reset values:


That's decisive — but let me confirm the bit polarity and per-bit reset in the
detailed register pages, because the whole conclusion hinges on it (and PDF
table columns can misalign):


That's conclusive, and it flips my earlier read — I need to correct myself.


The TRM detail pages show, bit by bit, that **both registers reset to `0x0`**,
with polarity "when high, disable clock" / "when high, reset logic." So `0`
means **clock enabled / reset released**. The RK3568 powers up with the VOP2
clocks **on** and resets **released**.


So my headline was wrong, and the culprit was my own guess:

- The registers read `0x0` because that **is** their power-on default — the display block was **not** "already brought up by u-boot." It's just that these clocks reset to on.

- My `DEFAULT` lines declared reset = `0x1FFC`/`0x01FF` (gated/held). That was **backwards**. So the `NON-DEFAULT` verdict was a **false alarm from my bad declaration**, not a real signal.


What this *doesn't* change — and actually validates harder — is the
save-first restore. Watch what restore-to-reset would have done with my
*declared* value: it'd have written `0x1FFC1FFC`, **gating clocks the chip
resets to ungated** — actively breaking the display block. Save-first captured
the real `0` and put `0` back, so it was correct *despite* my wrong reset
assumption. That's the whole argument for save-over-reset, proven by my own
mistake.


Let me fix the declaration from the TRM (your rule: find the doc that caused the
mistake and fix it):


Let me re-read the probe header to get the exact text:


The line wrapping differs from what I had. Fixing both the premise and the
register-facts with the exact text:


Now rebuild the image with the corrected declaration:


Rebuilt and verified — `output/bootable-sd.img` now carries the corrected
declaration.


## What the sweep told us


**The mechanism works.** Everything I changed ran clean — OTP, RNG, and crypto each logged their `restored … to as-found` line, all five i2c probes completed (PMIC still round-trips and the bus scan still finds `0x20`), nothing hung.


**I was wrong about u-boot, and the TRM says why.** I dug the reset values out of the TRM detail pages:


```

CRU_GATE_CON20 (0x350) reset 0x00000000 bit = "1: disable clock" → 0 = clock
ON

CRU_SOFTRST_CON16 (0x440) reset 0x00000000 bit = "1: reset logic" → 0 =
released

```


So the RK3568 powers up with the VOP2 clocks **on** and resets **released**. The
registers read `0x0` because that *is* the reset default — **not** because
u-boot lit the display. My `DEFAULT` lines had the reset value backwards (I
declared gated/held), so the `NON-DEFAULT` verdict was a false alarm from my own
bad declaration. I've corrected both `DEFAULT` lines to `reset = 0x00000000` and
fixed the probe's header comments; the next sweep will read `at-reset`.


**But this is the strongest possible vindication of save-first restore.** If I'd shipped the restore-to-reset version using my *declared* value, it would have written `0x1FFC1FFC` and **gated clocks the chip resets to ungated** — actively breaking the display block on every boot. Save-first captured the real `0` and wrote `0` back, so it was correct *despite* my wrong assumption. Restore-to-as-found protects against not knowing the reset value — which is exactly the situation I turned out to be in.


## Two things worth your eye in the gathered data


- **RNG only filled 2 of 8 words**: `0x556AAB55 0x9555AAAD` then six zeros. Words 0–1 look like real entropy, 2–7 are dead. This is unrelated to my change (the zeros are read *before* the restore), and it's the first RNG data we've pulled — but the probe's own note says "all-equal/zero = stuck," so this TRNG is either only producing 64 bits per draw or genuinely not filling the output FIFO. Might want a probe that starts a fresh draw per word.

- **The clock registers can't answer "does u-boot draw to the panel."** Since they're on at reset regardless, they tell us nothing about active scanout. To actually know, we'd read VOP2's **window-enable / framebuffer-address** registers — is a layer turned on, is a buffer programmed. That's a small new probe if you want the answer.


## Next steps


The fix is a clean, TRM-backed bugfix to the display probe
(`input/probes/display-presence.probe`). Ordered by what I'd do first:


1. **Commit the correction** — want me to stage and commit just the probe
file? (`git`, one file, message describing the reset-value fix.)

2. **Re-flash and re-sweep** to confirm `DEFAULT` now reads `at-reset` — the
last thing before issue `110o` is truly done.

3. **Add the scanout probe** if you want to settle the u-boot-draws-the-panel
question for real.


The image is built and ready either way. Which do you want?


--------------------------------------------------------------------------------

### User Request 7

- The clock registers can't answer "does u-boot draw to the panel." Since
they're on at reset regardless, they tell us nothing about active

scanout. To actually know, we'd read VOP2's window-enable / framebuffer-address
registers — is a layer turned on, is a buffer programmed.

That's a small new probe if you want the answer.



it's okay we don't need to know that now. There's a I/O validation utility issue
for that.


- RNG only filled 2 of 8 words: 0x556AAB55 0x9555AAAD then six zeros. Words
0–1 look like real entropy, 2–7 are dead. This is unrelated to

my change (the zeros are read before the restore), and it's the first RNG data
we've pulled — but the probe's own note says "all-equal/zero

= stuck," so this TRNG is either only producing 64 bits per draw or genuinely
not filling the output FIFO. Might want a probe that starts

a fresh draw per word.



this sounds like something we should fix?


--------------------------------------------------------------------------------

### Assistant Response 7

On the scanout probe — good, I'll leave that to the I/O validation utility
issue; no action from me there.


On the RNG: before calling it a fix, I want to know *why* words 2–7 are dead
— whether the TRNG only produces 64 bits per draw (so reading 8 words is the
probe's bug) or it should fill 256 bits and our config under-produces (a real
bug). The probe cites TRM Part 2 Ch5, so let me pull the actual TRNG spec.


Found it. The TRM is unambiguous (Part 2, §11.x TRNG):


> If `RNG_CTL.rng_len = 0x00`, the last valid bit is stored in
`RNG_DOUT_1.bit31`, and `RNG_DOUT_2 ~ RNG_DOUT_7 are [zero]`.


So words 2–7 aren't *stuck* — they're **defined-zero because the draw is in
64-bit mode**. The probe never sets `rng_len`, so it defaults to 64-bit, yet it
reads all 8 words — that mismatch is the "bug." Let me pin the exact `rng_len`
bit field before proposing the write:


That's the whole story: `rng_len` (bits 5:4 of `RNG_CTL`) defaults to `00` =
64-bit, so only `DOUT_0/1` are valid and `DOUT_2..7` read a **defined zero** —
the probe just never set it to 256-bit while reading all eight words. Not stuck
hardware; an under-configured draw. The clean fix is to request a full 256-bit
draw so the readout matches.


The TRM also corrects a stale note in our code: the write-enable mask is bits
**21:16** (six bits, for bits 5:0), not the "31:16" the comment claims. Fixing
both:


Both fixes are now in the image (the display reset-value correction and this RNG
one). One more prudent tweak while I'm here: a 256-bit draw collects ~4× more
oscillator samples than the old 64-bit one, so I'll widen the completion poll
budget so the longer draw can't spuriously time out:


Fixed and built. Final image sha256 `1d83ed39…79a80d`, with **both**
corrections baked in.


**RNG — root cause and fix.** Words 2–7 weren't stuck hardware; `RNG_CTL.rng_len` resets to `00` (64-bit), which by the TRM's own wording makes `DOUT_2..7` read a *defined zero* while the probe read all eight. So the draw and the readout disagreed. The probe now sets `rng_len = 2'b11` (256-bit) before starting, so a full draw fills all eight words. I also:

- Corrected a stale comment — the write-enable mask on `RNG_CTL` is bits **21:16**, not the "31:16" it claimed.

- Widened the completion poll from 200k to 1M iterations, since a 256-bit draw collects ~4× the samples (still bounded — it can only time out, never hang).


**Validation is the next sweep** (I can't run the TRNG here): the RNG section should now show eight populated, differing words instead of two-then-zeros, and — from the earlier fix — `display-presence` should read `DEFAULT … at-reset` instead of `NON-DEFAULT`.


**Two uncommitted changes are sitting in the tree, and they're separate concerns**, so I'd make them two commits to keep the record clean:

1. `input/probes/display-presence.probe` — declare the true clock/reset
defaults from the TRM (fixes the false `NON-DEFAULT`).

2. `src/019-probe-engine.c` — draw the full 256 bits from the TRNG (fixes the
dead output words).


Want me to commit both as two separate commits? And if you're flashing now, the
image is ready — `push-to-usb` → `lab-side/flash-sd`.


--------------------------------------------------------------------------------

### User Request 8

can we put a "sync" at the end of the flash-to-usb script so we know that the
rsync actually finished moving the data to the card? Might not be necessary, but
I think it could help.


--------------------------------------------------------------------------------

### Assistant Response 8

Good instinct — `rsync` returning only means the data reached the page cache;
the kernel can still be lazily writing it to the USB device when you pull it.
Let me read the script to see how it ends and where a flush belongs.


The script already does exactly what you're describing — and the guarantee is
even a bit stronger than a bare `sync`. Look at `do_cleanup` (the stage right
after the rsync):


```

sync # line 231 — flush dirty pages to the device

sudo umount "$USB_MOUNT" # line 232 — this is the real guarantee

```


`umount` won't return until the filesystem's dirty data is written out and the
device is detached — so by the time the script prints "Unplug the drive," the
bytes are already physically on the drive. There's a `sync` in front of it as
belt-and-suspenders, and the exit trap (`cleanup_on_exit`) does `sync` +
`umount` too, so even an error path flushes. So on `push-to-usb`, your goal is
already met — adding another `sync` after the `umount` would touch a
filesystem that's no longer mounted.


But I think your instinct is pointing at a real gap — just in the *next*
script. Let me check where it actually matters:


Same story on the other end — good news, the flush is already there in both
scripts, and the SD side is even more thorough than a bare `sync`:


**`push-to-usb`** (the rsync one), `do_cleanup`, lines 231–232:

```

sync # flush dirty pages

sudo umount "$USB_MOUNT" # can't return until the FS is flushed + detached

```


**`lab-side/flash-sd`** (the actual SD write), `flash_image`, lines 196–198:

```

sudo dd if="$image" of="$device" bs=4M status=progress conv=fsync

sync

```

That's three overlapping guarantees on the card write: `conv=fsync` makes `dd`
itself `fsync()` before it exits, then an explicit `sync`, then `eject` (line
206) on top.


So the bytes really are on the medium before either script tells you to unplug.
The mechanism that carries the weight isn't the `sync` — it's the
`umount`/`eject`: neither can complete until the filesystem's dirty data is
written out. A `sync` added *after* the `umount` would run against a filesystem
that's already gone.


Here's the thing I think you're actually reaching for, though — the word "**so
we know**." Today that flush is *silent*: in `push-to-usb` it's folded into the
single `cleaning up... done` line. The `done` only prints after `umount`
succeeds, so it *is* the confirmation — but it doesn't *say* "flushed," so you
can't tell by looking that the flush is what you waited on.


So rather than add a redundant no-op `sync`, the change with actual value is
**making the existing flush visible** — give it its own progress line so the
operator sees `flushing... done` as a distinct, acknowledged step. Options, by
usefulness:


1. **(Recommended)** Split the flush into its own visible step in `push-to-usb`
(`flushing... done`), so you *see* it complete — delivers the "so we know"
without a redundant op. Small, no behavior change.

2. Add a bare `sync` at the very end anyway — harmless belt-and-suspenders,
but it flushes nothing new after the `umount`.

3. Leave both as-is — they're already correct.


Want me to do #1?


--------------------------------------------------------------------------------

### User Request 9

okay logs are in.


--------------------------------------------------------------------------------

### Assistant Response 9

Let me pull the newest sweep and check both fixes landed:


Both fixes are confirmed on hardware.


**Display — the false alarm is gone:**

```

DEFAULT 0xFDD20350 at-reset got=0x00000000 reset=0x00000000

DEFAULT 0xFDD20440 at-reset got=0x00000000 reset=0x00000000

```

Reads `at-reset` now (was `NON-DEFAULT` before the TRM correction), and
SAVE→RESTORE still round-trips the found value. That's issue `110o`
hardware-confirmed — the last thing it was waiting on.


**RNG — 256-bit draw works:**

```

DOUT0-7: 0x555AAA55 0xA9556AAB 0xAAB5552A 0x2AAB5556 0x6AAA9555 0x2AAA9555
0x6AAAD555 0x6AAA9555

```

All eight words populated and differing, no more dead tail. The 64-bit-mode
mismatch is fixed.


**But now that we can see all 256 bits, the data raises a sharper question — and it's a good one.** Look closely at those words, don't just check "not zero":


- Nearly every nibble is `5` (0101), `A` (1010), or a neighbor (`9 6 2 D B`). The values `0`,`1`,`3`,`4`,`7`,`8`,`C`,`E`,`F` barely appear. A healthy TRNG spreads evenly across all sixteen; this is heavily biased toward **alternating-bit patterns**.

- Word 4 and word 7 are **byte-for-byte identical** — `0x6AAA9555` both times — and words 4–7 all share the `0x_AA_?555` skeleton. Two identical 32-bit words in a 256-bit "random" draw is a 1-in-4-billion coincidence, or it's structure.


So it passes the probe's crude "not all-equal/zero" check while clearly not
being good entropy. Here's the puzzle for you: **why would a true-random ring
oscillator emit near-alternating, partly-repeating bits?** My read:
`rng_sample_cnt` is `0` — the fastest rate — so we're sampling the
oscillator ring faster than it accumulates independent jitter between reads, and
correlated adjacent bits show up as that `0101/1010` shimmer. The TRM's own note
fits: *"the value more bigger, the rate more slower"* — slower sampling, more
jitter per captured bit. (This bias was actually there in the old 2-word output
too — `0x556AAB55 0x9555AAAD` has the same character — my change just made
it visible across all eight.)


I don't want to guess a sample-count value blind. Two honest ways forward, and
there's housekeeping too:


1. **Chase the entropy** — either look up what value the vendor RK3568 RNG
driver programs, or (more in the spirit of the probe) turn this into a quality
probe that draws at several `sample_cnt` values and reports a nibble histogram
per rate, so we *see* which rate whitens. Data-generation and data-viewing kept
separate.

2. **Commit what's validated** — the display reset-value fix and the RNG
256-bit fix are both confirmed now; I'd commit them as two separate commits, and
`110o` can move to completed with phase-1 progress updated.

3. The **`sync` visibility tweak** for `push-to-usb` is still on the table from
before, if you want it.


Which do you want first? My instinct is commit the validated fixes (2), then dig
into the entropy (1).


--------------------------------------------------------------------------------

### User Request 10

1. Chase the entropy — either look up what value the vendor RK3568 RNG driver
programs, or (more in the spirit of the probe) turn this into

a quality probe that draws at several sample_cnt values and reports a nibble
histogram per rate, so we see which rate whitens.

Data-generation and data-viewing kept separate.



sure I like that. We can learn how to turn the knobs to generate more / less
random random numbers. Useful.


3. The sync visibility tweak for push-to-usb is still on the table from before,
if you want it.


eh I don't think we need it. Maybe we could put one at the end of
dump-logs-to-sd instead? Like you said it's already there so we don't have to be
loud about it.


--------------------------------------------------------------------------------

### Assistant Response 10

Both good calls. The `dump-from-sd` sync makes sense — that script writes the
extracted logs onto the USB drive, and unlike `push-to-usb` it may not already
flush before you carry the drive back. Let me confirm, and check the RNG probe's
current shape:


Confirmed — and your instinct is right this time: `dump-from-sd` writes all
the extracted logs into `lab-output/` on the USB drive, then only `eject`s the
**SD card** (line 332), never the USB drive it wrote to. Nothing flushes those
writes before you carry the drive back — so a `sync` here is a real guarantee,
not a redundant one like it'd have been in `push-to-usb`.


Two pieces of work. The RNG sweep is a new capability (a feature), so per your
workflow it gets an issue file first:


Now the engine — splitting the RNG draw into a generator and a viewer, and
looping over sample rates:


Now the `sync` in `dump-from-sd` — as a small function with the "why" spelled
out, then wired into `main` after the writes:


Now validate the script syntax and rebuild the image with the sweep:


Done — image rebuilt with both changes. sha256 `87dc8c39…f4056`.


**The RNG sweep is in.** On the next flash the RNG section will draw a full 256-bit block at five sample rates and print a histogram under each, so you can watch the knob work. It'll look like this per rate:


```

[rng] sample_cnt=0 DOUT0-7: 0x555AAA55 0xA9556AAB ...

[rng] nibbles (of 64, ideal ~4 each): 0:0 1:1 2:4 3:0 4:0 5:15 6:9 7:0 8:0 9:8
A:13 B:3 C:0 D:2 E:0 F:0

[rng] ones=131/256 (ideal 128)

[rng] sample_cnt=16 ...

```


Generator (`rng_draw_256`) and viewer (`rng_report_quality`) are separate
routines, so the draw and the reading stay isolated — and the sample-rate
array is a one-liner you can edit to explore further. The open question it
answers on hardware: **at which `sample_cnt` does the nibble spread flatten
toward uniform?** (Fastest rate should show the `0x5`/`0xA` spikes; I expect
them to melt as the count climbs — but the whole point is to measure it, not
guess.) Recorded the finding-slot for that in the `110p` issue.


**`dump-from-sd` now flushes** — a `flush_outputs` step (`sync`) runs after the dumps and before it tells you to carry the drive back, so the extracted logs are guaranteed on the USB drive.


That leaves the tree with four uncommitted pieces across three clean concerns.
My suggested commits, in order:


1. **display probe** — the TRM reset-value correction (the `110o` fix that
made `DEFAULT` read `at-reset`). `input/probes/display-presence.probe`

2. **RNG quality sweep** — the 256-bit draw + sample-rate sweep, with its
issue. `src/019-probe-engine.c` + `issues/110p-…md`

3. **dump-from-sd flush** — the `sync`. `scripts/lab-side/dump-from-sd`


And separately, `110o` is hardware-confirmed now, so it can move to `completed/`
with phase-1 progress updated whenever you want.


Want me to make those three commits (and move `110o` to completed)? I can do all
of it, or just the ones you pick.


--------------------------------------------------------------------------------

### User Request 11

Let's commit those things when we know for sure they work. The display probe
could be committed now, and the dump-from-sd could as well, but we haven't
validated that the RNG probe does what we want. All we're waiting on is
validation.


So, what else could we build / fix / debug before the next flash? Where are we
at with USB flashing? We need to wipe the eMMC right, but we should make sure
USB debugging works first. We have the archive of the eMMC so we could re-create
it from an SD-card boot, can you read the safety document and tell me what ways
we could brick the system? I'm talking hardware damage, not "oh no we have to
re-flash the OS" or something. That's easy. We can reflash. Even if we have to
go through maskROM, that's fine. What's not fine is if we overload one of the
capacitors or push the wrong value to the CPU and cause it to shatter or
something idk how that would break.


So the rough roadmap in my mind is... ensure the archive is present, wipe the
eMMC, write our own u-boot that points to the SD card (let's stick with an SD
card based kernel for now, we can only overwrite the eMMC so many times, and
it's soldered onto the board...) and put that u-boot onto the eMMC. Is that
part... actually needed? Whatever, even if it's not, once we have the eMMC
completely wiped, we can start doing USB debugging, so we should make sure the
USB controller works. But we can't test it by plugging it into a computer until
we wipe the eMMC.


--------------------------------------------------------------------------------

### Assistant Response 11

Good call — validate before committing the RNG work. Let me commit the two
safe ones, and in parallel dig into the docs so I can answer the bricking and
roadmap questions properly. First, locating the safety doc and the relevant
hardware docs:


Found it: `notes/safety/000-bricking-and-recovery.md`. Reading it plus the PMIC,
USB, and recovery docs to ground the answer:


That's a thorough safety doc. Before I synthesize, let me ground the USB-status
and roadmap parts — reading the USB controller doc, the USB PHY issue, the
latest usb-phy probe result, and the roadmap:


The safety doc is thorough and the USB doc tells me what I need. Let me commit
the two validated changes, then check a couple of code facts (watchdog presence,
USB enumeration state) before I lay out the analysis.


Both committed cleanly (`78ca2df6`, `3b4330a2`); the RNG work stays uncommitted
for validation. (`src/018-bringup-test-suite.c` shows untracked — not mine,
leaving it.) Two quick code facts before I lay this out — is a watchdog in
place, and what's the state of the USB enumeration code:


Both committed (`78ca2df6` display fix, `3b4330a2` dump-from-sd flush). RNG work
held back for validation. Now the real conversation.


## Hardware damage — the honest map


I read `notes/safety/000-bricking-and-recovery.md` end to end. Filtering out
everything reflashable (S1/S2/S3/S11 — you're right, those are free), here's
what's left, and the single unifying fact:


**The PMIC is the only component that turns a software number into a physical voltage or current that can exceed a part's rating.** Everything else either self-limits (GPIO drivers, thermal shutdown at ~110 °C), just crashes (clocks/PLLs pushed too fast → reboot), or corrupts data (DMA/storage → reflash). The PMIC is the one actuator with a wire from "wrong register value" to "dead silicon." So your two worries collapse into one mechanism:


- **"Push the wrong value to the CPU and shatter it"** — silicon doesn't shatter mechanically; it dies electrically. Too much voltage across a transistor's gate oxide punches through the dielectric (permanent short); too much current density electromigrates a metal trace until it opens. The core voltage is set by an RK817 DCDC buck over i²c — so the "wrong value to the CPU" path runs *through the PMIC*, not through any CPU register.

- **"Overload a capacitor"** — same event. Every rail's decoupling caps are rated just above that rail. Raise the rail past their rating → they crack/short/vent. Frying the CPU and popping a cap are the *same* PMIC over-volt, seen at two components on the same rail.


The other permanent vectors, all narrower:

- **Backlight (S8)** — over-driving the backlight LED current via PWM burns it out (case-open repair). `pwm-bringup.probe` can do this; it's currently **de-selected**, keep it that way until we know the panel's rated current.

- **eFuse / secure-boot (S9/S10)** — not "damage" but permanent chip lock. Our OTP code only *reads*; it must never issue a fuse-program command.

- **Battery (S7)** — deep-discharge or a wrong charger setting kills the (soldered) cell — a fire risk, not just a brick.


**The part that should make us careful: our probe engine already carries the loaded gun.** `pmic_write_test` writes arbitrary RK817 registers (today just the harmless RTC reg 0x10), and `rk817_ldo_set_mv` sets LDO voltages. The i²c write path has **no register guard** — unlike our MMIO `W` commands, which have the `write_allowed` window check. So a probe that pointed a PMIC write at a buck/LDO/charger voltage register would sail straight through. That's the one concrete thing I'd *build* before we get adventurous: a deny-list on the PMIC register-write path (mirror the MMIO allowlist), so voltage and charger registers are physically unwritable from a probe. It directly neutralizes the only path to a dead board.


## The gate the doc screams about — and it's yours to answer


The doc's #1 unknown: **is Maskrom (or fastboot) reachable over USB-C from
outside the sealed case?** Until that's confirmed, every low-level flash is a
one-way trip. Your plan wipes the eMMC — which is *fine* only if a failed boot
afterward can still be recovered. So: **have we actually confirmed we can put
this unit into Maskrom and talk to it from the laptop without opening it?** If
yes, wipe away. If not, that confirmation is the true prerequisite, above the
wipe.


## Where USB actually is


I checked the code. `usb_init` runs at boot from the SD kernel
(`002-main.c:194`), and the PHY side (109a) is *favorable* — the doc's probe
shows the OTG PHY already out of suspend at reset, nothing to un-power-down.
**The blocker is 109b: `depcmd_issue` spins forever on the first DWC3 endpoint
command** — enumeration hangs. `009-usb.c` even says so in a comment. The
leading hypothesis is already written down: the controller's `DCTL` RUN/STOP bit
must be set (or the event buffer finished) before endpoint commands are accepted
— resolved in TRM Part 2 Ch17.


The important consequence: **this is debuggable right now, from the SD kernel,
with the eMMC untouched.** Our kernel brings USB up itself on the SD-boot path
(the bootloader doesn't). Nothing about the eMMC is stopping us from working the
109b hang.


## Your roadmap, three reactions


1. **"Write our own u-boot to the eMMC pointing at the SD" — not needed.** The
SD already carries its *own* full boot chain (idbloader at sector 64, u-boot at
16384, kernel), and the BootROM boots it directly — that's how every sweep so
far has run. Putting u-boot on the eMMC would only matter if the BootROM
couldn't boot SD, and it demonstrably can. Drop that step: one fewer write to
the soldered, finite-life eMMC.


2. **"Can't test USB until the eMMC is wiped" — I don't think that's true for
*our* USB, and I want to check your reasoning.** Our SD kernel already brings up
the gadget and hangs at enumeration regardless of the eMMC. The place the eMMC
*does* matter is the *other* USB path: a wiped eMMC makes the BootROM fall
through to Maskrom-over-USB on a boot miss, so the *laptop would see a Rockchip
download device*. Is that what you meant — you want the port to *appear on the
PC* (the recovery/flashing path), rather than testing our own gadget? Or have
you seen the stock eMMC OS grab the port when plugged in? That distinction
changes the sequencing.


3. **Boot priority:** since sweeps boot from SD with the eMMC still populated,
SD already wins the boot order on this unit — so wiping the eMMC won't change
how we boot, it only removes the stock OS. Good to know it's low-risk; it also
means the wipe buys us *recovery-path* behavior, not *boot* behavior.


## What I'd do before the next flash


We're already spending a flash on RNG validation, so batch it: **work the 109b
enumeration hang now** (it's pure software, no wipe, no risk), and let the next
flash validate *both* the RNG sweep *and* whatever USB progress we make. In
parallel, the **PMIC write-guard** is the one safety hardening worth landing
before we start poking power. Neither needs the eMMC touched.


So my proposed order: confirm the Maskrom-from-outside net (answer above) →
land the PMIC write-guard → fix the 109b hang → one flash validates RNG +
USB → *then* consider the wipe. Want me to start on the 109b hang, or the PMIC
guard, first?


--------------------------------------------------------------------------------

### User Request 12

- Backlight (S8) — over-driving the backlight LED current via PWM burns it out

(case-open repair). pwm-bringup.probe can do this; it's currently de-selected,

keep it that way until we know the panel's rated current.



uh, can you break the probe to make sure it doesn't run even if it's
accidentally enabled? Or, better yet, look through the datasheets or find a way
to probe so we can find that value, and instead of breaking it just make sure
it's at the right value.


- eFuse / secure-boot (S9/S10) — not "damage" but permanent chip lock. Our OTP

code only reads; it must never issue a fuse-program command.


um, what does this mean?


- Battery (S7) — deep-discharge or a wrong charger setting kills the
(soldered)

cell — a fire risk, not just a brick.


can we actually interact with the battery in any meaningful capacity? I thought
the hardware handled that and didn't expose anything for us to mess with.


The part that should make us careful: our probe engine already carries the
loaded

gun. pmic_write_test writes arbitrary RK817 registers (today just the harmless
RTC

reg 0x10), and rk817_ldo_set_mv sets LDO voltages. The i²c write path has no

register guard — unlike our MMIO W commands, which have the write_allowed
window

check. So a probe that pointed a PMIC write at a buck/LDO/charger voltage
register

would sail straight through. That's the one concrete thing I'd build before we

get adventurous: a deny-list on the PMIC register-write path (mirror the MMIO

allowlist), so voltage and charger registers are physically unwritable from a

probe. It directly neutralizes the only path to a dead board.



explain this more?


The doc's #1 unknown: is Maskrom (or fastboot) reachable over USB-C from outside

the sealed case? Until that's confirmed, every low-level flash is a one-way
trip.

Your plan wipes the eMMC — which is fine only if a failed boot afterward can
still

be recovered. So: have we actually confirmed we can put this unit into Maskrom

and talk to it from the laptop without opening it? If yes, wipe away. If not,
that

confirmation is the true prerequisite, above the wipe.



we can't confirm this without plugging the device into a computer, so... no we
haven't confirmed. We can't confirm. Just gotta wing it I guess. Unless you have
any better ideas...?


I checked the code. usb_init runs at boot from the SD kernel (002-main.c:194),
and

the PHY side (109a) is favorable — the doc's probe shows the OTG PHY already
out

of suspend at reset, nothing to un-power-down. The blocker is 109b: depcmd_issue

spins forever on the first DWC3 endpoint command — enumeration hangs.
009-usb.c

even says so in a comment. The leading hypothesis is already written down: the

controller's DCTL RUN/STOP bit must be set (or the event buffer finished) before

endpoint commands are accepted — resolved in TRM Part 2 Ch17.



great let's work on that.


1. "Write our own u-boot to the eMMC pointing at the SD" — not needed. The SD

already carries its own full boot chain (idbloader at sector 64, u-boot at
16384,

kernel), and the BootROM boots it directly — that's how every sweep so far has

run. Putting u-boot on the eMMC would only matter if the BootROM couldn't boot
SD,

and it demonstrably can. Drop that step: one fewer write to the soldered,

finite-life eMMC.


whenever we flash the SD card with a new kernel, are we writing to the same
memory locations? If so, that might cause damage to the memory card. Does the
internal software handle load distribution and stuff? How does that work?


--------------------------------------------------------------------------------

### Assistant Response 12

Lots of good questions — let me gather the facts before answering, rather than
hand-wave. Pulling the backlight probe, the PMIC/battery doc, the display doc,
and the USB enumeration code:


That reframes one of my own claims — let me correct it and pull the remaining
facts (the actual backlight spec, and the USB enumeration sequence for the work
you want to start):


Let me read the enumeration code to diagnose the hang before I write anything:


Let me see the core-init sequence in `009-usb.c` so my USB diagnosis is
grounded, not a guess:


Good batch of questions — and one of them catches me in a mistake. Let me go
through them, then get into the USB work you want to start.


## Backlight — I was wrong, walking that back


I conflated two different things. `pwm-bringup.probe` doesn't touch the
**display backlight** at all — it drives the **red indicator LED** (PWM1
channel 7) at ~10% duty as a pin-routing test. Indicator LEDs, low duty, not the
panel. So there's nothing there to burn out, and nothing to "set to the right
value" — it's already safe, and it's de-selected only because the LED layer
took over that job. My S8 worry was misattributed.


The *actual* panel backlight is a separate PWM channel we don't drive yet. And
its rated current is genuinely unknown — `docs/014-hardware-overview.md:167`
lists it explicitly under "still to extract," alongside the panel's DCS init
table. So there's no value to enforce until we build the backlight driver; when
we do, I'll pull the max current from the device tree's backlight node and the
panel driver before we ever raise the duty. Net: no fix needed now, and I
over-warned you. Good.


## eFuse / secure-boot — what that means


An eFuse is a microscopic physical fuse built into the chip's silicon.
"Programming" one means blowing it — pushing enough current to permanently
change it — and once blown it can **never** be restored; it's one-time and
physical. The chip has a bank of them (OTP, one-time-programmable). Some just
hold read-only facts like the chip ID (that's what `chip-otp` reads). Others are
*config* fuses — e.g. one that says "from now on, only run boot code signed
with key X" (secure boot). The OTP controller has two modes: a **read** path
(safe, reread a billion times — what our probe uses) and a **program/blow**
path (permanent). "Only reads, never a fuse-program command" means we
exclusively use the read path. The danger if we ever didn't: accidentally blow
the secure-boot fuse without owning the signing key → the chip rejects every
future flash → dead forever, no maskROM escape. It's the one peripheral where
a single wrong command is irreversible, so the rule is just "read side only."


## Battery — can we actually touch it?


Mostly your instinct is right, with one caveat. Per `docs/021`, the RK817 has an
**integrated battery charger**, and there's a separate CW2015 fuel gauge at i²c
`0x62`. The fuel gauge is read-only (it just reports charge %). But the charger
*is* software-configurable in principle — it's registers on the RK817 at
`0x20`, the same chip and same i²c bus our PMIC probes already talk to. So it's
not physically walled off. What protects us today is (a) we have **no code that
touches charger registers**, and (b) we don't even have the RK817 register map
(no datasheet in the repo), so we couldn't target them precisely if we tried.
The RK817 also enforces its own hardware charge-safety limits. So: reachable in
theory, untouched in practice, and the deny-list below would seal it off
explicitly.


## The PMIC deny-list — in more detail


Our probe engine has **two** ways to write hardware, and only one is guarded:


1. **MMIO writes** — the `W`/`WH`/`WB` script commands. These already pass
through `write_allowed(addr)`, which only permits the peripheral address
windows. A typo can't scribble on DRAM. Guarded.

2. **i²c writes to the PMIC** — `i2c0_write_reg(0x20, reg, val)`, used by
`pmic_write_test` and `rk817_ldo_set_mv`. **No guard at all.** Any RK817
register `0x00–0xFF`, any value.


That second path is the exposed one. From `docs/021` the dangerous targets are
concrete: DCDC_REG1 = `vdd_logic` (the CPU logic rail), DCDC_REG2 = `vdd_gpu`,
DCDC_REG3 = `vcc_ddr`, and the switchable LDOs. `rk817_ldo_set_mv` already knows
how to write LDO voltage registers (it uses `0xCC + (n-1)*2`). So the
reachable-today path is: set an LDO that feeds 1.8 V logic up to 3.4 V → fry
it.


The deny-list is a guard *inside the i²c-write path*, exactly mirroring
`write_allowed`: before `i2c0_write_reg` pokes the chip, it checks the target
register against a table and drops-and-logs a write to any voltage or charger
register. Two shapes:

- **Deny-list** — block a known-dangerous set (the buck/LDO `*_VSEL` registers, the charger config block), allow the rest. Easy, but you must know every dangerous register.

- **Allow-list (default-deny)** — block *everything* except a small set our probes legitimately need (the RTC comp reg, the read-only status regs). Safer, since an unknown register is dangerous-by-default — which matters because we *don't* have the full RK817 map.


I'd do the allow-list: it's the same "default-deny + explicit exceptions"
posture as the MMIO window check, and it means the one register class that can
kill the board is physically unwritable from a probe even by accident. Small,
self-contained, no hardware needed to land it.


## Maskrom — you're right we can't confirm it, but I think we have a better net


You can't confirm maskROM without plugging in, true. But I don't think maskROM
should be the safety net at all — **the SD card is a better one**, and it's
already in your hands:


- We boot from **SD**, and the boot never depends on the eMMC (every sweep proves it).

- Our kernel can **write** the eMMC (that's issue `110b`, bootable-emmc-overwrite, already done), and you have the **eMMC archive**.

- So the recovery loop is: bad state → reboot from a **known-good golden SD** → if needed, rewrite the eMMC archive from SD. That never touches maskROM.


The only unrecoverable case is "the SD boot chain *itself* is broken **and**
maskROM is unreachable" — and you kill the first half for free by always
keeping one tested golden SD and never flashing an untested image over it. So
the practical exposure is small, and "winging it" becomes reasonable *if* we (1)
keep a golden SD, (2) keep the archive, (3) confirm the eMMC-write-from-SD path
actually works before relying on it.


And the two ideas compound: **don't wipe the eMMC until USB is confirmed.**
Right now the stock eMMC OS is itself a fallback (the doc's
ADB→fastboot→maskROM path). The moment we fix the 109b hang and the device
enumerates on the laptop, we've *proven* the USB-C port carries a real data link
to the PC — which is 90% of the maskROM question, since maskROM uses the same
port and PHY. So: keep the eMMC as-is, get USB enumerating, plug in and observe,
*then* wipe if we still want to. The wipe becomes the last step, not the
prerequisite.


## SD card wear — are we hammering the same cells?


Logically yes, physically no. Every flash `dd`s to the same LBAs (block 0 up
through ~285 MB). But the SD card has a **Flash Translation Layer** — an
on-card controller that maps those logical block addresses to physical NAND
pages and does **wear leveling**: it deliberately spreads rewrites of the same
LBA across different physical cells so no single cell takes all the punishment.
We don't control it or see it; it's transparent. With a 285 MB image on a
multi-GB card, the controller has gigabytes of headroom to rotate through, and
SD cells are good for thousands of cycles each — so flashing thousands of
times is a non-issue, and SD is cheap and replaceable anyway. This is exactly
why you ration the **eMMC** instead: same wear-leveling, but it's soldered and
can't be swapped. (The eMMC also exposes its actual wear estimate — that's
what the `emmc-wear` probe reads out of EXT_CSD; SD cards generally don't report
it.)


## Now — the USB enumeration hang (109b)


I read both `009-usb.c` and `010-usb-enumeration.c`. Here's the diagnosis,
grounded in the code:


The hang is `depcmd_issue` spinning at line 547: `while (DEPCMD & CMDACT)`. The
controller only clears `CMDACT` when its **command state machine actually
executes the command** — and that state machine is clocked by the **USB2 PHY's
UTMI clock**. If that clock isn't running, the very first `DEPCMD`
(`DEPSTARTCFG`) can never complete, so we spin forever. That matches the symptom
exactly: not a wrong parameter (that'd complete with an error), but a command
that never even *runs*.


Two things in the bring-up point at an unclocked/half-reset core:


1. **`009-usb.c` never touches `GUSB2PHYCFG` (`0xFCC0C200`).** That register
carries the PHY suspend bit (`SusPHY`) and the UTMI reference-clock config. If
`SusPHY` is set, the PHY parks and stops feeding the controller its clock —
and `DEPCMD` hangs. The Linux dwc3 driver explicitly clears it during init; we
don't.

2. **We reset with `GCTL.CoreSoftReset` (bit 11)** — the *legacy* reset. The
modern DWC3 device init the driver uses is `DCTL.CSFTRST` **plus** toggling the
PHY soft-resets (`GUSB2PHYCFG.PHYSOFTRST`) around it. Using only the old GCTL
reset can leave the command interface not fully initialized.


So my plan, in order of likelihood:

1. In `009-usb.c`, before the endpoint bring-up: read/modify `GUSB2PHYCFG` to
**clear `SusPHY`** and set the ref-clock fields, and switch the reset to the
proper `DCTL.CSFTRST` + PHY-soft-reset sequence.

2. Add a bounded timeout to `depcmd_issue`'s spin so a future mistake **logs and
fails** instead of hanging the whole kernel (right now the "safe" watchdog would
just reset us — a bounded loop that reports "CMDACT stuck" is a far better
diagnostic, and it's the fail-loud posture the project wants).


Next concrete step is to pin the exact `GUSB2PHYCFG` bit positions and the reset
ordering against the DWC3 driver / TRM Part 2 Ch17 before I write it — I don't
want to guess register bits and burn a flash. Want me to go pin those down and
implement both changes (the PHY-clock fix + the bounded `depcmd` timeout), and
we validate it on the same flash as the RNG sweep? And should I land the PMIC
allow-list in that same batch, or keep it separate?


--------------------------------------------------------------------------------

### User Request 13

I conflated two different things. pwm-bringup.probe doesn't touch the display

backlight at all — it drives the red indicator LED (PWM1 channel 7) at ~10%
duty

as a pin-routing test. Indicator LEDs, low duty, not the panel. So there's
nothing

there to burn out, and nothing to "set to the right value" — it's already
safe,

and it's de-selected only because the LED layer took over that job. My S8 worry

was misattributed.



so it's dead code? we won't need this probe because there's another pwm system
that handles testing the LEDs and pwm system? If so... can we prune it?


The actual panel backlight is a separate PWM channel we don't drive yet. And its

rated current is genuinely unknown — docs/014-hardware-overview.md:167 lists
it

explicitly under "still to extract," alongside the panel's DCS init table. So

there's no value to enforce until we build the backlight driver; when we do,
I'll

pull the max current from the device tree's backlight node and the panel driver

before we ever raise the duty. Net: no fix needed now, and I over-warned you.

Good.



what's the status of that subsystem? Can we probe anything about the backlight /
display from a probe? Someone's working on the I/O validator, but if we can
gather anything silently without user interaction (like backlight details) then
we could write a probe for it.


An eFuse is a microscopic physical fuse built into the chip's silicon.

"Programming" one means blowing it — pushing enough current to permanently
change

it — and once blown it can never be restored; it's one-time and physical. The
chip

has a bank of them (OTP, one-time-programmable). Some just hold read-only facts

like the chip ID (that's what chip-otp reads). Others are config fuses — e.g.
one

that says "from now on, only run boot code signed with key X" (secure boot). The

OTP controller has two modes: a read path (safe, reread a billion times — what
our

probe uses) and a program/blow path (permanent). "Only reads, never a

fuse-program command" means we exclusively use the read path. The danger if we

ever didn't: accidentally blow the secure-boot fuse without owning the signing
key

→ the chip rejects every future flash → dead forever, no maskROM escape.
It's the

one peripheral where a single wrong command is irreversible, so the rule is just

"read side only."



can you write a "write" script for the OTP stuff that does nothing and outputs /
logs an error that's basically what you just said here? Make sure you say the
same things in a comment to. The idea is to say "hey you wanna do something
stupid? Here's a lever that you can pull" and if someone pulls the lever it says
"haha I tricked you, it doesn't actually do anything and here's why. Also you're
bad and should feel sorry for yourself because you almost ruined the device, ya
dummy. what a dingus. absolute moron."


I'd do the allow-list: it's the same "default-deny + explicit exceptions"
posture

as the MMIO window check, and it means the one register class that can kill the

board is physically unwritable from a probe even by accident. Small,

self-contained, no hardware needed to land it.



I like allowed-list better for this sort of thing. Question... Why don't we have
the datasheets? Can you find them online? Did you search in docs/datasheets/?


Next concrete step is to pin the exact GUSB2PHYCFG bit positions and the reset

ordering against the DWC3 driver / TRM Part 2 Ch17 before I write it — I don't

want to guess register bits and burn a flash. Want me to go pin those down and

implement both changes (the PHY-clock fix + the bounded depcmd timeout), and we

validate it on the same flash as the RNG sweep? And should I land the PMIC

allow-list in that same batch, or keep it separate?




yes please. and yes please.


--------------------------------------------------------------------------------

### Assistant Response 13

Green light received. Big batch — let me do the investigations first
(datasheets, the exact USB register bits so I'm not guessing), then implement.
Starting with the fact-finding:


The TRM Part 2 has the DWC3 registers — let me pin the exact bits from it
rather than trust memory. Reading the GUSB2PHYCFG field detail, the DCTL detail,
and that note about keeping the PHY clock alive:


Key finding already: `GUSB2PHYCFG0` resets to `0x40102400`, and decoding it
(`u2_freeclk_exists=1`, `lsipd=0x2`, `usbtrdim=0x9`) accounts for every set bit
— so **bits 9:0 are 0 at reset, meaning `SusPHY` is already clear**. My "clear
SusPHY" hypothesis was wrong; good thing I checked. Let me read the DCTL
run/stop rules and the lower PHYCFG bits to find the real cause:


The TRM gives me the smoking gun. **`GUSB2PHYCFG0` bit 6 (`suspendusb20`)**,
verbatim:


> *"In device mode, before issuing any device endpoint command when operating in
2.0 speeds, disable this bit and enable it after the command completes. If you
issue a command without disabling this bit ... if mac2_clk is gated off, **the
command will not get completed.**"*


"The command will not get completed" = `CMDACT` never clears = our exact hang.
And the doc-022 guess (RUN/STOP before endpoint commands) is *wrong* per the TRM
— `DCTL.run_stop` is for connecting to the host *after* CSR init. So the fix
is TRM-mandated: clear `GUSB2PHYCFG0[6]` before the endpoint-command sequence.
Let me confirm the datasheet-online question and 010's logging, then implement
everything:


RK817 datasheet **is** freely online (V1.7/V2.1, register map from ~p.47) —
I'll answer that and offer to grab it. Now let me implement all four things.
Reading the DWC3 define block for exact edit anchors:


The RK817 datasheet is freely online after all — good. Now implementing
everything. First, the OTP honeypot probe you asked for:


Now the PMIC write allow-list — the helper plus the guard in the i2c write
path:


Now the USB fix in `010-usb-enumeration.c` — the register defines, the
`SusPHY` clear, and a bounded (fail-loud) `depcmd` wait. First the defines:


Now the bounded `depcmd_issue` (with the `debug_write` extern it needs):


Now the actual fix — clear `SusPHY` at the top of endpoint-zero bring-up,
before any command:


Now build (debug, warnings) and assemble the image with all four changes:


Clean — 32 probes now, `otp-write` compiled in and DE-SELECTED (the dormant
lever). Assembling the image:


One consequence to handle cleanly: `pmic-ldo` is armed and calls the LDO
voltage-set path, which the new guard now blocks — that would print a
confusing "BLOCKED" + "OK" pair. Let me turn that into a coherent **self-test of
the guard** instead (keeps the code path exercised and proves the guard works):


All built, clean, final image **sha256 `bc85a553`**. Here's everything, and two
things I need to flag.


## What I built (in this image, pending the next flash)


**USB 109b — the enumeration hang, TRM-grounded.** The smoking gun was `GUSB2PHYCFG0` bit 6 (`suspendusb20`): the databook says outright that a device-mode endpoint command issued while it's set can find `mac2_clk` gated and *"will not get completed"* — our `CMDACT` spin, exactly. So I clear that bit at the top of endpoint-zero bring-up, before the first command. I also **corrected the doc's own hypothesis** — `DCTL.run_stop` is *not* required before endpoint commands (it's for connecting to the host after CSR init), so I didn't touch it. And I bounded `depcmd_issue`: instead of an infinite spin it now logs `DEPCMD stuck … (mac2_clk gated? check SusPHY)` and returns — fail-loud, so a future regression leaves a breadcrumb instead of a silent freeze.


**PMIC allow-list.** Default-deny in the i²c write path: `pmic_reg_write_allowed` permits exactly one register today (`0x10`, the RTC comp reg pmic-write round-trips) and refuses everything else — every VSEL voltage register, the charger, anything unrecognized — logged and dropped, un-overridable by a `#WRITES` probe, same posture as `write_allowed` for MMIO. And I turned `pmic-ldo`'s old "set-path OK" round-trip into a **guard self-test**: it now attempts the (same-value) LDO1 write and confirms the guard *refuses* it — so every armed sweep proves the safety floor is live.


**The OTP honeypot** (`input/probes/otp-write.probe`) — a `#WRITES`-marked, scary-named lever that issues zero writes and just logs the eFuse explanation and the scolding you asked for ("what a dingus. absolute moron. (said with love…)"). Compiled in, DE-SELECTED — arming it *is* pulling the lever.


## Your questions


**Datasheets — why not in the repo, and yes they're online.** They're not missing, they're **`.gitignore`d** on purpose: `docs/datasheets/.gitignore` is `*.pdf` because TRM Part 2 alone is 125 MB — bloating every clone. `INDEX.md` (tracked) lists each one and where to re-download it. We *do* have the RK3568 TRM 1+2, datasheet, SDHCI, JEDEC eMMC locally. What we lack is the RK817 PMIC datasheet — and it's freely findable (I searched): V1.7 and V2.1, register descriptions from ~p.47. The register map is *also* fully in the Linux `rk808`/`rk817` driver, which is what our code already cites. Want me to pull the PDF into `docs/datasheets/` (gitignored, local-only) the way the TRM was?


**pwm-bringup — dead code?** Not quite dead — it's a *dormant, armable* standalone check (de-selected, not unreachable), and its own header keeps it as the isolated "does the raw PWM channel + pin-mux actually work" test, independent of the LED abstraction. It *is* redundant with the LED layer (`003-pwm`/`004-led`) for normal operation, and it costs nothing idle. My lean: **keep it** — it's the one thing that isolates the PWM hardware from the LED abstraction, useful the day the LEDs misbehave and you need to know which layer broke. But nothing depends on it, so if you're trimming the battery it's a clean delete. Your call.


**Silent display/backlight probe — yes, very doable.** Read-only, no user interaction, we can gather: VOP2 **window-enable / scanout** registers (is a layer active, is a framebuffer address programmed — this finally answers "does u-boot actually draw to the panel?"), the **backlight PWM channel's period/duty/enable** (is it on, at what level), and DSI0/DSI1 presence (`0xFE850000`/`0xFE860000`). The one thing *not* silently gatherable is the backlight's rated max current — that's a datasheet/hardware spec, not a register. So a `display-recon` probe complements the interactive I/O validator nicely. To write it I'd pull the VOP2 window/scanout offsets from TRM Part 2 and the backlight PWM channel from the DTS. Want it in the next batch?


## Two flags


1. **The tree — and this image — carry someone else's in-progress work.**
Beyond my four files (`010-usb-enumeration.c`, `019-probe-engine.c`,
`otp-write.probe`, `110p`), the working tree has modified `002-main.c` and
`011-cdc-acm.c` and new `020-chips.c` + issues `115` (I/O validator) and `116`
(chip scripts / console-io) — that's the parallel effort. It all compiles, so
the **flashed image includes their uncommitted code**, not just mine. Good to
know for attributing what the next sweep shows, and I'll stage only my four
files when we commit.

2. **Validation load for the next flash is stacking up:** RNG sweep, the USB
fix, the PMIC guard's self-test — plus whatever the parallel work does. That's
fine, just a lot riding on one boot; the per-probe logs will separate it.


Ready for `push-to-usb` → `flash-sd` whenever. Want the RK817 PDF fetched
and/or the `display-recon` probe before you flash, or flash now and validate
this batch first?


Sources: [RK817 Datasheet V1.7
(rockchip.fr)](https://rockchip.fr/RK817%20datasheet%20V1.7.pdf) · [RK817
Datasheet V2.1
(boardcon)](https://www.boardcon.com/download/Rockchip_RK817_Datasheet_V2.1-20230320.pdf)
· [rockchip,rk817.yaml (kernel.org DT
binding)](https://www.kernel.org/doc/Documentation/devicetree/bindings/mfd/rockchip,rk817.yaml)


--------------------------------------------------------------------------------

### User Request 14

USB 109b — the enumeration hang, TRM-grounded. The smoking gun was
GUSB2PHYCFG0

bit 6 (suspendusb20): the databook says outright that a device-mode endpoint

command issued while it's set can find mac2_clk gated and "will not get
completed"

— our CMDACT spin, exactly. So I clear that bit at the top of endpoint-zero

bring-up, before the first command. I also corrected the doc's own hypothesis
—

DCTL.run_stop is not required before endpoint commands (it's for connecting to
the

host after CSR init), so I didn't touch it. And I bounded depcmd_issue: instead

of an infinite spin it now logs DEPCMD stuck … (mac2_clk gated? check SusPHY)
and

returns — fail-loud, so a future regression leaves a breadcrumb instead of a

silent freeze.



instead of saying this, which reads like a report on what you did (not
interested) can you walk me through the system, point at what you changed, and
explain the items in use and their relation to one another? For example for this
one, how does the USB pipeline actually work? What part did you modify?


Datasheets — why not in the repo, and yes they're online. They're not missing,

they're .gitignored on purpose: docs/datasheets/.gitignore is *.pdf because TRM

Part 2 alone is 125 MB — bloating every clone. INDEX.md (tracked) lists each
one

and where to re-download it. We do have the RK3568 TRM 1+2, datasheet, SDHCI,

JEDEC eMMC locally. What we lack is the RK817 PMIC datasheet — and it's freely

findable (I searched): V1.7 and V2.1, register descriptions from ~p.47. The

register map is also fully in the Linux rk808/rk817 driver, which is what our
code

already cites. Want me to pull the PDF into docs/datasheets/ (gitignored,

local-only) the way the TRM was?



oh. then why didn't you read them first instead of telling me you had no idea?
that's why they're there, you silly goose. :)


Silent display/backlight probe — yes, very doable. Read-only, no user
interaction,

we can gather: VOP2 window-enable / scanout registers (is a layer active, is a

framebuffer address programmed — this finally answers "does u-boot actually
draw

to the panel?"), the backlight PWM channel's period/duty/enable (is it on, at
what

level), and DSI0/DSI1 presence (0xFE850000/0xFE860000). The one thing not

silently gatherable is the backlight's rated max current — that's a

datasheet/hardware spec, not a register. So a display-recon probe complements
the

interactive I/O validator nicely. To write it I'd pull the VOP2 window/scanout

offsets from TRM Part 2 and the backlight PWM channel from the DTS. Want it in
the

next batch?



Okay, write a probe to gather the details. Also, look in the docs and see if you
can find the answers. If you can, then we don't need to probe them.


1. The tree — and this image — carry someone else's in-progress work. Beyond
my

four files (010-usb-enumeration.c, 019-probe-engine.c, otp-write.probe, 110p),
the

working tree has modified 002-main.c and 011-cdc-acm.c and new 020-chips.c +

issues 115 (I/O validator) and 116 (chip scripts / console-io) — that's the

parallel effort. It all compiles, so the flashed image includes their
uncommitted

code, not just mine. Good to know for attributing what the next sweep shows, and

I'll stage only my four files when we commit.



no need to be so defensive, they're your friend!


2. Validation load for the next flash is stacking up: RNG sweep, the USB fix,
the

PMIC guard's self-test — plus whatever the parallel work does. That's fine,
just a

lot riding on one boot; the per-probe logs will separate it.



MORE WEIGHT - let's gather more data. ^_^


--------------------------------------------------------------------------------

### Assistant Response 14

Fair — let me talk *systems*, not changelog. And you're right about the
datasheets: they're there to be read, not name-dropped. Let me apply that
immediately — before writing a display probe, I'll go read what we already
have. Researching first:


Docs + device tree answered most of it without needing a probe — good call to
look first. Let me resolve the two backlight PWM controllers from the DTS so the
probe can read their live state:


Everything I need is in the docs and DTS. Let me resolve the backlight
enable-GPIO controller, then I have the full picture:


Resolved: backlights are `pwm@fe700000`/`fe700010` ch0, enable on **gpio4** pins
4/3. And the DTS + docs answered nearly everything statically — so the probe
only needs to gather the one genuinely *runtime* fact. Writing it:


Image rebuilt with `display-recon` armed — sha256 `01fe9871`. Now let me
actually talk you through the USB machine, since that's the interesting part.


## How USB device-mode works here, and the one wire I touched


Picture it as a stack, cable at the bottom, "laptop sees a serial port" at the
top.


**The cable & the PHY.** A USB-C cable to the laptop carries two data wires (D+/D-). The **USB2 PHY** (an Innosilicon analog block, steered through a GRF syscon at `0xFDCA0000`) is what turns the controller's digital bitstream into the actual wiggling voltages on those wires. It runs off a 480 MHz PLL that it divides down to a ~60 MHz **UTMI clock — `mac2_clk`**. Hold onto that clock; it's the whole story. The PHY is allowed to *suspend* — gate `mac2_clk` — when the bus looks idle, to save power.


**The controller.** Above the PHY sits the **DWC3** (a Synopsys USB3 OTG core at `0xFCC00000`). It's the digital brain, and it's organized as a few register groups:

- *Global* (`GCTL`, `GUSB2PHYCFG`, `GSNPSID`…) — core-wide config,

- *Device* (`DCFG` = speed+address, `DCTL` = run/stop),

- *Per-endpoint command* (`DEPCMD`) — you drive each endpoint by writing a command here,

- an *event buffer* — a slab of RAM the controller writes into to tell you "a transfer finished," "the host reset the bus," etc.


Crucially: **the controller's command and link logic is clocked by `mac2_clk`,
which comes from the PHY.** The brain's heartbeat is borrowed from the analog
block below it.


**Endpoints & enumeration.** USB devices talk over *endpoints* (logical pipes). **EP0** is the control endpoint — the one the host uses to *enumerate*: on plug-in it resets the bus, then sends SETUP packets asking "who are you?", assigns an address, and reads your descriptors. So bring-up is really "get EP0 configured and armed to catch that first SETUP packet." To *catch* it you build a **TRB** (a tiny DMA descriptor in RAM) pointing at an 8-byte buffer and hand it to the controller with a command; the controller DMAs the packet in and posts an event. Once EP0 works, `011-cdc-acm.c` adds bulk IN/OUT endpoints and the device presents as a USB serial port — your debug channel.


**The bring-up path in code:** `usb_init` (009) ungates the USB clocks, brings the PHY out of reset, soft-resets the DWC3 core, sets device mode, pins USB-2.0 high speed, checks the controller ID. Then `usb_endpoint_zero_bringup` (010) sets up the event buffer and fires the endpoint-config commands — `DEPSTARTCFG` (allocate resources), `DEPCFG` (EP0 is control-type, 64-byte packets), `DEPXFERCFG`, enable EP0 — then arms EP0-OUT with a SETUP TRB.


**Where it hung, and the fix.** Every one of those commands goes through `depcmd_issue`: write the params, write `DEPCMD` with the `CMDACT` bit set, then **spin until the hardware clears `CMDACT`** — its way of saying "done." But executing that command runs on `mac2_clk`. If the PHY has suspended and gated `mac2_clk`, the command *can't run*, `CMDACT` never clears, and the spin is infinite. That was the freeze, on the very first command.


`GUSB2PHYCFG` bit 6 (`SusPHY`) is exactly the "let the PHY suspend" switch, and
the TRM says in so many words: in device mode, clear it before issuing endpoint
commands or a command "will not get completed." **So the one change that matters
is clearing `SusPHY` at the top of endpoint-zero bring-up, before the first
command** — pinning the PHY awake so its clock keeps feeding the controller's
command engine through the whole sequence. The bounded-spin change is just
insurance: if this ever regresses, `depcmd_issue` now logs "DEPCMD stuck
(mac2_clk gated? check SusPHY)" and returns instead of hanging the kernel.


And the relation the old doc got backwards: `DCTL.run_stop` is *not* upstream of
this. It's the "pull up D+ and actually connect to the host" switch — set
*after* all the endpoint config is done, not a precondition for it. Different
stage entirely.


## Display — you were right, the docs had most of it


I read `docs/023` and decompiled the device tree instead of guessing. What they
answered outright, so I did *not* probe:

- **Panel:** JD9365DA-H3, 640×480 RGB888, 4-lane MIPI DSI, one per screen — and its whole DCS init sequence is sitting in the DTS `panel_description` string (023 had it marked as a "gap," but it's right there).

- **Backlight:** it's a `pwm-backlight` at `pwm@0xFE700000`/`0xFE700010` (40 kHz), enabled via gpio4. Brightness is PWM *duty* only — **the LED forward current is fixed in hardware.** A pwm-backlight can dim but physically can't over-drive the LEDs, so there's no software path to burn the backlight and no "rated current" for us to enforce. That quietly closes safety scenario **S8**.


The *one* thing docs can't tell us — because it's live state, not spec — is
**whether the VOP2 is actually scanning a framebuffer to a panel right now**
(i.e. does u-boot light the screen). That's the `display-recon` probe: it reuses
display-presence's safe ungate/restore and reads the video-port standby bits,
the MIPI-interface-enable, the layer-enable, and the framebuffer address. Armed
for the next flash — it'll finally settle that question.


## The small stuff


Fair cop on the datasheets — read what we have first. Consider it applied: the
panel and backlight answers above came straight out of the docs and DTS, not a
shrug. And noted on the parallel work — they're a friend, not a merge
conflict; I'll just keep my own commits tidy when the time comes, no territorial
energy.


**MORE WEIGHT, then.** The batch riding the next flash is now: RNG sweep, the USB `SusPHY` fix, the PMIC guard's self-test, and `display-recon` (the OTP honeypot stays dormant). If you want to pile on more silent recon while we're here, cheap safe adds I can write next: **DSI-link state** (is the DSI host powered / PLL locked), the **backlight's live duty** (needs ungating the PWM2 domain), or a **thermal-sensor read** (what temperature is the chip actually running at). Say the word and I'll stack them on before you flash.


--------------------------------------------------------------------------------

### User Request 15

If you want to pile on more silent recon while we're here, cheap safe

adds I can write next: DSI-link state (is the DSI host powered / PLL locked),
the

backlight's live duty (needs ungating the PWM2 domain), or a thermal-sensor read

(what temperature is the chip actually running at). Say the word and I'll stack

them on before you flash.



What's a DSI-link? Also, the backlight's live duty probe sounds useful, same for
the thermal sensor.


I gotta be honest, I'm still not sure where we're at with the USB stuff. Can we
do anything more or do we just need to reflash?


--------------------------------------------------------------------------------

### Assistant Response 15

Good questions, and I want to be straight with you on the USB one. Let me pull
the facts first — the USB PHY bring-up code (the *other* thing that could be
wrong), and the register maps for the two probes:


Two important things surface here. Let me confirm one before I answer the USB
question — whether enumeration is even *called* at boot right now:


Two important facts here, and one changes the USB answer materially. Let me get
the last register details for the probes and pin down the TSADC map:


TSADC's register chapter didn't extract cleanly from the TRM (I'm not going to
guess thermal-sensor offsets — a wrong read there hangs the bus). And I hit a
bigger USB finding. Let me grab the one remaining backlight register, then I'll
lay it all out:


Both remaining pieces resolved: PWM3's gate is `CLKGATE_CON32` (`0xFDD20380`,
pclk bit 0), and I found the thing that reframes your USB question. Let me
implement, then explain.


First, wiring enumeration into the sweep so the fix is actually *exercised* —
the extern and the CALL target:


Now the two probes — the USB enumeration trigger and the backlight duty
reader:


Done — clean build, 35 probes, image **sha256 `19d304bd`**. Let me take your
questions in the order that matters, starting with the USB one because I owe you
a real answer there.


## USB — here's why you've felt unsure, and it's legitimate


I audited the boot path, and found the thing that's been making this murky:
**`usb_endpoint_zero_bringup` — the function my SusPHY fix lives in — is
declared in `002-main.c` but never actually called.** At boot, `usb_init()` runs
(brings the PHY and controller up into device mode, returns OK) and *stops
there*. Enumeration is never attempted. That's exactly why the kernel boots fine
and the probe sweep runs — the hanging code isn't in the boot path at all. It
was almost certainly disabled *after* someone hit the hang, so the rest of
bring-up could proceed, and that's what left 109b "open."


So the honest answer to "can we do more or just reflash": **a plain reflash
would have exercised none of the USB fix — we'd have learned nothing.** We had
to do more, so I did. I wired enumeration into the probe sweep — a `usb-enum`
probe that calls `usb_endpoint_zero_bringup` during the sweep (where `usb_init`
has already set up the controller), with the bounded `depcmd_issue` as the
safety net so it can't freeze the sweep. And I instrumented it: it logs
`GUSB2PHYCFG` before and after (did the fix clear SusPHY?), the bring-up result,
and — crucially — any `[usb] DEPCMD stuck` line.


So the next flash will actually *tell us where USB is*:

- `SusPHY=0 (fix cleared it)` + no "DEPCMD stuck" → the endpoint commands completed; the fix worked.

- `SusPHY=0` but a "DEPCMD stuck" → the PHY clock is still dead for a *different* reason. And I know the next suspect: the CRU `resetn_usb2phy0_por` reset, which `009`'s `usb2_phy_bring_up` never touches (it only does the GRF suspend write). It defaults to released, so it's a lower-confidence lead — but the log will settle it in one shot instead of a guessing game.


(I deliberately wired this through the probe engine, *not* `002-main.c`, since
your friend is mid-edit in that file.)


## What's a DSI-link


The VOP2 makes pixels, but the panel is a physical LCD at the end of a ribbon
cable — you don't want to run 24 parallel RGB wires + a clock down that cable.
**MIPI DSI (Display Serial Interface)** is the standard *serial* link that
replaces them: a few differential wire pairs ("lanes") carry the pixel stream as
high-speed serial packets, plus one clock lane. The "DSI link" is that pipe
between the chip and the screen. It has two ends — the **DSI host** inside the
SoC (`0xFE060000`/`0xFE070000`) and the panel's receiver — and a **MIPI
D-PHY**, the analog block that actually drives the lanes, with its own PLL
setting the bit clock. It runs in two modes: *command* mode (send the panel its
DCS init sequence — that big string in the device tree) and *video* mode
(stream pixels continuously). "Is the DSI link up" means: D-PHY PLL locked,
lanes in the right state, host powered, in video mode. On this device that's 4
lanes, RGB888, 640×480, one link per screen to a JD9365DA-H3. I didn't build a
DSI probe this round (you asked what it was, not for it) — easy to add if you
want it.


## Backlight duty — built


`backlight-duty` is written and armed. It ungates PWM3's clock (save/restore,
110o-style), then reads PERIOD/DUTY/CTRL for **both** screens' backlight
channels (`0xFE700000` and `0xFE700010`). DUTY÷PERIOD is the brightness
fraction; CTRL bit 0 tells you whether each channel is actually driving. So next
sweep you'll see, per screen, whether the backlight is on and how bright.


## Thermal — I'm going to *not* guess, and tell you why


The TSADC (temperature sensor) chapter didn't extract cleanly from my TRM text
dump — I have its base (`0xFE710000`) and its clock gate, but not the verified
DATA-register offset or the raw-code→°C conversion table. Reading a *wrong*
offset in a sensor block hangs the bus (same failure class as the VOP2/OTP
cases), so I won't ship a guessed-offset probe and risk a wasted flash. The
clean source is the Linux `rockchip_thermal` driver — it carries the exact
register map *and* the RK3568 code-to-temperature table. Let me pull that into
`docs/driver-refs/` (the way the OTP driver reference was captured) and write
the thermal probe properly next. Small delay, but it's the difference between
"here's the CPU temperature" and "the sweep hung on the sensor."


## The flash is now worth a lot


`19d304bd` carries, all armed: the RNG sample-rate sweep, the USB fix **plus its
exerciser** (this is the big one — USB is finally testable), the PMIC guard's
self-test, `display-recon`, and `backlight-duty`. The OTP honeypot stays
dormant. That's a genuinely heavy payload — one boot will tell us about
entropy, USB enumeration, the PMIC floor, whether firmware drives the panels,
and the backlight state.


Want me to pull the thermal driver ref and add that probe before you flash, or
send it now and get all this data back first?


--------------------------------------------------------------------------------

### User Request 16

The TSADC (temperature sensor) chapter didn't extract cleanly from my TRM text
dump — I have its

base (0xFE710000) and its clock gate, but not the verified DATA-register offset
or the

raw-code→°C conversion table. Reading a wrong offset in a sensor block hangs
the bus (same

failure class as the VOP2/OTP cases), so I won't ship a guessed-offset probe and
risk a wasted

flash. The clean source is the Linux rockchip_thermal driver — it carries the
exact register map

and the RK3568 code-to-temperature table. Let me pull that into
docs/driver-refs/ (the way the

OTP driver reference was captured) and write the thermal probe properly next.
Small delay, but

it's the difference between "here's the CPU temperature" and "the sweep hung on
the sensor."


Sure let's move forward on that.


--------------------------------------------------------------------------------

### Assistant Response 16

On it. The safe path is the Linux driver's verified register map — let me pull
it:


The driver gives me verified offsets — `DATA0`=`0x20` (CPU), `DATA1`=`0x24`
(GPU), 12-bit code, higher code = hotter, with the RK3568 conversion table. Let
me get the TSADC clock gate (so the read can't hang), then capture the reference
and write the probe:


TSADC clock gate is `CLKGATE_CON26` (`0xFDD20368`, pclk = bit 4) — the same
register the OTP probe uses, so I'll restore only the TSADC bits and leave OTP's
alone. Let me capture the driver reference and write the probe. First, the
existing driver-refs index:


Per the driver-refs convention, the reference is the actual driver source.
Fetching it:


Table confirmed. Now the driver-ref index entry, and the probe:


Done, and done properly — no guessed offsets.


I pulled the Linux `rockchip_thermal.c` into `docs/driver-refs/` (verified:
`DATA0` at `0xFE710020` = CPU, `DATA1` = GPU, 12-bit code, higher = hotter, plus
the full RK3568 code→°C table) and noted it in the driver-refs index for the
team. The `thermal` probe is written and armed: it ungates the TSADC clock
(save/restore — and since that gate register is *shared* with the OTP clocks,
the masked restore touches only the TSADC bits and leaves OTP's alone), reads
`AUTO_CON` + both channels, and logs the codes with the decode anchors right
there.


**How you'll read it next sweep:**

- `AUTO_CON` bit 0 = 1 → firmware has the sensor running (RK3568 usually does, for thermal-shutdown protection), so `DATA0`/`DATA1` are **live**. Decode: `2024 ≈ 25 °C`, `2196 ≈ 50 °C`, `2500 ≈ 95 °C` (the shutdown point), roughly `°C ≈ (code − 1856) / 6.78`. So a CPU code around 2050–2150 means a comfortable 30–45 °C.

- `AUTO_CON` bit 0 = 0 → the sensor's idle and the DATA is stale. That's still a useful answer — it means firmware *didn't* start the TSADC, and the next step is a bring-up probe (which needs the GRF analog init — the reference I just captured unblocks exactly that). Either way the sweep tells us where we stand, no hang.


Final image **sha256 `8eed1219`**, 36 probes. What's riding this flash, all
armed: RNG sample-rate sweep, the USB fix **+ its exerciser**, the PMIC guard
self-test, `display-recon`, `backlight-duty`, and now `thermal` — with the OTP
honeypot dormant. One boot will report entropy quality, where USB enumeration
actually gets, the PMIC floor, whether firmware drives the panels, the backlight
state, and the die temperature. That's a lot of weight on one boot. Ready when
you are.


--------------------------------------------------------------------------------

### User Request 17

okay logs at /mnt/generic


--------------------------------------------------------------------------------

### Assistant Response 17

The `cd` glitched — let me look again, carefully, and find the newest actual
sweep:


There it is — a fresh `180538` sweep with all the new probes. Reading the
headline results — USB first:


Big haul, and it's genuinely informative. Let me give you the honest readout —
wins first, then the USB truth.


## RNG — the sweep worked, and it answered the knob question


This is exactly what we built it for. Watch the nibble histogram flatten as the
sample rate climbs:


| `sample_cnt` | nibble spread | bit balance |

|---|---|---|

| **0** | spiked `5:27 A:24` — heavy alternating-bit bias | 131/256 |

| **16** | spiked `0:20 F:19` — flips to a *runs* bias | 125/256 |

| **64** | spiked `5:16 A:20` — still biased | 133/256 |

| **256** | `0:1 1:4 2:3 3:5 4:5 5:7 … F:4` — **flat, ~4 each** | 126/256 |

| **1024** | also flat | 125/256 |


So the TRNG whitens sharply around **`sample_cnt = 256`**: below that, the
oscillator bits are correlated and you get the `0x5`/`0xA` shimmer (or, at
cnt=16, the opposite runs-bias); at 256 the distribution is uniform and the bit
balance sits near the ideal 128. The old code's default of 0 was the worst case.
If we ever use the TRNG for real, `RNG_SAMPLE_CNT = 256` is the answer —
measured, not guessed.


## PMIC guard — proven live on hardware


```

guard self-test: LDO1 voltage write must be refused...

PMIC WRITE BLOCKED (not on allow-list): reg 0x000000CC

REFUSED, rail unchanged -- guard OK

```


The allow-list refused a voltage-register write on the real chip, rail
untouched. The one software path to a dead board is now floored. (Bonus: a clean
power-rail snapshot — LDO1/7/8 = 1.8 V, LDO2/3 = 0.9 V, LDO4/5/6 = 3.3 V, LDO9
= 2.8 V.)


## Display — question settled: firmware does NOT light the screens


```

SYS_DSP_INFACE_EN = 0x00000000 (no MIPI interface enabled)

POST0/1/2_DSP_CTRL = 0x8000000F (bit31 standby = 1 on all three video ports)

Esmart0 MST_CTL = 0, MST_YRGB = 0 (no layer, no framebuffer)

```


Every video port is in standby, no interface is up, no layer, no framebuffer —
and `backlight-duty` agrees: both backlight PWM channels read `CTRL=0` (off). So
the panels are **completely dark** during our SD boot; u-boot/ROCKNIX never
touches the display. That's the definitive answer to the question we've been
circling.


## Thermal — safe, but the sensor's asleep


```

AUTO_CON = 0x01000000 (bit0 AUTO_EN = 0 -> not converting)

DATA0 (CPU) = 0x0, DATA1 (GPU) = 0x0

```


Firmware didn't start the TSADC, so there's no live temperature — exactly the
"idle" case the probe was built to detect rather than hang on. So: no reading
yet, but no crash, and the restore left the shared OTP clock bits alone. Getting
a real temperature needs the bring-up (enable auto-conversion + the GRF analog
init) — the follow-up the driver reference now unblocks.


## USB — the fix missed, but we finally *know* why


I'll be straight: **SusPHY was not our bug.**


```

GUSB2PHYCFG before = 0x40102400 SusPHY=0 <- already clear

[usb] DEPCMD stuck ... on ep 0

[usb] DEPCMD stuck ... on ep 0

[usb] DEPCMD stuck ... on ep 1 (x6 — every endpoint command stuck)

GUSB2PHYCFG after = 0x40102400 SusPHY=0

```


SusPHY was already 0 at entry (it's 0 in the reset value), so clearing it
changed nothing, and all six endpoint commands still stuck. The databook note
was real but we were already satisfying it. **`mac2_clk` is dead for a different
reason** — which means the culprit is upstream, in the PHY itself: `009`'s
`usb2_phy_bring_up` only writes the GRF suspend word and never brings the PHY's
clock/PLL up (no CRU `resetn_usb2phy0_por` release, no PHY-clock ungate). That's
the real 109b bug, and this flash localized it precisely.


Two things earned their keep here: the **bounded `depcmd`** turned what used to
be an infinite kernel hang into six clean log lines and a completed sweep, and
the **instrumentation** ruled SusPHY out instead of leaving us guessing. So even
though the fix didn't land, we spent the flash well — we went from "USB hangs
somewhere" to "the USB2 PHY clock never starts, and here's the function that
should start it."


## Where that leaves us / next


- **USB (the real fix):** pull `phy-rockchip-inno-usb2.c` into driver-refs, find the CRU USB2-PHY clock gate + the `resetn_usb2phy0_por` reset, and add a proper PHY power-up to `usb2_phy_bring_up` — then the `usb-enum` probe re-tests it next flash.

- **Thermal:** a small bring-up probe (enable auto-convert + GRF analog init from the driver ref) to get an actual temperature.

- **Record the wins:** note `sample_cnt=256` in the RNG issue, and "firmware leaves the display dark" in the display doc.


Want me to go after the USB PHY clock next (it's the highest-value thread), and
fold the thermal bring-up in alongside it?


--------------------------------------------------------------------------------

### User Request 18

Okay. Are there any probes we don't need anymore? If so, please mark them as
unneeded.


Firmware didn't start the TSADC, so there's no live temperature — exactly the
"idle" case the

probe was built to detect rather than hang on. So: no reading yet, but no crash,
and the restore

left the shared OTP clock bits alone. Getting a real temperature needs the
bring-up (enable

auto-conversion + the GRF analog init) — the follow-up the driver reference
now unblocks.



what's the TSADC? OTP means one time programming, so you better be absolutely
sure we never touch them ever - except to read. In which case... why didn't we
read them? If we wanted to read them.


Getting a real temperature needs the bring-up (enable

auto-conversion + the GRF analog init) — the follow-up the driver reference
now unblocks.


ah I see. Well, let's work on that then!


Where that leaves us / next


- USB (the real fix): pull phy-rockchip-inno-usb2.c into driver-refs, find the
CRU USB2-PHY

clock gate + the resetn_usb2phy0_por reset, and add a proper PHY power-up to
usb2_phy_bring_up —

then the usb-enum probe re-tests it next flash.

- Thermal: a small bring-up probe (enable auto-convert + GRF analog init from
the driver ref) to

get an actual temperature.

- Record the wins: note sample_cnt=256 in the RNG issue, and "firmware leaves
the display dark"

in the display doc.



--------------------------------------------------------------------------------

### Assistant Response 18

Good cleanup instinct — several probes have answered their question and don't
need to keep running. Let me grab the thermal bring-up constants (I have the
driver locally now) and confirm the probe markers, in one pass:


Constants captured. I need the exact enable sequence and the GRF base before I
write anything that pokes the sensor. One more targeted read:


I have everything verified now: **SYS_GRF at `0xFDC60000`** (so the TSADC analog
control is `0xFDC60600`), the exact init sequence (`rk_tsadcv7_initialize` +
`rk_tsadcv3_control`), and all the constants. Let me de-select the done probes
and upgrade thermal to a real bring-up.


De-selecting the five that have answered their question:


The two I only `head`'d via Bash need a proper Read first. Reading them, then
finishing the de-select and the thermal upgrade:


Five de-selected. Now the thermal bring-up — enabling the sensor per the
driver, reading a real temperature, then restoring it to idle:


Let me confirm the exact armed roster for the report (the no-op rebuilds
swallowed it):


All set — image **sha256 `ba7278e2`**, clean build. Let me answer your
questions and lay out what changed.


## What's the TSADC


**Temperature Sensor ADC.** It's an on-die analog block (RK3568 has it at `0xFE710000`) that works in two halves: a temperature-sensitive circuit whose voltage drifts with heat, and an ADC that digitizes that voltage into a number. Two channels — one sits by the **CPU** cluster, one by the **GPU**. Its main job is safety: the chip can be told "if the sensor crosses 95 °C, pull a shutdown line" (that's the `tshut` we saw in the reset registers). We're using it just for its reading — the raw code comes out, and a calibration table (`rk3568_code_table`) maps code → °C. Firmware normally starts it for thermal protection, but on our SD boot it's asleep, which is why the read-only probe saw zeros.


## OTP — you're right to press on this, so let me be precise


**We never program a fuse. Ever.** There are two separate things, and I muddied them last time:


1. **The OTP fuses themselves** (the one-time, permanent bits). We **read**
these — that's the `chip-otp` probe, and it *did* read them: an earlier sweep
pulled the chip-ID words (word 0 = `0x4B52` = "RK" in ASCII, etc.). To read, the
code writes to the OTP *controller's* config registers to put it in read mode
— but it never issues a program/blow command, so the fuses are only ever read,
never changed. The `otp-write` honeypot is the proof-by-contradiction: it looks
like a fuse-writer and does nothing. I've kept `chip-otp` armed, so you'll see
the read again next sweep.

2. **The "OTP clock bits" I mentioned in the thermal context** are *not* fuses
— they're clock-enable bits (9–11) that happen to live in the same CRU
clock-gate register as the TSADC's bits. The thermal probe leaves them alone
simply because it has no business powering up the OTP controller; that's
unrelated to reading fuses. So "why didn't thermal read them?" — because
reading the fuses is `chip-otp`'s job, not thermal's; thermal just politely
didn't touch a neighbor's clock switch.


Bottom line: fuses = read-only for us, and I'm certain of it — there's no
program-command code anywhere in the tree.


## Probes marked unneeded (5)


These answered their question definitively, so I de-selected them (still
compiled in, just dormant — re-arm anytime):


- **`audio-codec`** — its own header says "TEMPORARY, probe-and-remove"; the register dump is captured.

- **`rng`** — the sweep answered the knob (`sample_cnt=256` whitens); no need to re-sweep every boot.

- **`display-presence` + `display-recon`** — display is settled: firmware leaves both panels idle/dark.

- **`backlight-duty`** — settled: both backlights off.


That leaves a still-largish armed roster (24). The **fixed-fact recon** —
`cpu-clock-recon`, `cpu-core-recon`, `gic`, `generic-timer`, `i2c-scan`,
`pmic-dump`, `pmic-write`, `crypto` — and the **storage battery** (`emmc-*`,
`sd-*`) have all passed and captured their facts too; I left them since they're
cheap and foundational, but say the word and I'll trim those to a lean sweep as
well. (One note: `saradc-gamepad` is armed and it's a `#WRITES` probe — that's
not from me, likely the parallel work; flagging it since it'll run.)


## Thermal — now a real bring-up


`thermal` is upgraded from read-only to a proper sensor bring-up, following the
vendor driver exactly: ungate the clock, run `rk_tsadcv7_initialize`
(interrupt-PD, auto-period, debounces, low-active polarity), power up the analog
through **SYS_GRF** (`0xFDC60600`: TSEN → settle → ANA_REG0/1/2), then
`rk_tsadcv3_control` to enable auto-conversion, wait for samples, and read
`DATA0`/`DATA1`. Then it **restores every register it touched** — the sensor
is handed back idle, exactly as found (110o); the temperature lands in the log
during the read, before the restore. Next sweep you should see real codes:
decode is `°C ≈ (code − 1856) / 6.78`, so a CPU code around 2050–2150 is
a healthy 30–45 °C.


If `DATA` still reads 0 after this, it's not a hang — it means auto-enable
alone isn't triggering conversion and there's a channel-source-enable step to
add (the `AUTO_SRC_CON` register), which I'd chase next. But this follows the
driver's RK3568 path faithfully, so I expect real numbers.


Ready to flash whenever — this sweep will give us the die temperature and
re-confirm the OTP read, on a leaner roster.


--------------------------------------------------------------------------------

### User Request 19

okay logs are in


--------------------------------------------------------------------------------

### Assistant Response 19

**OTP read confirmed** (chip ID `RK`… words, restored cleanly, never written — exactly as it should be). And the thermal bring-up ran perfectly *mechanically* but hit the wall I predicted:


```

R 0xFE710004 = 0x00010003 <- AUTO_CON: AUTO_EN=1, auto-convert IS enabled

R 0xFE710020 = 0x00000000 <- DATA0 (CPU) still 0

R 0xFE710024 = 0x00000000 <- DATA1 (GPU) still 0

```


So enabling `AUTO_EN` alone isn't triggering a conversion — it's the
channel-source-enable step. Let me find exactly how the driver arms the
channels:


The channel source-enable is a separate write the driver does per-channel. There
are two variants (v2 in `AUTO_CON`, v3 in `AUTO_SRC_CON`) — let me see which
RK3568 uses:


That's the missing step — the source-enable lives in the `set_tshut_temp`
callback. Let me confirm which variant RK3568 uses (v2 = `AUTO_CON` bit 4+chn,
v3 = separate register):


Confirmed: RK3568 uses **`rk_tsadcv2_tshut_temp`** → the source-enable is
`AUTO_CON |= BIT(4+chn)`, and the `tshut` routes **to the PMIC via GPIO** — so
I must also park the shutdown threshold high so it can't trip mid-probe. Fixing
the thermal probe: add the per-channel source bits (`AUTO_CON = 0x33`) and a
safe `COMP_SHUT`:


Two clean results, and the thermal fix is in.


**OTP — confirmed, exactly as it should be.** `chip-otp` read the fuses again — chip-ID words came out (`0x4B52` = "RK", then the per-die words), and it restored the clock/reset cleanly. Read-only, never programmed. So your concern is put to rest: we read them, we never touch them otherwise.


**Thermal — the bring-up was mechanically perfect, and failed exactly where I said it would.** Every write landed, `AUTO_CON` came back `0x10003` (auto-convert genuinely enabled), the restore put everything back — but `DATA0`/`DATA1` were still `0`. So `AUTO_EN` alone doesn't start a conversion; the per-channel *source* has to be armed too.


I traced it in the driver: RK3568 uses `rk_tsadcv2_tshut_temp`, which arms each
channel with `AUTO_CON |= BIT(4+chn)` — the `AUTO_SRC_EN` bits my first
attempt didn't set. So the fix is `AUTO_CON = 0x33` (enable + Q-select + **both
channel sources**).


One safety catch I want to flag, because it's the kind of thing that bites: the
driver notes `tshut` on this chip routes **to the PMIC via a GPIO** — i.e. an
over-temperature trip can tell the PMIC to cut power. So before arming the
channels I now park the shutdown threshold at maximum (`COMP_SHUT = 0xFFF`, ~125
°C+), so it physically can't fire while we're poking around at room
temperature, and it's restored afterward. Getting a temperature reading should
never risk a shutdown.


Rebuilt with the fix — **sha256 `4ee87566`**. Next flash should finally hand
back a real CPU/GPU code (decode `°C ≈ (code − 1856) / 6.78`). Ready when
you are.


--------------------------------------------------------------------------------

### User Request 20

um, can we set the max to something that would damage the chip, like 90 degrees?
better safe than sorry, and I can assure you my room is well below 90 degrees,
both fahrenheit and celsius. What's the difference between celsius and
"centigrade"? Sometimes I hear europeans say that... Anyway where are we at with
USB debugging? That's the real blocker here.


--------------------------------------------------------------------------------

### Assistant Response 20

Good instinct — and you're right, I over-corrected. Parking it at 125 °C
means "no protection during the probe," when the point of a shutdown threshold
is *to protect*. 90 °C it is: real overheat protection, and your room is indeed
well under 90 (in either scale — see below). Fixing that, and kicking off the
USB research in the same breath:


There it is — the PHY has a **`clkout_ctl`** register: "enable output clk of
phy." If that 480 MHz output isn't enabled, the controller never gets `mac2_clk`
— the exact symptom. Let me find the RK3568 config block:


This is a potentially big finding: the driver's RK3568 USB2 PHY lives at
**`0xFE8A0000`**, but `009` writes to `0xFDCA0000`. And the PHY needs its **480
MHz clock output enabled** (`clkout_ctl` at `+0x0008`), which `009` never does.
Before I trust the driver over our code, let me check the board's *own* device
tree — the ground truth:


The board's device tree is unambiguous: **`usb2phy@fe8a0000`** with an
`otg-port`, and the peripheral DWC3 (`dr_mode="peripheral"`) points its phy
there. The `syscon@fdca0000` that `009` pokes is just an auxiliary GRF —
**`009` has been configuring the wrong block, and never enables the PHY's 480
MHz output clock.** That fully explains a dead `mac2_clk`. Let me nail the exact
write semantics before I touch it:


**This is very likely the USB bug.** The struct confirms `clkout_ctl = { 0x0008, 4, 4, 1, 0 }` — enabling the PHY's 480 MHz output means writing `0` to bit 4 of `0xFE8A0008` — and `009` never does that (it pokes the wrong block entirely, `0xFDCA0000`). No PHY clock out → no `mac2_clk` → every `DEPCMD` stalls.


One safety check before I touch the boot path — whether `0xFE8A0000` needs a
clock ungated first (writing a gated block hangs, and a hang in `usb_init` would
freeze the boot silently):


Confirmed on all fronts: `USB2PHY_U3OTG @ 0xFE8A0000` is in the memory map, the
DTS names its output `clk_usbphy0_480m` (the clock that becomes `mac2_clk`), and
its register access doesn't need a separate gate we're missing. So this is a
high-confidence fix.


To be safe against a silent boot hang, I'll apply the corrected PHY bring-up in
the **sweep** (via `usb-enum`) rather than the boot path — a bad access there
fails into the watchdog with logs, not a frozen boot:


Big progress on the real blocker. Image **`daf1fa91`** carries both fixes.


## USB — I found the actual bug, and it's a good one


Last flash ruled out SusPHY (it was already clear, `mac2_clk` still dead), so
the problem had to be upstream in the PHY itself. I pulled the inno-usb2 PHY
driver and cross-checked it against **this board's device tree** — and there
it was:


The USB2 PHY our peripheral controller uses is **`usb2phy@fe8a0000`** (the DTS
names its output `clk_usbphy0_480m`, and the `dr_mode="peripheral"` DWC3 points
right at it). But `009-usb.c` has been writing to **`0xFDCA0000`** — a
*different*, auxiliary GRF syscon. **We've been configuring the wrong block this
whole time; the real PHY was never touched.**


And the specific consequence is exactly our symptom. That PHY has a `clkout_ctl`
register — bit 4 of `0xFE8A0008` — that **enables its 480 MHz output**. That
480 MHz *is* what becomes `mac2_clk`, the clock the controller's command engine
runs on. `009` never enabled it (it can't — it's poking the wrong address). No
clock-enable → no `mac2_clk` → every `DEPCMD` stalls forever. The whole
hang, explained by a one-block address mistake.


The fix, verified against both the driver's `rk3568_phy_cfgs` and the board DTS:
enable the 480 MHz output (`0xFE8A0008` bit 4 → 0) and resume the OTG port
(`0xFE8A0000` bits [8:0] → 0), at the correct base.


I put it in the **`usb-enum` probe** rather than the boot path on purpose: if a
PHY-register access is wrong it would hang, and a hang in `usb_init` freezes the
boot *silently* with no logs — whereas in the sweep it fails into the watchdog
with the log intact. The probe now writes the two PHY registers, reads them back
(did the writes land?), then re-runs enumeration. So next flash tells us
plainly: if the "DEPCMD stuck" lines are **gone**, USB is alive. Once proven, it
moves permanently into `usb2_phy_bring_up`. I'm genuinely optimistic about this
one — a wrong-address bug is a concrete, explanatory root cause, not a maybe.


## Thermal — 90 °C protection set


Done: the shutdown threshold is now `COMP_SHUT = 0x9A4` (~90 °C), so if the die
is genuinely that hot the tshut→PMIC line cuts power (better a shutdown than a
cooked chip), and room temperature is nowhere near tripping it. Restored to
as-found after the read, so the protection is live during the probe window.


## Celsius vs "centigrade"


Same scale, zero numerical difference — `20 °C = 20 centigrade`. "Centigrade"
is the *old* name: *centi* (100) + *grade* (degrees), i.e. the 100 divisions
between water freezing (0) and boiling (100). It was officially renamed
**Celsius** in 1948, after Anders Celsius who devised it — partly to honor
him, and partly to stop it clashing with "centigrade" as an *angle* unit (the
gradian, where 100 grads make a right angle, used in surveying). Older Brits and
much of Europe still say "centigrade" out of habit; it means exactly the same
thing. Your room is comfortably under 90 in both — and, reassuringly, under 90
°F too.


Ready to flash — this is the one that should light up USB.


--------------------------------------------------------------------------------

### User Request 21

okay logs are in


--------------------------------------------------------------------------------

### Assistant Response 21

Both fixes ran but didn't land — and the logs tell me exactly why. Let me read
them honestly.


**USB:** `clkout_ctl@0xFE8A0008 = 0x00000000` — reading that block returns *all zeros*, which means **`0xFE8A0000` isn't the register interface** (it's the PHY node's match address, but the control registers live in the `usb2phy0_grf` syscon at `0xFDCA0000`). My writes went nowhere, and the `DEPCMD`s are still stuck. But this pins it down: the driver's offsets are relative to `0xFDCA0000`, so the clock-enable bit is **`0xFDCA0008`** — and that's exactly the `CON2 usbphy_commononn` bit doc-022 already flagged (`0` = 480 MHz PLL always on). Correcting the address:


Now a diagnostic on why thermal armed correctly (`AUTO_CON = 0x33`, both channel
sources on) but `DATA` is still 0 — most likely the analog sensor didn't
actually power up. Reading the GRF analog reg back to find out:


Two more misses — but each one narrowed the target, and I'm now pointed at the
register doc-022 itself flagged. Image **`443b2cd2`**.


## USB — now aimed at the right block


The last flash was decisive even though it failed: writing `0xFE8A0000` read
back **all zeros**, which proves that address isn't the live register interface
— it's the PHY's *match* address in the device tree, but the actual control
registers are in the `usb2phy0_grf` syscon at **`0xFDCA0000`** (the exact block
doc-022 successfully read as `CON0 = 0x0C52`). So the driver's offsets are
relative to `0xFDCA`, not `0xFE8A`.


And that lands the clock-enable precisely on the bit doc-022 already called out:
**`CON2` bit 4, `usbphy_commononn`, at `0xFDCA0008`** — `0` = "480 MHz PLL
always on," `1` = "PLL off when both ports suspend." With no USB port active,
that PLL was off, `mac2_clk` was dead, and every command stalled. I've corrected
the write to `0xFDCA0008` (masked, bit 4 → 0) and it reads the register back
so we can confirm it took. This is the same PLL-control bit two independent
sources (the doc's register decode and the Linux driver's `clkout_ctl`) point at
— so I'm confident on the address now in a way I wasn't with the last two
attempts.


I want to be straight that this is the third USB swing. But the trajectory is
real narrowing, not flailing: *SusPHY ruled out → it's the PHY clock → wrong
syscon block → the correct block's PLL bit.* We're out of address ambiguity.


## Thermal — the source-enable worked; the analog didn't


Good news buried in the miss: `AUTO_CON` read back `0x00010033`, so the
per-channel source-enable (`SRC0|SRC1`) took — the channels are armed. But
`DATA` is still 0, which now points at the **analog sensor not powering up**:
the `SYS_GRF` TSEN/ANA writes either didn't land or weren't enough. I added a
readback of that GRF register (`0xFDC60600`) so the next sweep tells us plainly
whether the analog power-up stuck. Secondary to USB, but the diagnostic is cheap
and rides along.


Ready to flash. If `CON2@0xFDCA0008` comes back with bit 4 clear and the `DEPCMD
stuck` lines finally vanish, USB is alive — and that's the one that unblocks
everything.


--------------------------------------------------------------------------------

### User Request 22

Could it be because we don't have a USB cable plugged into the device? We use
USB to charge, does that have something to do with it? Also, there's two USB-C
ports. Which are we targetting? Does it matter?


--------------------------------------------------------------------------------

### Assistant Response 22

These are sharp questions, and I think you may have just put your finger on
something I've been poking around. Let me check the board's USB topology in the
device tree rather than guess — the two-port question especially matters:


Really useful — the device tree makes the topology clear, and it reframes the
whole thing. Let me get the last detail (what drives VBUS / identifies the
peripheral port):


The device tree confirms your instinct is right, and it reframes the problem.
Let me add a connection-state readback so the sweep actually *tells* us what's
plugged in, then explain:


Built (`e8f2687b`), and honestly — you may have just cut to the heart of it.
Let me answer all three, because they're connected.


## 1. The cable — yes, this is very likely central


`usbphy_commononn` literally means "PLL **off** when both ports suspend." A USB
port "suspends" when nothing's actively connected to it. So: nothing plugged
into the peripheral port → port suspended → (at the default) the 480 MHz PLL
is off → `mac2_clk` dead → every `DEPCMD` hangs. That *is* the "no cable"
you're describing, spoken in hardware. And here's the corroboration I hadn't
noticed: the device tree tags our controller with **`snps,dis_u2_susphy_quirk`**
— "don't let this PHY suspend." Mainline *knows* this port needs the PHY kept
awake. So we've been chasing the right ghost.


But there's a distinction I should be crisp about, because it changes
expectations:

- **Forcing the PLL on (commononn=0) lets the controller commands complete** — that needs no cable. That's what the next flash tests.

- **The device actually appearing on a PC needs a host on the other end** — a PC to supply VBUS, reset the bus, and ask "who are you?" No register poke substitutes for that.


So "USB debugging works" is really two milestones: (a) controller/PHY/clock
alive — testable on battery, and (b) enumerates on a PC — needs the cable.
We've only ever been able to test (a).


## 2. Charging — power, not a host


The RK817 handles charging; VBUS just arrives on the USB-C port. Plug a
**charger** into the peripheral port and you get VBUS (power) but no data host
— the device sees "something's connected" and waits for a PC that never talks.
Plug a **PC** into that same port and you get both: it charges *and* it's a
host. The data lines are separate from VBUS, so charging doesn't interfere —
it just isn't a host. For debugging: a PC, not a charger.


## 3. Two ports — yes, it matters, and they're not interchangeable


The device tree is unambiguous:

- **Peripheral port** = `usb2phy0` → the DWC3 at `0xFCC00000`, `dr_mode="peripheral"` — hard-wired as a *device*. **This is the only port that can present as a gadget to a PC. It's our target.**

- **Host port** = `usb2phy1` → the USB *host* controllers (for plugging accessories *into* the handheld).


Plug a PC into the host port and nothing happens for us. And there's no Type-C
role controller on this board (no `fusb302`/`tcpc` in the tree), so the roles
are **fixed by wiring** — each physical port is permanently one or the other.
Which physical one is the peripheral port? The DTS doesn't say, but on these
handhelds the peripheral/OTG port is almost always the port that also
**charges** — so the port you charge from is very likely the one to plug the
PC into.


## What I changed, and the plan


`usb-enum` now reads the OTG connection status (`0xFDCA00C0`) and prints
`VBUS=PRESENT` or `VBUS=absent` — so the next sweep tells us, in plain text,
whether anything was plugged into the peripheral port when it ran. No more
guessing.


- **Next flash:** if the `DEPCMD stuck` lines vanish (they should, even with nothing plugged in, now that the PLL is forced on), the controller path is alive — milestone (a). The `VBUS=` line confirms what was connected.

- **Then, for a real console:** plug a PC into the peripheral (charge) port and we drive the full gadget + CDC-ACM. That's where the cable is non-negotiable.


Good instinct to stop and ask — it's the difference between "the PHY won't
wake up" and "there was never a host to wake up *for*."


--------------------------------------------------------------------------------

### User Request 23

So "USB debugging works" is really two milestones: (a) controller/PHY/clock
alive — testable on

battery, and (b) enumerates on a PC — needs the cable. We've only ever been
able to test (a).


we can't test (b) until we wipe the eMMC


on the device, one of the USB-C ports is labelled "DC/USB" and the other is
labelled "OTG"


--------------------------------------------------------------------------------

### Assistant Response 23

Both of those are genuinely useful — the port labels especially.


## The port labels resolve it


**"OTG" is almost certainly our port.** The peripheral controller in the device tree is Rockchip's `usb3**otg**0` (the DWC3 at `0xFCC00000`, wired to `usb2phy0`) — the port physically labelled **OTG** is the one connected to that OTG controller. So for device-mode debugging, the PC goes into the **OTG** port. The **"DC/USB"** port is the charging port (DC) plus the USB *host* side (`usb2phy1`) — which also explains your "we charge over USB" point cleanly: charging lives on **DC/USB**, a *different* port from OTG, so it was never competing with our peripheral port at all.


And you don't have to take my word for the mapping — the readback I just added
makes it self-verifying. When you plug the PC into the **OTG** port and run a
sweep, `usb-enum` will print `VBUS=PRESENT`, because `0xFDCA00C0` is
`usb2phy0`'s status register. If you plugged into the wrong port, VBUS stays
`absent`. So the sweep tells you empirically which port is which.


## The eMMC wipe, and the right order to do this in


I'll take your word on the wipe requirement — you've got the device in hand,
and my best read is that with the stock eMMC present, connecting the OTG port to
a PC makes the BootROM/loader grab the port (or boot something that does) before
our SD kernel can present its gadget; wiping clears that path. Fair.


But the sequencing matters, because a wipe is the one genuinely one-way-ish step
and there's no point spending it early:


1. **Test milestone (a) first — this next flash, no wipe, no PC.** The
`usb-enum` probe runs from the SD kernel during the sweep; `commononn=0` either
makes the `DEPCMD stuck` lines vanish or it doesn't. That tells us the
controller/PHY/clock are alive — entirely on battery. If (a) *fails*, we fix
it before wiping anything.

2. **Only if (a) passes, wipe the eMMC and test (b).** Then boot SD, plug the PC
into the **OTG** port, and drive the full gadget/CDC-ACM to see it enumerate.


Before the wipe, the safety net we settled on earlier: a **known-good golden
SD** in hand and the **eMMC archive** present, since that SD-boot + `110b`
eMMC-restore path is our recovery (maskROM-from-outside is still unconfirmed).
With those two, winging the wipe is fine.


The current image (`e8f2687b`) is exactly what tests (a) — `commononn=0` plus
the VBUS readback. So flash it as-is: if the stuck lines are gone, the PHY is
finally awake and we've earned the wipe. Want me to prep the eMMC-wipe step
(confirm the archive + golden SD, stage `110b`) in parallel so it's ready the
moment (a) comes back green?


--------------------------------------------------------------------------------

### User Request 24

yes please!


--------------------------------------------------------------------------------

### Assistant Response 24

Let me take stock of what we actually have for the safety net — the archive,
the overwrite capability, and a golden image:


The archive is here — both a **full eMMC image** (`emmc-…img.gz.00/01`, ~5.2
GB compressed) and a **boot-chain backup with a checksum**. Let me read the
archive's own notes and the overwrite capability to understand the restore path:


Archive confirmed (boot-chain checksum **OK**, full eMMC present, restore path
documented). But you said "logs are in!" — that's the milestone (a) test, so
let me read that immediately alongside finishing the restore-path check:


Now I have the full picture, and it ties directly to your "no cable" question.
Let me finish the golden-SD snapshot, then give you both the milestone-(a)
result and the prep status together:


Both threads come together here — and your "no cable" instinct looks decisive.


## Milestone (a) — still stuck, and now we know why


```

CON2@0xFDCA0008=0x00000000 <- commononn write took (bit4 now 0)

OTG status@0xFDCA00C0=0x003840C8 <- a REAL value: we're finally reading the
right PHY GRF

VBUS=absent <- nothing plugged into the OTG port

[usb] DEPCMD stuck ... (x6) <- mac2_clk still dead

```


Two things landed even though the test "failed":

- **The address is finally right.** `0xFDCA00C0` read back `0x003840C8` (real data), versus the all-zeros we got from `0xFE8A` — so we're now genuinely talking to the OTG PHY's GRF, and `commononn` did clear.

- **`VBUS=absent`.** Nothing is on the port.


So we've now done *all* the software groundwork — cleared SusPHY, forced the
PLL always-on, confirmed the register block — and the command engine still
won't clock **with nothing plugged in**. That's exactly what you said: this
controller appears to need a live session (VBUS from a host) before `mac2_clk`
runs. I can't call it 100% proven over "one more register," but we've exhausted
the obvious pokes, and the honest read is that milestone (a) *isn't* separable
on battery the way I claimed — **(a) and (b) collapse into one, and both need
the cable, which needs the wipe.** Your framing was right, and it stops us
burning more flashes guessing registers blind.


## eMMC-wipe prep — status


- **Archive: confirmed.** The stock boot-chain slice (`bootchain-…bin.gz`) verifies against its checksum **OK**, and the full ~29 GB eMMC image is on disk as split gzip. That's the "put Anbernic back" net.

- **Golden SD: created.** Snapshotted the image that just booted and swept → `archives/golden-sd-20260702-200809.img.gz` (+ sha256). That's the "always have a bootable SD" net.

- **Write primitive: present.** `emmc_write_block` and `write_kernel_to_emmc_boot_partition` (110b) exist, code-complete with read-back verify.


## The one thing left — and it needs your go-ahead


The actual **wipe tool doesn't exist yet**, and it's a destructive eMMC write,
so I won't build-and-run it unprompted. My proposed design, minimal and
reversible:


- **Zero just the eMMC idbloader (LBA 64), maybe the whole boot-chain slice (LBA 0–32767)** via `emmc_write_block`, so the BootROM finds no valid loader there and stops engaging the eMMC on the OTG port — clearing the way for our SD kernel's gadget when a PC is connected.

- **Read-back-verify** each block (the 110b discipline).

- **Recovery** = the golden SD boots us; if we ever want stock back, the `bootchain` archive writes straight back to LBA 0 via the same primitive.


Two questions before I write it:

1. **Scope** — idbloader-only (surgical, easiest to reason about) or the full
16 MiB boot-chain slice (more thorough)? I lean idbloader-only first.

2. **Trigger** — an armed one-shot probe (runs once on the next flash and
wipes), or a deliberate button/hold gate so it can't fire by accident? I'd
strongly prefer the deliberate gate for a destructive op.


Say the word on those two and I'll write the issue + the tool.


--------------------------------------------------------------------------------

### User Request 25

2. Trigger — an armed one-shot probe (runs once on the next flash and wipes),
or a deliberate

button/hold gate so it can't fire by accident? I'd strongly prefer the
deliberate gate for a

destructive op.



let's do a one-shot probe. We can delete it afterward, just... don't forget,
teehee!


Two questions before I write it:

1. Scope — idbloader-only (surgical, easiest to reason about) or the full 16
MiB boot-chain

slice (more thorough)? I lean idbloader-only first.



we should zero out the entire eMMC card. Hey question, if we write 0 to a
register that already has zero in it, does that actually write? Does it cause
damage to the card?


The actual wipe tool doesn't exist yet, and it's a destructive eMMC write, so I
won't

build-and-run it unprompted. My proposed design, minimal and reversible:


Can you write it? I'm gonna flash now. Will let you know when we have logs.


--------------------------------------------------------------------------------

### Assistant Response 25

Great questions, and important ones before I write a destructive tool. Let me
answer the flash question and check what write speed we actually have, because
"zero the whole 29 GB card" hinges on it:


Good question to stop on — the answer changes the *design*, not just the
implementation. Let me confirm the command primitives I'll need:


I have the command primitives I need for the wipe. But you've got new logs —
let me read those first (urgent), and grab the command-busy handling I need for
the erase, together:


The USB log is **identical** — `VBUS=absent`, same six stuck commands. So this
flash was still on battery (no cable), and it confirms we're firmly at "need a
host on the cable, which needs the wipe." Nothing more to squeeze out without
it.


So — the wipe. Let me answer your flash question first, then check one thing
so I can build it right:


Both the flash question and the wipe design come together here — I've got
everything I need. Let me answer the question, then build it.


**Your flash question:** eMMC is NAND flash, not a register — so writing `0` to a block that already reads `0` **does** physically write (the card's controller doesn't compare-and-skip; it programs a fresh page and remaps). It's *not* a no-op like a `0→0` register write would be. Each such write spends one program cycle of the cell's endurance — but the flash is rated for thousands of cycles per cell with wear-leveling spreading them, so **one full wipe is negligible wear, no damage.** The catch is *speed*: our only write path is single-block PIO, so zeroing all 29 GB block-by-block would take **hours** and program every cell needlessly. The right way to blank the whole card is the card's own **ERASE** command — it blanks whole erase-groups internally in one bulk op: far faster, and *gentler* (fewer program cycles) — which also happens to answer your wear worry. So that's what I'm building.


Writing the erase primitive now:


Need to Read the file first (I'd only `sed`'d it). Reading the anchor region:


Now inserting the erase primitive after `emmc_write_block`:


Now wiring it into the probe engine — the extern and the `emmc_wipe` CALL
target:


A forward-declaration fix — `emmc_sector_count` is defined later in the file.
Adding the prototype:


Now the `emmc_wipe` CALL target:


Now the probe itself and its tracking issue (so we don't forget to delete it,
per your teehee):


Built and clean. Answered your flash question above — short version: yes it
physically writes even `0→0`, it's negligible wear for one pass, but
zero-writing 29 GB block-by-block would take hours, so the tool uses the card's
**ERASE** command instead (fast + gentler, which is also why it sidesteps your
wear worry).


## ⚠️ The wipe is built — and this image erases the eMMC


**`output/bootable-sd.img` sha256 `94edc418…cf35f3` is the WIPE image.** Booting it runs `emmc-wipe` last in the sweep, which calls the card's ERASE (CMD35/36/38) over the whole address range and blanks it. This is *not* the same as the image you've been flashing (`e8f2687b`, which does nothing to the eMMC). Flash `94edc418` only when you mean to wipe.


What it does, concretely:

- One-shot probe (priority 200 = runs after every other probe, so all recon is captured first).

- Whole-card ERASE, then reads back LBA 0 / 64 / 16384 and logs `word0` — `0x0` or `0xFFFFFFFF` there means the boot chain is gone.

- **Fails safe:** if the card rejects `CMD35/36/38`, it logs which one and leaves the eMMC untouched.


**Recovery net — both confirmed present before you run it:**

- `archives/golden-sd-*.img.gz` — a known-good SD that boots our kernel no matter what the eMMC looks like.

- `archives/bootchain-*.bin.gz` — the stock Rockchip boot chain (checksum OK), writable back via `emmc_write_block` if you ever want factory again.


Since the device already boots from SD independently of the eMMC, a blank eMMC
can't stop SD boot — so this is recoverable through the SD, no Maskrom needed.


## The flow from here


1. **Flash `94edc418`, boot once.** Watch the log for `[wipe] DONE. eMMC blank`.
That first boot's `usb-enum` still shows the eMMC (the wipe runs at the *end*),
so ignore its USB result.

2. **Then plug a PC into the OTG port and boot again.** Now the eMMC is blank,
the boot is clean, and `usb-enum` (which runs early) finally gets its shot with
`VBUS=PRESENT` — that's milestone (b). (The wipe re-runs harmlessly on the
already-blank card; or flash a clean non-wipe image if you'd rather it not.)

3. **Once USB (b) is confirmed, delete the wipe probe.** I filed **issue
`110q`** as the tracker — it lists the exact teardown (remove
`emmc-wipe.probe` + the `emmc_wipe` CALL target). *Don't-forget noted, in
writing, so it's not just on my honor.* 😄


Nothing's committed — the wipe lives in the working tree only, clearly marked
temporary. Go wipe it, then let's finally see that OTG port enumerate.


--------------------------------------------------------------------------------

### User Request 26

so how is the ERASE command different than writing all zeroes?


1. Flash 94edc418, boot once. Watch the log for [wipe] DONE. eMMC blank. That
first boot's

usb-enum still shows the eMMC (the wipe runs at the end), so ignore its USB
result.

2. Then plug a PC into the OTG port and boot again. Now the eMMC is blank, the
boot is clean,

and usb-enum (which runs early) finally gets its shot with VBUS=PRESENT —
that's milestone (b).

(The wipe re-runs harmlessly on the already-blank card; or flash a clean
non-wipe image if you'd

rather it not.)



we should instead run another flash inbetween 1) and 2) which dumps the eMMC and
ensures that it's completely clear.


--------------------------------------------------------------------------------

### Assistant Response 26

Good question — the difference is the heart of how flash works. And the
verify-between step is a smart safety add. Let me check the existing scan tool
so I build the verify right, then answer:


`emmc_scan_map` (the `emmc-scan` probe) already does exactly the verify you want
— a full-card read that reports any non-zero range — so no new code needed;
I'll re-arm it for the between-step. First, your question, because it's the crux
of why the wipe works the way it does:


## ERASE vs writing all zeros


They're genuinely different operations, because of one asymmetry in NAND flash:
**you can program a bit 1→0 by writing, but you cannot go 0→1 by writing.**
The *only* way to push bits back to 1 is to ERASE — and erase works on big
chunks (erase-groups), not individual bytes.


That cascades into four real differences:


1. **ERASE** resets whole erase-groups to the blank state in one bulk pulse —
the flash's native "make this blank" primitive. Fast: one operation per group,
not per byte. (At the silicon level "blank" is all-1s / 0xFF; the eMMC
controller may *present* that to reads as 0x00 or 0xFF.)

2. **Writing all zeros** *programs* every page to 0x00 — one program op per
page, thousands of them for the whole card. And to program a page the flash must
already be erased, so the controller does **erase-then-program** under the hood.
Writing zeros therefore costs an erase *plus* a program per region — **more
time and more wear** than just erasing.

3. **Semantically** they mean opposite things to the card. ERASE says "this
space is free" — the FTL can reclaim and wear-level it. Writing zeros says
"store the value 0 here" — the FTL treats it as *data* that happens to be
zeros. All-zeros is actually the *most-programmed* state, the opposite of blank.

4. **For our goal**, both make the boot chain unreadable, but ERASE is faster
and gentler — which also answers your earlier wear worry: erasing the card
once is lighter on the flash than zero-writing it.


The one caveat is that ERASE's read-back value is card-defined (0x00 or 0xFF)
— the wipe's own readback of LBA 0/64/16384 tells us which. Writing zeros
would *guarantee* literal 0x00, but at the cost of hours and extra wear. Not
worth it.


## The verify-between step — good call, and it's basically free


The full-card scan already exists: the `emmc-scan` probe reads every block via
DMA and logs any non-zero range. So the flow becomes:


1. **Flash the WIPE image (`94edc418`)** → boots, erases the card. Note its
readback line — it tells us whether erased reads as `0x0` or `0xFFFFFFFF`.

2. **Flash a VERIFY image** (I'll hand it to you the moment the wipe reports
done — it's a one-line marker flip: arm `emmc-scan`, de-select the wipe).
Fresh boot, reads the *whole* card, and reports: **no non-zero ranges =
completely clear** (if erased→0x00), or shows exactly what's left. This is
your independent confirmation, on a cold boot, before we trust it.

3. **Then plug the PC into the OTG port** and flash/boot the USB-test image
(`usb-enum`, no wipe) — milestone (b).


(If step 1's readback shows the card erases to `0xFF` rather than `0x00`,
`emmc-scan` would call the whole blank card "non-zero" — I'll swap in a
uniform-value check for the verify in that case. We'll know from the wipe log.)


The wipe image is still what's at `output/` (`94edc418`), ready to flash. Go run
step 1, and the instant it reports `eMMC blank`, I'll flip you the verify image.


--------------------------------------------------------------------------------

### User Request 27

okay, uh, what if we programmed it to 1's instead of 0's? How would that be
different?


--------------------------------------------------------------------------------

### Assistant Response 27

Ooh, this is the fun part, because flash is **asymmetric about 0 and 1** —
they aren't interchangeable the way they'd be in RAM or a register.


## 1 is the "natural" state; 0 is the effortful one


In NAND flash, a bit is a cell that either has charge trapped in it or doesn't:

- **1 = no charge** — the erased, rest state. It's what a cell *wants* to be.

- **0 = charge injected** — the programmed state. You had to *do work* to put it there.


And the operations map onto that asymmetry:

- **Programming (writing)** can only *add* charge: it drives bits **1→0**. It physically cannot do 0→1.

- **Erasing** is the only thing that *removes* charge, resetting a whole block back to all-**1**s.


## So "programming it to 1's" means programming *nothing*


Writing `0xFF` to a page is telling the flash "clear zero bits to 0" — i.e.
leave every cell at its erased 1. At the cell level that's the **gentlest
possible write: no charge injected at all.** Writing `0x00`, by contrast,
charges *every* cell — the maximum-effort write. So if you're only comparing
the raw programming, writing 1's is lighter (and slightly faster — fewer
program pulses) than writing 0's.


**But here's the twist that makes it not-a-no-op:** you can't actually blank existing data by writing 1's. If a block holds `0x12345678` (lots of 0-bits) and you "write `0xFFFFFFFF`," programming *can't lift those 0s back to 1* — only an erase can. The eMMC controller hides this with its translation layer: it doesn't overwrite the old page, it grabs a **fresh already-erased page**, programs your `0xFF` there (which programs nothing, since it's already all 1s), and remaps the block. So it *reads back* as `0xFF`, but it still spent a fresh page and queued the old one for erasing — the same slow, per-block, wear-costing path as writing 0's.


## Where that leaves the three options


| | Cell effort | Speed | What the card ends up with | FTL view |

|---|---|---|---|---|

| **ERASE** (what we use) | one bulk reset per erase-group | **fast** | all-1s
(card may present as 0x00 or 0xFF) | space is *free* |

| **Write 0x00** | charge every cell | slow (per-block) | 0x00 | data (all
zeros) |

| **Write 0xFF** | charge *nothing* | slow (per-block) | 0xFF | data (all ones)
|


So "programming to 1's" is essentially **the slow, per-block way to arrive at
the exact state a full-card ERASE gives you instantly** — and erase is the one
that actually frees the space rather than storing a card's-worth of "1" data.
There's a real chance our card's *erased* value already reads back as `0xFF`
(the wipe's LBA readback will tell us) — in which case erase and "writing 1's"
would look **identical** in the log, except erase did it in seconds and writing
1's would've taken the same hours as writing 0's.


**For our wipe:** no advantage either way. The boot chain is gone whether the blank byte is `0x00` or `0xFF`, and ERASE already lands us there the fast, gentle way. The only place the 0-vs-1 distinction bites us is *reading the verify* — if the card blanks to `0xFF`, `emmc-scan` would call the whole clear card "non-zero," and I'll swap in a uniform-value check. We'll know from the wipe's readback line.


--------------------------------------------------------------------------------

### User Request 28

okay but with ERASE isn't the data still there?


--------------------------------------------------------------------------------

### Assistant Response 28

Sharp question — and the honest answer is "it depends what you mean by
*there*," because there are two different layers.


## Two senses of "still there"


**Through the eMMC's front door (normal reads): no, it's gone.** After the ERASE, reading any block returns the blank value. The BootROM reads LBA 64, finds no idbloader magic, and skips the eMMC. `emmc-scan` reads the whole card and sees blank. So for *our* goal — the card no longer boots and no longer claims the USB port — the data is functionally gone, and the verify flash proves it. Nothing reachable over the block interface is the old data anymore.


**On the raw silicon (forensically): partly, yes.** Two things leave residue:


1. **Erase is address-scoped; the card's history isn't.** Our `CMD38` with arg
`0` is a *real* erase (not just a "trim/deallocate" that leaves the cells alone
and only returns blank on reads) — so the physical blocks currently *mapped*
to those addresses do get their charge wiped. But remember the FTL does
**out-of-place writes**: over this card's life, every "overwrite" left the *old*
copy sitting in some physical page that got unmapped and never reused. Those
stale copies aren't at any logical address, so an erase-by-address range never
touches them. A lab that de-solders the NAND and reads it raw could recover
fragments from those orphaned pages.

2. Even a freshly-erased cell can leave faint analog charge traces, though
that's exotic-recovery territory.


## The tool for *actually* destroying it


If the goal were "make this unrecoverable even against a chip-off forensic
read," ERASE isn't enough — you'd use the eMMC **SANITIZE** command (`EXT_CSD
SANITIZE_START`), which tells the controller to physically purge *every*
unmapped/stale physical page, not just the addressed ones. (Secure-erase or,
better, whole-disk encryption from day one are the other answers.)


## But for us it doesn't matter


We're not destroying secrets — quite the opposite. We *deliberately kept* the
stock Anbernic firmware in `archives/bootchain-*.bin.gz` and the full dump,
precisely so we *can* recover it. So "old bytes lingering in unmapped NAND"
isn't a threat, it's a non-event. What we need is: **the block interface returns
blank → the card won't boot → the OTG port comes free.** Plain ERASE
delivers exactly that, fast, and the verify scan confirms it.


So: leftover charge on the silicon, maybe. Anything the device — or our USB
test — can *see or boot*, no. That's the layer that matters here. If you ever
*did* want a forensic-grade wipe, say so and I'll add a SANITIZE pass — but
it's not needed to unblock USB.


--------------------------------------------------------------------------------

### User Request 29

yes, but we can't plug the device into a computer until it's completely wiped.
No chance of any data being present on the eMMC, and yes I am perhaps being a
bit too principled here but it was the requirements we set at the beginning so I
want to honor those. If we do ERASE on every single register, will that be the
same as a SANITIZE command?


--------------------------------------------------------------------------------

### Assistant Response 29

That's exactly the right question to be principled about — and the answer is
**no**, they're not the same, which is the whole reason SANITIZE exists.


## Why "ERASE every address" ≠ SANITIZE


ERASE (even sweeping every logical block 0…N) can only reach blocks that are
*currently mapped* to an address. But the flash translation layer has spent this
card's whole life doing out-of-place writes — every past overwrite left the
**old copy stranded in a physical page that got unmapped**. Those orphaned pages
have *no logical address*, so an erase-by-address literally cannot name them,
let alone erase them. Sweep every address you like; the stale copies sit
untouched in the raw NAND.


**SANITIZE is the command that specifically hunts down and physically purges those unmapped pages** — the ones no address-based operation can reach. The JEDEC-recommended sequence is exactly: erase/trim the addressable content *first*, then SANITIZE to purge what's left orphaned. So ERASE-all + SANITIZE is a proper superset of ERASE-all alone.


So you're not being too principled — if the requirement is "no chance of *any*
data on the eMMC," ERASE alone genuinely doesn't meet it, and SANITIZE does. Let
me add it. First, checking how the driver issues the EXT_CSD write SANITIZE
needs:


That's the tool for exactly your requirement. Adding SANITIZE after the erase,
and hardening the long busy-waits. First, the watchdog pet on the erase wait (a
minutes-long op must not let the watchdog reset us):


Now wiring SANITIZE into the wipe — the extern and the CALL sequence (erase,
then sanitize):


A declaration-order issue — `CMD6_WRITE_BYTE` is defined lower in the file.
Let me check its exact form so I can inline it:


The macro is at line 1351, below my function. Inlining its expansion in
`emmc_sanitize`:


Now the CALL target does both passes — erase, then sanitize:


Clean build. New **WIPE+SANITIZE image sha256 `080e86f6…c2030`** (it
supersedes `94edc418`, which only erased).


## What changed


The wipe is now two passes, in the JEDEC-recommended order:

1. **ERASE** the addressable range — blanks the current, mapped content
(`emmc_erase_all`, as before).

2. **SANITIZE** — `emmc_sanitize()` writes `EXT_CSD SANITIZE_START` (byte 165)
via CMD6, which tells the card's controller to physically erase **all the
unmapped/orphaned pages** the address-based erase can't reach. That's the piece
that closes your "no chance of *any* data present" requirement — it's the
strongest purge the eMMC exposes, and it exists precisely to defeat the
stale-copy problem we were discussing.


So to your question directly: **no, erasing every address is not the same as
SANITIZE** — and now the wipe does both, so it *is* equivalent to (erase +
sanitize), which is the real thing.


A few things worth knowing before you run it:

- **It can take minutes.** SANITIZE walks the whole flash. The busy-wait is long and **pets the watchdog** throughout (I added that to the erase pass too), so it won't get reset mid-wipe. Watch for `[wipe] SANITIZE complete — no orphaned data remains`.

- **Fails safe.** If the card rejects SANITIZE (some don't implement it), it logs `rejected` and returns — the erase pass still stands, and nothing is left in a weird state.

- **Recovery is untouched.** The stock firmware archive lives on the host (`archives/`), not the eMMC, so sanitizing the card can't hurt our ability to restore it.


## The flow, updated


1. **Flash `080e86f6`** → boot → erase pass, then sanitize pass. Note the
erase's LBA readback (tells us if blank is `0x0` or `0xFFFFFFFF`), and wait for
the SANITIZE-complete line (give it a few minutes).

2. **Verify flash** (`emmc-scan` armed, wipe off) → independent cold-boot
full-card read confirming it's blank.

3. **Plug the PC into the OTG port** → USB-test image → milestone (b).


You're not being too principled — "no recoverable data" was the requirement,
plain ERASE genuinely didn't meet it, and now the wipe does. Go run step 1 when
ready; it'll be slower than before (the sanitize), and that slowness is the card
actually scrubbing itself.


--------------------------------------------------------------------------------
