<!-- made by scripts/build-info-pages from the comments in 020-headless.lua; change the comments and rebuild, not this page -->
# 020-headless


Runs a match, a battle or a duel with no window, as fast as the processor
allows, and ends the way every run ends: with the receipt. The player's
soldier is driven by its own mind, so a headless battle is a whole battle.

Scripted key and mouse events need the window's handlers; a headless run
given one stops and says so rather than silently ignoring it.

Run as a program (luajit src/020-headless.lua DIR [options]) it finds its
neighbours by its own path; required as a module, the caller has already
set the module path.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.perk_choices` | `names` | The perks of --perk, as the battle takes them: the player chooses to be affected, so a converting perk given on the command line shows on the player's own soldier. |
| `M.mods` | `config, opts` | The mods a run lays over the catalogue: the configuration's, then --mod. |
| `M.run` | `dir, argv` | Returns the run summary it wrote into the receipt. |
| `M.report` | `run` | (no comment in the source) |

## Tables of rows

| Name | What it is |
| --- | --- |
| `MODES` | Each mode: how to make it, tick it, tell when it is over, and read it. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `duel_config` | `config` | A duel is a battle of one battalion of one soldier a side. |
| `battle_make` | `config, catalogue, opts` | (no comment in the source) |
| `battle_read` | `b` | Outcome 0 is a draw at the time limit; false is a battle stopped early. |
| `check_script` | `script` | (no comment in the source) |
