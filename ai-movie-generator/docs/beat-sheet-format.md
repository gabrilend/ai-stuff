# The beat sheet — format

What the ear hears, written down. A Lua file returning one table.

```lua
return {
  source   = "input/battle-theme.ogg",
  seconds  = 184.2,          -- number: total length
  rate     = 50,             -- integer: envelope samples per second
  envelope = { 0.01, 0.02, ... },  -- numbers 0..1, loudness every 1/rate s
  onsets   = { {at = 0.48, strength = 0.9}, ... },  -- sharp attacks
  sections = { {from = 0.0, to = 31.5, energy = 0.22, label = "quiet"},
               {from = 31.5, to = 70.0, energy = 0.71, label = "driving"}, ... },
  tempo    = 128.0,          -- number or false: beats per minute if steady
}
```

| field | type | meaning |
|---|---|---|
| envelope | list of numbers 0–1 | root-mean-square loudness per window, normalised to the loudest window |
| onsets | list of {at: seconds, strength: 0–1} | moments the loudness jumps faster than its recent average — candidate cut points |
| sections | list of {from, to, energy, label} | long stretches of similar energy; the writers' room plots one arc waypoint per section |
| tempo | number or `false` | estimated from the spacing of onsets; `false` when no steady pulse is found (ambient, speech, noise) — never a guess |

Labels are words chosen from energy (silent, quiet, steady, driving, peak),
so a language model can read them.
