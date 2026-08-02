# 054-riscv-words — info

A two-pass emitter for RISC-V payloads. It lays instructions out, counts
bytes, and writes every branch as a raw instruction word with the distance
already inside it — because on this architecture the assembler finishes no
label arithmetic of its own, and this project deliberately has no linker to
finish it either.

## Why it exists

Proven empirically before writing it: with `.option norelax` and `.option
norvc`, a `bnez` to a label, a `beq` to a label, and even a branch to `. + 12`
all leave relocations behind, and the extracted bytes still point at
themselves. A branch to a label becomes a branch to nowhere, silently. The
first payloads dodged this by having no control flow at all; issue `102` needs
loops, so the counting had to become a tool.

Counting is possible because compressed instructions are switched off, making
every instruction exactly four bytes. Everything with a data-dependent size
goes through a method that decides its expansion at emit time.

## What it exports

| Name | Meaning |
|---|---|
| `M.new()` | a program being laid out; returns the object below |
| `M.REGISTER` | register name to number, for encoding |

On the program object:

| Method | Meaning |
|---|---|
| `:op(text)` | one real four-byte instruction, verbatim |
| `:label(name)` | a position, for branches and addresses |
| `:branch(kind, rs1, rs2, label)` | conditional branch, encoded as a word at resolve time |
| `:jump(label)` | unconditional jump that links nothing (`jal zero`) |
| `:load_constant(reg, value)` | `li` with its expansion chosen deterministically |
| `:address(reg, label, base)` | a label's address as base plus counted offset; three instructions always |
| `:shorts(text)` | a string as UTF-16 halfwords with a terminator |
| `:align(to)` | padding to a boundary |
| `:resolve()` | assign offsets, encode branches, return assembly text and the offset table |

## What it refuses

`li`, `la`, `lla`, `j`, `jal`, `bnez`, `beqz`, `call`, `tail`, `ret` and their
relatives are rejected by `:op` with a note saying which method to use
instead. Each either expands to a data-dependent number of instructions or
swallows a label and produces a relocation, and one of them slipping through
breaks every offset after it.

## Range checking

Conditional branches reach ±4KB and jumps ±1MB; `:resolve()` refuses a
distance past either limit rather than wrapping it. The pattern for a long
conditional reach is a short branch guarding a jump, which is what the
blob-report payload does around its failure path.

## Proven

The encoder's words were disassembled back by llvm-objdump and matched the
intended targets exactly, with zero relocations in the object. Then the whole
blob-report payload (033) — loops, conditional ladders, string addressing —
ran on the emulated RISC-V board through real UEFI firmware on 2026-08-02.

Issue `401` inherits this tool: the RISC-V engine port cannot be written
without it.
