---
name: upstream-patch-system
description: >
  Build a reversible, idempotent patch system for customizing third-party
  source you don't own (a fork, a vendored dependency, a git submodule, any
  cloned upstream) WITHOUT maintaining a hard fork. The cloned tree becomes a
  regenerable build artifact; your customizations live as standalone
  apply/unapply scripts that re-derive on every build and revert afterward, so
  the tree always round-trips clean to upstream HEAD. Use whenever someone wants
  to patch/customize/modify upstream or vendored source, escape merge-conflict
  hell on a fork, keep local edits separate from cloned code, re-clone source on
  demand, separate compile-fixes from install-setup from runtime-tuning, "de-
  patch" / cleanly remove modifications, or audit whether their edits are still
  needed after an upstream release. Also fits plain phrasings like "I keep
  losing my changes when I update the dependency."
audience: any LLM agent or human operator; no editor, runtime, or vendor assumed
---

# Upstream Patch System

A method for owning customizations to code you didn't write, without forking it.

> **This document describes machinery to build, not a procedure to follow.** It
> assumes nothing about which agent, editor, language, or runtime executes it.
> Everything below is plain shell and text-processing logic — `git`, `sed`,
> `grep`, `awk`, traps, generated artifacts — that any LLM or human can assemble
> in any project. Swap equivalent tools freely.

---

## Principle: machinery, not procedure

A **procedure** is a sequence an operator (human or LLM) must work through by
hand. A **machine** is a set of components wired together so the outcome falls out
deterministically, with no operator memory in the loop. This system is built
entirely as machinery, on purpose:

- **Every "remember to…" is a defect.** Anything that depends on the operator
  recalling a step is a latent bug. Convert it into one of four mechanical forms:
  a **guard** (a precondition check that makes the operation a no-op when it
  shouldn't fire), a **trap** (cleanup wired to process exit so it runs even on
  failure), a **generated artifact** (a derived file that can't drift because it's
  recomputed, never hand-edited), or a **gate** (a hard stop that refuses to
  proceed until an explicit condition or approval is satisfied).

- **The only inputs left to a human are irreducible.** Three, specifically: the
  *transformation itself* (the old→new text edit and the anchor that locates it),
  the *judgment that a given patch belongs upstream*, and the *approval of an
  outward-facing action* (opening a PR, deleting a fork). Everything else — when
  patches apply, when they revert, whether they still match, what the registry
  says, whether the tree is clean — is wired and deterministic.

Read every section below as "here is a component and how it is wired so the
guarantee holds without anyone watching," not "here are steps to perform."

---

## The core problem this solves

You depend on a third-party codebase — an upstream project, a vendored library, a
submodule. You need to change it: fix a build error against your toolchain, add a
hook, silence warnings, tune a constant, adjust a behavior. The two naive
approaches both rot:

- **Edit the source in place.** Edits get clobbered when you pull upstream, or
  they silently survive and are forgotten. The tree drifts and nobody can tell
  your changes from upstream's.
- **Maintain a hard fork.** Every upstream update is a merge conflict. The fork
  diverges, the diff grows opaque, and "what did we change and why" becomes
  unanswerable.

The machine takes a third path: **the cloned source tree is a disposable build
artifact.** It is never committed and never the source of truth. The source of
truth is a directory of small scripts, each of which knows how to *apply* one
customization and how to *reverse* it. On every build the machine stamps the
changes into a freshly-cloned tree and peels them back off afterward; the tree
round-trips to a pristine copy of upstream HEAD.

What you version is the **intent** (the apply/unapply scripts and their headers),
not the **result** (the modified source). The result is a deterministic function
of `upstream + scripts`, regenerated on demand.

### What the machinery buys you

- **Upstream updates stop hurting.** Re-clone, re-apply. A patch that no longer
  matches fails loudly with an unmatched pattern — a *signal* the machine surfaces
  automatically, pointing at the one patch to re-target, rather than a conflict to
  resolve across the tree.
- **Every change is documented at the point of change.** Each script's header
  records the upstream symptom, the pattern it matches, and how it reverses — and
  the registry is *generated* from those headers, so "what did we change and why"
  is always answerable and never stale.
- **The diff is legible.** N upstream problems become N small, named, anchored
  edits, not one sprawling fork diff.
- **Changes are portable.** A patch script (or its prose "patch doc") replays onto
  any compatible upstream. You ship knowledge, not binaries.

---

