# lobby_ui.lua

The multiplayer screens (issue 801e): the game browser, the create-game
dialog and the lobby, over a connection of the matchmaking client library
(`matchmaking/client.lua`). Built like the in-game interface
(`ui/wc3/hud.lua`): `lobby_ui.new(conn, options)` keeps the screens'
state, **`s:update(input, dt)`** takes a frame's input (the HUD's shape:
`mx`, `my`, `lp`, `keys`, `chars`, `ctrl`, `shift`, `wheel`, and `w`, `h`
on a resize) and **`s:draw(ui)`** draws through the `render.ui_*` calls
(`ui_rect`, `ui_frame`, `ui_text`, `ui_text_width`), so it runs headless
with a recorder.

**Options** over `lobby_ui.DEFAULTS`: `w`, `h`, `name` (joined and hosted
under), `toast_seconds` (4), `chat_keep` (200 lines), `regions`, `modes`,
`maps` (for the filters and the create dialog), `clock`, `on_back` (what
the browser's back arrow and Escape do; without it they do nothing).

**State:** `s.screen` ("browser", "create", "lobby", "started"), `s.busy`
(what it waits for: "Finding games", "Joining", "Creating game"),
`s.toasts`, `s.games`, `s.filter`, `s.selected`, `s.lobby`, `s.chat`,
`s.chat_input`, `s.started` (the host's address once the game began).

**Actions** (each also a button): `refresh`, `set_filter(key, value)` /
`next_filter(key)` (region, free_slots, game_mode), `join(i)`,
`open_create`, `create(game)` (or from the dialog), `toggle_ready`,
`send_chat`, `start` (the host, when every other player is ready),
`cancel_start`, `kick(player_id)`, `leave`, `set_ping(game_id, ms)`.
Views: `rows()`, `player_rows()`, `can_start()`, `layout()` (every
rectangle and button for the window's size), `lobby_ui.latency_colour(ms)`
(green under 50 ms, yellow under 100, red from 100),
`lobby_ui.fit(ui, text, size, width)`.

**Keys:** browser: Up/Down, Enter joins, F5 looks again, Escape is
`on_back`; create: Enter creates, Escape cancels; lobby: typing goes to the
chat line, Enter sends it (or, with nothing typed, presses the button in
focus), Backspace, Ctrl+R toggles ready, Page Up/Down and the wheel scroll
the chat, Escape leaves. Tab and Shift+Tab move the focus between the
buttons that work; Space presses it outside the lobby. A click presses a
button and leaves the focus to the keyboard.

Errors and refusals (a refused join, a call the library refuses, a lost
connection, a kick, a closed lobby) become toasts; the screens never
raise from a network failure. Each game's ping shows "-" until something
measures it (`set_ping`); the header shows the round trip to the
matchmaking server.
