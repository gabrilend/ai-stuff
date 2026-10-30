-- 048-shape-words.lua — every word a shape scene may use, where it may
-- use it, and what it means.
--
-- What this is, generally: the 3D scene's closed vocabulary (issue 701c),
-- as the 2D score has its tables. Each context (the scene itself, a
-- shape, a shape's spin, a camera that orbits, ...) is a list of the
-- words legal there, each with the kind of value it takes and one line
-- of meaning. The wall (049-shape-wall.lua) refuses any word not listed
-- for its context, naming the nearest one that is; the documentation
-- (docs/shape-format.md, written by 050-shape-docs.lua) is printed from
-- these same lists, so the two cannot drift.
--
-- Kinds of value:
--   "value"           a number, a point {x,y,z}, a list of numbers, a
--                     flag: whatever the word's meaning says; its shape
--                     is checked where it is used
--   "tag"             a name this thing carries, for others to point at
--   "ref", "refs"     the tag, or a list of tags, of something carried
--                     elsewhere in the scene
--   "hue", "hues"     a colour name, or a list of them
--   "mesh"            a shape from the cabinet (034-meshes.lua)
--   "mesh_params"     the proportions of that shape, in its own words
--   "style", "shards", "effect", "solids"
--                     a word, or a list of words, from a short list
--   "motion", "camera_motion"
--                     a table whose `kind` picks the words legal in it
--   "route_point(s)"  a point, or { part = tag, plus = {x,y,z} } for the
--                     place a carried part stands
--   "target"          a point, or "ahead"
--   "roll_or_false"   a roll table, or false to stop rolling
--   a context name    a table of that context's words
--   { list = name }   a list of such tables
--
-- A word may carry a fourth field: its rules, space-separated. "!" means
-- the word is needed; "cycles" a whole number, so the loop has no seam
-- ("cycles3": three of them); "whole", "whole>=N"; "0..1", "(0,1)", ">0",
-- ">=0"; "3numbers"; "len>=N", "len=N" for lists; "rising" for a list of
-- { moment, ... } whose moments rise from 0 up to (not reaching) 1.
--
-- Value words owned by the runtime (the hues, the cabinet's shapes, the
-- motion kinds, the effects, the solids a shape can morph through) are
-- not listed here; the wall takes them from the modules that use them.

local words = {}

-- The order contexts are documented in.
words.ORDER = {
    "scene", "camera", "camera_roll", "bob", "stars", "ground",
    "instance", "spin", "pulse", "rock", "orient", "roll", "blob", "burst",
    "morph", "morph_through", "reaction", "becomes", "trail", "part",
    "sway", "anchor",
    "stroke", "beam", "track", "track_twist", "rails", "ties", "along",
    "streaks", "light", "fluid", "fluid_tilt", "framing", "clearance",
    "spacing",
}

words.CONTEXTS = {
    -- {{{ scene
    scene = {
        { "name", "value", "the film's name, which its GIF is named after" },
        { "size", "value", "the picture's width and height in pixels, whole, at least 8", "! whole>=8" },
        { "frames", "value", "frames in one loop, whole", "! whole>=1" },
        { "delay_cs", "value", "how long each frame shows, in hundredths of a second", "whole>=1" },
        { "jobs", "value", "worker processes to split the frames across (at most 4)", "whole>=1" },
        { "camera", "camera", "where the film is seen from" },
        { "stars", "stars", "a sky of fixed stars behind everything" },
        { "instances", { list = "instance" }, "the shapes in the scene", "!" },
        { "ground", "ground", "the land that keyframes and on_ground rest on" },
        { "strokes", { list = "stroke" }, "thin lines of light bent into a travelling wave" },
        { "beams", { list = "beam" }, "lines of light always joining two tagged things" },
        { "track", "track", "a closed smooth ride with a corkscrew" },
        { "streaks", "streaks", "speed lines rushing past a moving camera" },
        { "lights", { list = "light" }, "point lights for blobs" },
        { "fluid", "fluid", "a liquid in an invisible tilting box" },
        { "framing", "framing", "a promise about how many tagged shapes stay in the picture" },
        { "clearance", { list = "clearance" }, "a promise that the lens keeps clear of tagged shapes" },
        { "spacing", "spacing", "a promise that tagged shapes keep apart" },
    },
    -- }}}
    -- {{{ camera
    camera = {
        { "distance", "value", "a still camera's distance back from the origin" },
        { "fov", "value", "the field of view, in degrees" },
        { "tilt", "value", "a still camera's tip downward" },
        { "motion", "camera_motion", "a moving eye; its kind picks its words" },
        { "roll", "camera_roll", "the horizon rocking, or turning all the way round" },
    },
    camera_roll = {
        { "amount", "value", "how far the horizon rocks either way" },
        { "cycles", "value", "rocks per loop, whole", "cycles" },
        { "phase", "value", "where in its rock the loop starts" },
        { "turns", "value", "whole turns of the horizon per loop, in place of rocking", "cycles" },
    },
    bob = {
        { "amount", "value", "how far it lifts and lowers" },
        { "cycles", "value", "bobs per loop, whole", "! cycles" },
        { "phase", "value", "where in its bob the loop starts" },
    },
    -- }}}
    -- {{{ stars, ground
    stars = {
        { "count", "value", "how many stars" },
        { "seed", "value", "the number the sky is scattered from; the same seed is the same sky" },
        { "hues", "hues", "the stars' colours" },
    },
    ground = {
        { "base", "value", "the ground's height where no hill or wave lifts it" },
        { "hills", "value", "{ { x, z, height, radius }, ... }: smooth mounds" },
        { "waves", "value", "{ { height, x frequency, z frequency, phase }, ... }: rolling swells" },
        { "size", "value", "how far the drawn land reaches" },
        { "grid", "value", "how finely the drawn land is cut" },
    },
    -- }}}
    -- {{{ instance
    instance = {
        { "tag", "tag", "a name others point at: reactions, beams, lights, promises" },
        { "mesh", "mesh", "the shape, from the cabinet" },
        { "mesh_params", "mesh_params", "the shape's own proportions" },
        { "hue", "hue", "its colour" },
        { "scale", "value", "its size; a blob's radius" },
        { "stretch", "value", "{x,y,z}: a different size along each axis" },
        { "style", "style", "how it is drawn: glow (lit edges), solid or wire" },
        { "dim", "value", "0 to 1: how far its colour is darkened", "0..1" },
        { "motion", "motion", "how it travels; its kind picks its words" },
        { "spin", "spin", "a steady turn about an axis" },
        { "pulse", "pulse", "breathing in and out" },
        { "rock", "rock", "swinging back and forth about a centre" },
        { "orient", "orient", "a standing turn" },
        { "pivot", "value", "{x,y,z}: moves the shape off its middle before turning, so it hinges at one end" },
        { "face_motion", "value", "true: points nose-first along its path" },
        { "roll", "roll", "rolling contact: turns by the distance rolled (needs a route motion)" },
        { "becomes", "becomes", "shrinks away at a point of its route as a new shape grows in its place" },
        { "trail", "trail", "smaller copies following the same route a little behind" },
        { "parts", { list = "part" }, "shapes carried in this shape's frame; with no mesh, this shape is a hidden spine" },
        { "blob", "blob", "a soft round body with a hue and no mesh" },
        { "reacts", { list = "reaction" }, "what it does when a tagged shape comes near" },
        { "shatter_keys", "value", "{ { u, amount }, ... }: a shatter timed at points of its route", "rising" },
        { "shards", "shards", "the shards' colours: rainbow, or own (its own colour)" },
        { "shard_distance", "value", "how far its shards fly" },
        { "burst", "burst", "a shatter on a timer rather than a reaction" },
        { "morph", "morph", "a superball breathing between cube and octahedron" },
        { "morph_through", "morph_through", "a superball becoming each solid in turn" },
        { "flock", "value", "a label the tests count shapes by" },
        { "role", "value", "a label the tests count shapes by" },
    },
    -- }}}
    -- {{{ the ways a shape turns and breathes
    spin = {
        { "axis", "value", "{x,y,z}: the line it turns about" },
        { "turns", "value", "whole turns per loop", "! cycles" },
        { "phase", "value", "where in its turn the loop starts" },
    },
    pulse = {
        { "amount", "value", "how far it swells and shrinks" },
        { "cycles", "value", "breaths per loop, whole", "! cycles" },
        { "phase", "value", "where in its breath the loop starts" },
        { "axes", "value", "{x,y,z}: breathe only along these axes" },
    },
    rock = {
        { "axis", "value", "{x,y,z}: the line it swings about" },
        { "center", "value", "{x,y,z}: the point it swings about" },
        { "amount", "value", "how far it swings either way" },
        { "cycles", "value", "swings per loop, whole", "! cycles" },
        { "phase", "value", "where in its swing the loop starts" },
    },
    orient = {
        { "axis", "value", "{x,y,z}: the line of the standing turn" },
        { "angle", "value", "how far it is turned" },
    },
    roll = {
        { "radius", "value", "the rolling radius, above zero", "! >0" },
    },
    blob = {
        { "group", "value", "blobs of one group melt into each other" },
        { "bands", "value", "brightness levels its lighting is cut into, whole, at least 2", "whole>=2" },
        { "soft", "value", "how near two blobs come before they melt together, zero or more", ">=0" },
    },
    burst = {
        { "amount", "value", "how hard it shatters" },
        { "cycles", "value", "bursts per loop, whole", "! cycles" },
        { "phase", "value", "where in its burst the loop starts" },
        { "power", "value", "how sharply the burst rises and falls" },
    },
    morph = {
        { "cycles", "value", "breaths between the solids per loop, whole", "! cycles" },
        { "phase", "value", "where in the morph the loop starts" },
        { "cube", "value", "how far toward the cube it goes" },
        { "octa", "value", "how far toward the octahedron it goes" },
    },
    morph_through = {
        { "shapes", "solids", "the solids it becomes, in turn, at least two", "! len>=2" },
        { "hues", "hues", "the colour it takes with each" },
        { "cycles", "value", "times through them all per loop, whole", "! cycles" },
        { "hold", "value", "how much of each solid's share it holds that solid true" },
        { "phase", "value", "where in the round the loop starts" },
    },
    reaction = {
        { "to", "ref", "the tag of the shapes it reacts to" },
        { "within", "value", "how near the nearest of them comes before it reacts" },
        { "effect", "effect", "what it does", "!" },
        { "amount", "value", "how strongly" },
    },
    -- }}}
    -- {{{ becomes, trail, part
    becomes = {
        { "at", "value", "the point of its route (between 0 and 1) where it changes", "! (0,1)" },
        { "over", "value", "how much of the route the change takes" },
        { "mesh", "mesh", "the new shape" },
        { "mesh_params", "mesh_params", "the new shape's own proportions" },
        { "hue", "hue", "the new colour" },
        { "scale", "value", "the new size" },
        { "stretch", "value", "the new stretch" },
        { "style", "style", "the new style" },
        { "dim", "value", "the new darkening", "0..1" },
        { "spin", "spin", "the new spin" },
        { "pulse", "pulse", "the new breathing" },
        { "rock", "rock", "the new swing" },
        { "orient", "orient", "the new standing turn" },
        { "face_motion", "value", "the new nose-first rule" },
        { "roll", "roll_or_false", "the new rolling; false: stop rolling" },
        { "tag", "tag", "the new tag" },
        { "trail", "trail", "a trail behind the new shape" },
        { "reacts", { list = "reaction" }, "the new shape's reactions" },
    },
    trail = {
        { "count", "value", "how many copies, whole, at least one", "! whole>=1" },
        { "spacing", "value", "how far apart in time, as a fraction of the loop" },
        { "shrink", "value", "each copy's size against the one before" },
        { "mesh", "mesh", "the copies' shape, if not the leader's" },
        { "hues", "hues", "the copies' colours, in turn" },
        { "dim", "value", "the copies' darkening", "0..1" },
        { "full_speed", "value", "the speed (world units per loop) below which the copies fade" },
    },
    part = {
        { "tag", "tag", "a name others point at" },
        { "mesh", "mesh", "the part's shape" },
        { "mesh_params", "mesh_params", "the part's own proportions" },
        { "hue", "hue", "its colour" },
        { "offset", "value", "{x,y,z}: where it sits in its carrier's frame" },
        { "scale", "value", "its size, against its carrier's" },
        { "stretch", "value", "{x,y,z}: a different size along each axis" },
        { "pivot", "value", "{x,y,z}: where it hinges" },
        { "orient", "orient", "a standing turn" },
        { "spin", "spin", "a steady turn" },
        { "rock", "rock", "a swing" },
        { "pulse", "pulse", "breathing" },
        { "dim", "value", "0 to 1: darkening", "0..1" },
        { "style", "style", "how it is drawn" },
        { "parts", { list = "part" }, "parts it carries in turn, to any depth" },
    },
    -- }}}
    -- {{{ sway, anchor
    sway = {
        { "vector", "value", "{x,y,z}: the direction and size of the wave" },
        { "cycles", "value", "waves per loop, whole", "! cycles" },
        { "phase", "value", "where in its wave the loop starts" },
    },
    anchor = {
        { "part", "ref", "the tag of a carried part; the route starts where it stands" },
        { "plus", "value", "{x,y,z}: added to where the part stands" },
    },
    -- }}}
    -- {{{ strokes, beams
    stroke = {
        { "from", "value", "{x,y,z}: one end" },
        { "to", "value", "{x,y,z}: the other end" },
        { "amplitude", "value", "how far the wave bends" },
        { "waves", "value", "waves along its length" },
        { "drift", "value", "whole travels of the wave per loop", "cycles" },
        { "phase", "value", "where in its travel the loop starts" },
        { "hue", "hue", "its colour" },
        { "dim", "value", "0 to 1: darkening", "0..1" },
        { "up", "value", "{x,y,z}: the direction it bends in" },
        { "segments", "value", "how finely it is drawn" },
    },
    beam = {
        { "from", "ref", "the tag at one end" },
        { "to", "ref", "the tag at the other end" },
        { "amplitude", "value", "how far it bends" },
        { "waves", "value", "waves along its length" },
        { "writhe", "value", "whole writhes per loop", "cycles" },
        { "strands", "value", "how many strands" },
        { "hues", "hues", "the strands' colours" },
        { "dim", "value", "0 to 1: darkening", "0..1" },
        { "segments", "value", "how finely it is drawn" },
    },
    -- }}}
    -- {{{ track
    track = {
        { "points", "value", "{ {x,y,z}, ... }: at least four, the curve bends through them", "! len>=4" },
        { "gauge", "value", "the distance between the rails" },
        { "twist", "track_twist", "the corkscrew" },
        { "rails", "rails", "the rails, drawn as striped strokes" },
        { "ties", "ties", "small bars across the rails" },
        { "along", { list = "along" }, "shapes set beside the track" },
    },
    track_twist = {
        { "from", "value", "where along the track the corkscrew starts (0 to 1)" },
        { "to", "value", "where it ends" },
        { "turns", "value", "whole turns of the corkscrew", "! cycles" },
        { "radius", "value", "swing out round an axis this far to the side: a wide helix" },
    },
    rails = {
        { "hues", "hues", "the stripes' colours" },
        { "stripes", "value", "stripes along the rails" },
        { "samples", "value", "how finely the rails are drawn" },
        { "thickness", "value", "how far apart a rail's two lines are" },
        { "dim", "value", "0 to 1: darkening", "0..1" },
    },
    ties = {
        { "count", "value", "how many, whole", "! whole>=1" },
        { "hues", "hues", "their colours, in turn", "! len>=1" },
        { "dim", "value", "0 to 1: darkening", "0..1" },
        { "width", "value", "how wide along the track" },
        { "thickness", "value", "how thick" },
    },
    along = {
        { "tag", "tag", "a name others point at" },
        { "count", "value", "how many, evenly round the track", "! whole>=1" },
        { "mesh", "mesh", "their shape", "!" },
        { "hues", "hues", "their colours, in turn", "! len>=1" },
        { "scale", "value", "their size" },
        { "side", "value", "about how far left and right of the rails", "!" },
        { "up", "value", "about how far above", "!" },
        { "spin", "spin", "their spin" },
        { "style", "style", "how they are drawn" },
    },
    -- }}}
    -- {{{ streaks, lights
    streaks = {
        { "count", "value", "how many" },
        { "seed", "value", "the number they are scattered from" },
        { "cycles", "value", "whole rushes past per loop", "! cycles" },
        { "far", "value", "where they appear" },
        { "near", "value", "where they pass" },
        { "length", "value", "how long each is" },
        { "inner", "value", "how near the line of travel they come" },
        { "outer", "value", "how far from it they reach" },
        { "hue", "hue", "their colour" },
        { "dim", "value", "0 to 1: darkening", "0..1" },
    },
    light = {
        { "tag", "ref", "the shape or part it shines from, moving with it" },
        { "at", "value", "{x,y,z}: a fixed place to shine from, in place of a tag" },
        { "hue", "hue", "its colour" },
        { "strength", "value", "how bright" },
    },
    -- }}}
    -- {{{ fluid
    fluid = {
        { "count", "value", "drops, whole, at least one", "! whole>=1" },
        { "seed", "value", "the number the drops are scattered from" },
        { "radius", "value", "how near two drops come before they push apart" },
        { "box", "value", "{x,y,z}: the box's three half-widths", "! 3numbers" },
        { "tilt", "fluid_tilt", "how the box tips", "!" },
        { "gravity", "value", "how hard the drops fall" },
        { "stiffness", "value", "how hard they push apart" },
        { "drag", "value", "how quickly they slow" },
        { "substeps", "value", "steps worked out per frame" },
        { "time_scale", "value", "how fast the liquid's time runs" },
        { "warmup", "value", "loops run before filming, so it starts settled" },
        { "blend", "value", "how the loop's end is blended into its start" },
        { "hues", "hues", "the drops' colours" },
        { "bands", "value", "the drops' brightness levels" },
        { "soft", "value", "how near drops melt together" },
        { "blob_size", "value", "each drop's drawn radius" },
        { "center", "value", "{x,y,z}: where the box stands" },
    },
    fluid_tilt = {
        { "axis", "value", "{x,y,z}: the line the box tips about" },
        { "amount", "value", "how far it tips" },
        { "cycles", "value", "tips per loop, whole", "! cycles" },
    },
    -- }}}
    -- {{{ promises
    framing = {
        { "tag", "ref", "the shapes counted", "!" },
        { "at_least", "value", "how many must have their centre in the picture in every frame, whole", "! whole" },
        { "margin", "value", "how far inside the picture's edge counts as in" },
    },
    clearance = {
        { "tag", "ref", "the shapes the lens keeps clear of" },
        { "radius", "value", "how near it may come" },
        { "column", "value", "true: measure level to the shape's upright line, as for a trunk" },
    },
    spacing = {
        { "tags", "refs", "the shapes that keep apart" },
        { "at_least", "value", "how near two of them (from different families) may come" },
    },
    -- }}}
}

-- The words each kind of motion takes, besides `kind` and the words every
-- motion takes. The kinds themselves are choreography's own (the wall
-- checks the two lists agree).
words.MOTION_COMMON = {
    { "lag", "value", "follow the same path this fraction of a loop behind" },
    { "offset", "value", "{x,y,z}: added to every position" },
    { "sway", { list = "sway" }, "waves added on top" },
    { "on_ground", "value", "true: height is measured from the ground there" },
}
words.MOTIONS = {
    fixed = {
        { "at", "value", "{x,y,z}: where it stands" },
    },
    orbit = {
        { "radius", "value", "the circle's radius" },
        { "cycles", "value", "times round per loop, whole", "! cycles" },
        { "phase", "value", "where on the circle the loop starts" },
        { "tilt", "value", "the circle tipped about x" },
        { "yaw", "value", "then turned about y" },
        { "center", "value", "{x,y,z}: the circle's middle" },
        { "bob", "bob", "rising and falling as it goes" },
    },
    swing = {
        { "from", "route_point", "one end" },
        { "to", "route_point", "the other end" },
        { "cycles", "value", "swings per loop, whole", "! cycles" },
        { "phase", "value", "where in its swing the loop starts" },
    },
    lissajous = {
        { "size", "value", "{x,y,z}: how far it reaches along each axis" },
        { "freq", "value", "{x,y,z}: whole waves along each axis per loop", "! cycles3" },
        { "shift", "value", "{x,y,z}: each axis's wave shifted" },
        { "phase", "value", "where on the knot the loop starts" },
        { "center", "value", "{x,y,z}: the knot's middle" },
    },
    arc = {
        { "radius", "value", "the arch's radius" },
        { "center", "value", "{x,y,z}: the arch's middle" },
        { "cycles", "value", "crossings per loop, whole", "! cycles" },
        { "phase", "value", "where on the arch the loop starts" },
        { "from_angle", "value", "the angle it sets off at" },
        { "to_angle", "value", "the angle it lands at" },
        { "depth", "value", "the arch's lean toward or away from the lens" },
    },
    conveyor = {
        { "from", "route_point", "where it grows out of nothing" },
        { "to", "route_point", "where it shrinks away" },
        { "cycles", "value", "crossings per loop, whole", "! cycles" },
        { "phase", "value", "where on the way the loop starts" },
    },
    keyframes = {
        { "points", "value", "{ { u, x, z [, y] }, ... }: the route's moments; with no y, on the ground", "! rising len>=2" },
        { "sizes", "value", "{ { u, size }, ... }: sizes at moments; 0 hides the jump back", "rising" },
        { "cycles", "value", "times along the route per loop, whole", "! cycles" },
        { "phase", "value", "where on the route the loop starts" },
        { "lift", "value", "height above the ground for points with no y" },
    },
    wave = {
        { "from", "route_point", "where the line starts" },
        { "to", "route_point", "where it ends" },
        { "amplitude", "value", "how far it ripples" },
        { "waves", "value", "ripples along the line" },
        { "cycles", "value", "crossings per loop, whole", "! cycles" },
        { "phase", "value", "where on the line the loop starts" },
        { "up", "value", "{x,y,z}: the direction it ripples in" },
        { "wave_phase", "value", "where in its ripple the line starts" },
    },
    bezier = {
        { "points", "route_points", "exactly four: start, two pulls, end", "! len=4" },
        { "cycles", "value", "flights per loop, whole", "! cycles" },
        { "phase", "value", "where in its flight the loop starts" },
    },
    spline = {
        { "points", "route_points", "the closed curve passes through these" },
        { "cycles", "value", "times round per loop, whole", "! cycles" },
        { "phase", "value", "where on the curve the loop starts" },
        { "sizes", "value", "{ { u, size }, ... }: sizes at moments" },
    },
}

