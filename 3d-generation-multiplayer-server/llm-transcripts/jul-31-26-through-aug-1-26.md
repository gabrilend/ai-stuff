# Conversation Summary: c256c5f4-0059-4f29-b6e3-ba74f004ba0e

Generated on: 2026-09-16 15:56:06
Models: claude-opus-5

--------------------------------------------------------------------------------

### User Request 1

hiiiiiii can you create this project with me? pink star squiggles!

--------------------------------------------------------------------------------

### Assistant Response 1

>                                   Let me get the skeleton on the ground first.

>             Skeleton's down — directories, RAM tiers (`tmp/` → `/tmp/…`,
>    `tmp/shared-memory/` → `/dev/shm/…`), index counter at zero, and **pink
> star squiggles** written into `notes/spoken-while-building.md` before anything
>                                         else could overwrite the memory of it.
>
> I read it as three layers of one picture: *pink* is a hue that appears in none
>     of your four schemes, *star* is radial geometry that reads as light rather
>    than architecture, and *squiggles* is the one word in the whole vision that
>            isn't made of straight edges. Rigid terrain, non-rigid inhabitants.
>
> Before I write the architecture and roadmap docs, three forks that change what
>                                                                    gets built:

>                                                           **[Asked the user]**
>
>        *Q1 — The look:* Where does "pink star squiggles" live in the design?
>      - The whisps themselves (Recommended) — Your player characters are pink
>          star-shaped squiggling light — a radial burst whose arms wander and
>    wobble, trailing a hand-drawn line as it moves. The world stays squares and
>    triangles in whichever of the four schemes is loaded; the living things are
>        the only curved, pink, moving thing on screen. Maximum contrast, and it
>                                  makes 'which whisp is me' instantly readable.
>  - A fifth colour scheme — Pink-on-something becomes a fifth entry alongside
>   white-bright, black-bright, blue-muted, green-muted — a whole palette swap
>         where everything, terrain included, goes pink and squiggly. The scheme
>            selector gains an option rather than the creature design gaining an
>                                                                      identity.
>   - The project's overall signature — Not a game element at all — it's the
>       aesthetic of the whole thing: the docs pages, the HTML reading room, the
>     demo output, the logo. The game inside stays geometric; the wrapper around
>                                                                  it squiggles.
>                          → **Selected:** The whisps themselves (Recommended)
>
>   *Q2 — Client↔server:* The vision says custom client, and says the client
>  and engine are one project. How does the custom client first meet the server?
>   - Speak the real 3.3.5a protocol (Recommended) — The new client implements
>       the SRP6 login handshake on the auth port and the header-encrypted world
>     packet stream on the world port — enough opcodes to log in, walk, click,
>     and loot. It connects to an unmodified AzerothCore on day one. Every patch
>    you write afterward is then verifiable: a client that already worked either
>                         still works or tells you exactly which patch broke it.
>     - Patch the protocol first, then write to it — Strip the server's packet
>       layer down to our own simpler protocol before writing any client, so the
>          client is never burdened with WoW-isms. Faster to a clean design, but
>     nothing runs end-to-end until both halves are done — no working baseline
>                                                            to regress against.
>  - Keep the real client, replace only the art — Swap the model, texture, and
>        map files so the stock WoW client renders abstract geometry. Fastest to
>    something on screen, but it stays bound to 'a single client on the internet
>        we found' — which is the thing the vision explicitly wants liberation
>                                                                          from.
>                 → **Selected:** Speak the real 3.3.5a protocol (Recommended)
>
>                    *Q3 — Client stack:* What does the client get written in?
> - LuaJIT + FFI over SDL2/OpenGL (Recommended) — LuaJIT calls the C libraries
>      directly through its foreign-function interface, so you write Lua and get
>         raw OpenGL. Matches your standing language preference, the JIT handles
>   per-frame math fine, and rendering untextured coloured polygons needs almost
>   no asset pipeline — the whole art budget is vertex positions and a colour.
>                                Networking is FFI sockets in the same language.
>  - C with SDL2/OpenGL — Client in C, matching AzerothCore's own C++ world so
>       both halves compile with the same toolchain and share headers if useful.
>   Faster per frame, and you've asked for assembly-adjacent work before — but
>                it's a second language to maintain against your Lua preference.
>      - Decide once the protocol layer exists — Write the login handshake and
>   packet reader first as a headless tool that proves it can connect and walk a
>       character with no window at all, then pick the renderer knowing what the
>                                                      data actually looks like.
>                                           → **Selected:** C with SDL2/OpenGL

   Locked in: whisps are pink star squiggles, the client speaks authentic 3.3.5a
                                      from day one, and it's C with SDL2/OpenGL.

--------------------------------------------------------------------------------

### User Request 2

Base directory for this skill: /home/ritz/.claude/skills/upstream-patch-system

# Upstream Patch System

A method for owning customizations to code you didn't write, without forking it.

> **This document describes machinery to build, not a procedure to follow.** It
> assumes nothing about which agent, editor, language, or runtime executes it.
> Everything below is plain shell and text-processing logic — `git`, `sed`,
> `grep`, `awk`, traps, generated artifacts — that any LLM or human can
> assemble
> in any project. Swap equivalent tools freely.

---

## Principle: machinery, not procedure

A **procedure** is a sequence an operator (human or LLM) must work through by
hand. A **machine** is a set of components wired together so the outcome falls
out
deterministically, with no operator memory in the loop. This system is built
entirely as machinery, on purpose:

- **Every "remember to…" is a defect.** Anything that depends on the operator
  recalling a step is a latent bug. Convert it into one of four mechanical
  forms:
  a **guard** (a precondition check that makes the operation a no-op when it
  shouldn't fire), a **trap** (cleanup wired to process exit so it runs even on
  failure), a **generated artifact** (a derived file that can't drift because
  it's
  recomputed, never hand-edited), or a **gate** (a hard stop that refuses to
  proceed until an explicit condition or approval is satisfied).

- **The only inputs left to a human are irreducible.** Three, specifically: the
  *transformation itself* (the old→new text edit and the anchor that locates
  it),
  the *judgment that a given patch belongs upstream*, and the *approval of an
  outward-facing action* (opening a PR, deleting a fork). Everything else —
  when
  patches apply, when they revert, whether they still match, what the registry
  says, whether the tree is clean — is wired and deterministic.

Read every section below as "here is a component and how it is wired so the
guarantee holds without anyone watching," not "here are steps to perform."

