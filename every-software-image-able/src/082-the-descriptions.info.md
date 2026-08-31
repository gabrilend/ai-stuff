# 082-the-descriptions — info

Machine-readable descriptions of the standard device classes, and the read-only protocol that decides whether a description is about the part in front of it. Issue 302.

The machine can find out what is plugged into it and learns nothing from that about how to work any of it. Knowing there is a network chip at an address tells you where the doorbell is, not what happens when you ring it. These are the documents that say.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `082-the-descriptions.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/082-the-descriptions.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.FIELDS` | what a description must hold, and why each is there |
| `M.check(description)` | Refuses a description that could not be written from. |
| `M.CARRIED` | the classes worth carrying |
| `M.confirm(description, device, read)` | The read-only protocol. Returns true, or nil and everything that did not match -- everything rather than the first, because a person or a machine d... |
| `M.as_text(description)` | A description the machine can read. |
| `M.offer(catalogue, hands, read)` | The whole set, readable rather than compiled in -- so the machine can extend it when it works out a new device. |

### In more detail

**`M.FIELDS`**

Named as data so a description missing something is refused when it is
loaded rather than when a driver written from it fails strangely.

**`M.check(description)`**

Refuses a description that could not be written from. Loading is where
this belongs: a description with no errata section may genuinely have no
errata, but one that never had the section is one nobody checked.

**`M.CARRIED`**

Storage first, because 206 depends on it and the whole move-in sequence
depends on that. Then the ones a person needs to be able to use the
machine at all, and the one that speaks before anything else works.

**`M.confirm(description, device, read)`**

The read-only protocol. Returns true, or nil and everything that did not
match -- everything rather than the first, because a person or a machine
deciding whether this is the right document wants the whole disagreement.

## Written for a computer rather than for an engineer

Every field is something a driver can be written from without a person in between.

## Confirmation is a read-only act, and that is the point

Confirming a description by writing to the device is exactly the failure the whole exploration discipline exists to prevent (docs/003a). So confirmation reads: the maker and part must match, the registers the description calls read-only must hold what it predicts, the reserved ones must hold their predicted pattern, and the revision must be inside the range the description covers.

## A partial match is a failure, not a near miss

Enough agreement to feel confirmed with one silent disagreement in the register that matters is the dangerous case, not the safe one.

## A description is a transcription of somebody else's document

and transcriptions rot. Every one names its source, so it can be re-checked when a part revision lands.

## Where it sits

**Belongs to** `302`.

**Checked by** `085-test-the-payload`.

