# 020-forbidden-registers — info

Where the landmines are. Pure data, read by two tools that must never
disagree: the payload builder (019), which makes probes that write to these
addresses, and the trap runner (021), which arms watchpoints on them. One
source, so a probe and a trap cannot point at different places.

## What it exports

| Name | Type | Meaning |
|---|---|---|
| `categories` | array of string | the five kinds of write issue 003a calls unrecoverable |
| `mechanism` | table | category → one sentence on why that write is fatal |
| `boards` | table | architecture → `{synthetic_note, hazards}` |
| `by_category(arch, category)` | function | one hazard, or nil if not described |
| `all(arch)` | function | every hazard for an architecture, in declaration order |

## A hazard

| Field | Type | Meaning |
|---|---|---|
| `name` | string | what the register is, for the report |
| `category` | string | one of the five |
| `address` | integer | physical address the watchpoint is set on |
| `fatal_value` | integer | what a probe writes to represent the killing write |
| `real` | boolean | present and true only when the write genuinely ends the machine |

## Honesty about the addresses

Most are **synthetic**: ordinary RAM on the example boards, standing in for
register blocks a real device model would provide. That is enough to test the
discipline (issue 702a) — a watchpoint fires the same whether the address
belongs to a modelled device or to nothing. It is *not* enough to test whether
a machine can tell a destroyed part from a busy one; that is 702b and needs
device models rather than addresses.

One entry is not synthetic. The RISC-V board carries a real device at
`0x100000` that powers the machine off when written. It is there because a
trap that has only ever fired on invented addresses has not been shown to work
on a real one — and running it taught something the synthetic ones could not.
See the note in `021-trap-run.info.md`.

## Constraint worth knowing

x86 hazard addresses must sit below `0x10000`. The probe is a BIOS boot sector
in 16-bit real mode and cannot reach further.