---

## The core problem this solves

You depend on a third-party codebase — an upstream project, a vendored
library, a
submodule. You need to change it: fix a build error against your toolchain, add
a
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

What you version is the **intent** (the apply/unapply scripts and their
headers),
not the **result** (the modified source). The result is a deterministic function
of `upstream + scripts`, regenerated on demand.

## What the machinery buys you

- **Upstream updates stop hurting.** Re-clone, re-apply. A patch that no longer
  matches fails loudly with an unmatched pattern — a *signal* the machine
  surfaces
  automatically, pointing at the one patch to re-target, rather than a conflict
  to
  resolve across the tree.
- **Every change is documented at the point of change.** Each script's header
  records the upstream symptom, the pattern it matches, and how it reverses —
  and
  the registry is *generated* from those headers, so "what did we change and
  why"
  is always answerable and never stale.
- **The diff is legible.** N upstream problems become N small, named, anchored
  edits, not one sprawling fork diff.
- **Changes are portable.** A patch script (or its prose "patch doc") replays
  onto
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
   round-trip — and it is *asserted* by the verify harness (below), not
   trusted.

---

## The tiers: components separated by *when they fire* and *what they target*

Customizations fire at different moments and touch different trees, so the
machine
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
created it) so it can write paths/credentials pointing *at* it — values that
did
not exist at any earlier phase. The tiers cannot be collapsed without violating
a
precondition. A side benefit of wiring runtime-tuning (POST-DEPLOY) *after* the
validation gate: a botched tuning value cannot fail validation, because
validation
runs against complete, valid staging configs from POST-BUILD; POST-DEPLOY writes
only the *delta* between "valid for staging" and "valid for live."

**PRE-BUILD is the load-bearing tier** — the only one touching code you don't
own,
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

The cloned source is **never tracked**. A surviving modification to upstream
code
in your repo's history is, by construction, a bug — a failed unapply or a
manual
edit that should have been a patch. (The verify harness and a clean-tree
assertion
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

- **`reset_source_trees` first, unconditionally.** Hard-resets the clone and
  every
  submodule to HEAD. On a clean tree it is a no-op; on a dirty tree it discards
  residue from a build killed in a way that bypassed the trap (SIGKILL, OOM,
  power
  loss). Running it always — never "only if dirty" — is what makes "source
  ==
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

- **The trap is the revert machine.** `trap 'unapply_patches_prebuild' EXIT`
  wires
  the revert to process exit, so a crashed or failed build leaves the source
  clean
  anyway. The explicit `unapply` on the success path (after disarming) is the
  normal route; the trap covers every abnormal one. Together they make "the tree
  returns to HEAD" true across *all* exit modes, with no operator action.

- **`.upstream-lock` advances only after success.** Wiring the lock write to the
  end of the successful path means the audit's baseline can never point at a
  version you didn't actually ship. A failed build leaves the previous baseline
  intact.

The driver loads the active profile's patch list and dispatches by naming
convention — no central registry of "which function to call," just a glob and
a
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
(leaving build dirs, installed artifacts, data, config untouched), so "the
source
is in a weird state" is never a debugging session — it's `redownload-source &&
install`. That shortcut is *safe specifically because* the real work lives in
`patches/`, not in the tree.

---

## Anatomy of a patch (the standard component)

Every patch file is a self-contained apply/unapply pair with a header. The
header
fields are not prose decoration — they are the input the generator emits and
the
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

(`<C>` is the target language's line-comment token — `//`, `#`, `--`, `;`,
…)

The mechanical properties the *shape* enforces:

- **The guard makes idempotency structural.** A one-line edit guards with
  `grep -q "<unpatched anchor>" && sed …`; run it again and the anchor is
  gone, so
  nothing happens. The operator never has to track "did I already apply this."
- **Anchored, one-to-one patterns.** N problems = N anchored edits + N inverses.
  A
  broad pattern corrupts clean source; the `MATCHES` field plus the verify
  harness
  turn "anchor tightly" from advice into an asserted invariant.
- **Markers make the inverse robust.** A unique `{{{ <ID> … }}} <ID>` wrapper
  is a
  stable handle the inverse always finds and a sibling patch can never hit. The
  same marker doubles as the witness, so the probe and the inverse agree by
  construction.
- **The witness probe is the deterministic answer to "is this needed?"** —
  reused
  by the build's skip shortcut, by `--dry-run`, and by the audit's convergence
  test.

## The generator and the verifier replace the "add a patch" checklist

Adding a patch is not a remembered procedure; it is **a generator that stamps
the
component and a verifier that refuses malformed ones.** The only human input is
the irreducible creative part — the actual old→new edit and its anchor.

- **`scaffold-patch <tier> <name> <file>`** computes the next free ID for the
  tier
  (by scanning existing filenames), emits the skeleton above with the header
  fields and the `patch_/unpatch_/needs_applying_` triplet pre-named, and
  pre-fills
  the marker string. The author fills in only the `sed` bodies and the
  OLD/NEW/ANCHOR/WITNESS fields.
- **`verify-patches`** is the assertion harness, wired into the build and CI as
  a
  gate. For each patch it mechanically checks, against a fresh clone:
  - apply changes the tree;
  - `grep -c "<ANCHOR>"` equals the declared `MATCHES` (0 or >1 ⟶ fail);
  - the witness is present after apply and absent after unapply;
  - **the round-trip is exact**: `apply → unapply → git diff` is empty.
  A patch that fails any assertion never enters the active set — the property
  isn't "the author tested it," it's "the harness won't let a broken one build."
- **`gen-registry`** regenerates `docs/patches/patch-registry.md` by reading the
  header fields of every patch file. The registry is a *generated artifact*: it
  cannot drift from reality because it is never hand-edited, only recomputed.
  "Add
  a row to the registry" — a classic forgettable step — ceases to exist as a
  manual act.

---

## The orchestrator (`patches.sh`): wiring, not bookkeeping

One sourced file wires the components together:

1. **Auto-registration by glob.** Each patch file, when sourced, registers its
   functions; the orchestrator just globs them in. Adding a file *is*
   registering
   it — there is no separate manifest to keep in sync.
   ```bash
   PATCHES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   for f in "${PATCHES_DIR}"/P[0-9][0-9][0-9]-*.sh; do [[ -f "$f" ]] && source "$f"; done
   ```