## Mental model: a patch is a reversible function over a text tree

Each patch is a **pair of functions** over the source tree:

```
apply:    pristine_tree    ->  customized_tree
unapply:  customized_tree  ->  pristine_tree     (exact inverse of apply)
```

Two properties, both enforced mechanically rather than by discipline:

1. **Idempotent.** `apply` twice equals `apply` once; same for `unapply`. The
   enforcement is a *guard*: apply checks "is the un-patched pattern present?"
   before editing; unapply checks "is the post-patch shape present?" before
   reverting. An already-applied patch is a silent no-op — not because the
   operator avoided re-running it, but because the guard makes re-running inert.

2. **Exact-inverse.** `unapply(apply(tree)) == tree`. The unapply transformation
   is the literal mirror of the apply transformation. This is what lets the tree
   round-trip — and it is *asserted* by the verify harness (below), not trusted.

---

## The tiers: components separated by *when they fire* and *what they target*

Customizations fire at different moments and touch different trees, so the machine
groups them into tiers keyed to the **chronological phase of the build**. Each
tier is a driver function; a project wires up as many as its chronology requires
(often fewer than three).

```
PRE-BUILD   (source patches)    before compile   edits the SOURCE tree (code you don't own)
POST-BUILD  (install patches)   after install    sets up the INSTALL tree (configs, assets, schema)
POST-DEPLOY (config patches)    after promote     tunes the LIVE config (paths, secrets, runtime knobs)
```

| Tier | Fires | Target | Job | Reverts? |
|------|-------|--------|-----|----------|
| **PRE-BUILD** | after clone, before compile | upstream source files | make upstream build/behave for you (fixes, hooks, warning silencing, behavior tweaks) | **Yes** — must revert so the source stays pristine |
| **POST-BUILD** | after install-to-staging, before validate | the just-installed staging tree (configs from templates, log dirs, symlinks, schema/data) | set up a freshly-installed instance | usually no (re-run is idempotent) |
| **POST-DEPLOY** | after promoting staging to live, before start | live config files + runtime data rows | write deploy-specific values unknowable earlier: which database, which paths, which ports, plus runtime tuning | no |

**The separation is chronological because each tier has a precondition the prior
phase establishes.** PRE-BUILD needs the source present but the binary not yet
built. POST-BUILD needs the binary installed into staging, though the live
directory may not exist. POST-DEPLOY needs the live directory to exist (promote
created it) so it can write paths/credentials pointing *at* it — values that did
not exist at any earlier phase. The tiers cannot be collapsed without violating a
precondition. A side benefit of wiring runtime-tuning (POST-DEPLOY) *after* the
validation gate: a botched tuning value cannot fail validation, because validation
runs against complete, valid staging configs from POST-BUILD; POST-DEPLOY writes
only the *delta* between "valid for staging" and "valid for live."

**PRE-BUILD is the load-bearing tier** — the only one touching code you don't own,
hence the only one whose revert must be exact. POST-BUILD and POST-DEPLOY touch
*your* artifacts and behave like ordinary idempotent setup. Wire only the tiers
your chronology demands.

---

## Directory layout (the parts bin)

```
project/
├── patches/
│   ├── patches.sh                  # the orchestrator: sources every patch,
│   │                               #   declares per-profile patch lists,
│   │                               #   defines the apply/unapply/audit drivers
│   ├── P001-<short-name>.sh         # one PRE-BUILD patch: apply + unapply pair
│   ├── P002-<short-name>.sh
│   ├── I001-<short-name>.sh         # POST-BUILD (install) patches
│   └── C001-<short-name>.sh         # POST-DEPLOY (config) patches
├── scripts/
│   ├── scaffold-patch               # emits a new patch skeleton (generator)
│   ├── verify-patches               # asserts round-trip + match-count invariants
│   ├── gen-registry                 # regenerates the registry from patch headers
│   ├── redownload-source            # wipes the source tree for a fresh clone
│   ├── install                      # clones upstream + submodules, then compiles
│   ├── compile                      # the build driver (apply → build → unapply)
│   ├── apply-patches                # operator surface over the drivers
│   └── audit-patches                # the pruning machine (post-update)
├── docs/patches/
│   ├── patch-registry.md            # GENERATED index — never hand-edited
│   └── <feature>.md                 # optional prose "patch docs"
├── .upstream-lock                   # commit last successfully built against
└── source/                          # THE CLONED TREE — gitignored, disposable
```

