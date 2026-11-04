-- The reading walk, read from its description: stops as stepping stones in the
-- project's order, each a little higher (a project builds as it goes); at stop 9
-- the guide steps back along a lit line to a stop it is built from.
scene{ what = "stepping stones rising in order, with a lit line from one stone back to an earlier one" }
cylinder { name = "stop 1", at = {-3.000, 0.080, 0.387}, radius = 0.17, height = 0.160, color = "#5a7a9a" }
cylinder { name = "stop 2", at = {-2.540, 0.110, 0.591}, radius = 0.17, height = 0.220, color = "#5a7a9a" }
cylinder { name = "stop 3", at = {-2.080, 0.140, 0.518}, radius = 0.17, height = 0.280, color = "#5a7a9a" }
cylinder { name = "stop 4", at = {-1.620, 0.170, 0.201}, radius = 0.17, height = 0.340, color = "#5a7a9a" }
cylinder { name = "stop 5", at = {-1.160, 0.200, -0.210}, radius = 0.17, height = 0.400, color = "#5a7a9a" }
cylinder { name = "stop 6", at = {-0.700, 0.230, -0.523}, radius = 0.17, height = 0.460, color = "#5a7a9a" }
cylinder { name = "stop 7", at = {-0.240, 0.260, -0.589}, radius = 0.17, height = 0.520, color = "#5a7a9a" }
cylinder { name = "stop 8", at = {0.220, 0.290, -0.379}, radius = 0.17, height = 0.580, color = "#5a7a9a" }
cylinder { name = "stop 9", at = {0.680, 0.320, 0.010}, radius = 0.17, height = 0.640, color = "#d0603a" }
cylinder { name = "stop 10", at = {1.140, 0.350, 0.394}, radius = 0.17, height = 0.700, color = "#5a7a9a" }
cylinder { name = "stop 11", at = {1.600, 0.380, 0.593}, radius = 0.17, height = 0.760, color = "#5a7a9a" }
cylinder { name = "stop 12", at = {2.060, 0.410, 0.513}, radius = 0.17, height = 0.820, color = "#5a7a9a" }
cylinder { name = "stop 13", at = {2.520, 0.440, 0.191}, radius = 0.17, height = 0.880, color = "#5a7a9a" }
cylinder { name = "stop 14", at = {2.980, 0.470, -0.220}, radius = 0.17, height = 0.940, color = "#5a7a9a" }
box { name = "step back: from stop 9 to the stop it is built from", at = {-0.55, 0.9, 0.2}, size = {1.6, 0.04, 0.04}, color = "#d0603a", glow = true }
sphere { name = "the reader", at = {0.68, 1.15, 0.6}, radius = 0.12, color = "#e8d8a0" }
