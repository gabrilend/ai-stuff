-- 024-the-scene-grammar.lua
--
-- Decides what the picture is of.
--
-- For a general: `022` decided where the darkness goes. This decides what the
-- darkness *is*. It answers four questions about a character, in an order where
-- each answer narrows the next: what world is this, who is in it, what is each
-- individual line, and which way round is the light.
--
-- What comes out is a table of facts and contains no prose. `025` turns facts
-- into a sentence. Keeping those apart is what lets the wording be rewritten
-- without touching the reasoning, and the reasoning to be tested without
-- reading any English -- so the tests for this file assert that a river lands
-- in the water world, not that it produced a good-sounding phrase.
--
--   luajit src/024-the-scene-grammar.lua --chars 休森語時
--   luajit src/024-the-scene-grammar.lua --spread

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local shape = project.load("021-the-shape-of-a-stroke")
local lexicon = project.load("023-the-component-lexicon")

local M = {}

-- {{{ BIOMES -- the worlds a character can be about
--
-- The most opinionated thing in this project, and it is meant to be readable
-- straight through as a list of worlds.
--
-- Each holds: the words and pieces that are evidence for it, a *register* --
-- which particular version of that world -- the light in it, whether its ink is
-- dark or light, and a vocabulary saying what a stroke of each shape becomes
-- inside it.
--
-- THE REGISTER IS NOT DECORATION. "Forest" is not a world; a Hokkaido birch
-- stand, a Kyoto temple grove and a satoyama woodland edge are three worlds, and
-- naming which one is what the vision meant by cultural context being baked into
-- the imagery rather than added on top of it.
--
-- The role vocabulary is keyed by the shape of a stroke, not by its position:
-- the same long vertical is a cedar trunk in a forest and a cataract in water.
-- The measurement is universal; the vocabulary is per world.
local BIOMES = {

  { name = "forest",
    register = "the edge of a satoyama woodland at the foot of low hills",
    light = "late afternoon sun coming sideways between the trunks",
    palette = "deep greens, wet bark, pale sky between the leaves",
    polarity = "dark_ink",
    words = { "tree", "wood", "forest", "branch", "leaf", "root", "timber",
              "grove", "bamboo", "pine", "plum", "cherry", "bough", "trunk" },
    pieces = { "木", "竹", "才", "林", "森" },
    roles = {
      horizontal = "a long low branch reaching across",
      vertical = "a cedar trunk",
      falling_left = "a bough leaning out to the left",
      falling_right = "a shaft of light falling through the canopy",
      rising = "a root breaking up out of the leaf litter",
      reversing = "a branch doubling back on itself",
      dot = "a small bird perched",
      hooked = "a branch that curls at its tip",
    } },

  { name = "water",
    register = "a river mouth on the Sea of Japan with mist on the far bank",
    light = "flat silver light off the surface",
    palette = "grey-greens, wet stone, white spray",
    polarity = "dark_ink",
    words = { "water", "river", "sea", "ocean", "lake", "wave", "flow",
              "stream", "swim", "wet", "drown", "pond", "spring", "tide",
              "fish", "float", "sink", "harbour", "harbor", "boat", "ship" },
    pieces = { "水", "氵", "川", "巛", "魚", "舟", "冫" },
    roles = {
      horizontal = "a line of surf running across",
      vertical = "a cataract falling",
      falling_left = "a current sweeping left",
      falling_right = "a channel cutting away to the right",
      rising = "a sandbar lifting out of the shallows",
      reversing = "an eddy turning back",
      dot = "a stone breaking the surface",
      hooked = "a wave curling at its crest",
    } },

  { name = "mountain",
    register = "a granite ridge above the tree line with cloud sitting below it",
    light = "hard high light and long shadow",
    palette = "cold grey stone, snow in the clefts, thin blue distance",
    polarity = "dark_ink",
    words = { "mountain", "peak", "hill", "cliff", "stone", "rock", "valley",
              "cave", "ridge", "slope", "steep", "summit", "boulder" },
    -- Two numbers for the same shape: the form that stands alone and the form
    -- written on the left of another character look identical and are different
    -- characters. Holding only one of them cost three of the five hundred
    -- commonest characters their world.
    pieces = { "山", "石", "厂", "阝", "⻖", "谷", "穴", "岩" },
    roles = {
      horizontal = "a ledge running across the face",
      vertical = "a vertical fissure in the rock",
      falling_left = "a scree slope falling away left",
      falling_right = "a ridgeline dropping to the right",
      rising = "a spur climbing out of the valley",
      reversing = "an overhang folding back",
      dot = "a boulder standing alone",
      hooked = "a crag that hooks over",
    } },

  { name = "field",
    register = "terraced rice paddies in late summer, worked by hand",
    light = "warm flat light just after rain",
    palette = "wet green, brown water, straw",
    polarity = "dark_ink",
    words = { "field", "rice", "grain", "farm", "plant", "grass", "harvest",
              "seed", "crop", "soil", "earth", "dirt", "agriculture", "sow",
              "reap", "paddy", "garden", "grow", "flower", "bloom", "root",
              "sprout", "green", "leaf", "ground" },
    pieces = { "田", "土", "禾", "艹", "生", "花", "丰", "业", "韭" },
    roles = {
      horizontal = "a paddy bund running the width of the frame",
      vertical = "a channel cut down through the terraces",
      falling_left = "a slope of planting falling left",
      falling_right = "an irrigation ditch running away right",
      rising = "a bank rising between two levels",
      reversing = "a furrow turning back on itself",
      dot = "a single seedling standing clear",
      hooked = "a sickle left in the stubble",
    } },

  { name = "dwelling",
    register = "a wooden farmhouse with its paper screens half open onto the garden",
    light = "soft light coming in low through the opening",
    palette = "aged cedar, tatami straw, paper white",
    polarity = "dark_ink",
    words = { "house", "home", "roof", "room", "dwell", "live", "family",
              "door", "window", "shelter", "building", "wall", "floor",
              "residence", "inn", "hall" },
    pieces = { "宀", "广", "戸", "疒", "冖", "爿", "匚", "匸", "門",
               "用", "入" },
    roles = {
      horizontal = "a roof beam running the width of the room",
      vertical = "a pillar of dark cedar",
      falling_left = "a rafter sloping down to the left",
      falling_right = "the edge of an eave falling away right",
      rising = "a step up onto the veranda",
      reversing = "a screen folded back",
      dot = "a hanging lamp",
      hooked = "a hook set into a beam",
    } },

  { name = "town",
    register = "a narrow shotengai lane at dusk with the shop lanterns lit",
    light = "warm lantern light against a cooling sky",
    palette = "paper orange, wet asphalt, dark timber",
    polarity = "light_ink",
    words = { "city", "town", "street", "market", "shop", "gate", "capital",
              "village", "ward", "district", "trade", "buy", "sell", "money",
              "price", "public", "crowd", "section", "region", "border",
              "limit", "boundary", "wall", "province", "county" },
    pieces = { "囗", "冂", "門", "貝", "里", "丨", "冋", "邑", "部" },
    roles = {
      horizontal = "a shop awning stretching across the lane",
      vertical = "a banner hanging down the frontage",
      falling_left = "a line of lanterns receding left",
      falling_right = "a cable slung away to the right",
      rising = "a stepped alley climbing out of the lane",
      reversing = "a sign folding back over the street",
      dot = "a single paper lantern",
      hooked = "a shop sign on a hooked bracket",
    } },

  { name = "sky",
    register = "an open plain under moving weather",
    light = "broken cloud with the sun coming through in bands",
    palette = "high blue, grey cloud, gold at the edges",
    polarity = "dark_ink",
    words = { "sky", "sun", "moon", "star", "cloud", "heaven", "air", "wind",
              "rain", "snow", "weather", "day", "light", "bright", "shine",
              "storm", "thunder", "season", "spring", "summer", "autumn",
              "winter", "morning", "noon" },
    pieces = { "日", "雨", "一", "彡", "电", "光", "𠦝", "西" },
    roles = {
      horizontal = "a band of cloud lying across the sky",
      vertical = "a column of rain reaching down",
      falling_left = "a squall trailing away to the left",
      falling_right = "a shaft of sun breaking down to the right",
      rising = "a plume of cloud lifting",
      reversing = "a wind curling back",
      dot = "a bird high up, almost lost",
      hooked = "a cloud that hooks over at the top",
    } },

  { name = "fire",
    register = "a charcoal brazier in a dark workshop",
    light = "everything lit from one low glowing source",
    palette = "orange core, red edges, deep black around",
    polarity = "light_ink",
    words = { "fire", "flame", "burn", "hot", "heat", "smoke", "ash", "lamp",
              "cook", "forge", "boil", "roast", "candle", "spark", "blaze" },
    pieces = { "火", "灬", "丶", "⺍", "炏", "尞", "𤇾" },
    roles = {
      horizontal = "a bed of embers lying across",
      vertical = "a flame standing straight up",
      falling_left = "smoke drifting off to the left",
      falling_right = "a spray of sparks thrown right",
      rising = "heat rising visibly from the coals",
      reversing = "a flame folding back on itself",
      dot = "a single ember",
      hooked = "a flame that curls at its tip",
    } },

  { name = "metal",
    register = "a smith's bench with the tools laid out on oiled cloth",
    light = "one hard lamp, everything else in shadow",
    palette = "blue steel, black iron, oil sheen",
    polarity = "light_ink",
    words = { "metal", "gold", "iron", "steel", "sword", "blade", "knife",
              "tool", "machine", "cut", "needle", "nail", "hammer", "copper",
              "silver", "weapon", "arrow", "bow", "sharp" },
    pieces = { "金", "刀", "刂", "戈", "弓", "矢", "斤", "工", "殳", "𢦏",
               "王", "玉" },
    roles = {
      horizontal = "a blade lying flat on the bench",
      vertical = "a chisel standing on end",
      falling_left = "a file angled down to the left",
      falling_right = "a length of wire running away right",
      rising = "a tool propped up against the wall",
      reversing = "a bent length of iron",
      dot = "a rivet catching the light",
      hooked = "a hooked pick",
    } },

  { name = "person",
    register = "a figure alone in a plain room, caught mid-gesture",
    light = "even north light from one window",
    palette = "skin, unbleached cloth, plaster",
    polarity = "dark_ink",
    words = { "person", "man", "woman", "child", "body", "hand", "eye",
              "mouth", "ear", "heart", "self", "people", "human", "face",
              "head", "foot", "finger", "arm", "leg", "voice", "old", "young",
              "friend", "mother", "father", "stand", "sit", "hold", "large",
              "big", "small", "little", "help", "together", "effort", "work",
              "strength", "power", "skill", "good", "wear", "see", "look",
              "hear", "feel", "breathe", "life", "birth", "live", "die" },
    pieces = { "人", "亻", "儿", "女", "子", "目", "口", "耳", "心", "忄",
               "扌", "又", "足", "首", "頁", "士", "父", "寸", "卩",
               "大", "小", "立", "見", "自", "身", "手", "老", "羽", "良",
               "長", "求" },
    roles = {
      horizontal = "an outstretched arm crossing the frame",
      vertical = "a standing figure",
      falling_left = "a shoulder turning away left",
      falling_right = "a leg braced out to the right",
      rising = "a hand lifted",
      reversing = "an arm folded back",
      dot = "an eye",
      hooked = "a hand curled to grip",
    } },

  { name = "beast",
    register = "a wild animal at the edge of a clearing, holding still",
    light = "dappled shade with one bright patch",
    palette = "fur brown, wet black nose, green shade",
    polarity = "dark_ink",
    words = { "animal", "dog", "cat", "bird", "horse", "cow", "ox", "sheep",
              "insect", "beast", "wing", "tail", "feather", "hunt", "wild",
              "pig", "deer", "snake", "dragon", "tiger", "bear", "nest" },
    pieces = { "犬", "犭", "鳥", "隹", "虫", "馬", "牛", "羊", "彑", "翏",
               "喿", "隶" },
    roles = {
      horizontal = "a back held level",
      vertical = "a foreleg planted",
      falling_left = "a tail sweeping down left",
      falling_right = "a haunch falling away right",
      rising = "a raised muzzle",
      reversing = "a tail curled back",
      dot = "a watching eye",
      hooked = "a claw",
    } },

  { name = "cloth",
    register = "an indigo dyer's yard with lengths of cloth hanging to dry",
    light = "flat overcast, no shadows to speak of",
    palette = "indigo, undyed hemp, wet stone",
    polarity = "dark_ink",
    words = { "cloth", "thread", "silk", "weave", "sew", "garment", "clothes",
              "wear", "dress", "string", "rope", "cotton", "dye", "knit",
              "ribbon", "belt", "hat", "sleeve" },
    pieces = { "糸", "巾", "衣", "衤", "幺", "革", "𧘇" },
    roles = {
      horizontal = "a line strung across with cloth over it",
      vertical = "a length of indigo hanging straight down",
      falling_left = "a fold of cloth falling to the left",
      falling_right = "a loose end blown out to the right",
      rising = "a hem lifting in the draught",
      reversing = "a length doubled back over the line",
      dot = "a wooden peg",
      hooked = "a hook holding the line",
    } },

  { name = "food",
    register = "a low table set with lacquer bowls before anybody has sat down",
    light = "warm light from one side, steam catching it",
    palette = "black lacquer, red interior, white rice",
    polarity = "dark_ink",
    words = { "eat", "food", "drink", "meal", "taste", "sweet", "bitter",
              "hunger", "bowl", "wine", "tea", "salt", "sugar", "soup",
              "vegetable", "fruit", "meat", "cup", "dish", "feast" },
    pieces = { "食", "米", "皿", "匕", "㐭", "䍃" },
    roles = {
      horizontal = "the edge of the table running across",
      vertical = "a pair of chopsticks stood upright",
      falling_left = "a ladle angled down to the left",
      falling_right = "steam drifting off to the right",
      rising = "a lid being lifted",
      reversing = "a handle curving back",
      dot = "a single grain of rice",
      hooked = "a hooked pot handle",
    } },

  { name = "road",
    register = "an old post road between two provinces with stone markers along it",
    light = "early morning, long shadows down the road",
    palette = "packed earth, grey stone, cedar dark at the verge",
    polarity = "dark_ink",
    words = { "road", "path", "way", "walk", "go", "come", "travel",
              "journey", "move", "run", "cart", "vehicle", "car", "bridge",
              "cross", "far", "near", "return", "leave", "arrive", "carry",
              "send", "advance", "retreat", "station", "wheel", "ride" },
    pieces = { "辶", "廴", "彳", "車", "止", "走", "十", "非" },
    roles = {
      horizontal = "the road running straight across the frame",
      vertical = "a stone marker standing at the verge",
      falling_left = "a track branching away to the left",
      falling_right = "the road bending off to the right",
      rising = "the road climbing out of the frame",
      reversing = "a switchback turning on itself",
      dot = "a milestone",
      hooked = "a signpost with a hooked arm",
    } },

  { name = "shrine",
    register = "a moss-covered wayside shrine with offerings left at its foot",
    light = "green shade with one bar of sun across the stone",
    palette = "moss, weathered granite, vermilion gone dull",
    polarity = "dark_ink",
    words = { "god", "spirit", "shrine", "temple", "ritual", "pray", "sacred",
              "offering", "ancestor", "festival", "ceremony", "worship",
              "soul", "holy", "priest", "bless", "curse", "omen", "divine",
              "buddha", "grave", "dead", "death" },
    pieces = { "示", "礻", "卜", "歹" },
    roles = {
      horizontal = "the lintel of a torii running across",
      vertical = "a torii post",
      falling_left = "a rope of straw hanging down to the left",
      falling_right = "a paper streamer blown out right",
      rising = "a step worn up to the shrine",
      reversing = "a rope looped back",
      dot = "a stone left as an offering",
      hooked = "a bell rope with a hooked end",
    } },

  { name = "word",
    register = "a scholar's desk by a window with scrolls and an oil lamp",
    light = "one lamp and the last of the daylight",
    palette = "ink black, paper cream, dark wood",
    polarity = "dark_ink",
    words = { "say", "speak", "word", "language", "write", "read", "book",
              "learn", "study", "think", "know", "mean", "letter", "poem",
              "number", "count", "law", "rule", "name", "record", "story",
              "question", "answer", "teach", "school", "wisdom", "truth" },
    pieces = { "言", "文", "聿", "冊", "二", "八" },
    roles = {
      horizontal = "a scroll unrolled flat across the desk",
      vertical = "a hanging scroll",
      falling_left = "a brush laid down at an angle",
      falling_right = "a shaft of lamplight across the paper",
      rising = "a stack of books rising at the desk edge",
      reversing = "a page curling back",
      dot = "a drop of ink",
      hooked = "a brush hook on its stand",
    } },

  { name = "night",
    register = "a mountain village after dark with one window still lit",
    light = "moonlight, and one warm rectangle of window",
    palette = "blue-black, snow blue, one square of amber",
    polarity = "light_ink",
    words = { "night", "dark", "evening", "dusk", "sleep", "dream", "black",
              "shadow", "quiet", "silence", "late", "midnight", "rest" },
    pieces = { "夕", "夜", "夗" },
    roles = {
      horizontal = "a ridge of dark roofs across the frame",
      vertical = "a lit window standing tall",
      falling_left = "a lane running down into the dark to the left",
      falling_right = "a fall of moonlight to the right",
      rising = "a wisp of smoke going up from a chimney",
      reversing = "a shadow folding back",
      dot = "a lit window far off",
      hooked = "a lamp on a hooked bracket",
    } },
}

local BY_NAME = {}
for index, biome in ipairs(BIOMES) do
  biome.order = index
  BY_NAME[biome.name] = biome
end
-- }}}

