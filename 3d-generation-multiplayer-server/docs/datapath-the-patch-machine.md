# datapath — the patch machine

*upstream commit + patches/ → a customized tree → binaries → a pristine tree again*

The first thing the vision asks for. Everything else in the project sits on
top of it, because until the server can be changed safely, it cannot be changed
at all.

---

## The data, end to end

```
  a commit hash                patches/*.sh              a build profile
       │                            │                          │
       └────────────┬───────────────┴──────────────┬───────────┘
                    ▼                              ▼
            ┌───────────────┐              ┌───────────────┐
            │  reset to     │              │  select the   │
            │  that commit  │              │  patch list   │
            └───────┬───────┘              └───────┬───────┘
                    └───────────┬──────────────────┘
                                ▼
                     ┌─────────────────────┐
                     │  apply, in order    │───▶ tree is customized
                     └──────────┬──────────┘
                                ▼
                     ┌─────────────────────┐
                     │  compile + install  │───▶ binaries in staging
                     └──────────┬──────────┘
                                ▼
                     ┌─────────────────────┐
                     │  unapply, reverse   │───▶ tree == the commit again
                     └──────────┬──────────┘
                                ▼
                        .upstream-lock          ◀── advances only on success
```

The tree at the top and the tree at the bottom are byte-identical. That is the
whole guarantee, and everything below is a mechanism for making it true without
anyone watching.

---

## What one patch is

A **pair of inverse functions over a text tree**, plus a probe that says whether
it is needed. Living in one file, with a header the machine reads back.

| Header field | What it holds | Who reads it |
|---|---|---|
| `TARGET` | path within the clone, plus the function or region | the audit machine |
| `SYMPTOM` | what upstream does as shipped | humans; the generated registry |
| `CHANGE` | what we make it do, **and why** | humans; the registry; a PR body |
| `ANCHOR` | the unique pattern the apply keys on | the audit; the verifier |
| `WITNESS` | a string present only in the patched form | the probe; the verifier |
| `MATCHES` | how many times `ANCHOR` should occur — usually 1 | the verifier, as an assertion |

The `MATCHES` field is the one that prevents the classic silent disaster: a
pattern loose enough to hit two places edits the wrong one, and nothing
complains. Declaring the expected count turns "anchor tightly" from advice into
something a harness can fail you for.

### The three functions

```
patch_<ID>_<name>()             the apply.   Guarded: does nothing if the
                                un-patched pattern is already gone.

unpatch_<ID>_<name>()           the inverse. Matches the marker-wrapped block
                                the apply produced, restores the original.

patch_needs_applying_<ID>()     the probe.   True when the witness is absent.
```

The replacement is wrapped in a unique marker in the target language's own
comment syntax:

```
    // {{{ P017-marker
    ...our version...
    // }}} P017-marker
```

The marker does three jobs at once, which is why it exists rather than
re-matching content. It gives the inverse a **stable handle** that survives
upstream reflowing the code around the block. It **cannot collide** with a
sibling patch, because the ID is in it. And it doubles as the **witness**, so
the probe and the inverse can never disagree about whether the patch is present
— they are looking at the same string.

The fold markers are also the same ones the editor uses to collapse a function,
which is a small courtesy to anyone reading the patched tree by hand.

---

## The two properties, and how each is forced

**Idempotent** — applying twice equals applying once.

Not a rule anyone follows. The apply's guard looks for the *un-patched* pattern
and returns without doing anything when it is absent; the unapply's guard looks
for the *marker* and returns when it is absent. A second run is inert by
construction. This matters because the build runs unapply twice on the success
path — once explicitly, once via a trap that may or may not have been disarmed
in time — and neither run may corrupt anything.

**Exact inverse** — `unapply(apply(tree)) == tree`, byte for byte.

Asserted, not trusted. The verifier runs, per patch, against a fresh clone:

```
    apply            →  the tree must have changed
    count ANCHOR     →  must equal the declared MATCHES
    grep WITNESS     →  must be present
    unapply          →  the tree must be clean
    grep WITNESS     →  must be absent
    git diff         →  must be empty
```

A patch failing any line never enters the active set. The property is not "the
author checked" — it is "the harness will not let a broken one build."

---

## The build driver, wire by wire

Each line establishes the precondition the next line depends on.