> ID prefixes (`P`/`I`/`C`) are arbitrary; the rule is one tier per prefix,
> sequential numbering, so a glob selects a tier deterministically.

The load-bearing line of the whole design lives in `.gitignore`:

```gitignore
source/
```

The cloned source is **never tracked**. A surviving modification to upstream code
in your repo's history is, by construction, a bug — a failed unapply or a manual
edit that should have been a patch. (The verify harness and a clean-tree assertion
catch both before they land.)

---

## The build driver: a wired pipeline, not a list of steps

The build is a composition of functions in which **each edge guarantees the
precondition the next stage relies on.** Nobody "performs the steps"; the driver
runs the graph and the invariants hold by construction. The wiring, in full:

```bash
source patches/patches.sh

reset_source_trees                       # ⟶ guarantees: source == upstream HEAD
audit_patches "$(cat .upstream-lock)" \
              "$(git -C "$SRC" rev-parse HEAD)"   # ⟶ on update: classify/flag drift
apply_patches_prebuild                   # ⟶ guarantees: customizations present
trap 'unapply_patches_prebuild' EXIT     # ⟶ guarantees: revert happens NO MATTER WHAT
build                                    # compile the customized tree
install_to_staging                       # binaries land in staging, not live
apply_patches_install                    # ⟶ guarantees: staging is set up
trap - EXIT                              # success path: disarm the net...
unapply_patches_prebuild                 # ...and revert explicitly ⟶ source pristine
git -C "$SRC" rev-parse HEAD > .upstream-lock   # ⟶ baseline advances ONLY on success
```

Each wire, and the guarantee it makes deterministic:

- **`reset_source_trees` first, unconditionally.** Hard-resets the clone and every
  submodule to HEAD. On a clean tree it is a no-op; on a dirty tree it discards
  residue from a build killed in a way that bypassed the trap (SIGKILL, OOM, power
  loss). Running it always — never "only if dirty" — is what makes "source ==
  HEAD" a *guaranteed* entry precondition rather than a hope. It is the backstop
  for the one failure the trap cannot catch: a signal that kills the shell
  outright.

  ```bash
  reset_source_trees() {
      git -C "${SRC}" reset --hard HEAD --quiet
      for sub in "${SRC}"/<submodules>/*/; do
          [[ -d "${sub}/.git" ]] && git -C "${sub}" reset --hard HEAD --quiet
      done
  }
  ```

- **The trap is the revert machine.** `trap 'unapply_patches_prebuild' EXIT` wires
  the revert to process exit, so a crashed or failed build leaves the source clean
  anyway. The explicit `unapply` on the success path (after disarming) is the
  normal route; the trap covers every abnormal one. Together they make "the tree
  returns to HEAD" true across *all* exit modes, with no operator action.

- **`.upstream-lock` advances only after success.** Wiring the lock write to the
  end of the successful path means the audit's baseline can never point at a
  version you didn't actually ship. A failed build leaves the previous baseline
  intact.

The driver loads the active profile's patch list and dispatches by naming
convention — no central registry of "which function to call," just a glob and a
grep over declared functions:

```bash
apply_patches_prebuild() {
    local patches="${PREBUILD_PATCHES[$PROFILE]:-}"
    for patch_id in ${patches}; do                  # e.g. "P001 P004 P009"
        local fn=$(declare -F | grep "^declare -f patch_${patch_id}_" | sed 's/declare -f //')
        [[ -n "${fn}" ]] && ${fn}
    done
}
```

`redownload-source` is the regeneration lever: it removes only the source tree
(leaving build dirs, installed artifacts, data, config untouched), so "the source
is in a weird state" is never a debugging session — it's `redownload-source &&
install`. That shortcut is *safe specifically because* the real work lives in
`patches/`, not in the tree.

---

## Anatomy of a patch (the standard component)

Every patch file is a self-contained apply/unapply pair with a header. The header
fields are not prose decoration — they are the input the generator emits and the
data the registry generator and audit machine read back. Canonical shape:

```bash
#!/usr/bin/env bash
# P017-<short-name>.sh
#
# TARGET:   <relative/path/to/file> :: <function or region>
# SYMPTOM:  <what upstream does / the code as shipped>
# CHANGE:   <what we make it do, and WHY>
# ANCHOR:   <the unique pattern the apply keys on>
# WITNESS:  <a string present ONLY in the patched form>
# MATCHES:  1            # expected match count of ANCHOR (verify asserts this)