-- {{{ TERRAIN -- what a phonetic component's strokes become
--
-- A phonetic piece was chosen for how the word sounds, not for what it means
-- (`docs/002`). Painting it as a subject puts an object in the picture with no
-- relation to the character -- the most plausible-looking way this project can
-- be wrong, because the result looks fine.
--
-- Its strokes still have to be something, so they become ground rather than
-- figure: present in the composition, absent from the sentence.
local TERRAIN = {
  "a ridgeline behind everything", "a worn path", "a rock face",
  "a fold in the ground", "a reflection in still water",
  "a line of distant trees", "a shadow cast across the ground",
  "a bank of low cloud",
}
-- }}}

-- {{{ M.biomes()
-- Every world there is, in order.
function M.biomes() return BIOMES end
-- }}}

-- {{{ component_box(record, component, measured)
-- Where a piece of a character actually sits, as a box.
--
-- Read off the strokes the piece owns rather than from the archive's position
-- label. The label says "left"; the box says the left third and upper half,
-- which is what a sentence can use.
local function component_box(component, measured)
  local left, top = math.huge, math.huge
  local right, bottom = -math.huge, -math.huge
  for index = component.stroke_first, component.stroke_last do
    local one = measured[index]
    if one then
      local box = one.flat.bbox
      if box[1] < left then left = box[1] end
      if box[2] < top then top = box[2] end
      if box[3] > right then right = box[3] end
      if box[4] > bottom then bottom = box[4] end
    end
  end
  if left == math.huge then return nil end
  return { left, top, right, bottom }
end
-- }}}