```bash
source patches/patches.sh

reset_source_trees                                # ⟶ tree == upstream HEAD
audit_patches "$(cat .upstream-lock)" "$(current_head)"
apply_patches_prebuild                            # ⟶ customizations present
trap 'unapply_patches_prebuild' EXIT              # ⟶ revert happens regardless
build
install_to_staging
apply_patches_install                             # ⟶ staging configured
trap - EXIT                                       # disarm the net...
unapply_patches_prebuild                          # ...and revert deliberately
current_head > .upstream-lock                     # ⟶ baseline advances on success
```

**`reset_source_trees` runs unconditionally, never "only if dirty."** On a clean
tree it costs nothing. On a dirty one it discards residue from a build that died
in a way the trap could not catch — a kill signal, an out-of-memory, a power
cut. Running it always is precisely what converts "the tree starts clean" from a
hope into a guarantee. It is the backstop for the single failure mode the trap
structurally cannot cover.

**The trap is the revert machine.** Wiring the revert to process exit means a
crashed compile still leaves a pristine tree. The explicit revert on the success
path is the normal route; the trap covers every abnormal one. Between them,
"the tree returns to the commit" is true across all exit modes with no operator
action.

**`.upstream-lock` is written last, on success only.** The audit compares the
last version we *actually shipped* against the current one. A failed build
leaves the old baseline, so the machine can never poison its own reference
point.

---

## Three tiers, because they fire at different moments

| Tier | Fires | Touches | Reverts? |
|---|---|---|---|
| **PRE-BUILD** `P###` | after clone, before compile | upstream C++ source | **yes** — must, or the tree is not pristine |
| **POST-BUILD** `I###` | after install to staging | our staging tree: server configs, database schema, log dirs | no; re-running is idempotent |
| **POST-DEPLOY** `C###` | after promoting staging to live | live configs and runtime data rows | no |

The split is chronological because each tier has a precondition the previous
phase creates. PRE-BUILD needs source present and no binary yet. POST-BUILD
needs binaries installed. POST-DEPLOY needs the live directory to exist, so it
can write values pointing *at* it — which database, which port, which data
directory — values that do not exist any earlier.

Only PRE-BUILD touches code we do not own, so it is the only tier whose inverse
has to be exact. The other two behave like ordinary idempotent setup over our
own artifacts.

A useful side effect of putting runtime tuning last: a bad tuning value cannot
fail validation, because validation runs against complete staging configs from
POST-BUILD. POST-DEPLOY writes only the delta between "valid for staging" and
"valid for live."

---

## Profiles

A **profile** is a named subset of the patch set. One parts bin, several
machines. The selection is data, in a table:

```bash
declare -A PREBUILD_PATCHES=(
    ["stock"]=""                        # unmodified upstream: the day-1 baseline
    ["compile"]="P001 P004"             # only what our toolchain needs to build
    ["world"]="P001 P004 P009 …"        # + what the fabricated data needs to load
    ["ours"]="P001 … P0nn"              # everything, including messages of our own
)
```

`stock` earns its place: the client is supposed to connect to an unmodified
server on day one, and keeping that build reachable forever means any later
breakage can be bisected against it.

The active profile is read from a `.profile` file rather than passed as a flag,
so nobody has to remember to pass it. A flag overrides when wanted.

Where the same setting wants a different value per profile, the two values
become **two sibling patches with non-overlapping profile lists**, so exactly
one fires. The old value stays visible in the tree as a sibling rather than
being overwritten, which is a small machine for never losing a prior decision.

---

## Generated artifacts, so nothing can go stale

- **`scaffold-patch <tier> <name> <file>`** scans existing filenames for the
  next free ID, emits the skeleton with the function triplet pre-named and the
  marker pre-filled. The author supplies only the irreducible part: the old→new
  edit and its anchor.
- **`gen-registry`** rebuilds `docs/patches/patch-registry.md` by reading every
  patch header. The registry is *never hand-edited*, so it cannot drift. "Add a
  row to the registry when you add a patch" — a classic forgettable step —
  stops existing as a manual act.
- **`verify-patches`** is the gate described above, wired into the build.

---

## The pruning machine

Patches rot as upstream moves. Three ways, and the audit computes which:

| Verdict | Means | Detected by |
|---|---|---|
| **RETIRE** | upstream adopted our shape; the patch is redundant | the probe says "not needed" on a *pristine* tree |
| **STALE** | upstream restructured the target; apply can no longer match | `ANCHOR` absent from `TARGET` |
| **REVIEW** | upstream changed the region around our anchor; it may still apply but its meaning is no longer guaranteed | changed line ranges overlap the anchor's line |
| **OK** | anchor intact, region untouched | neither of the above |

