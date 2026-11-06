-- candy-coaster: a ride on a rollercoaster made of candy light. Two rails
-- striped like a candy cane run over hills and round bends, whip through a
-- full corkscrew, and come back round to where they began; gold ties cross
-- between them. The camera rides the track, rolling with the corkscrew,
-- while stars flash past on either side and pale wind streaks rush out from
-- the middle of the view to show the speed.
--
-- The owner's words: "similar to the rainbow tunnel except it's a path down
-- a track, like a rollercoaster made out of candy light... two tracks, and
-- they should bend and whip and return to themselves. Maybe even a corkscrew
-- at one point. There should be stars that fly past and pale gray wind like
-- in the windmill example that stream from the center point to show that
-- we're moving forward."
--
-- The track is one smooth closed curve through the points below (a
-- Catmull-Rom spline), so it returns to itself; the corkscrew turns the rails
-- one whole time round the direction of travel between about a fifth and two-fifths of
-- the way round, and they are level again after it. The corkscrew is a
-- wide one: the track swings out round an axis 1.6 to its side, over the top
-- and back (the owner found the first, which only turned the rails in place,
-- "much too tight"). The wind streaks pour from wherever the ride is heading
-- this instant, not from the middle of the view ("make the gray streaks come
-- from the orientation of motion ... they can adjust instantly").
return {
    name = "candy-coaster",
    size = 320, frames = 216, delay_cs = 4,
    track = {
        points = {
            { 0, 0, 7 }, { 4.5, 1.2, 6 }, { 8, 2.8, 2.5 }, { 8.5, 0.4, -2 }, { 5, -1.2, -5.5 },
            { 0, 0.6, -7 }, { -4.5, 2.4, -5 }, { -7.5, 1.0, -1 }, { -6.5, -1.4, 3 }, { -3, -0.6, 6 },
        },
        gauge = 0.9,
        twist = { from = 0.18, to = 0.38, turns = 1, radius = 1.6 },
        rails = { hues = { "rose", "cloud" }, stripes = 90, samples = 360, thickness = 0.03 },
        ties = { count = 80, hues = { "gold", "ember" }, dim = 0.75, width = 0.035, thickness = 0.02 },
        along = { { tag = "star", count = 44, mesh = "star_prism", hues = { "gold", "rose", "ice" },
                    scale = 0.16, side = 1.4, up = 0.9, spin = { axis = { 0, 1, 0 }, turns = 3 } } },
    },
    streaks = { count = 46, seed = 17, cycles = 4, far = 16, near = 0.8, length = 1.6,
                inner = 0.5, outer = 3.2, hue = "cloud", dim = 0.5 },
    camera = { fov = 70, motion = { kind = "ride", cycles = 1, height = 0.8, lead = 0.022 } },
    stars = { count = 120, seed = 283, hues = { "gold", "rose", "ice" } },
    instances = {},
}