# {{{ patch_P017_<short_name>
patch_P017_<short_name>() {
    local FILE="${SRC}/<relative/path/to/file>"
    [[ -f "${FILE}" ]] || return 0                 # missing target = silent skip

    # Marker-wrapped replacement: the NEW block carries unique markers so the
    # inverse can locate it EXACTLY and can never false-match upstream or a
    # sibling patch, no matter how upstream reflows around it.
    sed -i -z 's|<OLD upstream text, escaped>|<C> {{{ P017-marker\n<NEW text>\n<C> }}} P017-marker|' "${FILE}"
}
# }}}

# {{{ unpatch_P017_<short_name>
unpatch_P017_<short_name>() {
    local FILE="${SRC}/<relative/path/to/file>"
    [[ -f "${FILE}" ]] || return 0
    # Exact inverse: match the marker-wrapped NEW block, restore OLD.
    sed -i -z 's|<C> {{{ P017-marker\n<NEW text escaped>\n<C> }}} P017-marker|<OLD upstream text>|' "${FILE}"
}
# }}}

# {{{ patch_needs_applying_P017   (the witness probe)
patch_needs_applying_P017() {
    local FILE="${SRC}/<relative/path/to/file>"
    [[ -f "${FILE}" ]] && ! grep -q "P017-marker" "${FILE}"   # absent witness ⟶ needs applying
}
# }}}
```

(`<C>` is the target language's line-comment token — `//`, `#`, `--`, `;`, …)

The mechanical properties the *shape* enforces:

- **The guard makes idempotency structural.** A one-line edit guards with
  `grep -q "<unpatched anchor>" && sed …`; run it again and the anchor is gone, so
  nothing happens. The operator never has to track "did I already apply this."
- **Anchored, one-to-one patterns.** N problems = N anchored edits + N inverses. A
  broad pattern corrupts clean source; the `MATCHES` field plus the verify harness
  turn "anchor tightly" from advice into an asserted invariant.
- **Markers make the inverse robust.** A unique `{{{ <ID> … }}} <ID>` wrapper is a
  stable handle the inverse always finds and a sibling patch can never hit. The
  same marker doubles as the witness, so the probe and the inverse agree by
  construction.
- **The witness probe is the deterministic answer to "is this needed?"** — reused
  by the build's skip shortcut, by `--dry-run`, and by the audit's convergence
  test.

### The generator and the verifier replace the "add a patch" checklist

Adding a patch is not a remembered procedure; it is **a generator that stamps the
component and a verifier that refuses malformed ones.** The only human input is
the irreducible creative part — the actual old→new edit and its anchor.

- **`scaffold-patch <tier> <name> <file>`** computes the next free ID for the tier
  (by scanning existing filenames), emits the skeleton above with the header
  fields and the `patch_/unpatch_/needs_applying_` triplet pre-named, and pre-fills
  the marker string. The author fills in only the `sed` bodies and the
  OLD/NEW/ANCHOR/WITNESS fields.
- **`verify-patches`** is the assertion harness, wired into the build and CI as a
  gate. For each patch it mechanically checks, against a fresh clone:
  - apply changes the tree;
  - `grep -c "<ANCHOR>"` equals the declared `MATCHES` (0 or >1 ⟶ fail);
  - the witness is present after apply and absent after unapply;
  - **the round-trip is exact**: `apply → unapply → git diff` is empty.
  A patch that fails any assertion never enters the active set — the property
  isn't "the author tested it," it's "the harness won't let a broken one build."
- **`gen-registry`** regenerates `docs/patches/patch-registry.md` by reading the
  header fields of every patch file. The registry is a *generated artifact*: it
  cannot drift from reality because it is never hand-edited, only recomputed. "Add
  a row to the registry" — a classic forgettable step — ceases to exist as a
  manual act.

---

## The orchestrator (`patches.sh`): wiring, not bookkeeping

One sourced file wires the components together:

1. **Auto-registration by glob.** Each patch file, when sourced, registers its
   functions; the orchestrator just globs them in. Adding a file *is* registering
   it — there is no separate manifest to keep in sync.
   ```bash
   PATCHES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   for f in "${PATCHES_DIR}"/P[0-9][0-9][0-9]-*.sh; do [[ -f "$f" ]] && source "$f"; done
   ```