The collision test reads the changed line ranges straight out of the version
control delta — with zero context lines, each hunk header reports exactly the
range that changed in the new revision:

```bash
git -C "${SRC}" diff --unified=0 "${OLD}" "${NEW}" -- "${file}" \
  | awk '/^@@/ { split($3,a,","); s=substr(a[1],2)+0; l=(a[2]==""?1:a[2])+0;
                 if (l>0) print s","(s+l-1) }'
```

The anchor's own line comes from `grep -n`. Overlap is the trigger.

**The machine emits its own worklist.** For every REVIEW and STALE verdict it
inserts a uniquely tagged comment into the working tree, directly above the
anchor, in that file's comment syntax. A single `grep -rn "PATCH-AUDIT"` then
enumerates the entire decision set. The machine produces the list; a human
supplies only the judgment per site, then deletes the tag.

Two records with two lifetimes, both automatic. The in-tree tags are
**ephemeral** — they live in a disposable tree and vanish at the next reset,
which is exactly right for one review session. A persistent report at
`docs/patches/audit-<ref>.md` keeps the verdicts after the reset.

Whether the audit blocks or merely warns is wired policy, not habit: block for
releases, warn during fast local iteration.

---

## De-patching: three mechanisms, and why the call site picks

There is a real failure mode that makes the obvious cleanup unsafe:

> An unapply matches the **post-patch shape**. It cannot tell "we applied this"
> from "upstream now ships this." Run defensively, against a tree we did not
> patch, it will happily revert clean upstream code into false dirt that reads
> like an upstream regression.

So each mechanism is wired only where it is safe, and nobody chooses:

| Mechanism | Wired to | Safe because |
|---|---|---|
| `unapply_patches_prebuild` | the EXIT trap and the success-path revert | it only ever reverses patches *this same run* applied — authorship is certain |
| `reset_source_trees` | every defensive and pre-flight position | it goes to a *commit*; it cannot manufacture dirt |
| `apply-patches --revert` | the human control panel | explicitly asked for |

The operator surface is deliberately thin:

```
./scripts/apply-patches --dry-run           # which would apply, computed
./scripts/apply-patches --prebuild          # apply to the tree
./scripts/apply-patches --prebuild --revert # revert, then incremental rebuild
./scripts/apply-patches --profile stock     # a different machine from the same bin
```

`redownload-source` removes only the clone, leaving build output, installed
artifacts, databases, and configs alone. "The source is in a weird state" is
therefore never a debugging session; it is one command and a rebuild. That
shortcut is safe *specifically because* the real work lives in `patches/`.

---

## Non-textual patches

The contract survives a change of substrate. Registering a custom map in the
server's data tables is an **idempotent insert** keyed on a unique column for
apply, the matching delete for unapply, and a row-presence check for the guard.
A generated asset is written by apply, removed by unapply, and probed by
existence. Same four properties, different tool.

---

## Failure modes this is built to foreclose

Each is a real bug, paired with the part that makes it impossible:

- **False dirt from a defensive revert** → unapply is wired only to same-run
  reverts; reset covers every defensive position.
- **Silent corruption from a loose pattern** → `MATCHES` plus the verifier.
- **A fragile inverse that breaks when upstream reflows** → unique markers.
- **Double-apply from a retry or a trap firing over an explicit call** → the
  guards make repeats inert.
- **A patch that applies but will not reverse, leaking dirt into the next
  build** → the round-trip assertion blocks it from the set.
- **Residue from a kill the trap cannot catch** → the unconditional pre-flight
  reset.
- **A patch needing re-targeting going unnoticed** → a loud unmatched-pattern
  failure, plus STALE/REVIEW verdicts with auto-inserted tags.
- **The registry going stale** → it is generated from headers, never edited.
- **A poisoned audit baseline** → the lock advances only on a successful build.
- **A tracked or surviving edit to upstream code** → the `.gitignore` wire plus
  a clean-tree assertion.

## Related

- `docs/architecture.md` — why the server is not forked, and the module seam
- `docs/roadmap.md` — phase 1 is this document, made real
- `docs/patches/patch-registry.md` — generated; what we changed and why
