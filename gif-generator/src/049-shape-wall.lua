-- 049-shape-wall.lua — the 3D scene's wall: every word checked against
-- its context, every mistake reported at once.
--
-- What this is, generally: the 2D score's discipline (024-compile.lua)
-- for shape scenes (issue 701c). A scene is walked from the top; each
-- word is looked up in the closed list for where it stands
-- (048-shape-words.lua), and each name it gives (a hue, a shape, a
-- motion, an effect, a tag) is looked up in the vocabulary it names. A
-- miss is not the end of the walk: the wall goes on, so an author fixes
-- one film's worth of mistakes per attempt, not one mistake. Every miss
-- carries where it is and the nearest legal word.
--
-- The hues, the cabinet's shapes and choreography's own words are handed
-- in (wall.vocabulary), so nothing here keeps a second copy of them.

local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local words = dofile(HERE .. "048-shape-words.lua")
local nearest = dofile(HERE .. "047-nearest.lua").word

local wall = {}

-- {{{ local function sorted()
local function sorted(list)
    local copy = {}
    for i, v in ipairs(list) do copy[i] = v end
    table.sort(copy)
    return copy
end
-- }}}

-- {{{ local function a_or_an()
-- "a swing", "an orbit": the name with its article.
local function a_or_an(name)
    return (name:match("^[aeiou]") and "an " or "a ") .. name
end
-- }}}

-- {{{ local function set_of()
local function set_of(list)
    local set = {}
    for _, v in ipairs(list) do set[v] = true end
    return set
end
-- }}}

-- {{{ local function same_words()
-- Whether two sorted lists hold the same words; the first that differs
-- otherwise.
local function same_words(a, b)
    local in_a, in_b = set_of(a), set_of(b)
    for _, w in ipairs(a) do if not in_b[w] then return false, w end end
    for _, w in ipairs(b) do if not in_a[w] then return false, w end end
    return true
end
-- }}}

