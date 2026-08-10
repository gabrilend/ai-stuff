#!/usr/bin/env bash
# P001-laptop-binds.sh
#
# TARGET:   binds-laptop.cfg :: whole file (created, not edited)
# SYMPTOM:  Xonotic ships one keyboard layout. It assumes a mouse does the
#           aiming, so it puts every movement key under the left hand and
#           leaves the right hand holding a mouse. With no mouse present the
#           right hand has nothing to rest on, and the two strongest digits on
#           that hand -- thumb and little finger -- do no work at all.
# CHANGE:   Add a second layout, alongside the stock one and never replacing
#           it, in which both hands rest and all ten digits have a job. Every
#           action it needs is a command the engine already ships, so this
#           change introduces no code whatsoever -- it is a list of keys.
# ANCHOR:   the target path itself; this patch creates a file rather than
#           editing one, so its "anchor" is the absence of that file upstream
# WITNESS:  the file exists
# MATCHES:  0            # upstream must NOT already ship this path

# {{{ _P001_target()
# Single definition of the path, so the three functions below cannot disagree
# about which file they are talking about.
_P001_target() {
    echo "${SRC_DATA}/binds-laptop.cfg"
}
# }}}

# {{{ patch_P001_laptop_binds()
patch_P001_laptop_binds() {
    local FILE
    FILE="$(_P001_target)"

    # The guard that makes re-running inert. Applying twice must equal applying
    # once, and the cheapest way to guarantee that for a file-creating patch is
    # to refuse when the file is already there.
    [[ -e "${FILE}" ]] && return 0

    # No "unbind" lines are needed. Every key this layout claims is given a new
    # command on the line that claims it, and binding a key replaces whatever it
    # held before. Adding unbinds would be noise that implies a subtlety that is
    # not there.
    cat > "${FILE}" <<'LAPTOP_BINDS_EOF'
// binds-laptop.cfg
//
// A keyboard layout for playing without a mouse.
//
// The stock layout puts movement under the left hand and aiming under a mouse.
// Take the mouse away and the right hand has nowhere to rest: it reaches for
// the arrow cluster in the far corner, which leaves the thumb over the edge of
// the deck and puts the little finger to work stretching rather than pressing.
// Two of the hand's strongest and most independent digits go idle exactly when
// the hand needs the most from them.
//
// This layout is mirrored instead. Each hand's middle finger rocks between two
// rows to own one axis; the index and ring fingers flank it with the other; the
// little fingers take the two floor actions; the thumb takes the trigger.
//
//         [e]                                  [i]
//     [a][s][d][f]                  [h] [j] [k] [l] [;]
//
//                     [ space ]
//
// Left hand owns the body's sideways motion and the view's vertical motion.
// Right hand owns the body's forward motion and the view's horizontal motion.
//
// Nothing here is loaded by default. Xonotic's own layout is untouched.

// ---------------------------------------------------------------- left hand
bind a +crouch            // little finger, resting
bind s +moveleft          // ring finger
bind d +lookdown          // middle finger, home row
bind e +lookup            // middle finger, one row up
bind f +moveright         // index finger

// --------------------------------------------------------------- right hand
bind h +left              // index finger, reaching one key left
bind i +forward           // middle finger, one row up
bind k +back              // middle finger, home row
bind l +right             // ring finger
bind SEMICOLON +jump      // little finger, resting
//
// The engine calls that key SEMICOLON rather than accepting the character
// itself, because a bare semicolon is how the console separates one command
// from the next. Written literally it would end the line early.

// -------------------------------------------------------------------- thumb
bind SPACE +fire

// `j` is left deliberately unbound. It is the right index finger's home key,
// which makes it the easiest key on that hand to catch by accident while
// rocking between the turn keys and the movement keys. A slip there should
// cost nothing.

// ------------------------------------------------------------ what was lost
// Seven keys had other jobs in the stock layout. Three are ordinary reshuffles
// -- strafe and walk-backward simply moved elsewhere in this file. Four
// commands lost their only keyboard home and are listed here so the loss is
// deliberate rather than discovered later:
//
//     +hook          was `e`   -- the grappling hook. Also on a mouse button,
//                                 which is exactly the thing this layout
//                                 assumes you do not have. A real loss in the
//                                 game modes that use it.
//     +use           was `f`
//     +show_info     was `i`
//     kill           was `k`   -- suicide. Deliberately left unbound here.
//
// That last one is the important one. In the stock layout `k` kills you on a
// single press. In this layout `k` is the key you walk backward with, held for
// whole seconds at a time, so the stock binding cannot survive. The decided
// resolution is that suicide should fire on three presses in a row -- the key
// keeps its meaning and gains a cost proportional to how much you ought to
// have to mean it.
//
// Recognizing three presses requires press timing, which the engine does not
// currently keep for any key, and which is built in a later phase alongside the
// other tap gestures. Until that exists, suicide stays unbound: it is the only
// option here that cannot kill a player by accident.
LAPTOP_BINDS_EOF
}
# }}}

# {{{ unpatch_P001_laptop_binds()
unpatch_P001_laptop_binds() {
    local FILE
    FILE="$(_P001_target)"

    # The exact inverse of creating a file is removing it. The guard makes a
    # repeated revert inert, and keeps this from reporting work it did not do.
    [[ -e "${FILE}" ]] || return 0
    rm -f "${FILE}"
}
# }}}

# {{{ patch_needs_applying_P001()
# The witness probe. For a file-creating patch the witness is simply presence,
# so the probe and the inverse cannot disagree about what "applied" means.
patch_needs_applying_P001() {
    local FILE
    FILE="$(_P001_target)"
    [[ ! -e "${FILE}" ]]
}
# }}}
