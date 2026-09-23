# 10-070: run.sh Menu — Missing Glyphs, a Hang on Leaving, and Copy to Clipboard

## Status
- **Phase**: 10 (Developer Tooling)
- **Priority**: High (the hang leaves a terminal stuck)
- **Type**: Bug fixes
- **Status**: BUILT 2026-09-23, confirmed by the owner
- **Created**: 2026-09-23
- **Related**: 10-016 (per-stage force options; added the `↳` labels),
  10-043 (dual-checkbox stage selection), 10-013 (TUI config editor)

## What the owner reported (2026-09-23)

> There's some emojis that aren't showing on my machine, before the "Force
> regenerate" text at the top. Also if the user pushes esc to exit, it runs
> away in an infinite loop, ignoring ctrl+c. It should quit immediately after
> the interactive page is closed. Also, the "copy to clipboard" functionality
> isn't working - it should go to both the ctrl+v clipboard, and the middle
> mouse-click clipboard.

## Background

`run.sh -I` builds its menu with the shared menu library in
`/home/ritz/programming/ai-stuff/scripts/libs/` (`lua-menu.sh` for the shell
side, `menu.lua` and `menu-runner.lua` for the screen, `tui.lua` for keys).
`menu_run` in `lua-menu.sh` starts the screen as
`result=$(luajit menu-runner.lua CONFIG)` and reads the answer ("run" or
"quit", plus the chosen values) from what the screen prints. Other projects
use the same library, so fixes 2 and 3 land in the library and help them too.

## Current Behavior

