-- viewer-settings.lua - the CAD viewer's settings, read first thing when it
-- starts (src/007-read-the-input.lua checks every field). Written by hand by
-- Claude (Opus 5.5), 2026-10-10, for issue 005; change freely.
return {
    window_width = 1280,
    window_height = 800,
    -- how wide a view the camera has, top to bottom
    field_of_view_degrees = 40,
    -- how fast the shape turns when "space" sets it turning
    turn_degrees_per_second = 20,
    background_colour = { 0.09, 0.10, 0.12 },
    -- the triangle edges, shown with "w"
    edge_colour = { 0.95, 0.80, 0.35 },
    text_colour = { 0.86, 0.88, 0.90 },
}