2. **Per-profile selection as declarative structure.** The one genuinely
   *declarative* input — which patches a build variant wants — lives as an
   associative array (configuration in structure, greppable, with inline
   justification). This is the human's intent encoded as data the drivers read;
   it
   is config, not procedure.
   ```bash
   declare -A PREBUILD_PATCHES=(
       ["minimal"]="P001 P004"
       ["standard"]="P001 P004 P009 ... P024"   # compile fixes + module compat
       ["full"]="P001 P002 P003 ... P024"       # everything incl. feature hooks
   )
   ```

3. **The drivers** (`apply_*`, `unapply_*`, `reset_source_trees`,
   `patches_need_applying`, `audit_patches`) each iterate the active profile's
   list
   and dispatch by naming convention. Dispatch-by-convention means there is no
   lookup table to maintain — the function name *is* the registration.

**Revert reporting is computed, not narrated.** `unapply_patches_prebuild`
snapshots `git status --porcelain` across the tree and submodules before and
after
each unpatch and prints `[<ID>] Reverted` only when content actually changed.
"Nothing printed" is therefore an unambiguous, machine-derived fact (with a
no-op
count in the summary), not an operator guess.

---

## Profiles: one parts bin, many machines

A **profile** is a named selection of patches (and submodules, and config
values).
The same `patches/` directory drives every variant; the per-profile arrays
select
the subset. The active profile is itself read mechanically — from a `.profile`
file, overridable by `--profile` — so the selection is data the machine
consumes,
never a flag an operator must remember to pass:

```bash
PROFILE="$([[ -f "${ROOT}/.profile" ]] && cat "${ROOT}/.profile" || echo "standard")"
```

The **a/b variant pattern** encodes "same setting, different value per profile"
as
two sibling patches with non-overlapping profile lists, so exactly one fires.
History stays visible — old values are recorded as siblings, not overwritten
—
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

The split exists because of a real failure mode that makes one mechanism unsafe
in
the other's role:

> An `unapply` transformation targets *the post-patch shape*. It cannot
> distinguish
> "we applied this" from "upstream now ships this." When upstream converges on
> the
> form you patched to, a defensive unapply silently reverts **clean upstream
> code
> into false dirt.**

So the wiring assigns each mechanism the job it is safe for: `unapply` only ever
runs to reverse patches the same run applied (where authorship is certain), and
`reset_source_trees` — which goes to a commit and *cannot* manufacture dirt
— is
the one wired to every defensive/pre-flight position. The operator never
chooses;
the call site already did.

The operator surface itself is the one deliberately human-facing tool:

```
./scripts/apply-patches --dry-run            # show which patches WOULD apply (computed)
./scripts/apply-patches --prebuild           # apply source patches to the tree
./scripts/apply-patches --prebuild --revert  # revert + incremental rebuild
./scripts/apply-patches --profile minimal --prebuild
```

It is a thin, explicit control panel over the same drivers — not a procedure,
a
switchboard.

---

## The pruning machine: auditing patches on every upstream update

Patches rot as upstream moves: some become redundant (upstream fixed it), some
stale (upstream restructured the target), some quietly mean something different
(upstream changed the region around your anchor). The pruning machine makes "are
these still needed?" a **computed verdict wired into the update path** — not a
review someone must remember to run. It is invoked by the build driver on every
update (`audit_patches OLD NEW`), so it *cannot be skipped*.

## What it computes, per patch, against the pristine new tree

The machine reads each patch's `TARGET`, `ANCHOR`, and `WITNESS` header fields
and
emits exactly one verdict:

1. **RETIRE (convergence).** The witness probe reports the patch is no longer
   needed on pristine upstream → upstream adopted your shape. The edit is
   redundant.
2. **STALE (disappearance).** The anchor is absent from the target → upstream
   restructured the code out from under the patch; apply can no longer match.
3. **REVIEW (collision).** Upstream's changed line ranges overlap the patch's
   anchor line → the patch may still apply but its meaning in the new context
   is no
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