-- The words each kind of camera motion takes, besides `kind`.
words.CAMERA_MOTIONS = {
    orbit = {
        { "radius", "value", "how far out" },
        { "height", "value", "how high above the target" },
        { "cycles", "value", "times round per loop, whole (negative: the other way)", "! cycles" },
        { "phase", "value", "where on the circle the loop starts" },
        { "target", "target", "the point looked at" },
        { "bob", "bob", "the eye lifting and lowering" },
    },
    dolly = {
        { "from", "value", "{x,y,z}: one end of its straight track" },
        { "to", "value", "{x,y,z}: the other end" },
        { "cycles", "value", "times there and back per loop, whole", "! cycles" },
        { "phase", "value", "where on the track the loop starts" },
        { "target", "target", "the point looked at" },
    },
    crane = {
        { "radius", "value", "how far out" },
        { "low", "value", "its lowest height" },
        { "high", "value", "its highest height" },
        { "cycles", "value", "rises and sinks per loop, whole", "! cycles" },
        { "phase", "value", "where in its rise the loop starts" },
        { "turns", "value", "times round per loop, whole", "cycles" },
        { "turn_phase", "value", "where on the circle the loop starts" },
        { "follow", "value", "how far the target rises with the eye" },
        { "target", "target", "the point looked at" },
    },
    spiral = {
        { "near", "value", "its nearest reach" },
        { "far", "value", "its farthest reach" },
        { "low", "value", "its height when near" },
        { "high", "value", "its height when far" },
        { "cycles", "value", "sweeps in and out per loop, whole", "! cycles" },
        { "phase", "value", "where in its sweep the loop starts" },
        { "turns", "value", "times round per loop, whole", "! cycles" },
        { "turn_phase", "value", "where on the circle the loop starts" },
        { "target", "target", "the point looked at" },
    },
    lobed = {
        { "radius", "value", "how far out, on average" },
        { "pinch", "value", "how far each lobe pinches in" },
        { "lobes", "value", "pinches per round, whole", "! cycles" },
        { "cycles", "value", "rounds per loop, whole", "! cycles" },
        { "phase", "value", "where on the loop it starts" },
        { "height", "value", "how high" },
        { "bob", "bob", "the eye lifting and lowering" },
        { "center", "value", "{x,y,z}: the loop's middle" },
        { "target", "target", "the point looked at, or ahead along the loop" },
        { "lead", "value", "looking ahead: how far ahead, as a fraction of the loop" },
    },
    ride = {
        { "cycles", "value", "times round the track per loop, whole", "! cycles" },
        { "phase", "value", "where on the track the loop starts" },
        { "height", "value", "how high above the rails" },
        { "lead", "value", "how far ahead it looks, as a fraction of the loop" },
    },
    fly = {
        { "size", "value", "{x,y,z}: how far it reaches along each axis" },
        { "freq", "value", "{x,y,z}: whole waves along each axis per loop", "! cycles3" },
        { "shift", "value", "{x,y,z}: each axis's wave shifted" },
        { "center", "value", "{x,y,z}: the path's middle" },
        { "phase", "value", "where on the path the loop starts" },
        { "target", "target", "the point looked at, or ahead along the path" },
        { "lead", "value", "looking ahead: at where it will be this fraction of a loop later" },
    },
}

