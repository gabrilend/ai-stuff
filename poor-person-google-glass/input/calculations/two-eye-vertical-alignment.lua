-- two-eye-vertical-alignment.lua - do the two eyes' pictures line up?
-- Written by Claude (Opus 5.5), 2026-10-10, for issue 009, for the tiles of
-- issue 304 if each is a small curved mirror (open question 1 there).
--
-- Each eye sees its picture reflected from a tile. Tilting a mirror turns
-- the reflected light by twice the tilt, so every tilt error counts double.
-- The pictures fuse into one only if they land at nearly the same height in
-- both eyes; what matters is the difference between the sides.
return {
    question = "How far apart vertically do the two eyes' pictures land, if the tile mirrors tilt by their tolerances?",
    inputs = {
        { name = "hinge_angle_left", nominal = 0, unit = "deg", minus = 0.05, plus = 0.05, from = "guess: arm hinge angle error" },
        { name = "hinge_angle_right", nominal = 0, unit = "deg", minus = 0.05, plus = 0.05, from = "guess: arm hinge angle error" },
        { name = "mount_tilt_left", nominal = 0, unit = "deg", minus = 0.03, plus = 0.03, from = "guess: tile glued to its sub-arm" },
        { name = "mount_tilt_right", nominal = 0, unit = "deg", minus = 0.03, plus = 0.03, from = "guess: tile glued to its sub-arm" },
        { name = "sag_left", nominal = 0.02, unit = "deg", minus = 0.02, plus = 0.02, from = "guess: arm droop under the tile's weight" },
        { name = "sag_right", nominal = 0.02, unit = "deg", minus = 0.02, plus = 0.02, from = "guess: arm droop under the tile's weight" },
        { name = "frame_twist", nominal = 0, unit = "deg", minus = 0.05, plus = 0.05, condition = true, from = "guess: frame twisted between the eyes when worn" },
    },
    outputs = {
        -- signed (left higher is positive), limited either way
        { name = "vertical_mismatch", unit = "mrad", at_least = -1.0, at_most = 1.0 },
    },
    compute = function(v)
        local left = v.hinge_angle_left + v.mount_tilt_left + v.sag_left
        local right = v.hinge_angle_right + v.mount_tilt_right + v.sag_right + v.frame_twist
        -- a mirror turns light by twice its tilt; degrees to milliradians
        return { vertical_mismatch = 2 * (left - right) * math.pi / 180 * 1000 }
    end,
}