The patch's anchor line is `grep -n "<ANCHOR>" "${file}" | head -1 | cut -d:
-f1`;
overlap with any printed range (optionally padded by context) is the trigger.

## The machine emits its own worklist — and a durable record

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

Now a single `grep -rn "PATCH-AUDIT" "${SRC}"` *enumerates the entire decision
set*
mechanically — the machine produces the worklist; the human (or LLM) supplies
only
the irreducible judgment per site, then deletes the tag. Two records, two
lifetimes, both produced automatically:

- **In-tree tags are ephemeral** — they live in the disposable tree and vanish
  at
  the next `reset_source_trees`, which is exactly right for one review session.
- **A persistent report** (`docs/patches/audit-<NEW_REF>.md`) records every
  verdict, so the decision history survives the reset.

## The gate

Whether the audit *blocks* or merely *warns* is a wired policy, not a habit:
block
in CI/releases (a stale patch is a latent bug), warn in fast local iteration.
The
`.upstream-lock` baseline advances only on a successful build, so the next audit
always compares against the last *known-good* version — the machine cannot
drift
its own reference point.

---

## Patch docs: the prose form (a portable replay artifact)

For complex multi-file changes, a **prose "patch doc"** in
`docs/patches/<feature>.md`
describes the edit in human/agent-readable form — file paths, insertion points
by
*context* (not just line number), before/after snippets — so any agent or
human
can **replay it onto any compatible upstream** even after line numbers drift. It
is
the durable, forge-independent specification a script (or a reviewer)
implements.

```markdown
# <Feature> Patch
## Overview        — what this adds and why
## Files to Modify — for each file: context to locate the spot + the change
## Build           — how to rebuild after applying
```

The three artifacts form a ladder: a **behavior spec** says what the system
should
do (portable across reimplementations); a **patch doc** says what edits to make
to
one codebase (portable across upstreams of it); a **patch script** is the
mechanical, idempotent, reversible implementation. Each is derivable downward.

---

## Contributing a patch upstream: the same machine, run forward-only

A subset of your patches are genuine upstream improvements. For those, the
system
is already most of a contribution machine: the build runs `apply → build →
unapply`; a contribution runs `apply → commit`. **Same apply function,
different
downstream wiring.** A patch's anchored transformation against a pristine clone
of
upstream HEAD *produces the contribution diff*; the header *is* the PR body.

This is built as a driver with **gates** at the outward-facing edges — the one
place where the machine deliberately halts and requires irreducible human input.

## The two human inputs the machine is built around

- **Eligibility is a human judgment, never automated.** Only the author knows
  whether an edit belongs upstream. The machine therefore records no
  upstreamability field and decides nothing; it acts only on a patch a human
  hands
  it. (A behavior change worth upstreaming should be contributed behind a config
  flag, with the patch-doc as the PR body.)
- **Each outward action is gated on approval.** Fork creation, branch push, PR
  open, and optional fork deletion each pass through a gate that renders what
  will
  happen and refuses to proceed without an explicit yes.

Everything *between* those two human touch-points is wired and deterministic:

## Forge detection — computed from the remote, not asked

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

## Fork and clone are different objects with different lifetimes

The machine keeps these roles mechanically distinct, which is what lets a
persistent fork coexist with a throwaway tmpfs clone:

- **The fork is server-side and durable.** Created once on the account, it holds
  the PR branches and survives so review threads persist. It is **not** on
  tmpfs.
- **The working clone is local and disposable, and exactly one is needed** for
  any
  number of open PRs. Per patch, the machine resets the clone to pristine
  default-branch HEAD (reusing `reset_source_trees`), cuts `patch/<id>-<name>`,
  applies that one patch forward-only, commits, and pushes the branch to the
  fork.
  The fork accumulates one branch per PR; the clone is recycled between them.
- **Each PR carries only its relevant files, by construction** — because each
  patch is atomic and one-to-one targeted, its branch differs from base only in
  the
  files it touches. No filtering machinery is needed.
- **Open PRs survive clone deletion**: once a branch is pushed, its commits live
  on
  the remote fork, so end-of-run cleanup (`rm` the clone) cannot disturb them.

## Clone placement — a measured decision, with a logged fallback

The clone prefers the RAM-backed `tmp/` symlink and falls to on-disk only when
it
won't fit. The fit test measures **space available on that mount right now**
(not
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

The fallback announces itself every time it fires — a silent fallback would
hide a
capacity problem worth surfacing. Either location is `rm`'d when the run ends.

## The verify-match interlock

Before any gate is reached, the machine asserts each patch's anchored pattern
hits
its declared `MATCHES` count on upstream HEAD. A zero or extra match means the
patch was written against an older ref and **the driver aborts** rather than
opening a PR on stale assumptions — the same signal the pruning machine uses,
reused here as a pre-flight interlock.

## The driver, as a graph

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
  runner): apply is an idempotent insert (`INSERT IGNORE`, or
  create-if-not-exists
  keyed on a unique column); unapply is the matching delete; the guard checks
  for
  the row.
- **A binary asset or generated file**: apply writes/links it, unapply removes
  it,
  the guard checks presence.

**Where upstream provides its own seam — a plugin dir, a migrations folder, a
hooks
directory — wire into it instead of editing upstream files.** A registration
is a
patch that *cannot* conflict, because you are using a mechanism upstream
intends.

---

## Assembling the machine in a new project

This is a parts list and wiring diagram, not a sequence to march through. Build
the
components; the guarantees emerge from how they connect.

- **Disposability wire:** add `source/` (or `vendor/`, or the submodule path) to
  `.gitignore`. Commit only `patches/` and `scripts/`. This single line is what
  makes the tree a regenerable artifact rather than a thing to protect.
- **The orchestrator (`patches.sh`):** glob-source patch files; declare the
  per-profile `declare -A` lists; define `reset_source_trees`, the
  `apply_/unapply_`
  drivers, and `audit_patches`. Dispatch by naming convention so there is no
  manifest to maintain.
- **The standard component:** patches as guarded, anchored, marker-wrapped,
  exact-inverse pairs with a witness probe and header fields. The substrate (any
  language, any config DSL) is irrelevant — anchored `sed`/`awk` operate on
  any
  text tree; non-textual patches swap the tool and keep the contract.
- **The generators and the gate:** `scaffold-patch` (emits components),
  `gen-registry` (recomputes the registry from headers), `verify-patches`
  (asserts
  round-trip + match-count and blocks the build on failure).
- **The build driver:** compose `reset → audit → apply → (trap) → build
  → install →
  unapply → record-lock` exactly as the wiring above, so every precondition is
  a
  guaranteed product of the prior edge.
- **The pruning machine + lock:** `audit_patches` wired into the update path,
  `.upstream-lock` written only on success.
- **The contribution driver (optional):** forward-only apply against a fork
  clone,
  forge detection from the remote, verify-match interlock, and approval gates at
  the outward edges.

Tiers beyond PRE-BUILD are added only when the chronology demands them.

---

## Failure modes the machinery is built to foreclose

These are not reminders for an operator — they are the specific failures each
mechanism above exists to make impossible. Stated as "the bug, and the part that
forecloses it":

- **False dirt from defensive unapply.** `unapply` matches the post-patch shape
  and
  cannot tell your edit from an upstream that converged on it; run defensively
  it
  reverts clean code into phantom diffs that read like upstream regressions.
  *Foreclosed by* wiring `unapply` only to same-run reverts and
  `reset_source_trees`
  (which goes to a commit) to every defensive position — the call site, not
  the
  operator, picks the safe one.
- **Silent corruption from a loose pattern.** An unanchored pattern matching two
  sites edits the wrong one. *Foreclosed by* the `MATCHES` field +
  `verify-patches`,
  which fail any patch whose anchor count isn't exactly as declared.
- **A fragile inverse.** Reverting by re-matching content breaks when upstream
  reflows around the block. *Foreclosed by* the unique `{{{ <ID> }}}` markers,
  which give the inverse a stable handle and double as the witness.
- **Double-apply / double-revert.** Retries, re-sourcing, and trap-over-explicit
  all run things twice. *Foreclosed by* the guards that make a repeated apply or
  unapply inert.
- **A patch that applies but won't reverse.** It leaks false dirt into the
  *next*
  build, far from its origin. *Foreclosed by* the round-trip assertion in
  `verify-patches` (`apply → unapply → empty diff`), which blocks it from
  the set.
- **Residue from an uncatchable kill.** The EXIT trap misses SIGKILL/OOM/power
  loss. *Foreclosed by* the unconditional pre-flight `reset_source_trees`, which
  covers exactly the modes the trap cannot.
- **A re-targeting need going unnoticed.** Upstream moves the code under a
  patch.
  *Foreclosed by* a loud unmatched-pattern failure and the pruning machine's
  STALE/REVIEW verdicts with auto-inserted tags — the machine surfaces the one
  patch needing attention instead of letting it drift.
- **The patch set silently rotting.** *Foreclosed by* wiring `audit_patches`
  into
  the update path so it cannot be skipped, and generating the registry from
  headers
  so it cannot go stale.
- **A poisoned audit baseline.** *Foreclosed by* writing `.upstream-lock` only
  on a
  successful build, so the machine never compares against a version it didn't
  ship.
- **A tuning knob masquerading as a build failure.** *Foreclosed by* the
  chronology: POST-DEPLOY writes runtime values only after the validation gate.
- **A tracked or surviving source edit.** It breaks the `upstream + patches`
  guarantee. *Foreclosed by* the `.gitignore` wire plus a clean-tree assertion
  —
  any surviving edit is a verify failure, not a thing to remember not to do.
- **An outward action firing without consent.** *Foreclosed by* the approval
  gates
  on fork/push/PR/delete, which render the action and refuse to proceed without
  an
  explicit yes.

--------------------------------------------------------------------------------

### Assistant Response 2

>     The patch skill maps directly onto what the vision asks for first. Now the
>                                                                 documentation.

>     There's an `init-project.sh` in the shared scripts directory I should have
>                                                                 checked first.

>                          Documentation set is written. Here's where it stands.
>
>  **What's on disk** — `docs/` has the architecture, a six-phase roadmap, and
>     five datapath documents: the patch machine, the login handshake, the world
>       stream, the whisp, and the world of shapes. Plus a table of contents, an
>         append-only balance-updates file, one strategem, and the `desire/` and
>  `faith/` notes. `input/` has an account example, a realm example, and a first
> room in the geometry format — a floor, four walls, a ramp, and two blocks to
>                                                                  stand behind.
>
>                                             **Three findings worth flagging:**
>
>   *The patch skill's method fits the vision's first ask exactly.* The clone is
>      gitignored and disposable; `patches/` is the real project. But the bigger
>   lever is that AzerothCore ships a module system with real script hooks — a
>        change made through a hook upstream deliberately exposes survives every
>    upstream refactor untouched, where a source patch has to be re-anchored. So
> phase 5 splits before it starts: what can be done from outside, and what needs
>                                                                   reaching in.
>
>   *On custom maps, patch the extraction tools, not the server.* The extractors
>      are already a translation layer — art in, server collision out. Replace
>       their input stage with a reader for our geometry and the navigation-mesh
>   builder downstream works unmodified. That's weeks of Recast work you inherit
>   for free, zero patches on code upstream actively changes, and it's testable:
>     feed the patched extractor a real map and it should produce byte-identical
>                                                   output to the unpatched one.
>
>    *I built the skeleton by hand, then found `scripts/init-project.sh` sitting
>     untracked in the shared scripts directory.* I've aligned the folder set to
>  match what its skeleton function produces. I did not run it — it provisions
>    a bubblewrap sandbox, a RAM clone, and a launcher, and writes a notice into
>     CLAUDE.md, which is more than you asked for. Say the word if you want this
>                                                       project set up that way.
>
> **This is not finished.** Ten open questions came out of writing the docs, all
>        recorded at the bottom of the roadmap. Three of them I can't move past:

>                                                           **[Asked the user]**
>
>                                      *Q1 — Generation:* The project is named
> 3d-**generation**-multiplayer-server, but the vision never mentions procedural
>                                            generation. Is the world generated?
>      - Authored by hand — Worlds are written in the text geometry format and
>            edited directly. 'Generation' in the name means 3D generation as in
>        rendering — producing images. Simplest, and it makes the first room I
>                                wrote the real thing rather than a placeholder.
> - Generated from a seed — A generator emits the geometry format from a seed,
>   and the format stays hand-editable so a generated world can be tweaked. This
>     makes the generator a first-class subsystem and probably its own phase —
>                                                        the roadmap would grow.
>  - Authored, then grown — A person places the skeleton — rooms, landmarks,
>   the shape of the place — and a generator fills in the detail between them.
>    The format carries both literal geometry and 'grow something here' markers.
>  - The name is about the server — '3d-generation' means third-generation —
>          a third attempt or a third era of this idea, not procedural anything.
>      Changes nothing about the build; worth knowing so the docs stop guessing.
>     → **Answered:** doesn't matter at this point, just use the same map file
>  format that 3.3.5a uses and we're good to build whatever we want on it later.
>
>        *Q2 — Creatures:* Is anything in the world alive besides the players?
>        - Only players — The things you click are gathering nodes, doors, and
>      objects — nothing that moves on its own. This may remove the need for a
>    navigation mesh entirely, which would substantially shrink the hardest part
>                                                        of the custom-map work.
> - Creatures that stand still — Things that are alive and clickable but never
>        path anywhere — a whisp tending a spot, an object with a personality.
>    Still no navmesh needed, but the creature system stays alive in the server.
>   - Creatures that wander — Things that move on their own through the world.
>     Requires the navigation mesh, which means the collision-generation work in
>                                  phase 5 is load-bearing rather than optional.
>       - Not decided yet — Leave it open and build phases 1 through 4 without
>     needing the answer — nothing before the narrowing depends on it. Revisit
>                            when the world exists and it's clear what it wants.
> → **Answered:** we will build things slowly bit by bit, don't worry too much
>  about that. Assume that all the 3.3.5a functionality is requested eventually,
>          but we will only use some of it. I don't know what "some" yet though.
>
>  *Q3 — Git:* Nothing here is committed yet, and the shared repo has 18 files
>       staged from the backwards-reader work plus ~20 modified transcripts that
>                             aren't mine. How should I handle the first commit?
>  - Commit only my paths — Use a pathspec commit so only this project's files
>        land, leaving the backwards-reader staging and the modified transcripts
>          exactly as they are. Nothing of anyone else's is touched or unstaged.
>   - Hold off entirely — Leave everything uncommitted until you've sorted the
>    staging area yourself. The work sits on disk in the meantime; nothing is at
>                                                                          risk.
>   - Sort it all out first — I look at what the staged backwards-reader files
>   and modified transcripts belong to, report back on each group, and we decide
>                                         together before anything is committed.
> → **Answered:** commit only the lines you changed. If you edited a file that
>                       has someone else's changes, then only commit your lines.

>                           Both answers change the design. Let me fold them in.

>        Now the commit — only this project's paths, nothing of anyone else's.

>     Committed — 19 files, only this project's paths. The 18 backwards-reader
>               files staged by the earlier session are still staged, untouched.
>
>    **Your two answers reshaped the plan, both in the direction of less work:**
>
>    *Keeping the 3.3.5a map format* dissolved what had been the largest fork in
>          the roadmap. And it pays a dividend I didn't expect when I asked: the
>    collision file is already a triangle soup, and our renderer wants triangles
>   — so **both halves read the same files.** What you see is what you collide
> with, not by synchronisation but because there's no second copy to drift from.
>   Point the extractors at client data and phase 4 has a real world on day one:
> real maps, real collision, real pathfinding, drawn as untextured flat polygons
>                 in four schemes. Seeing a world now comes *before* making one.
>
>         *"All the functionality is requested eventually"* changed phase 5 from
>    amputation to selection. The server keeps everything; the game is what gets
>   granted and exposed. "No abilities" means nobody's handed one and there's no
>     button — not that the code is gone. That's reversible, it conflicts with
>  nothing upstream (a deletion is the most fragile patch there is — it fights
>    every refactor of the thing it deletes), and it doesn't require knowing the
>      final subset in advance, which is the actual state of the design. It also
>      dissolved the spell-system tension: gathering keeps working exactly as it
>                                                                    always did.
>
>   **One small deviation to flag:** I moved `vision` from the project root into
>           `notes/` before anything was tracked, so git only ever records it at
>     `notes/vision`. Nothing was lost — it had no history to preserve — but
>                             it's not the two-version trail your rule asks for.
>
> **Seven questions are still open** at the bottom of the roadmap. Six can wait.
>                                                                This one can't:

>                                                           **[Asked the user]**
>
> *Q1 — Client data:* The server won't start without extracted data tables and
>     map files, and phase 4's free-first-world depends on the same archives. Is
>                              there a copy of the 3.3.5a client data available?
>        - Yes, I have it — Then phase 1 can run all the way to a stock server
>   standing, and phase 4 has real maps to draw the moment the window opens. I'd
>                add an issue for the extraction run and where the output lives.
>    - Not yet, but I can get it — Work starts on the patch machine regardless
>    — issues 101 through 107 need no data at all. I'd sequence the extraction
>               as the last thing in phase 1 and note the dependency explicitly.
>   - No, and assume there won't be — This is a much bigger constraint than it
>    looks: without the data tables the server cannot boot at all, not just lack
>       maps. It would mean generating minimal substitutes as a phase-1 problem,
>                       which is real work and changes the roadmap's foundation.
> - Skip it — just start building — Begin the patch machine now and find out
>          about data when phase 1 reaches its last issue. Nothing in issues 101
>                                                        through 107 touches it.
>                                → **Selected:** No, and assume there won't be

>         That's a much bigger constraint than the other two, and it changes the
>                        foundation. Let me work through what it actually means.
>
>     The world server won't boot without the client-derived data tables — not
>    "lacks maps," *refuses to start*. But three things make this tractable, and
>                                the third makes it better than the alternative:

             Two commits in, backwards-reader's 18 staged files still untouched.

## What "no client data" actually costs, mechanically

The world server loads about a hundred fixed-layout binary tables at startup and
     **exits** if they're missing — this is a refusal, not a degradation. Each
       table is a 20-byte header (magic, record count, field count, record size,
string-block size), then fixed-size records where every field is 4 bytes, then a
      string block where text lives and string fields hold byte offsets into it.
                           That's the whole format. Writing one is an afternoon.

The question was never the format — it was the layouts. And they're already in
 the tree we clone: the server's loading code registers each table with a format
  descriptor giving the type of every column in order. **That descriptor is what
 will actually be applied to our bytes**, so it's authoritative in the strongest
   available sense. An extractor reads it at build time; nothing is transcribed.
       When upstream inserts a column, the generator has no value for it and the
          *build* stops naming the table — rather than the server starting and
                               misreading every field after the insertion point.

                                                  Three things shrank the phase:

       - **The world database was never client data.** Creatures, items, quests,
    spawns, starting positions all ship as SQL with the server source. We're not
      reconstructing a game — we're producing the tables and terrain grids the
                                   server reads before it agrees a world exists.
 - **The height format has a flag meaning "this tile is flat at height Z."** Set
          it and there's no grid to generate. A whole tile is a few dozen bytes.
  - **Line of sight, collision height, and pathfinding are each switchable off**
    in the server's own config. None is needed to stand on flat ground and walk.
  When collision does arrive, the navigation mesh is never written by us — the
  server's own tool builds it from height plus collision, so producing those two
    correctly is the entire job and the hardest-sounding artifact costs nothing.

   The trap worth knowing in advance: a localised string is not one column, it's
     sixteen language columns plus a flags column. Emit one and every subsequent
field shifts, and the server reads it without complaint. Defence is a round-trip
     check — generate, read back with the *same* extracted schema, compare —
        which is the patch verifier's assertion pointed at a different artifact.

## What changed in the documents

    Seven phases now. Phase 2 (login) moved ahead of the data problem, since the
    login daemon needs no tables at all — it's a complete piece of client that
       depends on none of this. New phase 3 is the fabrication. Everything after
                                                                        shifted.

   This is the third time a definition has been read out of the clone instead of
   copied into our tree — message numbers, cipher constants, now table layouts
     — so it's written up as `the-upstream-tree-is-the-schema`, sibling to the
       build-artifact strategem. One refuses to store a modified tree, the other
                                          refuses to store a transcribed format.

        Two flips are recorded rather than tidied away: the geometry format went
   authoritative → fixture → authoritative across three of your answers, and
   the protocol went from "thrown away at the end" to "extended, never replaced"
                           once *all functionality eventually* was on the table.

## Seven questions still open

   Pink versus multicolour · which camera · write the big-number arithmetic or
    link it · keep the shipped identifiers or invent our own · what the client
    does with a message it doesn't implement · how many people at once · which
                                                       upstream commit to track.

   Nothing blocks phase 1 — the patch machine touches none of them. Want me to
   keep working through the questions, or start writing the phase 1 issue files?

--------------------------------------------------------------------------------

### User Request 3

> The world server loads about a hundred fixed-layout binary tables at startup
> and exits if they're missing — this is a refusal, not a degradation. Each
> table is a 20-byte header (magic, record count, field count, record size,
> string-block size), then fixed-size records where every
> field is 4 bytes, then a string block where text lives and string fields hold
> byte offsets into it. That's the whole format. Writing one is an afternoon.

we should make an issue file about creating a patch for the src/ file that
handles that check. we should be able to route past it if we gate off the parts
that need it, while enabling the rest. for example, no map, no world, means no
need for character designs. We can add that stuff in later one by one. For now,
let's just getting it running and talking.

> - The world database was never client data. Creatures, items, quests, spawns,
> starting positions all ship as SQL with the server source. We're not
> reconstructing a game — we're producing the tables and terrain grids the
> server reads before it agrees a world exists.

we shouldn't need any of that SQL data either, except as a reference.

> and the protocol went from "thrown away at the end" to "extended, never
> replaced" once all functionality eventually was on the table.

I mean, I never said never... but a 3.3.5a client should be able to connect to
us and talk while in a blank featureless void. or whatever we manage to create,
ideally it'd be portable to there too. But we'd have a custom client before it's
considered "complete" or "ready" or "done".

  Pink versus multicolour

boy vs girl?

which camera

if it's my camera, it's a witch camera, thank you very much.

> write the big-number arithmetic or link it

write? link? oh yes number waves, right? it's here:
https://www.desmos.com/calculator/cxayticajg

basically it's this: y = {x > 2: -sin(pi*x/2) * 2

I think part of the multiplication is just for a visual effect, but the visual
effect is striking.

--------------------------------------------------------------------------------

### Assistant Response 3

>   Four separate things there, and three of them change the design. Let me take
>                                                                 them in order.
>
>    First the record — the wordplay goes in before anything gets built on it.

>   Now the issue file. It gets written before anything is touched, and it can't
>    name exact paths yet — the clone doesn't exist — so it describes how to
>                           find the check rather than asserting where it lives.

>      A transcript file appeared in the project that isn't mine — the session
>       tooling wrote it. Unstaging it, and adding the directory to the table of
>                                                  contents since it's now real.

 Three commits, backwards-reader's 18 still staged and untouched. The transcript
    directory is left untracked — it's the tooling's file, not mine to commit.

## The gating issue

    `issues/301-boot-the-server-with-no-data.md`. The finding that made it worth
   writing as its own thing: **an empty character list is reachable with nothing
                                                                loaded at all.**

```
client                                          world server
  │◀─── AUTH_CHALLENGE ──────────────────────────│   it started
  │──── AUTH_SESSION ───────────────────────────▶│   it is listening
  │◀─── AUTH_RESPONSE  accepted ─────────────────│   it knows who we are
  │──── CHAR_ENUM ──────────────────────────────▶│
  │◀─── CHAR_ENUM  (empty list) ─────────────────│   it is talking
