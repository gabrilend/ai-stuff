-- 023-the-component-lexicon.lua
--
-- A piece of a character in, a thing that can be drawn out.
--
-- For a general: the stroke archive states what each character is built from.
-- The character for "rest" contains a person and a tree, and that is not our
-- invention -- it is the character's etymology, written down by people who
-- catalogued it. So the picture can be a traveller leaning on a trunk, and
-- nothing had to be made up.
--
-- Turning "contains 木" into "there is a cedar in this picture" needs a
-- dictionary of pieces. Most of that dictionary is not written here: a piece is
-- usually a character in its own right, and the meaning archive already glosses
-- it. What is written here is only what derivation cannot reach.
--
--   luajit src/023-the-component-lexicon.lua --coverage

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")

local M = {}

-- {{{ CATALOGUE_TALK -- glosses that describe the writing system, not the world
--
-- THE PROBLEM THIS SOLVES IS NOT COVERAGE. Ninety-six percent of component
-- appearances have a dictionary gloss. The trouble is that the *commonest*
-- pieces have the *worst* ones, because a piece that appears in two thousand
-- characters is a structural radical and a dictionary describes those by their
-- catalogue entry:
--
--   亻 -- "radical number 9"          丿 -- "katakana no radical (no. 4)"
--   亠 -- "kettle lid radical (no. 8)" 儿 -- "legs radical (no. 10)"
--   冂 -- "upside-down box radical (no. 13)"
--
-- Every one of those is a correct dictionary entry and none of them is a thing
-- that can be in a photograph. A scene built on them would be about the naming
-- of radicals.
--
-- They are recognised by a rule rather than by being listed, because the list
-- would be long, would be missing entries, and would say nothing about why.
-- A gloss that talks about radicals, kana, stroke counts or catalogue numbers
-- is a gloss about writing.
local CATALOGUE_TALK = {
  "radical", "%(no%.", "katakana", "hiragana", "kana ", "^kana$",
  "counter for", "stroke", "kokuji", "variant of", "old form",
  "abbreviation of", "%f[%a]form of%f[%A]",
  -- And glosses that are grammar rather than things. A pronoun is a correct
  -- translation and cannot be in a photograph -- the piece 吾 is glossed "I",
  -- which put the word "I" into a scene description as though it named
  -- something. These are anchored, because "it" is inside "item" and "we" is
  -- inside "west".
  "^i$", "^me$", "^my$", "^mine$", "^you$", "^your$", "^we$", "^us$",
  "^he$", "^she$", "^it$", "^they$", "^them$", "^this$", "^that$",
  "^these$", "^those$", "^oneself$", "^itself$", "^etc%.?$", "^and$",
  "^or$", "^but$", "^not$", "^very$", "^more$", "^most$",
}
-- }}}

-- {{{ CUTS -- where a describing phrase stops being a name
--
-- A piece has two things to say about itself and they are not the same length.
-- *A hand reaching down to grasp* is a phrase to drop into a sentence. *Hand*
-- is what the piece is called, and what a learner is told it is called.
--
-- The names are derived from the phrases rather than written a second time,
-- because a hundred and seventy of them written by hand would be a hundred and
-- seventy chances for the two to disagree -- and a piece whose name and whose
-- description have drifted apart is a piece nobody can trust either half of.
--
-- Everything from the first of these onward is elaboration on the name and is
-- cut. Where the derivation gets one wrong, NAMED below says so outright.
local CUTS = {
  ", ", " with ", " on ", " of ", " above ", " under ", " beneath ", " over ",
  " reaching ", " lying ", " held ", " being ", " that ", " which ", " where ",
  " turned ", " laid ", " set ", " left ", " seen ", " going ", " coming ",
  " standing ", " driven ", " cut ", " split ", " stepping ", " walking ",
  " breaking ", " enclosing ", " curled ", " raised ", " caught ", " calling ",
  " falling ", " trailing ", " drawing ", " side by side ", " mid-step ",
  " from ", " for ", " to ", " at ", " in ", " into ", " and ", " up ", " down ",
  " out ", " apart ", " away ", " leaving ", " used ", " making ", " running ",
  " catching ", " pushing ", " bent ", " planted ", " worn ", " spoken ",
  " round ", " across ", " between ", " beside ", " like ", " asleep ",
}
-- }}}