1. **Marker.** The ten per-stage options read `    └─ Force regenerate`
   (was `↳`, U+21B3, missing from the owner's terminal font). Owner:
   "The suggested marker seems fine to me."
2. **Hang after leaving the menu -- cause found and fixed.** The copy key
   (`~` on the command preview) started `xclip` for each selection. `xclip`
   stays running after a copy, to serve the text to whoever pastes, and it
   inherited the menu's standard output -- the pipe `menu_run` in
   `lua-menu.sh` reads the menu's answer from with `$(…)`. A `$(…)` waits for
   every holder of its pipe, so `run.sh` hung after the menu closed.
   Reproduced in a real menu session (2026-09-23, under `script`: open,
   `` ` `` then `k` to reach the command preview, `~`, `Q`): the menu process
   had exited, `run.sh` sat in a pipe read, and two `xclip` processes held the
   pipe. It also explains "the command didn't end up being copied": the
   copied text lived in those `xclip` processes, which belonged to the
   terminal's foreground process group, so the Ctrl+C or closed window used
   to escape the hang killed them and the copy with them.
   Fix (`copy_to_clipboard` in `scripts/libs/menu.lua`): each tool is started
   as `setsid TOOL < tmpfile >/dev/null 2>&1` -- its own session (Ctrl+C and
   closing the terminal no longer end it) and no hold on anyone's output.
   The same session now ends 0 s after `Q`, prints "Goodbye!", and both
   clipboards hold the command afterwards.
3. **Clipboard.** Both selections are written, as before: Ctrl+V
   (clipboard) and middle-click (primary), with `wl-copy`, `xclip` or `xsel`.
   What was broken was the hang above and the copy dying with it.
4. **Prompt loop.** `menu.batch_pause` now cancels on end of input (a nil
   key) and on Ctrl+C, instead of asking again forever.
5. **Escape quits from the command preview too.** Owner, after the fixes
   above (2026-09-23): "the escape key doesn't do anything now. But pushing q
   seems to quit without the infinite loop. It also correctly copies to
   middle-mouse click and ctrl+v's registers." Escape already quit from the
   main list, but on the command preview -- where the cursor is after the
   copy key -- it only left insert or arrow mode and did nothing in vim-nav.
   It now quits from vim-nav like `q`; from insert or arrow mode the first
   Escape returns to vim-nav (as in vim) and a second one quits. The help
   lines read `q/esc:quit`. Checked in a real session: Escape on the command
   preview quits at once; `i`, Escape, Escape quits on the second Escape.
6. **Box characters drew as garbage when highlighted or dimmed.** Owner
   (2026-09-23): "the new markers look great, but there's two problems. When
   the cursor highlights them, they return to the undiscipherable glyphs.
   Also, if we enable 'force regenerate all stages' they also become
   indecipherable." Cause: `tui.write_str` (`scripts/libs/tui.lua`) put one
   BYTE in each screen cell. `└` and `─` are three bytes; unstyled, the three
   cells went out back to back and the terminal reassembled them, but a
   highlighted (black on white) or disabled (dim) cell is sent with its own
   colour code in front, which cut each character into three broken bytes.
   `write_str` now puts one UTF-8 character in each cell. (None of the
   library's own drawing passes non-ASCII text, so only labels and other
   data are affected -- and they now also take the right number of columns.)
7. **Skip the per-stage force options while "force all" is on.** Owner:
   "when force regenerate is enabled, we can't change their values, so we
   should skip over their entry in the list. For example going from 1.
   Update Words directly to 2. Extract". Built as an opt-in per rule, because
   the menu deliberately lets the cursor land on a disabled item to show what
   is disabling it: `menu_add_dependency` takes a seventh argument `"skip"`,
   carried to the screen as `skip_when_disabled`; up/down movement
   (`menu.nav_up` / `menu.nav_down` in `menu.lua`) keeps stepping past items
   disabled by such a rule, and returns to where it started if that runs off
   the end. `run.sh` marks its ten per-stage force rules `"skip"`.
- Test: `scripts/libs/test-menu-screen.sh` drives a four-item stand-in menu
  in a pretend terminal (`script`, sized with `stty`), replays the recording
  with `scripts/libs/test-menu-screen-replay.lua`, and checks the highlighted
  `└─` option draws whole (no character cut by a colour code), that down
  passes over the disabled option to the next stage, and that the dimmed
  option still draws its box characters (4 checks). With the previous
  `tui.lua` the cut-character check fails. The same check against `run.sh`'s
  real menu: with force-all on, `j` `j` went Force ALL -> 1. Update Words ->
  2. Extract.
- Test: `scripts/libs/test-menu-clipboard.sh` -- a stand-in for the menu
  copies and exits, read through `$(…)` as `lua-menu.sh` does; it must return
  within two seconds and both selections must hold the text. Passes (45 ms);
  run against the previous `menu.lua` it fails at its 10-second guard with
  both selections empty. `menu.copy_to_clipboard` is exposed for it.

## Intended Behavior

1. The per-stage option labels draw in any terminal font the rest of the menu
   already needs (box-drawing characters), for example `    └─ Force
   regenerate`.
2. Leaving the menu by any route -- Escape, `q`, Ctrl+C, Run -- returns to
   `run.sh` at once, and `run.sh` exits (or runs) straight away, with the
   terminal in its normal state (Ctrl+C working).
3. The copy key puts the command in both clipboards -- Ctrl+V and
   middle-click -- and leaving the menu afterwards is instant.

## Suggested Implementation Steps

1. `run.sh`: replace `↳` in the ten per-stage labels with `└─`.
2. `menu.lua` `copy_to_clipboard`: start every clipboard tool with its input
   from the temp file and its standard output and error sent to `/dev/null`
   (`xclip -selection X -i FILE >/dev/null 2>&1`, likewise `xsel` and
   `wl-copy`), so the background process cannot hold the screen's output
   pipe. Check both selections afterwards with `xclip -o -selection …` and
   report failure in the status line.
3. `menu.lua` `menu.batch_pause`: return nil (cancel) on a nil key and on
   `CTRL_C`, like the main loop does.
4. Test (in the library's test script): a stand-in for the screen that copies
   with `copy_to_clipboard` and exits must return through `$(…)` within a
   second; both selections must then hold the text. Needs X11; skip with a
   message (not silently) when `DISPLAY` is unset.
5. By hand: `run.sh -I`, copy the command, press Escape -- the shell prompt
   returns at once; paste with Ctrl+V and with a middle click.

## Open Questions

1. **Answered.** Had the owner pressed the copy key before Escape ran away?
   Owner (2026-09-23): "Nope the command didn't end up being copied." After
   the clipboard fix the owner found no more runaway ("pushing q seems to
   quit without the infinite loop"), which fits the clipboard hang as the
   cause; the remaining Escape complaint is item 5.
2. **Answered.** `└─` for the per-stage labels: "The suggested marker seems
   fine to me."
