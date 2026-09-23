# 10-070: run.sh Menu — Missing Glyphs, a Hang on Leaving, and Copy to Clipboard

## Status
- **Phase**: 10 (Developer Tooling)
- **Priority**: High (the hang leaves a terminal stuck)
- **Type**: Bug fixes
- **Status**: OPEN — investigated, not built
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

1. **Missing glyphs.** Each per-stage option in the Pipeline Stages section is
   labelled `    ↳ Force regenerate` (`run.sh`, the `menu_add_item` calls
   for `force_update_words` … `force_generate_html`). `↳` is U+21B3 (a
   down-then-right arrow). The menu library draws no emoji of its own, so
   this is the only unusual character there, and the owner's terminal font
   has no drawing for it.
2. **Hang after leaving the menu — cause found.** The copy key (`~` on the
   command preview) runs `copy_to_clipboard` in `menu.lua`, which starts
   `xclip -selection primary` and `xclip -selection clipboard` (X11 here:
   `DISPLAY=:0`, no Wayland, `xclip` installed, no `wl-copy` or `xsel`).
   `xclip` keeps running in the background after the copy, to hand the
   text to whoever pastes, and it inherits the screen's standard output --
   which is the pipe `$(…)` in `menu_run` is reading. A `$(…)` capture
   waits until every holder of its pipe closes it, so after a copy, leaving
   the menu (Escape, `q`, Run) leaves `run.sh` waiting until something else
   takes over the clipboard. Reproduced 2026-09-23 without the screen:
   `x=$(timeout 8 luajit -e 'os.execute("echo t | xclip -selection clipboard 2>/dev/null")')`
   returned only after 38 seconds, when the stray `xclip` was killed by
   hand; `timeout` had ended the Lua process at 8 seconds.
   A second, unconfirmed way to spin: the key loop in `menu.batch_pause` near the
   end of `menu.lua` ("Wait for valid key") calls `tui.read_key()` in a
   `while true` and never handles a nil key (end of input), so with the
   terminal gone it would loop without pause; it also does not treat
   Ctrl+C as a key.
3. **Copy to clipboard.** The code already tries both clipboards (primary for
   middle-click, clipboard for Ctrl+V). With the pipe problem above, the copy
   reaches the clipboard, but the menu's run hangs on exit, and a stray
   `xclip` holding the pipe is what the owner then kills or waits out; with
   `2>/dev/null` only, `xclip`'s standard output is not redirected.

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

1. Which screen was open when Escape ran away -- the main list, the command
   preview, or a prompt (a yes/no question at the bottom)? The clipboard hang
   needs a copy first; if the owner had not copied, the prompt loop (Current
   Behavior 2, second part) is the likelier cause.
2. `└─` for the per-stage labels, or another marker?