2. **Per-profile selection as declarative structure.** The one genuinely
   *declarative* input — which patches a build variant wants — lives as an
   associative array (configuration in structure, greppable, with inline
   justification). This is the human's intent encoded as data the drivers read; it
   is config, not procedure.
   ```bash
   declare -A PREBUILD_PATCHES=(
       ["minimal"]="P001 P004"
       ["standard"]="P001 P004 P009 ... P024"   # compile fixes + module compat
       ["full"]="P001 P002 P003 ... P024"       # everything incl. feature hooks
   )
   ```

3. **The drivers** (`apply_*`, `unapply_*`, `reset_source_trees`,
   `patches_need_applying`, `audit_patches`) each iterate the active profile's list
   and dispatch by naming convention. Dispatch-by-convention means there is no
   lookup table to maintain — the function name *is* the registration.

**Revert reporting is computed, not narrated.** `unapply_patches_prebuild`
snapshots `git status --porcelain` across the tree and submodules before and after
each unpatch and prints `[<ID>] Reverted` only when content actually changed.
"Nothing printed" is therefore an unambiguous, machine-derived fact (with a no-op
count in the summary), not an operator guess.

---

## Profiles: one parts bin, many machines

A **profile** is a named selection of patches (and submodules, and config values).
The same `patches/` directory drives every variant; the per-profile arrays select
the subset. The active profile is itself read mechanically — from a `.profile`
file, overridable by `--profile` — so the selection is data the machine consumes,
never a flag an operator must remember to pass:

```bash
PROFILE="$([[ -f "${ROOT}/.profile" ]] && cat "${ROOT}/.profile" || echo "standard")"
```

The **a/b variant pattern** encodes "same setting, different value per profile" as
two sibling patches with non-overlapping profile lists, so exactly one fires.
History stays visible — old values are recorded as siblings, not overwritten —
which is itself a small machine for never losing the prior decision.

---

## De-patching: three cleanup mechanisms, each wired to its own trigger

There is no "decide which cleanup to run." There are three mechanisms, and the
**call site selects the right one automatically**:

| Mechanism | Wired to (trigger) | Guarantee it provides |
|-----------|--------------------|-----------------------|
| `unapply_patches_prebuild` | the EXIT trap, and the success-path revert | reverses exactly the patches *this run* applied, with computed per-patch reporting |
| `reset_source_trees` | the unconditional pre-flight at every build entry point | drives the tree to a known commit; cannot fabricate dirt |
| `apply-patches --revert` | the operator surface (manual) | exposes revert by hand; for source patches it also triggers an incremental rebuild so the binary matches |

The split exists because of a real failure mode that makes one mechanism unsafe in
the other's role:

> An `unapply` transformation targets *the post-patch shape*. It cannot distinguish
> "we applied this" from "upstream now ships this." When upstream converges on the
> form you patched to, a defensive unapply silently reverts **clean upstream code
> into false dirt.**

So the wiring assigns each mechanism the job it is safe for: `unapply` only ever
runs to reverse patches the same run applied (where authorship is certain), and
`reset_source_trees` — which goes to a commit and *cannot* manufacture dirt — is
the one wired to every defensive/pre-flight position. The operator never chooses;
the call site already did.

The operator surface itself is the one deliberately human-facing tool:

```
./scripts/apply-patches --dry-run            # show which patches WOULD apply (computed)
./scripts/apply-patches --prebuild           # apply source patches to the tree
./scripts/apply-patches --prebuild --revert  # revert + incremental rebuild
./scripts/apply-patches --profile minimal --prebuild
```

It is a thin, explicit control panel over the same drivers — not a procedure, a
switchboard.

---

## The pruning machine: auditing patches on every upstream update

Patches rot as upstream moves: some become redundant (upstream fixed it), some
stale (upstream restructured the target), some quietly mean something different
(upstream changed the region around your anchor). The pruning machine makes "are
these still needed?" a **computed verdict wired into the update path** — not a
review someone must remember to run. It is invoked by the build driver on every
update (`audit_patches OLD NEW`), so it *cannot be skipped*.

### What it computes, per patch, against the pristine new tree

The machine reads each patch's `TARGET`, `ANCHOR`, and `WITNESS` header fields and
emits exactly one verdict:

1. **RETIRE (convergence).** The witness probe reports the patch is no longer
   needed on pristine upstream → upstream adopted your shape. The edit is
   redundant.
2. **STALE (disappearance).** The anchor is absent from the target → upstream
   restructured the code out from under the patch; apply can no longer match.