-- {{{ NAMED -- pieces whose name is not the head of their phrase
--
-- Every row here is one the derivation above got wrong, and it is short because
-- the derivation is mostly right. Kept as a list of corrections rather than as
-- a full second column, so that adding a phrase does not oblige anybody to
-- invent a name for it.
local NAMED = {
  ["亻"] = "leader",     ["儿"] = "legs",       ["彳"] = "loiter",
  ["丿"] = "slide",      ["丶"] = "drop",       ["丨"] = "stick",
  ["亠"] = "lid",        ["冖"] = "cover",      ["宀"] = "roof",
  ["广"] = "canopy",     ["厂"] = "cliff",      ["囗"] = "enclosure",
  ["冂"] = "head",       ["匚"] = "box",        ["匸"] = "hiding",
  ["勹"] = "wrap",       ["卩"] = "seal",       ["厶"] = "private",
  ["又"] = "again",      ["寸"] = "measurement", ["扌"] = "fingers",
  ["忄"] = "heart",      ["氵"] = "tsunami",    ["灬"] = "boil",
  ["艹"] = "flowers",    ["竹"] = "bamboo",     ["糹"] = "thread",
  ["糸"] = "thread",     ["衤"] = "cloak",      ["礻"] = "altar",
  ["犭"] = "animal",     ["阝"] = "building",   ["⻖"] = "building",
  ["辶"] = "scooter",    ["廴"] = "stretch",    ["攵"] = "task",
  ["殳"] = "weapon",     ["夂"] = "winter",     ["彡"] = "hair",
  ["廾"] = "twenty",     ["⺕"] = "grip",       ["幺"] = "poop",
  ["爿"] = "bed",        ["彑"] = "snout",      ["癶"] = "tent",
  ["屰"] = "reversed",   ["歹"] = "death",      ["尸"] = "flag",
  ["疒"] = "sick",       ["龰"] = "foot",       ["𠂉"] = "eave",
  ["乂"] = "cross",      ["弋"] = "stake",      ["卜"] = "toe",
  ["匕"] = "spoon",      ["王"] = "king",       ["玉"] = "jewel",
  ["頁"] = "geoduck",    ["隹"] = "turkey",     ["聿"] = "brush",
  ["革"] = "leather",    ["髟"] = "hair",       ["隶"] = "slave",
  ["言"] = "say",        ["口"] = "mouth",      ["目"] = "eye",
  ["心"] = "heart",      ["火"] = "fire",       ["水"] = "water",
  ["土"] = "dirt",       ["田"] = "rice paddy", ["山"] = "mountain",
  ["石"] = "stone",      ["金"] = "gold",       ["月"] = "moon",
  ["日"] = "sun",        ["木"] = "tree",       ["人"] = "person",
  ["女"] = "woman",      ["子"] = "child",      ["大"] = "big",
  ["小"] = "small",      ["中"] = "middle",     ["一"] = "ground",
  ["二"] = "two",        ["八"] = "fins",       ["十"] = "cross",
  ["入"] = "enter",      ["西"] = "west",       ["用"] = "task",
  ["長"] = "long",       ["貝"] = "shellfish",  ["食"] = "eat",
  ["米"] = "rice",       ["皿"] = "dish",       ["衣"] = "clothes",
  ["巾"] = "towel",      ["車"] = "car",        ["刀"] = "sword",
  ["刂"] = "knife",      ["弓"] = "bow",        ["矢"] = "arrow",
  ["戈"] = "spear",      ["斤"] = "axe",        ["工"] = "construction",
  ["示"] = "altar",      ["穴"] = "hole",       ["谷"] = "valley",
  ["門"] = "gate",       ["戸"] = "door",       ["里"] = "village",
  ["虫"] = "insect",     ["魚"] = "fish",       ["鳥"] = "bird",
  ["馬"] = "horse",      ["牛"] = "cow",        ["羊"] = "sheep",
  ["犬"] = "dog",        ["舟"] = "boat",       ["雨"] = "rain",
  ["竹"] = "bamboo",     ["生"] = "life",       ["足"] = "foot",
  ["耳"] = "ear",        ["首"] = "neck",       ["自"] = "nose",
  ["見"] = "see",        ["立"] = "stand",      ["止"] = "stop",
  ["走"] = "run",        ["手"] = "hand",       ["文"] = "writing",
  ["夕"] = "evening",    ["夜"] = "night",      ["光"] = "sunlight",
  ["禾"] = "grain",      ["才"] = "genius",     ["求"] = "request",
}
-- }}}