```

 An empty list is the *correct* answer for an account with no characters — not
  a degraded one. None of that needs a map, a race table, a display, or a row of
 content. So "running and talking" is a real milestone reachable before a single
                                                                   table exists.

       The issue's actual deliverable is the inventory, not the patch: table →
   consuming subsystem → what breaks. The patch is small once that map exists.
Two things it insists on — check whether upstream already offers the switch as
configuration before writing any patch, since a setting upstream provides cannot
   conflict with upstream; and make every closed gate announce itself by name at
              every startup, because a configured absence that doesn't say so is
                    indistinguishable from a feature that silently doesn't work.

   Phase 3 is now **The Void That Boots**, and fabrication happens one gate at a
                                time after it rather than all at once before it.

## On the SQL

        Recorded as reference-only, and I drew the consequence explicitly: every
   identifier in our world is one we chose. The temptation there is real — the
     content is right there and it's free — but taking it would mean the first
 world that boots is somebody else's world with our geometry laid over it, and a
 hundred inherited decisions that might turn out to mean something a year in. It
             stays as documentation of how the tables relate, since it's a large
                                  internally-consistent example of exactly that.

## On the protocol

Corrected — I overstated "never replaced." What's recorded now: replacement is
  left open, and one property is held deliberately meanwhile. An original client
connecting to our void isn't sentiment; it's **the only oracle in the project we
   didn't also write.** A second implementation of the format, by people who had
   the specification, will disagree with us wherever we're wrong. The completion
  criterion stays the other direction: custom client before this is called done.

That raised a new open question — whether there's an original client *program*
 available to test that property against. Holding a property nobody can check is
  weaker than holding one we test. (The program, not the data; no data is needed
                                              to reach an empty character list.)

## The two declines

    Both got recorded verbatim in `spoken-while-building.md` before anything was
                                                                  built on them.

     **"boy vs girl?"** — read as naming the shape of the question rather than
  answering it. So pink stopped being one of two options and became the **centre
 of a hue range**: every creature sits somewhere inside it, none of them leaves.
      A centre and a drift — which is the same shape the arms already had. The
     design produced its own shape twice without being asked, and letting it was
                                                   cheaper than arguing with it.

  **"witch camera"** — all three rigs I offered were *mounts*, a camera bolted
     to an offset and dragged behind you. A witch camera flies. It's now another
   floating thing in a world of floating things: lags so acceleration is visible
rather than inferred, leans into turns and overshoots out of them, drifts on its
  own when you hold still so a stationary frame is never dead, rises with speed.
 The three rigs survive as extremes it can be tuned toward — overhead is stiff
         spring and high offset, over-the-shoulder is short offset and long lag.

## The wave

 It answered a question nobody had asked yet, and it landed somewhere real. Read
  as written: a wave that doesn't exist below a threshold, whose period and gate
are arranged so it's worth **exactly zero at the moment it's allowed to begin.**
  Period four, gate at two. Move the gate to one and it starts at full amplitude
                                                                    — a cliff.

     *Gate the wave where it crosses zero, and it emerges instead of appearing.*

    That's the whisp's arm, described before the arm was written down. The inner
    portion of every arm is exactly straight — not damped, straight — so the
 centre stays a findable point, which is what a player actually tracks. Past the
 gate it's free, and because the wave was zero at the seam there's no kink where
  they meet. It replaced the squared amplitude ramp I'd written, which only made
      the root *nearly* still. You're right that the doubling is visual; it's an
                                 amplitude and it lives in `balance-updates.md`.

 **One correction, because it changes what gets built:** the big-number question
    was a different kind of number. The login proves you know a password without
  sending one — the server stores a value derived from your password, and both
     sides raise a number to a huge power and take the remainder against a fixed
   32-byte prime, arriving at the same answer by different routes. Those numbers
           are wider than any register the CPU has, so somebody has to write the
    multiply-and-reduce loop over arrays of 32-bit words, or call a library that
   already has one. That's the open question: write that loop, or link it. Still
                                                                           live.

    Four questions open now: write-or-link the modular arithmetic · is there an
  original client program to test against · what the client does with a message
     it doesn't implement · how many people at once · which upstream commit to
                                                                          track.

--------------------------------------------------------------------------------

### User Request 4

On the protocol

> Corrected — I overstated "never replaced." What's recorded now: replacement
> is left open, and one property is held deliberately meanwhile. An original
> client connecting to our void isn't sentiment; it's the only oracle in the
> project we didn't also write. A second implementation of
> the format, by people who had the specification, will disagree with us
> wherever we're wrong. The completion criterion stays the other direction:
> custom client before this is called done.
>
> That raised a new open question — whether there's an original client program
> available to test that property against. Holding a property nobody can check
> is weaker than holding one we test. (The program, not the data; no data is
> needed to reach an empty character list.)


yes, but we want to distance ourselves from it. We would need very specific
reasons to examine the client. Much preferred is to examine the server, because
that is fully open source.

> "boy vs girl?" — read as naming the shape of the question rather than
> answering it. So pink stopped being one of two options and became the centre
> of a hue range: every creature sits somewhere inside it, none of them leaves.
> A centre and a drift — which is the same shape the arms
> already had. The design produced its own shape twice without being asked, and
> letting it was cheaper than arguing with it.
>
> "witch camera" — all three rigs I offered were mounts, a camera bolted to an
> offset and dragged behind you. A witch camera flies. It's now another floating
> thing in a world of floating things: lags so acceleration is visible rather
> than inferred, leans into turns and overshoots out
> of them, drifts on its own when you hold still so a stationary frame is never
> dead, rises with speed. The three rigs survive as extremes it can be tuned
> toward — overhead is stiff spring and high offset, over-the-shoulder is
> short offset and long lag.


teehee silly creature, I think you're building mountains out of molehills. Let's
focus on the details that matter.

> One correction, because it changes what gets built: the big-number question
> was a different kind of number. The login proves you know a password without
> sending one — the server stores a value derived from your password, and both
> sides raise a number to a huge power and take the
> remainder against a fixed 32-byte prime, arriving at the same answer by
> different routes. Those numbers are wider than any register the CPU has, so
> somebody has to write the multiply-and-reduce loop over arrays of 32-bit
> words, or call a library that already has one. That's the
>   open question: write that loop, or link it. Still live.


that's not necessarily true. Just sacrifice the ability to compute in one
operation, and you should be able to access as many registers as you need. Heck
you could use a single register for a single digit and you'd be fine. Just count
how many digits - oh, six billion? Good thing we can store six billion integers
between 0 and 9 in the entire computer. Then do mathematics on MANY registers at
once. Should be easy enough! also... why are we doing big number arithmetic?

> Four questions open now: write-or-link the modular arithmetic · is there an
> original client program to test against · what the client does with a message
> it doesn't implement · how many people at once · which upstream commit to
> track.
>
> · what the client does with a message it doesn't implement ·

um, nothing I guess?

 · how many people at once ·

like a bunch

· which upstream commit to track.

whichever

--------------------------------------------------------------------------------

### Assistant Response 4

> Fair — I was deriving design theses from one-liners. Trimming that back, and
>                                                         three questions close.
>
>      First, the client-as-oracle framing was wrong: the server source *is* the
>                                  second implementation, and it's the open one.

        Four commits. Net −109 lines this round, which is the right direction.

 **On the client** — you're right, and I'd reached past the obvious thing. The
   server *is* the second implementation: same protocol, other side, fully open,
   already in our tree. Any question about what a message means gets answered by
reading it. Compatibility stays a property of the format; we don't go looking at
                                     a client to confirm it. Question withdrawn.

        **On the registers** — correct, and my phrasing was bad. "Wider than a
  register" isn't an obstacle, it's just what multi-word arithmetic is: an array
           of words, carry propagating along it. One digit per word if you like.

**Why we're doing it at all** — that's the better question, and the answer is:
                                                           *maybe we shouldn't.*

   The login convinces the server we know a password without a password crossing
        the wire. The server stores a value derived from the password, never the
 password. Both sides raise a number to a power and take the remainder against a
     fixed 32-byte prime, arriving at the same value by different routes — the
                  server can check the answer, and can't reconstruct the secret.

    We need that only because we chose to speak the existing login format. **The
 login server is ours.** A patch could have it accept something trivial, and the
                                        client's arithmetic disappears entirely.

  What that costs: the client can no longer log into an *unpatched* server. That
 was the day-one baseline — a working end-to-end loop before any patch exists,
      so every later patch is checkable against something that already ran. That
baseline was worth more when real-client compatibility mattered. It's worth less
                                                                            now.

 It also runs exactly once per login, so nothing about it is a performance path.
                         That's the whole fork, and it's the last open question.

The three shrugs are recorded as answers: unknown messages dropped silently in a
       default table entry, no log and no counter; player count unsized, nothing
      threaded up front; upstream tracked at its default branch with the pruning
                                                   machine reporting what moved.

  Next is `301` — find where startup loads the tables, check whether any of it
   is already a config switch before writing a patch, and build the inventory of
table → subsystem → what breaks. Want me to start there, or settle the login
                                                                 question first?

--------------------------------------------------------------------------------

### User Request 5

why not just do both? what problem are you trying to solve?

--------------------------------------------------------------------------------

### Assistant Response 5

>       Nothing. I manufactured the fork — the machinery already assumed both.
>
> A profile *is* a named subset of the patch set. A simplified login is one more
> patch in one more profile; it doesn't compete with the client implementing the
>    proof properly. Keep both in the parts bin, pick per build. That's what the
>                profile table is for, and I'd written it two documents earlier.
>
>      The "cost" I described only existed if you picked one. Picking one was my
>                                                                     invention.

                             Open questions section is empty for the first time.

         **Where things actually stand:** phase 1 is the patch machine, and it's
 unblocked and unqueried — issues 101 through 108, from the gitignore wire and
  the unconditional reset through the standard patch shape, the orchestrator and
 its profile table, the build driver with its trap, the generators, the verifier
  gate, the pruning machine, and a login server standing on an unmodified build.

   `301` is written but can't be worked yet — it *is* a patch, so it needs the
                                    machine that applies patches to exist first.

    So the next thing is phase 1's issue files, then the machine itself. Say the
                                                       word and I'll write them.

--------------------------------------------------------------------------------

