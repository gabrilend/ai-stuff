# lobby.lua

The game's side of shared lists (issue 609c), without drawing anything.
It polls rmail, shows one dialog at a time, takes the player's answer,
and puts an applied list on the asset loader for this game only.
`ui/wc3/share_prompt.lua` draws the dialogs over the HUD.

| Function | Takes | Gives |
|----------|-------|-------|
| `lobby.new(opts)` | `data`, `connection` (rmail_hook's `C`) or `transport`, `loader`, `me`, `pack`, `poll_every` | a lobby; first settles what an earlier game left applied (`Lb.settled`) |
| `Lb:update(dt)` | seconds | polls rmail every `poll_every` seconds (the first at once); the poll's events |
| `Lb:dialog()` | | the dialog to show now, or nil |
| `Lb:press(d, id)` | a dialog, a button's id | what came of it |
| `Lb:keep(id[, name])` | a question's id | keeps that list as an asset pack after the game (written down at once) |
| `Lb:end_game()` | | each list taken off, or made an asset pack if kept |
| `lobby.settle(data)` | the player data folder | what an earlier game left: kept (if asked) or reverted |

The three kinds of dialog, in the order they are shown:

| Kind | When | Buttons |
|------|------|---------|
| `question` | a list arrived from someone not trusted | Yes, No, Always from <sender>, Always for this map |
| `ready` | a list was applied | Keep them after the game, OK |
| `notice` | a refusal, a failed poll, rmail without the hooks, or what was kept last time | OK |

"Always from" and "Always for this map" are remembered in
`<data>/share-trust.lua` (`profile.trust`), and they also answer yes.
A kept list is noted in `<data>/profiles/<name>.keep`, so it is kept even
when the game ends without saying so.
