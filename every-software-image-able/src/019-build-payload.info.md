# 019-build-payload — info

Builds small payloads that run on a bare emulated board. One tool, several
payloads: a first-light stub that only says hello, and hazard probes that
deliberately write where they must not, so the traps in 021 have something to
catch.

This began as a builder for one payload and was generalised rather than copied when
the trap work needed a second kind — one builder that takes a description, not two
builders sharing a generator. The rename that came with it is in the commit history.

## Invocation

```
luajit src/019-build-payload.lua [--payload NAME] [--arch NAME] [--dir ROOT]
```

Omitting `--payload` builds every known payload; omitting `--arch` builds all
three architectures. Artifacts land on the RAM artifact tier at
`tmp/shared-memory/payloads/<payload>-<arch>.{s,o,bin}` — the generated
assembly is kept beside the binary, so what ran is always readable.

## Known payloads

| Name | What it does |
|---|---|
| `first-light` | says `first light: <arch>` and sleeps |
| `hazard-<category>` | announces the register it is about to write, writes the fatal value there, then announces that it survived |
| `uefi-hello` | says hello through real firmware's own console, wrapped in the envelope from `029` |
| `blob-report` | carries a packed model inside itself, reads its header aloud, reads the firmware's memory map, and computes the ratchet (`033`); all three architectures |

The hazard categories come from the forbidden register map (020), so adding a
category there adds a payload here. The addresses come from there too, which
is what stops a probe and a trap pointing at different places.

**Why a hazard probe speaks before it acts.** If the write really does end the
machine, no watchpoint can report it — the debugger connection dies with the
machine. The console is then the only witness, and the last line before
silence is the confession.

## How it works, in one paragraph

The assembly is generated from a list of steps rather than written by hand.
Two kinds of step exist: `say` a string, and `poke` a value to an address.
Each becomes load-immediates and stores, so a payload has no data section and
no relocations — which is what lets the whole build be an assembler and an
extractor, with no linker on the machine at all.

One generator table per architecture, each knowing `prologue`, `say`, `poke`
and `epilogue`. Adding an architecture is adding a table and a target triple;
adding an instruction is adding a row to each. The x86 variant is a BIOS boot
sector and is checked to be exactly 512 bytes.

## Constraints worth knowing

The x86 payload runs in 16-bit real mode and can only reach addresses below
`0x10000`. Hazard addresses for that board sit inside that range; anything
further away cannot be poked from a boot sector.

The console addresses are duplicated from the board descriptions, and marked
as such in the source. A payload is built for an architecture rather than for
a board, so the builder has no board to read them from. If a second board per
architecture ever appears with a different console, that duplication becomes a
lie and the builder should start taking a board instead.

## Proven results

All payload kinds built and ran on all three architectures on 2026-08-02.
First light on each board; hazard probes caught by the traps in `022`, six of
six cases as expected.
