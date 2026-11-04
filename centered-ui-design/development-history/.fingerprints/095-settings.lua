-- game-settings.lua - the settings the program reads before anything else.
--
-- Written by hand (Claude Opus 5.5, 2026-10-10, for issue 101 and the first
-- renderer slice). Every field is required: the reader stops the program
-- with the field's name if one is missing or the wrong kind, rather than
-- guessing. Change numbers here to change how the program starts.

return {
    -- the seed every generated thing grows from (whole number)
    seed = 20261010,

    -- the window, in screen pixels (whole numbers)
    window_width = 1600,
    window_height = 1000,

    -- the starting framerate cap, 0 to 240 frames per second; 0 means no cap.
    -- The player changes it in the settings menu (Escape).
    max_framerate = 144,

    -- how many units walk the map, and how many of the ceramic engine's worker
    -- threads take their chunks of work, first come, first served
    unit_count = 192,
    worker_count = 6,

    -- how many cuboids lie about for the units to carry to their sections
    cuboid_count = 96,

    -- the far camera: how far away it sits (world units), how many world units
    -- it shows from the screen's center to its top edge at the map's center
    -- (the zoom), and how steeply it looks down (degrees above the ground)
    camera_distance = 10000000,
    view_half_height = 78,
    camera_elevation_degrees = 62,

    -- the depth band the scene is drawn within, either side of the map's center
    -- (world units), and how far toward the camera from the map's center the
    -- dashboard's view plane hangs (must be inside the band, above everything)
    depth_half_range = 400,
    view_plane_distance = 300,

    -- the sphere projection: tiers drawn, how strongly the outer tiers fold
    -- toward the edge (0 = evenly spaced), the hub's radius under the dashboard
    -- and the map's outer radius (world units)
    tiers_shown = 6,
    fold_strength = 0.7,
    hub_radius = 14,
    edge_radius = 112,

    -- the team: how many allies (1 to 4) share the hub, and which seat this
    -- player holds. The console is one arch per ally (an M); you see your
    -- own arch whole and your neighbours' feet beside it.
    team_size = 4,
    seat = 1,

    -- how many seconds of game time make one calendar day (the light dials
    -- turn once a day)
    calendar_seconds_per_day = 24,

    -- the console: an arch standing on the window's bottom edge and stretched
    -- to both sides; its height as a share of the window's height
    arch_height_share = 0.2,

    -- How the world is filmed, to compare (all can be switched in the
    -- settings menu while running):
    --   view_depth     "flat": the far camera, nearly flat, like a map;
    --                  "hub": a camera just above the hub looking out over
    --                  one quadrant at a time (the scroll wheel turns it);
    --                  "slant": the hub at the screen's bottom behind the
    --                  console, the quadrant running up to the map's edge
    --                  at the top, everything the same size near and far;
    --                  "arch": the tier rings drawn as copies of the
    --                  console's arch grown outward from it, the hub on the
    --                  arch itself, everything the same size near and far
    --   view_standing  "upright": figures stand straight up on their ground;
    --                  "outward": they lean away from the hub
    --   view_blur      "on": a sharp band of distance, blurring nearer and
    --                  farther (tilt-shift); "off": none
    view_depth = "arch",
    view_standing = "upright",
    view_blur = "off",

    -- the hub camera: how high its eye stands (world units), how steeply it
    -- looks down (degrees below level), and how wide it sees (degrees, top
    -- to bottom of the window)
    hub_eye_height = 34,
    hub_look_down_degrees = 30,
    hub_field_of_view_degrees = 55,

    -- the slant view: how far out from the hub (world units) the top of the
    -- screen reaches; the hub is at the bottom. The map's edge is
    -- edge_radius, so a little more shows all of it.
    slant_reach = 120,

    -- the world is a sphere: our hub is one pole, and the foes' kingdom
    -- across from it is the other, this many tiers out (past the tiers
    -- shown). Laps around the hub are shortest near either pole, so walkers
    -- far out cross the map's wide outer rings fast from side to side.
    far_pole_tier = 7,

    -- the arch view: how far out from the hub (world units) the top of the
    -- screen reaches above the arch's apex; the hub lies on the arch itself
    arch_reach = 112,
    -- how many degrees of the world one arch shows foot to foot: 90 is just
    -- this seat's quadrant; past 360 the circle runs on past itself (a
    -- "magic circle"), the far side of the world showing at both ends
    arch_span_degrees = 450,

    -- under the arch view, how much a villager turns to face its path on
    -- screen: 0 faces its way on the ground (looks like walking left and
    -- right), 1 follows the ring's curve (back to the camera walking toward
    -- the middle, facing it walking toward the sides); between or beyond
    -- to compare
    figure_facing_follow = 1.5,

    -- the land: "dots", its points drawn as round sprites lit by the sun on
    -- an otherwise empty ground; or "map", the flat painted map (tier rings,
    -- quadrants, sections). Switched in the settings menu too.
    view_ground = "dots",
    -- how each terrain circle is drawn: "shade", dark pole to bright pole;
    -- or "bars", a spiral of bars growing from none to the rim, to watch
    -- each circle's turn (the longest bar where the bright pole would be);
    -- or "bars-open", the same with the background between bars clear
    view_circle = "shade",
}