-- {{{ M.name_from(phrase)
-- The short name inside a describing phrase.
--
-- Strips the article, then cuts at the first place the phrase stops naming the
-- thing and starts saying more about it.
function M.name_from(phrase)
  if not phrase or phrase == "" then return nil end
  local name = phrase:gsub("^[Aa]n?%s+", ""):gsub("^[Tt]he%s+", "")
  local cut = #name + 1
  for _, marker in ipairs(CUTS) do
    local at = name:find(marker, 1, true)
    if at and at < cut then cut = at end
  end
  name = name:sub(1, cut - 1)
  -- "long low branch" is still a name; "long low" is not. A cut that left an
  -- adjective dangling has cut in the wrong place, and the whole phrase is a
  -- better answer than a fragment of it.
  if name == "" or name:match("^%a+ly$") then return phrase end
  return name
end
-- }}}

-- {{{ M.is_paintable(gloss)
-- Whether a gloss names something that could be in a picture.
function M.is_paintable(gloss)
  if not gloss or gloss == "" then return false end
  local lowered = gloss:lower()
  for _, pattern in ipairs(CATALOGUE_TALK) do
    if lowered:find(pattern) then return false end
  end
  return true
end
-- }}}

-- {{{ WRITTEN -- what derivation cannot reach
--
-- The only place in this project that asserts something neither archive said.
-- Every row is here for one of three reasons, and the reason is in the row:
--
--   shape    the piece is not a character and has no dictionary entry at all
--   catalogue  it has one and the entry describes the writing system
--   abstract   it has one, the entry is true, and it cannot be photographed
--
-- `depicts` is a noun phrase that goes straight into a prompt. `biome` is the
-- world this piece is evidence for, and `docs/004` weighs it above a keyword
-- because a piece is what the character was built from and a keyword is a
-- translation of what it came to mean.
--
-- The order of the rows is the order --coverage ranked them in, which is by how
-- often each piece appears. That ordering is the whole maintenance strategy for
-- this table: a piece in a hundred characters is worth a hundred times a piece
-- in one, and nobody has to decide what to write next.
local WRITTEN = {
  -- people and their parts
  { "亻", "a standing figure",              "person",  "catalogue" },
  { "人", "a person",                        "person",  "abstract" },
  { "儿", "a pair of legs walking",          "person",  "catalogue" },
  { "彳", "a figure on a road",              "road",    "shape" },
  { "又", "an open hand",                    "person",  "abstract" },
  { "扌", "a working hand",                  "person",  "catalogue" },
  { "寸", "a hand measuring a span",         "person",  "abstract" },
  { "口", "an open mouth",                   "person",  "abstract" },
  { "目", "a watching eye",                  "person",  "abstract" },
  { "耳", "an ear",                          "person",  "abstract" },
  { "心", "a heart",                         "person",  "abstract" },
  { "忄", "a heart, felt from the side",     "person",  "catalogue" },
  { "月", "a body, or the moon over it",     "person",  "abstract" },
  { "足", "a foot mid-step",                 "person",  "abstract" },
  { "首", "a head turned to look",           "person",  "abstract" },
  { "女", "a kneeling woman",                "person",  "abstract" },
  { "子", "a small child",                   "person",  "abstract" },
  { "父", "an elder",                        "person",  "abstract" },
  { "士", "a standing scholar",              "person",  "abstract" },
  { "尸", "a body at rest",                  "person",  "shape" },
  { "疒", "a sickbed",                       "dwelling","shape" },
  { "歹", "a bare bone",                     "shrine",  "shape" },

  -- growing things
  { "木", "a tree",                          "forest",  "abstract" },
  { "艹", "low grass",                       "field",   "catalogue" },
  { "竹", "bamboo",                          "forest",  "abstract" },
  { "禾", "a stalk of ripe grain",           "field",   "abstract" },
  { "米", "scattered rice grains",           "food",    "abstract" },
  { "生", "a shoot breaking ground",         "field",   "abstract" },
  { "花", "a flower",                        "field",   "abstract" },
  { "才", "a sapling",                       "forest",  "abstract" },

  -- water and weather
  { "水", "water",                           "water",   "abstract" },
  { "氵", "running water",                   "water",   "catalogue" },
  { "雨", "falling rain",                    "sky",     "abstract" },
  { "冫", "ice",                             "water",   "shape" },
  { "川", "a river",                         "water",   "abstract" },
  { "魚", "a fish",                          "water",   "abstract" },
  { "舟", "a small boat",                    "water",   "abstract" },

  -- earth and stone
  { "土", "bare earth",                      "field",   "abstract" },
  { "山", "a mountain",                      "mountain","abstract" },
  { "石", "a stone",                         "mountain","abstract" },
  { "厂", "a cliff face",                    "mountain","catalogue" },
  { "阝", "a steep bank",                    "mountain","shape" },
  { "田", "a flooded rice field",            "field",   "abstract" },
  { "谷", "a valley",                        "mountain","abstract" },
  { "穴", "a cave mouth",                    "mountain","abstract" },

  -- fire and light
  { "火", "an open flame",                   "fire",    "abstract" },
  { "灬", "embers underneath",               "fire",    "catalogue" },
  { "日", "the sun",                         "sky",     "abstract" },
  { "夕", "the evening sun going down",      "night",   "abstract" },
  { "光", "a shaft of light",                "sky",     "abstract" },

  -- made things
  { "金", "worked metal",                    "metal",   "abstract" },
  { "刀", "a blade",                         "metal",   "abstract" },
  { "刂", "a blade held to the side",        "metal",   "catalogue" },
  { "戈", "a halberd",                       "metal",   "abstract" },
  { "弓", "a drawn bow",                     "metal",   "abstract" },
  { "矢", "an arrow",                        "metal",   "abstract" },
  { "車", "a cart",                          "road",    "abstract" },
  { "糸", "a thread",                        "cloth",   "abstract" },
  { "巾", "a hanging cloth",                 "cloth",   "abstract" },
  { "衣", "a robe",                          "cloth",   "abstract" },
  { "衤", "a robe's edge",                   "cloth",   "catalogue" },
  { "皿", "a shallow dish",                  "food",    "abstract" },
  { "食", "a bowl of food",                  "food",    "abstract" },
  { "貝", "a cowrie shell used as money",    "town",    "abstract" },
  { "斤", "an axe head",                     "metal",   "abstract" },
  { "工", "a carpenter's square",            "metal",   "abstract" },

  -- buildings and enclosures
  { "宀", "a roof over everything below",    "dwelling","catalogue" },
  { "广", "a lean-to roof against a slope",  "dwelling","shape" },
  { "厶", "a small sealed thing",            "dwelling","abstract" },
  { "冖", "a cloth laid over something",     "dwelling","catalogue" },
  { "囗", "a wall enclosing a space",        "town",    "abstract" },
  { "冂", "an open frame",                   "town",    "catalogue" },
  { "門", "a gate with two leaves",          "town",    "abstract" },
  { "戸", "a single door",                   "dwelling","abstract" },
  { "示", "an altar table",                  "shrine",  "abstract" },
  { "礻", "an altar, seen edge on",          "shrine",  "catalogue" },
  { "辶", "a road being walked",             "road",    "shape" },
  { "廴", "a long stride along a road",      "road",    "shape" },
  { "里", "a village among fields",          "town",    "abstract" },

  -- beasts
  { "犬", "a dog",                           "beast",   "abstract" },
  { "犭", "a crouching animal",              "beast",   "catalogue" },
  { "鳥", "a bird",                          "beast",   "abstract" },
  { "隹", "a short-tailed bird",             "beast",   "shape" },
  { "虫", "an insect",                       "beast",   "abstract" },
  { "馬", "a horse",                         "beast",   "abstract" },
  { "牛", "an ox",                           "beast",   "abstract" },
  { "羊", "a sheep",                         "beast",   "abstract" },
  { "貝", "a cowrie shell used as money",    "town",    "abstract" },

  -- speech and thought
  { "言", "speech leaving a mouth",          "word",    "abstract" },
  { "文", "a written mark",                  "word",    "abstract" },
  { "聿", "a brush held upright",            "word",    "shape" },
  { "冊", "bound tablets",                   "word",    "abstract" },

  -- the bare shapes, which have no meaning of their own and still take up
  -- strokes. these are the pieces that exist only as parts.
  { "一", "a level horizon line",            "sky",     "abstract" },
  { "丨", "a standing pole",                 "town",    "catalogue" },
  { "丶", "a single spark",                  "fire",    "catalogue" },
  { "丿", "a leaning pole",                  "town",    "catalogue" },
  { "亠", "a lid resting on top",            "dwelling","catalogue" },
  { "乂", "two crossed sticks",              "field",   "abstract" },
  { "弋", "a stake driven into the ground",  "field",   "abstract" },
  { "卜", "a divining stick",                "shrine",  "abstract" },
  { "勹", "an arm curled around something",  "person",  "abstract" },
  { "匕", "a spoon",                         "food",    "abstract" },
  { "廿", "a pair of raised hands",          "person",  "abstract" },
  { "𠂉", "a sloping eave",                  "dwelling","shape" },
  { "䒑", "two shoots side by side",         "field",   "shape" },
  { "マ", "a small folded corner",           "cloth",   "shape" },
  { "龰", "a foot planted on the ground",    "person",  "shape" },
  { "龶", "a stake with a crossbar",         "field",   "shape" },
  { "⺍", "three small sparks",              "fire",    "shape" },

  -- The next rows down the queue that --coverage printed. Written in the order
  -- it ranked them, which is by how often they appear, because a piece in a
  -- hundred characters is worth a hundred times a piece in one.
  { "⺕", "a hand reaching down to grasp",   "person",  "shape" },
  { "匚", "an open box lying on its side",   "dwelling","catalogue" },
  { "幺", "a twist of thread",               "cloth",   "catalogue" },
  { "卩", "a kneeling figure",               "person",  "catalogue" },
  { "匸", "a hiding place behind a screen",  "dwelling","catalogue" },
  { "冋", "an outer wall seen from far off", "town",    "shape" },
  { "巛", "a winding river",                 "water",   "catalogue" },
  { "丰", "a lush growth of leaves",         "field",   "shape" },
  { "爿", "a plank split lengthwise",        "dwelling","catalogue" },
  { "业", "a row of young shoots",           "field",   "shape" },
  { "彑", "a boar's snout",                  "beast",   "catalogue" },
  { "癶", "two feet stepping apart",         "person",  "catalogue" },
  { "𡰪", "a body bent at the waist",        "person",  "shape" },
  { "𢆉", "a stalk with a crossbar",         "field",   "shape" },
  { "𡗗", "a spring shoot pushing up",       "field",   "shape" },
  { "㐄", "two feet turned apart",           "person",  "shape" },
  { "㐭", "a granary",                       "food",    "shape" },
  { "舛", "two feet turned away from each other", "person", "catalogue" },
  { "韭", "a bed of leeks",                  "field",   "catalogue" },
  { "屰", "a figure standing upside down",   "person",  "shape" },
  { "炏", "two flames side by side",         "fire",    "shape" },
  { "翏", "long feathers trailing",          "beast",   "shape" },
  { "𠦝", "the sun caught in the grass at dawn", "sky", "shape" },
  { "电", "a fork of lightning",             "sky",     "shape" },
  { "夗", "a body curled up asleep",         "person",  "shape" },
  { "咅", "a mouth split in two",            "person",  "shape" },
  { "夋", "a figure walking slowly away",    "person",  "shape" },
  { "詹", "a cliff with words spoken beneath it", "mountain", "shape" },
  { "喿", "birds calling from a tree",       "beast",   "shape" },
  { "尞", "a signal fire on a pole",         "fire",    "shape" },
  { "𧘇", "the hem of a robe",               "cloth",   "shape" },
  { "𤇾", "two fires above a roof",          "fire",    "shape" },
  { "𢦏", "a blade cutting a mark",          "metal",   "shape" },
  { "䍃", "a clay jar being lifted",         "food",    "shape" },
  { "夂", "a foot coming down from above",   "person",  "shape" },
  { "攵", "a hand holding a stick",          "person",  "catalogue" },
  { "殳", "a raised weapon",                 "metal",   "catalogue" },
  { "欠", "a figure with its mouth open",    "person",  "abstract" },
  { "氏", "a blade at the root of a plant",  "field",   "abstract" },
  { "革", "a stretched hide",                "cloth",   "abstract" },
  { "頁", "a head with a face on it",        "person",  "catalogue" },
  { "隶", "a hand catching a tail",          "beast",   "shape" },
  { "廾", "two hands raised together",       "person",  "shape" },
  { "彡", "three trailing marks of light",   "sky",     "catalogue" },
  { "彳", "a figure walking a road",         "road",    "shape" },
  { "止", "a footprint that has stopped",    "road",    "abstract" },
  { "走", "a figure running",                "road",    "abstract" },
  { "髟", "long hair falling",               "person",  "catalogue" },
  { "鬥", "two figures grappling",           "person",  "shape" },

  -- Found by running the whole set and reading the failures. Every row below
  -- was a character that could not be pictured at all, and most of them are
  -- among the five hundred commonest.
  { "王", "a polished jade disc",             "metal",   "abstract" },
  { "玉", "a jewel on a cord",                "metal",   "abstract" },
  -- The left-hand form of the bank radical has a *different number* from the
  -- one that stands alone, and looks identical. Three common characters had no
  -- world because the lists held one of the two.
  { "⻖", "a steep bank",                     "mountain","shape" },
  { "阝", "a steep bank",                     "mountain","shape" },
  { "西", "the western sky where the sun goes down", "sky", "abstract" },
  { "用", "a wooden pail with a handle",      "dwelling","abstract" },
  { "長", "an elder with long hair",          "person",  "abstract" },
  { "入", "the mouth of a doorway",           "dwelling","abstract" },
  { "二", "two marks tallied",                "word",    "abstract" },
  { "八", "two marks drawing apart",          "word",    "abstract" },
  { "求", "a hand reaching for something",    "person",  "abstract" },

  -- Pieces whose dictionary gloss is a pronoun or a grammatical word, refused
  -- above and given a picture here. Every one is drawn from what the piece is
  -- actually built out of, which is the same move the rest of this file makes.
  { "吾", "five mouths all speaking at once",  "word",    "abstract" },
  { "予", "a shuttle passed between hands",    "cloth",   "abstract" },
  { "其", "a winnowing basket on a stand",     "food",    "abstract" },
  { "之", "a foot setting off",                "road",    "abstract" },
  { "乃", "a rope hanging in a loop",          "cloth",   "abstract" },
  { "亦", "a figure with marks under each arm", "person", "abstract" },
  { "自", "a nose",                          "person",  "abstract" },
  { "勿", "a banner with streamers flying",  "cloth",   "abstract" },
  { "此", "a foot halted beside another",    "road",    "abstract" },

  -- And the next rows the coverage report named, all of them pieces with no
  -- dictionary entry of their own. Drawn from what each is built out of.
  { "䜌", "two skeins of silk either side of a word", "cloth", "shape" },
  { "叚", "a hand passing something across",  "person",  "shape" },
  { "壴", "a drum standing on its post",      "shrine",  "shape" },
  { "枼", "a spray of leaves on a branch",    "forest",  "shape" },
  { "睪", "an eye watching from above",       "person",  "shape" },
  { "肙", "a small pale worm",                "beast",   "shape" },
  { "囟", "the crown of a skull",             "person",  "shape" },
  { "冘", "a figure carrying a load",         "road",    "shape" },
  { "啇", "a stalk with a mouth beneath it",  "field",   "shape" },
  { "夆", "two hands meeting",                "person",  "shape" },
  { "尗", "a bean plant with pods",           "field",   "shape" },
  { "夌", "a figure climbing over a mound",   "mountain","shape" },
  { "匃", "a figure with an outstretched hand", "person", "shape" },
  { "乡", "three marks trailing behind",      "sky",     "shape" },
  { "𥁕", "a dish set down in an enclosure",  "food",    "shape" },
  { "㐺", "three figures standing together",  "town",    "shape" },
  { "巸", "a wide-open gateway",              "town",    "shape" },
  { "豖", "a pig with its legs bound",        "beast",   "shape" },
  { "㫃", "a banner on a leaning pole",       "cloth",   "shape" },
  { "冎", "a bone joint",                     "person",  "shape" },
  { "見", "an eye above a pair of legs",      "person",  "abstract" },
}

local BY_CHARACTER = {}
for _, row in ipairs(WRITTEN) do
  BY_CHARACTER[row[1]] = { depicts = row[2], biome = row[3], why = row[4] }
end
-- }}}

