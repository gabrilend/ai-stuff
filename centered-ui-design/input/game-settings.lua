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

    -- how many spheroid units walk the map, and how many worker threads take
    -- their updates first come, first served
    unit_count = 192,
    worker_count = 6,

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

    -- the dashboard's radius as a fraction of the window's height
    dashboard_radius_fraction = 0.33,

    -- how many seconds of game time make one calendar day
    calendar_seconds_per_day = 3,
}