-- {{{ box_place(box)
-- A box, as a phrase about where it is in the frame.
local function box_place(box)
  local CANVAS = 109
  local x = (box[1] + box[3]) * 0.5 / CANVAS
  local y = (box[2] + box[4]) * 0.5 / CANVAS
  local width = (box[3] - box[1]) / CANVAS
  local height = (box[4] - box[2]) / CANVAS

  local column = (x < 0.36) and "left" or (x < 0.64) and "centre" or "right"
  local row = (y < 0.36) and "upper" or (y < 0.64) and "middle" or "lower"

  -- A piece that fills most of the frame is not "in the middle" -- it is the
  -- whole picture, and saying it sits in the centre would make the prompt
  -- describe a small thing in a large space.
  if width > 0.7 and height > 0.7 then
    return "filling the frame", column, row
  end
  if width > 0.7 then return "across the " .. row .. " of the frame", column, row end
  if height > 0.7 then return "down the " .. column .. " of the frame", column, row end
  return "in the " .. row .. " " .. column, column, row
end
-- }}}

-- {{{ sound_halves(record)
-- Which pieces are inside the half of the character chosen for its sound.
--
-- WHY THIS IS NOT JUST THE MARKED ONES. The archive marks the phonetic piece
-- itself and says nothing about the pieces *inside* it -- reasonably, since
-- being a component of a phonetic component is not a property anybody
-- catalogues. But those inner pieces are just as unrelated to what the
-- character means, and they vote.
--
-- The word for "language" is a speech radical beside a phonetic half, and that
-- phonetic half contains two mouths. Counted, the two mouths outvoted the
-- speech radical and the scene came out being about a person alone in a room
-- rather than about words. The character for "time" is a sun beside a phonetic
-- half containing earth, and the earth outvoted the sun into a rice paddy.
--
-- Both were wrong in the way this project is most at risk of being wrong: the
-- picture would have looked perfectly good and been about the wrong thing.
--
-- A piece is inside the sound half when its strokes fall entirely within a
-- marked piece's strokes and it sits deeper in the tree.
local function sound_halves(record)
  local inside = {}
  for outer_index, outer in ipairs(record.components) do
    if outer.phonetic then
      for inner_index, inner in ipairs(record.components) do
        if inner_index ~= outer_index
           and inner.depth > outer.depth
           and inner.stroke_first >= outer.stroke_first
           and inner.stroke_last <= outer.stroke_last then
          inside[inner_index] = true
        end
      end
    end
  end
  return inside
end
M.sound_halves = sound_halves
-- }}}