-- {{{ M.written_count()
function M.written_count()
  local count = 0
  for _ in pairs(BY_CHARACTER) do count = count + 1 end
  return count
end
-- }}}

-- {{{ M.look_up(component, store)
-- One component, as something that can be in a picture.
--
-- Returns nil when nothing can be found, which is a real answer -- `docs/004`
-- turns those strokes into structure rather than into a subject, and `303`
-- counts them so the commonest one is the next row somebody writes here.
--
-- The order is: what is written here, then the piece's own dictionary entry,
-- then the entry for the character the piece is a squeezed form of. The last of
-- those is why 亻 works without a row: the archive says it is a compressed 人,
-- and 人 is glossed "person".
function M.look_up(component, store)
  local element = component.element
  if not element then return nil end

  local written = BY_CHARACTER[element]
  if written then
    return { depicts = written.depicts, biome = written.biome,
             name = NAMED[element] or M.name_from(written.depicts),
             named_by_us = true,
             source = "written", why = written.why, element = element }
  end

  local own = store.records[element]
  if own and M.is_paintable(own.meanings[1]) then
    -- A dictionary's first gloss is already a name -- "tree", "mouth", "five".
    -- That is the whole reason most of this lexicon did not have to be written.
    return { depicts = own.meanings[1], biome = nil,
             name = NAMED[element] or own.meanings[1],
             named_by_us = NAMED[element] ~= nil,
             source = "dictionary", element = element,
             meanings = own.meanings }
  end

  if component.original then
    local under = BY_CHARACTER[component.original]
    if under then
      return { depicts = under.depicts, biome = under.biome,
               name = NAMED[component.original] or M.name_from(under.depicts),
               named_by_us = true,
               source = "written-original", why = under.why,
               element = component.original }
    end
    local other = store.records[component.original]
    if other and M.is_paintable(other.meanings[1]) then
      return { depicts = other.meanings[1], biome = nil,
               name = NAMED[component.original] or other.meanings[1],
               named_by_us = NAMED[component.original] ~= nil,
               source = "dictionary-original", element = component.original,
               meanings = other.meanings }
    end
  end

  return nil
end
-- }}}

