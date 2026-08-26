# 002 — The notation

Read this before `010`. Every blueprint in `src/` is written in the form below,
and the form is strict because a program reads it.

## Why a blueprint is not prose

A hardware specification decays in a particular way. Somebody writes *the cube is
sixty millimetres on a side* in four documents. Then the heat budget grows, the
face gets thicker, and one of those four is edited. Nothing complains. The
drawing in the third document is now wrong and will stay wrong until a machinist
cuts metal to it.

So in this project a dimension is **written once, as a named symbol, in exactly
one blueprint**, and every other use of it is a reference. A symbol is either
*given* — a number a person chose — or *derived*, in which case it is an
expression over other symbols and has no number of its own at all. There are
eleven given lengths in the entire machine. Everything else follows from them,
and if you change one, `104` will tell you what broke.

## The shape of a blueprint file

    src/NNN-short-name.md

    # NNN — Title in words

    [prose: what this part is, why it is shaped this way, what it is made of]

    ## Drawing            (one or more; ASCII, dimensioned)

    ## Symbols            (a fenced block, tagged `symbols`)

    ## Constraints        (a fenced block, tagged `constraints`)

    [prose: what is still open about this part]

Every blueprint opens with a fenced `meta` block before anything else:

    ```meta
    phase  | 3
    issues | 303, 307
    ```

`phase` is which of the fourteen it belongs to. `issues` names every ticket that
describes work on this file — usually one, sometimes more, because a dimension
belongs in one file no matter how many tickets discuss it.

## Symbols

A fenced block tagged `symbols`. One declaration per line, five fields separated
by a vertical bar. Blank lines and lines beginning with `#` are ignored.

    name | unit | kind | value or expression | meaning

```symbols
L_cube    | mm | given   | 60                | outer edge length of the finished cube
t_face    | mm | given   | 7.0               | face assembly, outward surface to inward surface
L_cavity  | mm | derived | L_cube - 2*t_face | edge length of the space the six faces enclose
```

**The name** is unique across the whole project, not just the file. `103` refuses
to load a project where two blueprints declare the same name, because the second
one is either a duplicate or a disagreement and both are worth stopping for.

Names carry their meaning in a prefix, by convention rather than by rule:

| prefix | quantity | prefix | quantity |
|---|---|---|---|
| `L_` `w_` `h_` `t_` `d_` `r_` | length | `P_` | power |
| `A_` | area | `Q_` | heat flow |
| `V_` | volume, or voltage where `U_` would be worse | `T_` | temperature |
| `n_` `N_` | a count | `dT_` | a temperature difference |
| `f_` | frequency | `R_` | resistance, thermal or electrical |
| `v_` | velocity | `B_` | bandwidth |
| `m_` | mass, or mass flow as `mdot_` | `C_` | capacity or capacitance |
| `p_` | pressure | `k_` | thermal conductivity |
| `rho_` | density | `eta_` | an efficiency or a fraction |

**The unit** is written in ASCII: `mm`, `W/(m*K)`, `kg/m^3`, `1` for
dimensionless. `100` parses it into a dimension vector with ten slots — the seven
SI base dimensions plus **bit**, **tok** and **flop** — so that bandwidth in
bit/s and clock frequency in Hz are different types even though both are
one-over-seconds, and adding them fails rather than producing a number nobody
questions.

**The kind** is one of four:

| kind | what it means |
|---|---|
| `given` | a person chose this. The fourth field is a bare number. |
| `derived` | computed. The fourth field is an expression and there is no number. |
| `measured` | a material property or a vendor figure. Bare number; the meaning field must say where it came from. |
| `target` | a goal with no derivation yet. `104` counts these and lists them; a blueprint set with targets left in it is not finished. |

The difference between `given` and `measured` is who you argue with when it turns
out to be wrong. A `given` is a decision and can be changed by deciding
differently. A `measured` is the world, and changing it means changing material.

**The value or expression.** For `given` and `measured`, a bare decimal number,
interpreted in the declared unit. For `derived`, an expression.

**The meaning** is one line of English. It appears in the companion page, in the
site, and in the specification report, so it is the sentence an engineer reads
when they meet this symbol somewhere else and do not know what it is.

## Expressions

Infix, with the usual precedence. `+ - * / ^`, unary minus, parentheses. The
functions `sqrt abs min max log ln exp floor ceil round sin cos tan atan`, and
the constant `pi`.

**Every literal number in an expression is dimensionless.** This is the rule that
makes the notation worth having. If you need twenty kelvin, you may not write
`T_amb + 20` — you declare `dT_rise | K | given | 20 | the design coolant
temperature rise across the cube` and write `T_amb + dT_rise`. There is no way to
put an unnamed physical quantity into this project. The cost is a few more
declarations; the return is that `106` can print every number in the machine with
its name and its reason next to it.

Dimensionless literals that *are* genuinely pure — a factor of two because
something has two sides, a four because a duct has four walls — are written
directly, and that is the only thing a bare number ever is.

## Constraints

A fenced block tagged `constraints`. Three fields.

    tag | relation | why it must hold

```constraints
C-013-1 | L_cavity >= L_stack + 2*g_plenum | the core must fit inside the cavity with clearance for the radial fabric
C-013-2 | t_face >= t_die + t_interposer + t_coldplate | the face stack cannot be thicker than the space allotted to it
```

The tag is `C-` then the blueprint number then a serial. Relations may use
`<= >= < > == ~=`. `==` compares exactly and is only correct for integers and
counts. `~=` means *agrees within one part in a thousand* and is what you use for
anything computed two ways, which is the most valuable kind of constraint in the
set: it catches the case where two blueprints each derived the same quantity by a
different route and got different answers.

Both sides are dimension-checked before they are compared. A constraint whose
sides have different dimensions is a failure, not a false result, and `104`
reports it separately because it means somebody wrote nonsense rather than
somebody's design being too tight.

## Drawings

ASCII, in a fenced block tagged `drawing`, with a caption line immediately after
the fence:

    ```drawing
    a face assembly in section, looking along +x
    ...
    ```

Every dimension called out in a drawing is written as its symbol name in
brackets, never as a number:

        ├────────────── [L_cube] ──────────────┤

`107` reads every drawing, pulls out every bracketed name, and fails if one of
them is not a symbol that exists. That check is the only thing standing between
this project and a drawing that says `60` after the cube has become sixty-four.

## The companion pages

Each `src/NNN-name.md` has a `src/NNN-name.info.md` beside it. **Do not edit
them.** They are written by `105` from the blueprint's own declarations, and they
hold what the blueprint publishes, what it consumes and from where, what consumes
it, and which constraints mention it. Change the blueprint and run the sweep.

## Running the checks

    ./run-checks

Loads every blueprint, resolves every symbol, evaluates every constraint, and
prints a line per failure with the two sides evaluated so you can see how far off
it is. It also reports cycles, undefined references, duplicate names, dimension
mismatches, orphan symbols nothing uses, and the count of `target` kinds still
outstanding.

It writes nothing except to `tmp/shared-memory/`. There is no state.
