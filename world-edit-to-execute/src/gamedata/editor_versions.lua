--[[
editor_versions.lua - which game patch a map's editor version belongs to

A map's war3map.w3i records the World Editor build that last saved it
(e.g. 6052). This table says which patch layer (src/gamedata/patch_layer.lua)
that build shipped with, so a map loads with the stock values it was made
against.

Only entries backed by evidence belong here, each with where the evidence
came from. A map whose editor version isn't listed loads with the newest
layer available and a counted warning (src/gamedata/chain.lua).

Seen in the maps in assets/ (2026-09-24): 6052, 6057, 6059, 6060. None is
confirmed yet; see the open question in issues/112b-game-version-layers-per-map.md.

Format:  [editor_version] = { layer = "1.21b", evidence = "how we know" }
]]

return {
}
