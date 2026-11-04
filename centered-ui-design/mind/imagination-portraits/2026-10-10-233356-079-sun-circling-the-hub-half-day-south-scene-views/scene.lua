scene{ what = "a round land of grass and sand around a central console, three flat-topped clay mesas ahead, the sun low in the south behind the viewer lighting the mesas' near cliffs, while the villagers stand in night-blue" }
-- one world unit here is ten of the game's; the hub (the console) at the
-- origin, the seat being looked at straight ahead (-z), the sun circling
cylinder { name = "the land (the map's disc)", at = {0, 0.02, 0}, radius = 11.2, height = 0.04, color = "#8a9a50" }
cylinder { name = "the console over the hub", at = {0, 0.15, 0}, radius = 1.4, height = 0.3, color = "#9aa0a8" }
cylinder { name = "mesa ahead left", at = {-2.6, 0.3, -6.0}, radius = 1.6, height = 0.6, color = "#c8a060" }
cylinder { name = "mesa ahead right", at = {2.6, 0.4, -6.6}, radius = 1.8, height = 0.8, color = "#c8a060" }
cylinder { name = "mesa far right", at = {6.5, 0.25, -5.0}, radius = 1.0, height = 0.5, color = "#c8a060" }
cylinder { name = "the lake (west, out of the picture)", at = {-3.4, 0.03, 0.2}, radius = 1.1, height = 0.02, color = "#80b8e0" }
sphere   { name = "the sun, south, 35 degrees up", at = {0, 8.6, 12.3}, radius = 0.8, color = "#fff2c0", glow = true }
cylinder { name = "villager on the left mesa", at = {-2.4, 0.75, -6.0}, radius = 0.06, height = 0.3, color = "#1a2a6a" }
cylinder { name = "villager on the right mesa", at = {2.4, 0.95, -6.4}, radius = 0.06, height = 0.3, color = "#1a2a6a" }
cylinder { name = "villager in the lowland", at = {0.0, 0.15, -4.4}, radius = 0.06, height = 0.3, color = "#1a2a6a" }
box      { name = "the section's stacked cuboids", at = {0.0, 0.1, -4.2}, size = {0.3, 0.2, 0.1}, color = "#2a2018" }
