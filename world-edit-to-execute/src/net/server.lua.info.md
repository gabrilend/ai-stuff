# server.lua

The server's side of play (issue 803): the one true simulation, advanced
62.5 ticks a second, and the rules for talking to its players. Plain logic:
no threads, sockets or clock of its own.

- **`server.new(sim, players, send, now_ms) -> server`:** `players` (`int`,
  ids 0 .. players-1); `send(player, bytes)` delivers one message; `sim`
  plugs in the game:
  - `sim.order(player, order, tick) -> accepted (bool), refusal (int)`;
  - `sim.tick(tick) -> events` (list of `{kind, tick, unit, other}`);
  - `sim.visible(player) -> unit records`;
  - optionally `sim.allied(a, b) -> bool`: whether player b sees player
    a's pings. Without it a ping goes back to its own player only.
- **`server:receive(player, bytes, now_ms)`:** one message from a player.
  Takes `heard`, `order`, `tolerance`, `drop_vote` and `ping`; any other message,
  or bytes that don't decode, are recorded in `server.refused` (`{player,
  why}`) and don't count as hearing from the player.
- **`server:step(now_ms)`:** brings the game up to that moment. If a player
  has been silent longer than the tolerance in force, the game pauses (or
  stays paused) and the waiting news goes out every 100 ms; otherwise it
  resumes from the tick it paused on and runs every tick now due, sending
  each player their states and the tick's events.
- **`server:tolerance_in_force()`:** the lowest slider of the players in
  the game.
- **`server.votes_needed(connected) -> int`:** three quarters of the
  connected players, rounded down, and at least one.
- **The numbers:** `TICK_MS` 16, `TOLERANCE_START_MS` 2000,
  `TOLERANCE_LEAST_MS` 250, `TOLERANCE_MOST_MS` 10000, `COUNTDOWN_MS` 30000,
  `WAITING_EVERY_MS` 100, `PING_EVERY_MS` 250. Changes go in `docs/balance-updates.md`.
- **Pings (issue 507f):** a `ping` is sent at once, as `pinged` with the
  current tick, to the pinger and every connected ally, also while paused.
  One sooner than `PING_EVERY_MS` after that player's last, or at a point
  that isn't a finite number, is refused.
- **Per player:** `heard_ms`, `tolerance_ms`, `dropped` (bool), `last_ping_ms`, and
  `silent_since_ms` while their silence is part of a pause.