-- The proportions each shape in the cabinet takes (034-meshes.lua). The
-- ground of a scene takes the terrain's.
words.MESH_PARAMS = {
    cube = {}, tetrahedron = {}, octahedron = {}, icosahedron = {},
    torus = {
        { "major", "value", "the ring's radius" },
        { "minor", "value", "the tube's radius" },
        { "rings", "value", "how finely round the ring" },
        { "sides", "value", "how finely round the tube" },
    },
    star_prism = {
        { "points", "value", "the star's points" },
        { "outer", "value", "the points' reach" },
        { "inner", "value", "the notches' reach" },
        { "depth", "value", "how thick" },
    },
    cone = {
        { "segments", "value", "how finely round" },
        { "radius", "value", "the base's radius" },
        { "height", "value", "how tall" },
    },
    horn = {
        { "ridges", "value", "ridges round it" },
        { "twist", "value", "turns of the ridges along it" },
        { "length", "value", "how long" },
        { "radius", "value", "the base's radius" },
        { "rings", "value", "how finely along it" },
    },
    terrain = {
        { "base", "value", "the height where no hill or wave lifts it" },
        { "hills", "value", "{ { x, z, height, radius }, ... }: smooth mounds" },
        { "waves", "value", "{ { height, x frequency, z frequency, phase }, ... }: rolling swells" },
        { "size", "value", "how far it reaches" },
        { "grid", "value", "how finely it is cut" },
    },
    superball = {
        { "grid", "value", "how finely it is cut" },
    },
}