-- {{{ M.coverage(store)
-- How much of the archive this lexicon can actually picture, and what it cannot.
--
-- Counted by appearance rather than by distinct piece, because a component in
-- two thousand characters matters two thousand times more than one in a single
-- rare character -- and the frequency ordering of the failures is the queue for
-- what to write next.
function M.coverage(store)
  local by_source = {}
  local missing = {}
  local total = 0

  for _, record in ipairs(store.order) do
    for _, component in ipairs(record.components) do
      if component.depth > 1 and component.element then
        total = total + 1
        local found = M.look_up(component, store)
        if found then
          by_source[found.source] = (by_source[found.source] or 0) + 1
        else
          by_source.nothing = (by_source.nothing or 0) + 1
          local entry = missing[component.element]
          if not entry then
            local own = store.records[component.element]
            entry = { element = component.element, count = 0,
                      gloss = own and own.meanings[1] or nil }
            missing[component.element] = entry
          end
          entry.count = entry.count + 1
        end
      end
    end
  end

  local queue = {}
  for _, entry in pairs(missing) do queue[#queue + 1] = entry end
  table.sort(queue, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.element < b.element
  end)

  return { total = total, by_source = by_source, queue = queue }
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  project.hello("023-the-component-lexicon")
  local store = project.load("019-the-kanji-record").store()

  if options.coverage or not options.chars then
    local found = M.coverage(store)
    io.write(string.format("%d component appearances across the joined set\n",
             found.total))
    io.write(string.format("%d rows written by hand\n\n", M.written_count()))
    local names = {}
    for name in pairs(found.by_source) do names[#names + 1] = name end
    table.sort(names, function(a, b)
      return found.by_source[a] > found.by_source[b]
    end)
    for _, name in ipairs(names) do
      io.write(string.format("  %-22s %6d  %5.1f%%\n", name,
               found.by_source[name], found.by_source[name] / found.total * 100))
    end
    io.write("\nwhat cannot be pictured, commonest first -- the queue for the\n")
    io.write("written half of this file:\n")
    for index = 1, math.min(24, #found.queue) do
      local entry = found.queue[index]
      io.write(string.format("  %-4s %5d   %s\n", entry.element, entry.count,
               entry.gloss and ("dictionary says: " .. entry.gloss)
               or "no dictionary entry at all"))
    end
    project.goodbye("023-the-component-lexicon",
                    { found.total .. " component appearances examined" })
    return
  end

  local xml = project.load("011-scan-xml")
  for _, character in ipairs(xml.characters(options.chars)) do
    local record = store.records[character]
    if not record then error(character .. " is not in the joined set") end
    io.write("\n", character, "  ", table.concat(record.meanings, ", "), "\n")
    for _, component in ipairs(record.components) do
      if component.depth > 1 then
        local found = M.look_up(component, store)
        io.write(string.format("  %-4s depth %d %-8s %-14s %s%s\n",
          component.element, component.depth,
          component.phonetic and "(sound)" or "",
          found and (found.name .. (found.named_by_us and "*" or "")) or "",
          found and found.depicts or "-- nothing to picture --",
          found and ("   [" .. found.source .. "]") or ""))
      end
    end
  end
  project.goodbye("023-the-component-lexicon", { "looked up" })
end
-- }}}

if arg and arg[0] and arg[0]:find("023%-the%-component%-lexicon") then
  main(arg)
end

return M