-- {{{ function wall.vocabulary()
-- The names a scene may give, from the modules that use them: `hues` is
-- the colour table handed to choreography.load (name -> rgb), `meshes`
-- the cabinet, `choreography` the motion file. Refuses, loudly, if the
-- word lists here and the motions there have drifted apart.
function wall.vocabulary(hues, meshes, choreography)
    local hue_names = {}
    for name in pairs(hues) do hue_names[#hue_names + 1] = name end
    table.sort(hue_names)
    local owned = choreography.vocabulary()
    local vocab = {
        hues = hue_names, meshes = meshes.names(), motions = owned.motions,
        camera_motions = owned.camera_motions, effects = owned.effects, solids = owned.solids,
        routes = owned.routes,
    }
    -- {{{ local function keys()
    local function keys(tbl)
        local list = {}
        for k in pairs(tbl) do list[#list + 1] = k end
        table.sort(list)
        return list
    end
    -- }}}
    for _, pair in ipairs({
        { "shape motions", vocab.motions, keys(words.MOTIONS) },
        { "camera motions", vocab.camera_motions, keys(words.CAMERA_MOTIONS) },
        { "shapes in the cabinet", vocab.meshes, keys(words.MESH_PARAMS) },
    }) do
        local same, odd = same_words(pair[2], pair[3])
        if not same then
            error("shape wall: the " .. pair[1] .. " in 048-shape-words.lua and in the code that "
                  .. "runs them differ, at '" .. odd .. "'; list it in both, or in neither", 0)
        end
    end
    local sets = {}
    for name, list in pairs(vocab) do sets[name] = set_of(list) end
    return { lists = vocab, sets = sets }
end
-- }}}

-- {{{ local function is_whole()
local function is_whole(n) return type(n) == "number" and n == math.floor(n) end
-- }}}

-- {{{ local function rule_broken()
-- What is wrong with a value under one rule of its word (the rules are
-- written in 048-shape-words.lua), or nil when it keeps the rule.
local function rule_broken(rule, v)
    local n = tonumber(rule:match("%d+$"))
    if rule == "!" then
        return nil
    elseif rule == "cycles" then
        if not is_whole(v) then return "must be a whole number, or the loop has a seam" end
    elseif rule == "cycles3" then
        if type(v) ~= "table" or not (is_whole(v[1]) and is_whole(v[2]) and is_whole(v[3])) then
            return "must be three whole numbers, or the loop has a seam"
        end
    elseif rule == "whole" then
        if not is_whole(v) then return "must be a whole number" end
    elseif rule:match("^whole>=") then
        if not (is_whole(v) and v >= n) then return "must be a whole number, at least " .. n end
    elseif rule == "0..1" then
        if not (type(v) == "number" and v >= 0 and v <= 1) then return "must be a number from 0 to 1" end
    elseif rule == "(0,1)" then
        if not (type(v) == "number" and v > 0 and v < 1) then return "must be a number between 0 and 1" end
    elseif rule == ">0" then
        if not (type(v) == "number" and v > 0) then return "must be a number above zero" end
    elseif rule == ">=0" then
        if not (type(v) == "number" and v >= 0) then return "must be a number, zero or more" end
    elseif rule == "3numbers" then
        if type(v) ~= "table" or #v ~= 3 or type(v[1]) ~= "number" or type(v[2]) ~= "number"
           or type(v[3]) ~= "number" then
            return "must be three numbers"
        end
    elseif rule:match("^len>=") then
        if type(v) ~= "table" or #v < n then return "needs at least " .. n end
    elseif rule:match("^len=") then
        if type(v) ~= "table" or #v ~= n then return "needs exactly " .. n end
    elseif rule == "rising" then
        if type(v) ~= "table" then return "should be a list of moments" end
        for k, item in ipairs(v) do
            local u = type(item) == "table" and item[1]
            if type(u) ~= "number" or u < 0 or u >= 1
               or (k > 1 and (type(v[k - 1]) ~= "table" or u <= v[k - 1][1])) then
                return "its moments must rise from 0 up to (not reaching) 1"
            end
        end
    else
        error("shape wall: 048-shape-words.lua names a rule '" .. rule .. "' the wall does not know", 0)
    end
    return nil
end
-- }}}

-- The rules that tie one word to another, by place. Each is handed the
-- table, its path, `say`, and the whole scene with the vocabulary.
local CROSS = {}

-- {{{ local function route_list()
local function route_list(vocab) return table.concat(vocab.lists.routes, ", ") end
-- }}}

-- {{{ function CROSS.scene()
function CROSS.scene(t, path, say)
    if type(t.instances) == "table" and #t.instances == 0 and not t.track then
        say(path, "has nothing to film: no instances and no track")
    end
    if t.streaks and not (type(t.camera) == "table" and t.camera.motion) then
        say(path .. ".streaks", "streaks rush past a moving camera, but this scene's camera stands still")
    end
end
-- }}}

-- {{{ function CROSS.instance()
-- Three bodies: a blob (a hue, no mesh, no parts), a shape (a mesh and a
-- hue), or a spine (parts and no mesh). Rolling, becoming and timed
-- shatters ride the route's own clock; only a superball morphs.
function CROSS.instance(t, path, say, scene, vocab)
    if t.blob then
        if t.mesh or t.parts then say(path, "is a blob, which is a soft round body with no mesh and no parts") end
        if t.hue == nil then say(path, "needs a hue") end
    elseif not t.parts then
        if t.mesh == nil then say(path, "needs a mesh (or parts, which make it a hidden spine, or a blob)") end
        if t.hue == nil then say(path, "needs a hue") end
    elseif t.mesh ~= nil and t.hue == nil then
        say(path, "needs a hue")
    end
    local kind = type(t.motion) == "table" and t.motion.kind or "fixed"
    if not vocab.sets.routes[kind] then
        for _, word in ipairs({ "roll", "becomes", "shatter_keys" }) do
            if t[word] then
                say(path .. "." .. word, "needs a route motion (" .. route_list(vocab) .. "), not " .. tostring(kind))
            end
        end
    end
    -- a morph rides along into what the shape becomes and into its trail,
    -- so each of those must be a superball too
    local other = type(t.becomes) == "table" and t.becomes.mesh or nil
    local trailing = type(t.trail) == "table" and t.trail.mesh or nil
    for _, word in ipairs({ "morph", "morph_through" }) do
        if t[word] and t.mesh ~= "superball" then
            say(path .. "." .. word, "only a superball can morph")
        elseif t[word] and other and other ~= "superball" then
            say(path .. "." .. word, "only a superball can morph, and this one becomes a " .. tostring(other))
        elseif t[word] and trailing and trailing ~= "superball" then
            say(path .. "." .. word, "only a superball can morph, and this one's trail is " .. tostring(trailing))
        end
    end
end
-- }}}

-- {{{ function CROSS.part()
function CROSS.part(t, path, say)
    if t.mesh == nil then say(path, "needs a mesh") end
    if t.hue == nil then say(path, "needs a hue") end
end
-- }}}

-- {{{ function CROSS.light()
function CROSS.light(t, path, say)
    if t.tag == nil and t.at == nil then say(path, "needs a tag to ride or a fixed `at`") end
end
-- }}}

-- {{{ function CROSS.camera()
function CROSS.camera(t, path, say)
    local roll = t.roll
    if type(roll) == "table" and roll.cycles == nil and roll.turns == nil then
        say(path .. ".roll", "must count whole cycles or whole turns")
    end
end
-- }}}

-- {{{ function CROSS.motion()
-- A route that starts at a carried part needs a route motion; resting on
-- the ground needs a ground.
function CROSS.motion(t, path, say, scene, vocab)
    local anchored = false
    for _, p in ipairs({ t.from or false, t.to or false, unpack(type(t.points) == "table" and t.points or {}) }) do
        if type(p) == "table" and p.part then anchored = true end
    end
    if anchored and not vocab.sets.routes[t.kind] then
        say(path, "starts from a part, which needs a route motion (" .. route_list(vocab) .. ")")
    end
    if t.on_ground and not scene.ground then
        say(path .. ".on_ground", "stands on the ground, but the scene has no `ground`")
    end
    if t.kind == "keyframes" and type(t.points) == "table" and not scene.ground then
        for _, p in ipairs(t.points) do
            if type(p) == "table" and p[4] == nil then
                say(path .. ".points", "a point with no height rests on the ground, but the scene has no `ground`")
                break
            end
        end
    end
end
-- }}}

-- {{{ function CROSS.camera_motion()
function CROSS.camera_motion(t, path, say, scene)
    if t.target == "ahead" and t.kind ~= "fly" and t.kind ~= "lobed" then
        say(path .. ".target", "only a flying or lobed camera can look \"ahead\"")
    end
    if t.kind == "ride" and not scene.track then
        say(path, "the camera rides a track, but the scene has no `track`")
    end
end
-- }}}

-- {{{ function wall.check()
-- Every problem with the scene, in the order met, as lines of text. An
-- empty list means the scene speaks only legal words.
function wall.check(scene, vocab)
    local problems = {}
    local declared, refs = set_of(words.MADE_TAGS), {}

    -- {{{ local function say()
    local function say(path, message) problems[#problems + 1] = path .. ": " .. message end
    -- }}}

    -- {{{ local function name_in()
    -- A name checked against a vocabulary: a string, and one of its words.
    local function name_in(path, what, value, list)
        if type(value) ~= "string" then
            say(path, what .. " should be a word, not a " .. type(value))
        elseif not vocab.sets[list][value] then
            say(path, "no " .. what .. " '" .. value .. "' -- nearest legal: "
                      .. nearest(value, vocab.lists[list]))
        end
    end
    -- }}}

    local check_table

    -- {{{ local function check_list()
    -- A list of tables, each in one context: only the numbered places.
    local function check_list(value, context, path, carried)
        if type(value) ~= "table" then
            say(path, "should be a list of " .. context .. " tables, not a " .. type(value))
            return
        end
        for k in pairs(value) do
            if type(k) ~= "number" or k < 1 or k > #value or k % 1 ~= 0 then
                say(path, "a list takes no named word '" .. tostring(k) .. "'; each " .. context
                          .. " is a table in the list")
            end
        end
        for i, item in ipairs(value) do
            local label = path .. "[" .. i .. "]"
            if type(item) == "table" and type(item.tag) == "string" then
                label = label .. " (" .. item.tag .. ")"
            end
            check_table(item, words.CONTEXTS[context], context, label, carried, CROSS[context])
        end
    end
    -- }}}

    -- {{{ local function check_route_point()
    -- A point is numbers; an anchor names a carried part.
    local function check_route_point(value, path)
        if type(value) ~= "table" then return end
        for k in pairs(value) do
            if type(k) == "string" then
                check_table(value, words.CONTEXTS.anchor, "anchor", path)
                return
            end
        end
    end
    -- }}}

    -- {{{ local function check_motion()
    -- A motion's kind picks its words: `table_of(kind)` gives them.
    local function check_motion(value, path, what, list, table_of, cross)
        if type(value) ~= "table" then
            say(path, "a " .. what .. " should be a table, not a " .. type(value))
            return
        end
        if value.kind == nil then
            say(path, "a " .. what .. " needs a kind -- legal kinds: " .. table.concat(vocab.lists[list], ", "))
            return
        end
        name_in(path .. ".kind", what, value.kind, list)
        local legal = vocab.sets[list][value.kind] and table_of(value.kind)
        if legal then check_table(value, legal, value.kind .. " " .. what, path, nil, cross) end
    end
    -- }}}

    -- {{{ local function check_value()
    -- One word's value, by the kind of value the word takes. `owner` is
    -- the table the word stands in; `carried` is the mesh a mesh_params
    -- belongs to when the owner names none (a `becomes` keeps its shape's).
    local function check_value(kind, value, path, owner, carried)
        if type(kind) == "table" then
            check_list(value, kind.list, path, owner.mesh or carried)
        elseif kind == "value" then
            return
        elseif kind == "tag" then
            if type(value) ~= "string" then say(path, "a tag should be a word, not a " .. type(value))
            else declared[value] = true end
        elseif kind == "ref" then
            if type(value) ~= "string" then say(path, "should name a tag, not a " .. type(value))
            else refs[#refs + 1] = { path = path, tag = value } end
        elseif kind == "refs" then
            if type(value) ~= "table" then say(path, "should be a list of tags, not a " .. type(value)) return end
            for i, tag in ipairs(value) do check_value("ref", tag, path .. "[" .. i .. "]", owner, carried) end
        elseif kind == "hue" then
            name_in(path, "hue", value, "hues")
        elseif kind == "hues" then
            if type(value) ~= "table" then say(path, "should be a list of hues, not a " .. type(value)) return end
            for i, hue in ipairs(value) do name_in(path .. "[" .. i .. "]", "hue", hue, "hues") end
        elseif kind == "mesh" then
            name_in(path, "shape", value, "meshes")
        elseif kind == "mesh_params" then
            local mesh = owner.mesh or carried
            local legal = type(mesh) == "string" and words.MESH_PARAMS[mesh]
            if legal then check_table(value, legal, mesh, path) end
        elseif kind == "style" or kind == "shards" then
            local list = kind == "style" and words.STYLES or words.SHARDS
            if type(value) ~= "string" then say(path, "should be a word, not a " .. type(value))
            elseif not set_of(list)[value] then
                say(path, "no " .. kind .. " '" .. value .. "' -- nearest legal: " .. nearest(value, list))
            end
        elseif kind == "effect" then
            name_in(path, "effect", value, "effects")
        elseif kind == "solids" then
            if type(value) ~= "table" then say(path, "should be a list of solids, not a " .. type(value)) return end
            for i, solid in ipairs(value) do name_in(path .. "[" .. i .. "]", "solid", solid, "solids") end
        elseif kind == "motion" then
            check_motion(value, path, "motion", "motions", words.motion_words, CROSS.motion)
        elseif kind == "camera_motion" then
            check_motion(value, path, "camera motion", "camera_motions", words.camera_motion_words,
                         CROSS.camera_motion)
        elseif kind == "route_point" then
            check_route_point(value, path)
        elseif kind == "route_points" then
            if type(value) ~= "table" then return end
            for i, p in ipairs(value) do check_route_point(p, path .. "[" .. i .. "]") end
        elseif kind == "roll_or_false" then
            if value ~= false then check_table(value, words.CONTEXTS.roll, "roll", path) end
        elseif kind == "target" then
            if type(value) == "string" and value ~= "ahead" then
                say(path, "a target is a point or \"ahead\", not '" .. value .. "'")
            end
        else
            check_table(value, words.CONTEXTS[kind], kind, path, owner.mesh or carried, CROSS[kind])
        end
    end
    -- }}}

    -- {{{ check_table = function()
    -- A table in one context: every named word legal there, then each
    -- word's value and its rules, then the words it must have, then the
    -- rules that tie its words together (`cross`). `name` says what the
    -- table is, for the messages.
    check_table = function(t, legal_list, name, path, carried, cross)
        if type(t) ~= "table" then
            say(path, "should be a table of " .. name .. " words, not a " .. type(t))
            return
        end
        local legal, legal_sorted = words.legal(legal_list)
        local named = {}
        for k in pairs(t) do
            if type(k) == "string" then
                named[#named + 1] = k
            else
                say(path, a_or_an(name) .. " takes only named words, not a value at [" .. tostring(k) .. "]")
            end
        end
        table.sort(named)
        -- a needed word already suggested for a misspelling is not asked
        -- for twice
        local suggested = {}
        for _, k in ipairs(named) do
            local entry = legal[k]
            if not entry then
                if #legal_sorted == 0 then
                    say(path, "no word '" .. k .. "' -- " .. a_or_an(name) .. " takes no words")
                else
                    local near = nearest(k, legal_sorted)
                    suggested[near] = true
                    say(path, "no word '" .. k .. "' in " .. a_or_an(name) .. " -- nearest legal: " .. near)
                end
            else
                check_value(entry[2], t[k], path .. "." .. k, t, carried)
                for rule in (entry[4] or ""):gmatch("%S+") do
                    local broken = rule_broken(rule, t[k])
                    if broken then say(path .. "." .. k, broken); break end
                end
            end
        end
        for _, entry in ipairs(legal_list) do
            if t[entry[1]] == nil and (entry[4] or ""):match("^!") and not suggested[entry[1]] then
                say(path, "needs `" .. entry[1] .. "` (" .. entry[3] .. ")")
            end
        end
        if cross then cross(t, path, say, scene, vocab) end
    end
    -- }}}

    check_table(scene, words.CONTEXTS.scene, "scene", "scene", nil, CROSS.scene)

    -- Pointing at a tag nothing carries is a miss like any other, checked
    -- once every tag is known.
    local tag_list = {}
    for tag in pairs(declared) do tag_list[#tag_list + 1] = tag end
    table.sort(tag_list)
    for _, ref in ipairs(refs) do
        if not declared[ref.tag] then
            say(ref.path, "nothing is tagged '" .. ref.tag .. "' -- nearest tag: "
                          .. tostring(nearest(ref.tag, tag_list)))
        end
    end
    return problems
end
-- }}}

-- {{{ function wall.require()
-- Refuses a scene with any problem, listing them all.
function wall.require(scene, vocab)
    local problems = wall.check(scene, vocab)
    if #problems > 0 then
        local name = type(scene.name) == "string" and scene.name or "(unnamed)"
        error("scene " .. name .. ": " .. #problems .. (#problems == 1 and " problem" or " problems")
              .. ", all at once:\n  " .. table.concat(problems, "\n  "), 0)
    end
end
-- }}}

return wall