-- {{{ M.score(record, measured, settings)
-- How much evidence there is for each world, and which wins.
--
-- Scoring rather than branching. Three kinds of evidence, weighted differently
-- because they are differently trustworthy:
--
--   a piece of the character   strongest -- it is what the character was
--                              actually built out of
--   the primary gloss          next -- the sense the character is normally
--                              used in, and the archive orders them
--   a later gloss              weakest -- a secondary sense, or a translator's
--                              second attempt at the same one
function M.score(record, measured, store, settings)
  local weights = settings.scene
  local scores = {}
  local why = {}
  for _, biome in ipairs(BIOMES) do
    scores[biome.name] = 0
    why[biome.name] = {}
  end

  local function add(name, amount, reason)
    if scores[name] == nil then return end
    scores[name] = scores[name] + amount
    local list = why[name]
    list[#list + 1] = reason
  end

  for index, meaning in ipairs(record.meanings) do
    local lowered = meaning:lower()
    local weight = (index == 1) and weights.weight_primary_meaning
                                 or weights.weight_other_meaning
    for _, biome in ipairs(BIOMES) do
      for _, word in ipairs(biome.words) do
        -- whole words only: "sun" must not be found inside "sunder", and
        -- "art" must not be found inside "start"
        if lowered:find("%f[%a]" .. word .. "%f[%A]") then
          add(biome.name, weight, meaning)
          break
        end
      end
    end
  end

  -- Every piece counts, including the outermost one -- which is the character
  -- itself.
  --
  -- WHY THE OUTERMOST ONE MATTERS. A character with no parts has exactly one
  -- component: itself. Skipping the outermost level, on the reasoning that it
  -- restates the character rather than describing it, left every atomic
  -- character with no component evidence at all -- so "one", "ten", "large",
  -- "car" and a hundred like them scored nothing anywhere and were reported as
  -- belonging to no world. They are among the first characters anybody learns.
  --
  -- For a compound the outermost element is the whole character and is almost
  -- never in a world's list of pieces, so counting it costs nothing there.
  local inside_sound = sound_halves(record)
  for position, component in ipairs(record.components) do
    if component.element
       and not component.phonetic and not inside_sound[position] then
      for _, biome in ipairs(BIOMES) do
        for _, piece in ipairs(biome.pieces) do
          if piece == component.element then
            add(biome.name, weights.weight_component, component.element)
            break
          end
        end
      end
      -- The lexicon also carries a world for the pieces it has a written row
      -- for, which is the same evidence reached a second way and is why the
      -- weight is shared rather than doubled.
      local found = lexicon.look_up(component, store)
      if found and found.biome then
        add(found.biome, weights.weight_component * 0.5, component.element)
      end
    end
  end

  local ranked = {}
  for name, value in pairs(scores) do
    ranked[#ranked + 1] = { name = name, score = value, why = why[name] }
  end
  table.sort(ranked, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    -- A tie is broken by the order the worlds are written in, so the same
    -- character lands in the same world on every run. Nothing about the order
    -- is meaningful; the determinism is.
    return BY_NAME[a.name].order < BY_NAME[b.name].order
  end)
  return ranked
end
-- }}}

-- {{{ M.scene(record, store, settings, options)
-- One record in, one scene out. Or nil and a reason.
--
-- Returns nil when nothing scores, and that refusal is the point. A default
-- world would mean some unknown share of the output is a generic landscape with
-- no relationship to its character -- and every one of those pictures would look
-- perfectly fine, so nobody would ever find them. It is the most dangerous
-- fallback available in this project.
function M.scene(record, store, settings, options)
  options = options or {}
  local measured = options.measured or shape.measure_record(record)
  local ranked = M.score(record, measured, store, settings)

  if ranked[1].score <= 0 then
    return nil, "nothing in " .. record.character ..
                " is evidence for any world: no gloss matched and no piece is" ..
                " known.\n  glosses were: " .. table.concat(record.meanings, ", ")
  end

  local biome = BY_NAME[ranked[1].name]

  -- Which pieces are subjects, which are only ground, and which are neither
  -- because nothing can be said about them. All three are recorded; `303`
  -- counts the third so the lexicon's queue stays honest.
  local subjects, landscape, unglossed = {}, {}, {}
  local inside_sound = sound_halves(record)
  for position, component in ipairs(record.components) do
    if component.element then
      local box = component_box(component, measured)
      local where, column, row = box and box_place(box) or "somewhere", nil, nil
      -- A piece inside the sound half is ground for the same reason the sound
      -- half itself is, and must not reach the sentence either.
      if component.phonetic or inside_sound[position] then
        landscape[#landscape + 1] = {
          element = component.element, where = where, box = box,
          marked = component.phonetic or false,
          terrain = TERRAIN[((#landscape) % #TERRAIN) + 1],
        }
      else
        local found = lexicon.look_up(component, store)
        if found then
          subjects[#subjects + 1] = {
            element = component.element, depicts = found.depicts,
            source = found.source, where = where, box = box,
            depth = component.depth,
            stroke_first = component.stroke_first,
            stroke_last = component.stroke_last,
          }
        else
          unglossed[#unglossed + 1] = component.element
        end
      end
    end
  end

  -- The outermost pieces are the ones a reader sees first. Deeper ones are the
  -- pieces of pieces, and naming every level would describe a tree diagram
  -- rather than a picture.
  --
  -- The first level is the character itself, which for a compound is not a
  -- subject -- naming it would put "the character for rest" in a picture of a
  -- person and a tree. For a character with no parts it is the *only* piece
  -- there is, and skipping it left rivers and mountains with no subject at all
  -- while the scoring, which does count it, had already put them in the right
  -- world. So: the shallowest level below the character, or the character
  -- itself when there is nothing below it.
  local shallowest = math.huge
  for _, subject in ipairs(subjects) do
    if subject.depth > 1 and subject.depth < shallowest then
      shallowest = subject.depth
    end
  end
  if shallowest == math.huge then shallowest = 1 end
  local outer = {}
  for _, subject in ipairs(subjects) do
    if subject.depth == shallowest then outer[#outer + 1] = subject end
  end

  -- Largest first, so that when the sentence has to be shortened, the piece
  -- that dominates the picture is the one that survives.
  table.sort(outer, function(a, b)
    local function area(one)
      if not one.box then return 0 end
      return (one.box[3] - one.box[1]) * (one.box[4] - one.box[2])
    end
    local left, right = area(a), area(b)
    if left ~= right then return left > right end
    return a.stroke_first < b.stroke_first
  end)

  -- A role for every stroke, from its own shape and this world's vocabulary.
  local roles = {}
  for index, one in ipairs(measured) do
    local key
    if one.hooked then key = "hooked"
    elseif one.size == "dot" then key = "dot"
    else key = one.direction end
    roles[index] = {
      index = index,
      object = biome.roles[key] or biome.roles.horizontal,
      key = key,
      direction = one.direction,
      size = one.size,
      place = one.place.name,
      weight = one.weight,
    }
  end

  -- Only the strokes carrying the most ink are named in the sentence. A
  -- twenty-stroke character listed stroke by stroke is longer than a text
  -- encoder can hold, and a prompt past that limit does not fail -- it quietly
  -- ignores its own end.
  -- Where two named strokes land on the same phrase -- three verticals all
  -- being cedar trunks -- the repeats are told apart by where they are, rather
  -- than by inventing a second word for a trunk. The learner needs the position
  -- anyway, and a prompt that says the same noun three times gets one of them.
  local named = {}
  local said = {}
  for _, one in ipairs(shape.structural(measured, settings.scene.named_strokes)) do
    local role = roles[one.index]
    said[role.object] = (said[role.object] or 0) + 1
    role.phrase = (said[role.object] > 1)
                  and (role.object .. ", " .. role.place) or role.object
    role.named = true
    named[#named + 1] = role
  end

  -- A character read only with borrowed pronunciations is usually an abstract,
  -- bookish word; one with native readings is usually a concrete everyday
  -- thing. That is a real signal about how literal the scene should be, and it
  -- costs one look at a record that already has the readings.
  local register_note = (#record.readings_kun == 0) and "abstract" or "concrete"

  return {
    character = record.character,
    meanings = record.meanings,
    primary = record.meanings[1],
    biome = biome,
    score = ranked[1].score,
    runners_up = { ranked[2], ranked[3] },
    evidence = ranked[1].why,
    subjects = outer,
    all_subjects = subjects,
    landscape = landscape,
    unglossed = unglossed,
    roles = roles,
    named = named,
    polarity = biome.polarity,
    register_note = register_note,
    grade = record.grade,
    jlpt = record.jlpt,
    strokes = #measured,
  }, nil
end
-- }}}

-- {{{ M.spread(store, settings)
-- Which worlds the whole set lands in.
--
-- A distribution nobody looks at is a trigger list nobody knows is thin. If
-- four thousand characters land in three worlds, the lists need widening, and
-- that is invisible from any single character.
function M.spread(store, settings)
  local counts, homeless = {}, {}
  for _, biome in ipairs(BIOMES) do counts[biome.name] = 0 end
  for _, record in ipairs(store.order) do
    local scene = M.scene(record, store, settings)
    if scene then
      counts[scene.biome.name] = counts[scene.biome.name] + 1
    else
      homeless[#homeless + 1] = record.character
    end
  end
  local ranked = {}
  for name, count in pairs(counts) do
    ranked[#ranked + 1] = { name = name, count = count }
  end
  table.sort(ranked, function(a, b) return a.count > b.count end)
  return ranked, homeless
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("024-the-scene-grammar")
  local store = project.load("019-the-kanji-record").store()

  if options.spread then
    local started = os.clock()
    local ranked, homeless = M.spread(store, settings)
    io.write(string.format("%d characters placed into %d worlds in %.1fs\n\n",
             #store.order - #homeless, #BIOMES, os.clock() - started))
    for _, row in ipairs(ranked) do
      io.write(string.format("  %-10s %5d  %5.1f%%\n", row.name, row.count,
               row.count / #store.order * 100))
    end
    io.write(string.format("\n%d characters matched no world at all\n", #homeless))
    if #homeless > 0 then
      io.write("  ")
      for index = 1, math.min(40, #homeless) do io.write(homeless[index], " ") end
      io.write("\n")
    end
    project.goodbye("024-the-scene-grammar",
                    { #homeless .. " characters matched no world" })
    return
  end

  local xml = project.load("011-scan-xml")
  for _, character in ipairs(xml.characters(options.chars or "休森語時")) do
    local record = store.records[character]
    if not record then error(character .. " is not in the joined set") end
    local scene, why = M.scene(record, store, settings)
    if not scene then
      io.write("\n", character, "  ", why, "\n")
    else
      io.write("\n", character, "  ", table.concat(record.meanings, ", "), "\n")
      io.write("  world      ", scene.biome.name, " (", string.format("%.1f", scene.score),
               ", next was ", scene.runners_up[1].name, " at ",
               string.format("%.1f", scene.runners_up[1].score), ")\n")
      io.write("  register   ", scene.biome.register, "\n")
      io.write("  sense      ", scene.register_note, "\n")
      for _, subject in ipairs(scene.subjects) do
        io.write("  subject    ", subject.element, "  ", subject.depicts,
                 ", ", subject.where, "\n")
      end
      for _, ground in ipairs(scene.landscape) do
        io.write("  ground     ", ground.element,
                 ground.marked and "  (chosen for its sound) "
                                or "  (inside the sound half) ",
                 ground.terrain, ", ", ground.where, "\n")
      end
      for _, element in ipairs(scene.unglossed) do
        io.write("  no picture ", element, "\n")
      end
      for _, role in ipairs(scene.named) do
        io.write(string.format("  stroke %-2d  %s\n", role.index, role.phrase))
      end
    end
  end
  project.goodbye("024-the-scene-grammar", { "scenes built" })
end
-- }}}

if arg and arg[0] and arg[0]:find("024%-the%-scene%-grammar") then
  main(arg)
end

return M
