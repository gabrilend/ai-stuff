<!-- made by scripts/build-info-pages from the comments in 001-config.def.lua; change the comments and rebuild, not this page -->
# 001-config.def


The default of every knob in the game, laid out the way dwm's config.def.h
is: one knob per line, aligned, with a short comment saying what the number
means and in what unit. To change a knob, write config.lua at the project
root returning a table of the same shape holding only the knobs to change;
002-util.lua lays it over these and stops on any name these do not have.

Every change to a default is written down in docs/balance-updates.md with
the reason, so the record of how the numbers moved is never lost.