-- World space, stated once (the rasteriser, 036-raster.lua, is its
-- arithmetic). Printed at the head of the documentation.
words.WORLD_SPACE = {
    "Positions are world units around the origin, `{ x, y, z }`: x to the right, y upward,",
    "z toward the viewer of a still camera.",
    "",
    "- A still camera (`camera = { distance, fov, tilt }`) sits `distance` back along +z (7",
    "  when left out), looks at the origin, and is tipped down by `tilt` radians.",
    "- A moving camera (`camera.motion`) has an eye and a target, both worked out each frame;",
    "  it looks from the eye at the target, keeping its up near the world's up, and `roll`",
    "  turns the picture about that line in radians.",
    "- `fov` is the picture's width (and height, the picture being square) as an angle, in",
    "  degrees; 45 when left out.",
    "- Time is the loop: moments run from 0 up to 1, and every cycle, turn and frequency",
    "  counts whole times round per loop, so the last frame leads into the first with no seam.",
    "- Angles: `turns` count whole turns; `angle`, `center`, `amount` (of a rock) and `tilt`",
    "  are radians; `phase` is a fraction of a cycle.",
}

-- The rules that tie one word to another, in words; the wall
-- (049-shape-wall.lua, CROSS) keeps them, and the documentation prints
-- this list beside the tables.
words.TIES = {
    "A scene has something to film: instances, or a track.",
    "A shape is a blob (a hue, and no mesh or parts), a shape (a mesh and a hue) or a spine (parts and no mesh).",
    "A part needs a mesh and a hue.",
    "Rolling, becoming and `shatter_keys` need a route motion, and so does a route that starts at a carried part.",
    "Only a superball morphs, and a morphing superball becomes and trails only superballs.",
    "Standing `on_ground`, or a keyframe point with no height, needs the scene's `ground`.",
    "Streaks need a moving camera; a riding camera needs a `track`; only a flying or lobed camera looks `\"ahead\"`.",
    "A camera's roll counts whole `cycles` or whole `turns`.",
    "A light needs a `tag` to ride or a fixed `at`.",
    "Every tag pointed at (by a reaction, a beam, a light, an anchor or a promise) is carried by something.",
}