3. **REVIEW (collision).** Upstream's changed line ranges overlap the patch's
   anchor line → the patch may still apply but its meaning in the new context is no
   longer guaranteed.
4. **OK.** Anchor intact, region untouched.

The collision test is computed directly from the version-control delta — hunk
headers give the changed line ranges in the new revision:

```bash
# Lines changed in <file> between old and new upstream. --unified=0 makes each
# hunk header report exactly the changed range: @@ -<oS>,<oL> +<nStart>,<nLen> @@
git -C "${SRC}" diff --unified=0 "${OLD_REF}" "${NEW_REF}" -- "${file}" \
  | awk '/^@@/ { split($3,a,","); s=substr(a[1],2)+0; l=(a[2]==""?1:a[2])+0;
                 if (l>0) print s","(s+l-1) }'
```

The patch's anchor line is `grep -n "<ANCHOR>" "${file}" | head -1 | cut -d: -f1`;
overlap with any printed range (optionally padded by context) is the trigger.

### The machine emits its own worklist — and a durable record

For every REVIEW and STALE verdict, the audit **auto-inserts a uniquely-tagged
comment** into the working tree directly above the anchor, in the file's own
comment syntax:

```bash
insert_audit_tag() {                       # <file> <line> <patch_id> <range>
    local C; C="$(comment_token_for "$1")" # //, #, --, ; … by extension
    sed -i "${2}i\\${C} [[PATCH-AUDIT $3 $4]] upstream changed this region — \
confirm patch still needed and the anchor still matches, then delete this line." "$1"
}
```

Now a single `grep -rn "PATCH-AUDIT" "${SRC}"` *enumerates the entire decision set*
mechanically — the machine produces the worklist; the human (or LLM) supplies only
the irreducible judgment per site, then deletes the tag. Two records, two
lifetimes, both produced automatically:

- **In-tree tags are ephemeral** — they live in the disposable tree and vanish at
  the next `reset_source_trees`, which is exactly right for one review session.
- **A persistent report** (`docs/patches/audit-<NEW_REF>.md`) records every
  verdict, so the decision history survives the reset.

### The gate

Whether the audit *blocks* or merely *warns* is a wired policy, not a habit: block
in CI/releases (a stale patch is a latent bug), warn in fast local iteration. The
`.upstream-lock` baseline advances only on a successful build, so the next audit
always compares against the last *known-good* version — the machine cannot drift
its own reference point.

---

## Patch docs: the prose form (a portable replay artifact)

For complex multi-file changes, a **prose "patch doc"** in `docs/patches/<feature>.md`
describes the edit in human/agent-readable form — file paths, insertion points by
*context* (not just line number), before/after snippets — so any agent or human
can **replay it onto any compatible upstream** even after line numbers drift. It is
the durable, forge-independent specification a script (or a reviewer) implements.

```markdown
# <Feature> Patch
## Overview        — what this adds and why
## Files to Modify — for each file: context to locate the spot + the change
## Build           — how to rebuild after applying
```

The three artifacts form a ladder: a **behavior spec** says what the system should
do (portable across reimplementations); a **patch doc** says what edits to make to
one codebase (portable across upstreams of it); a **patch script** is the
mechanical, idempotent, reversible implementation. Each is derivable downward.

---

## Contributing a patch upstream: the same machine, run forward-only

A subset of your patches are genuine upstream improvements. For those, the system
is already most of a contribution machine: the build runs `apply → build →
unapply`; a contribution runs `apply → commit`. **Same apply function, different
downstream wiring.** A patch's anchored transformation against a pristine clone of
upstream HEAD *produces the contribution diff*; the header *is* the PR body.

This is built as a driver with **gates** at the outward-facing edges — the one
place where the machine deliberately halts and requires irreducible human input.

### The two human inputs the machine is built around

- **Eligibility is a human judgment, never automated.** Only the author knows
  whether an edit belongs upstream. The machine therefore records no
  upstreamability field and decides nothing; it acts only on a patch a human hands
  it. (A behavior change worth upstreaming should be contributed behind a config
  flag, with the patch-doc as the PR body.)
- **Each outward action is gated on approval.** Fork creation, branch push, PR
  open, and optional fork deletion each pass through a gate that renders what will
  happen and refuses to proceed without an explicit yes.

Everything *between* those two human touch-points is wired and deterministic:

### Forge detection — computed from the remote, not asked

```bash
remote_url="$(git -C "${SRC}" remote get-url upstream 2>/dev/null \
            || git -C "${SRC}" remote get-url origin)"
case "${remote_url}" in
    *github.com*) FORGE=gh   ;;   # gh pr create
    *gitlab*)     FORGE=glab ;;   # glab mr create
    *gitea*|*)    FORGE=tea  ;;   # gitea: tea pr create / REST API
esac
# owner/repo derive from the same URL; an unrecognized host trips a gate (ask).
```

### Fork and clone are different objects with different lifetimes

The machine keeps these roles mechanically distinct, which is what lets a
persistent fork coexist with a throwaway tmpfs clone:

- **The fork is server-side and durable.** Created once on the account, it holds
  the PR branches and survives so review threads persist. It is **not** on tmpfs.
- **The working clone is local and disposable, and exactly one is needed** for any
  number of open PRs. Per patch, the machine resets the clone to pristine
  default-branch HEAD (reusing `reset_source_trees`), cuts `patch/<id>-<name>`,
  applies that one patch forward-only, commits, and pushes the branch to the fork.
  The fork accumulates one branch per PR; the clone is recycled between them.
- **Each PR carries only its relevant files, by construction** — because each
  patch is atomic and one-to-one targeted, its branch differs from base only in the
  files it touches. No filtering machinery is needed.
- **Open PRs survive clone deletion**: once a branch is pushed, its commits live on
  the remote fork, so end-of-run cleanup (`rm` the clone) cannot disturb them.

### Clone placement — a measured decision, with a logged fallback

The clone prefers the RAM-backed `tmp/` symlink and falls to on-disk only when it
won't fit. The fit test measures **space available on that mount right now** (not
total capacity — other things already occupy it):

```bash
avail=$(df -kP "${ROOT}/tmp" | awk 'NR==2 {print $4 * 1024}')   # free bytes NOW
need=$(( $(forge_repo_size_kb) * 1024 * 2 ))                    # shallow clone + margin
if (( avail >= need )); then
    CLONE_DIR="${ROOT}/tmp/pr-work"
else
    CLONE_DIR="${ROOT}/.pr-work"        # on-disk fallback inside the project
    echo "FALLBACK: tmp/ has ${avail} B free; clone needs ~${need} B. Using" \
         "on-disk ${CLONE_DIR}. This is a fallback, not the normal path." >&2
fi
git clone --depth 1 --branch "<default-branch>" "<fork-url>" "${CLONE_DIR}"
```

The fallback announces itself every time it fires — a silent fallback would hide a
capacity problem worth surfacing. Either location is `rm`'d when the run ends.

### The verify-match interlock

Before any gate is reached, the machine asserts each patch's anchored pattern hits
its declared `MATCHES` count on upstream HEAD. A zero or extra match means the
patch was written against an older ref and **the driver aborts** rather than
opening a PR on stale assumptions — the same signal the pruning machine uses,
reused here as a pre-flight interlock.

### The driver, as a graph

```
select(patch)            ─ human: hands the machine an eligible patch
detect_forge(remote)     ─ computed
ensure_fork()            ─ GATE: approve creating the server-side fork (once)
place_clone()            ─ tmpfs if it fits now, else on-disk fallback (logged)
for each patch:
    reset → branch → apply(forward-only) → verify_match()   ─ abort on mismatch
    render(diff, pr_body_from_header)                       ─ computed
    GATE: approve push + PR open
    push_branch(); open_pr(FORGE)
cleanup()                ─ rm the clone; fork + open PRs remain
```

The driver *prepares* everything up to each gate and stops; nothing reaches the
network or the account without the human passing that gate.

---

## Non-textual patches (same discipline, different substrate)

The apply/unapply/idempotent/round-trip machinery is not specific to text:

- **A data row** (registering a path with an upstream's own migration/plugin
  runner): apply is an idempotent insert (`INSERT IGNORE`, or create-if-not-exists
  keyed on a unique column); unapply is the matching delete; the guard checks for
  the row.
- **A binary asset or generated file**: apply writes/links it, unapply removes it,
  the guard checks presence.

**Where upstream provides its own seam — a plugin dir, a migrations folder, a hooks
directory — wire into it instead of editing upstream files.** A registration is a
patch that *cannot* conflict, because you are using a mechanism upstream intends.

---

## Assembling the machine in a new project

