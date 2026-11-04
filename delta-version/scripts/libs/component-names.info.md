# component-names.lua

When two component names mean the same thing. Shared by `todone.lua`
(053b) and `todone-roadmap.lua` (053c), so the names in
`config/shared-components.conf` match the names todone reports.

```lua
local names = require("component-names")
names.key_of("Thread-Pool")                    --> "threadpool" (tier 1)
local synonyms = names.load_synonyms("config/component-synonyms.conf")
names.canonical("chat client", synonyms)       --> "llm client" (tier 2)
```

- **Tier 1, `key_of`:** a name is compared with case, spaces, `-` and `_`
  ignored.
- **Tier 2, `load_synonyms`:** reads lines of the form
  `name = alias, alias`. Each alias maps to the first name. A missing file
  gives an empty map.