-- Short lists of words the wall owns, since the code that reads them
-- only tells one from the rest.
words.STYLES = { "glow", "solid", "wire" }
words.SHARDS = { "own", "rainbow" }

-- The tags a scene's shapes carry without anyone writing them: track
-- ties, trackside shapes, trail copies and liquid drops.
words.MADE_TAGS = { "drop", "tie", "trackside", "trail" }

-- {{{ function words.legal()
-- A context's words as a lookup (word -> its entry) and a sorted list.
local cache = {}
function words.legal(list)
    if cache[list] then return cache[list].lookup, cache[list].sorted end
    local lookup, sorted = {}, {}
    for _, entry in ipairs(list) do
        lookup[entry[1]] = entry
        sorted[#sorted + 1] = entry[1]
    end
    table.sort(sorted)
    cache[list] = { lookup = lookup, sorted = sorted }
    return lookup, sorted
end
-- }}}

-- {{{ function words.motion_words()
-- Every word legal in one kind of shape motion: `kind`, its own, then the
-- ones every motion takes.
local motion_cache = {}
function words.motion_words(kind)
    if not words.MOTIONS[kind] then return nil end
    if not motion_cache[kind] then
        local list = { { "kind", "value", "which motion" } }
        for _, e in ipairs(words.MOTIONS[kind]) do list[#list + 1] = e end
        for _, e in ipairs(words.MOTION_COMMON) do list[#list + 1] = e end
        motion_cache[kind] = list
    end
    return motion_cache[kind]
end
-- }}}

-- {{{ function words.camera_motion_words()
local camera_cache = {}
function words.camera_motion_words(kind)
    if not words.CAMERA_MOTIONS[kind] then return nil end
    if not camera_cache[kind] then
        local list = { { "kind", "value", "which motion" } }
        for _, e in ipairs(words.CAMERA_MOTIONS[kind]) do list[#list + 1] = e end
        camera_cache[kind] = list
    end
    return camera_cache[kind]
end
-- }}}

return words