This is a parts list and wiring diagram, not a sequence to march through. Build the
components; the guarantees emerge from how they connect.

- **Disposability wire:** add `source/` (or `vendor/`, or the submodule path) to
  `.gitignore`. Commit only `patches/` and `scripts/`. This single line is what
  makes the tree a regenerable artifact rather than a thing to protect.
- **The orchestrator (`patches.sh`):** glob-source patch files; declare the
  per-profile `declare -A` lists; define `reset_source_trees`, the `apply_/unapply_`
  drivers, and `audit_patches`. Dispatch by naming convention so there is no
  manifest to maintain.
- **The standard component:** patches as guarded, anchored, marker-wrapped,
  exact-inverse pairs with a witness probe and header fields. The substrate (any
  language, any config DSL) is irrelevant — anchored `sed`/`awk` operate on any
  text tree; non-textual patches swap the tool and keep the contract.
- **The generators and the gate:** `scaffold-patch` (emits components),
  `gen-registry` (recomputes the registry from headers), `verify-patches` (asserts
  round-trip + match-count and blocks the build on failure).
- **The build driver:** compose `reset → audit → apply → (trap) → build → install →
  unapply → record-lock` exactly as the wiring above, so every precondition is a
  guaranteed product of the prior edge.
- **The pruning machine + lock:** `audit_patches` wired into the update path,
  `.upstream-lock` written only on success.
- **The contribution driver (optional):** forward-only apply against a fork clone,
  forge detection from the remote, verify-match interlock, and approval gates at
  the outward edges.

Tiers beyond PRE-BUILD are added only when the chronology demands them.

---

## Failure modes the machinery is built to foreclose

These are not reminders for an operator — they are the specific failures each
mechanism above exists to make impossible. Stated as "the bug, and the part that
forecloses it":

- **False dirt from defensive unapply.** `unapply` matches the post-patch shape and
  cannot tell your edit from an upstream that converged on it; run defensively it
  reverts clean code into phantom diffs that read like upstream regressions.
  *Foreclosed by* wiring `unapply` only to same-run reverts and `reset_source_trees`
  (which goes to a commit) to every defensive position — the call site, not the
  operator, picks the safe one.
- **Silent corruption from a loose pattern.** An unanchored pattern matching two
  sites edits the wrong one. *Foreclosed by* the `MATCHES` field + `verify-patches`,
  which fail any patch whose anchor count isn't exactly as declared.
- **A fragile inverse.** Reverting by re-matching content breaks when upstream
  reflows around the block. *Foreclosed by* the unique `{{{ <ID> }}}` markers,
  which give the inverse a stable handle and double as the witness.
- **Double-apply / double-revert.** Retries, re-sourcing, and trap-over-explicit
  all run things twice. *Foreclosed by* the guards that make a repeated apply or
  unapply inert.
- **A patch that applies but won't reverse.** It leaks false dirt into the *next*
  build, far from its origin. *Foreclosed by* the round-trip assertion in
  `verify-patches` (`apply → unapply → empty diff`), which blocks it from the set.
- **Residue from an uncatchable kill.** The EXIT trap misses SIGKILL/OOM/power
  loss. *Foreclosed by* the unconditional pre-flight `reset_source_trees`, which
  covers exactly the modes the trap cannot.
- **A re-targeting need going unnoticed.** Upstream moves the code under a patch.
  *Foreclosed by* a loud unmatched-pattern failure and the pruning machine's
  STALE/REVIEW verdicts with auto-inserted tags — the machine surfaces the one
  patch needing attention instead of letting it drift.
- **The patch set silently rotting.** *Foreclosed by* wiring `audit_patches` into
  the update path so it cannot be skipped, and generating the registry from headers
  so it cannot go stale.
- **A poisoned audit baseline.** *Foreclosed by* writing `.upstream-lock` only on a
  successful build, so the machine never compares against a version it didn't ship.
- **A tuning knob masquerading as a build failure.** *Foreclosed by* the
  chronology: POST-DEPLOY writes runtime values only after the validation gate.
- **A tracked or surviving source edit.** It breaks the `upstream + patches`
  guarantee. *Foreclosed by* the `.gitignore` wire plus a clean-tree assertion —
  any surviving edit is a verify failure, not a thing to remember not to do.
- **An outward action firing without consent.** *Foreclosed by* the approval gates
  on fork/push/PR/delete, which render the action and refuse to proceed without an
  explicit yes.
