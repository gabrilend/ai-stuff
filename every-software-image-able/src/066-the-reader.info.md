# 066, 067 — reading something too big to hold — info

A hand answers with a megabyte; a megabyte cannot enter the thinking loop.
`066` searches it in a scratch context and lets only the useful part cross
into the machine's own. Issue `201a`.

## Running the checks

```
luajit src/067-test-the-reader.lua
```

## What `066` exports

| Name | Meaning |
|---|---|
| `chunk(text, size)` | cuts on meaningful boundaries where the content allows |
| `new(options)` | a reader: context size, the machine's judgement, an optional summariser |
| `read(reader, whole, question)` | walks the whole thing a window at a time |
| `as_atom(found, source)` | what crosses: an atom naming where the text came from |
| `for_hands(reader, source)` | the shape `064` wants for its `reader` slot |

`read` returns the text, which pieces of how many it came from, how many
passes it took, and whether it was summarised or widened — or nil and a
reason. The reason distinguishes *the document was read and does not contain
it* from *the search itself failed*, which are different facts.

## The sizing is what makes it work

Chunks are about a tenth of a context each and eight are resident at a time,
so the scratch context is filled without crowding out the asking, and a
document of any size is covered in a predictable number of passes: its
length over about eight tenths of a context.

## The reader does not decide what counts as an answer

The judgement is handed in — a function the machine provides, asked a
question with a shape that can be answered cheaply: is what is wanted in
here, and if not, should the search widen. A scan producing prose about
every chunk would cost more than reading the whole document.

## Cutting

Blank line, then line ending, then space, each looked for in the last
quarter of the chunk so a cut is never dragged far from where it was wanted.
Content with none of them — one enormous line of data — is cut at the byte,
which is correct rather than a fallback: there is no meaningful boundary to
find.

## Summarising is said out loud

An answer spanning several pieces is summarised only if a summariser was
given, and the atom then says so in words. A summary presented as a
quotation is a lie the machine told itself, and the difference matters most
exactly when the machine goes back to check.

## What it does not solve

**An answer needing the first piece and the last one together.** Each pass
sees a window, so a relationship spanning the whole document is invisible to
every pass. A widened search carries findings forward, which helps; some
questions will still come back wrong rather than unanswered. Stated here and
printed by the test on every run, because a clean sweep invites the wrong
conclusion.

## Result on 2026-08-02

19 of 19, including the seam with the hands: a hand answering with 35,000
characters, crossing as one labelled piece under 600.
