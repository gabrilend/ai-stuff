--[[
models.lua - which WoW model stands in for each WC3 doodad, destructible and unit type

Data only (issue W02b): read with loadfile in an empty environment, so it
holds tables, strings, numbers and booleans and nothing else.

A WC3 map places doodads (war3map.doo: trees, rocks, plants, walls ...) and
units (war3mapUnits.doo) by four-character type id. A converted map names
a model for each by its path, as WoW 3.3.5a's archives name it:

  doodads   an M2 path (World\...\Tree01.m2) lands in the ADT's MMDX and
            MDDF blocks; a WMO path (...\Building.wmo) in MWMO and MODF
  units     an M2 path becomes a creature's model: wowbuild.creatures gives
            each path a display id of the map's own, which W02c writes into
            the client's display tables

The path is a logical name, looked up by the W client's resolver in its
order (docs/wow-client-bridge.md, "Our own models are the default"):

  1. the player's own packs
  2. the server's files: what a hosted map brings (a map's own imported
     models, which wowbuild.placements carries into the build folder)
  3. the player's own Blizzard install, if they plugged it in
  4. the baseline standard model set (the asset forge's, W05/W06): the
     project's own models, made with feature parity under these same names,
     so a player without Blizzard's files sees ours
  5. a wire-frame: nothing matched

So these paths are the names the baseline set has to cover; the files
themselves are Blizzard's and never copied into this repository or a build.

Fields of a row:
  name      the WC3 type's name in the World Editor (or what the row covers)
  wow       the WoW 3.3.5a path (backslashes, as the archives name it);
            ".m2" or ".wmo" decides which ADT blocks place it
  scale     multiplies the WC3 placement's own scale (default 1): the stand-in
            and the WC3 model aren't drawn the same size. A first guess,
            tuned in docs/balance-updates.md as the owner looks at the result
  size      WMO rows: the building's width and height in yards, roughly, for
            its MODF bounding box until the model file is read
  radius, reach   unit rows: the creature's bounding radius and combat reach
            in yards (the server's creature_model_info); defaults 1 and 1.5
  baseline  the baseline set's own model for this row, once the forge has
            made one (a pack's logical path); absent while none exists, and
            the conversion report counts placements still waiting for one
  checked   false: the path was written from memory of the 3.3.5a archives
            and has not been looked up in the owner's client. Set it true
            (and correct the path if needed) once a listfile or W01's reader
            shows the file is there. Every row is unchecked so far.

How a placement finds its row (wowbuild.placements, first match wins):
  1. the map's own model: the object's model field (the map's change to it)
     names a file inside the map archive: that file travels with the map
  2. by_model[the WC3 model path, lower case, ".mdl" written ".mdx"]: a
     custom type the map pointed at another stock WC3 model
  3. types[the type id, or the stock id a custom type copies]
  4. classes[category letter][tileset letter], else classes[letter].any: a
     doodad id is <tileset letter><category letter><two more>, so
     "LRrk" is a Lordaeron Summer rock; the categories filled here are
     P plants and R rocks (the letters for the others are less certain and
     left unmapped)
  5. nothing: counted as unmapped in the conversion report; doodads are
     then left out of the ADT (the W client draws them from the placement
     list or as a wire-frame), units get units.fallback so the server can
     still spawn them
]]

return {
    format = 1,

    -- {{{ doodads (war3map.doo: doodads and destructibles)
    doodads = {
        types = {
            -- {{{ tree walls, one stand-in per tileset (by look, as W02a's ground table)
            LTlt = { name = "Summer Tree Wall", wow = [[World\Azeroth\Elwynn\PassiveDoodads\Trees\ElwynnTreeCanopy01.m2]], scale = 0.5, checked = false },
            ATtr = { name = "Ashenvale Tree Wall", wow = [[World\Kalimdor\Ashenvale\PassiveDoodads\AshenvaleTrees\AshenvaleTree01.m2]], scale = 0.5, checked = false },
            ATtc = { name = "Ashenvale Canopy Tree", wow = [[World\Kalimdor\Ashenvale\PassiveDoodads\AshenvaleTrees\AshenvaleTreeCanopy01.m2]], scale = 0.5, checked = false },
            BTtw = { name = "Barrens Tree Wall", wow = [[World\Kalimdor\Barrens\PassiveDoodads\Trees\BarrensTree01.m2]], scale = 0.5, checked = false },
            BTtc = { name = "Barrens Canopy Tree", wow = [[World\Kalimdor\Barrens\PassiveDoodads\Trees\BarrensTree02.m2]], scale = 0.5, checked = false },
            CTtr = { name = "Felwood Tree Wall", wow = [[World\Kalimdor\Felwood\PassiveDoodads\Trees\FelwoodTree01.m2]], scale = 0.5, checked = false },
            CTtc = { name = "Felwood Canopy Tree", wow = [[World\Kalimdor\Felwood\PassiveDoodads\Trees\FelwoodTree02.m2]], scale = 0.5, checked = false },
            FTtw = { name = "Fall Tree Wall", wow = [[World\Lordaeron\TirisfalGlade\PassiveDoodads\Trees\TirisfalTree01.m2]], scale = 0.5, checked = false },
            WTtw = { name = "Winter Tree Wall", wow = [[World\Azeroth\DunMorogh\PassiveDoodads\Trees\DunMoroghTree01.m2]], scale = 0.5, checked = false },
            WTst = { name = "Winter Snowy Tree Wall", wow = [[World\Azeroth\DunMorogh\PassiveDoodads\Trees\DunMoroghTreeSnow01.m2]], scale = 0.5, checked = false },
            NTtw = { name = "Northrend Tree Wall", wow = [[World\Expansion02\Doodads\Dragonblight\Trees\DragonblightTree01.m2]], scale = 0.5, checked = false },
            NTtc = { name = "Northrend Canopy Tree", wow = [[World\Expansion02\Doodads\Dragonblight\Trees\DragonblightTree02.m2]], scale = 0.5, checked = false },
            VTlt = { name = "Village Tree Wall", wow = [[World\Azeroth\Westfall\PassiveDoodads\Trees\WestfallTree01.m2]], scale = 0.5, checked = false },
            YTlb = { name = "Cityscape Tree Wall", wow = [[World\Azeroth\Elwynn\PassiveDoodads\Trees\ElwynnTreeMid01.m2]], scale = 0.5, checked = false },
            YTct = { name = "Cityscape Tree", wow = [[World\Azeroth\Elwynn\PassiveDoodads\Trees\ElwynnTreeMid02.m2]], scale = 0.5, checked = false },
            YTft = { name = "Cityscape Fall Tree", wow = [[World\Lordaeron\TirisfalGlade\PassiveDoodads\Trees\TirisfalTree02.m2]], scale = 0.5, checked = false },
            YTst = { name = "Cityscape Snowy Tree", wow = [[World\Azeroth\DunMorogh\PassiveDoodads\Trees\DunMoroghTreeSnow02.m2]], scale = 0.5, checked = false },
            JTct = { name = "Dalaran Ruins Tree", wow = [[World\Lordaeron\AlteracMountains\PassiveDoodads\Trees\AlteracTree01.m2]], scale = 0.5, checked = false },
            JTtw = { name = "Dalaran Ruins Tree Wall", wow = [[World\Lordaeron\AlteracMountains\PassiveDoodads\Trees\AlteracTree02.m2]], scale = 0.5, checked = false },
            ZTtw = { name = "Ruins Tree Wall", wow = [[World\Kalimdor\Azshara\PassiveDoodads\Trees\AzsharaTree01.m2]], scale = 0.5, checked = false },
            ZTtc = { name = "Ruins Canopy Tree", wow = [[World\Kalimdor\Azshara\PassiveDoodads\Trees\AzsharaTree02.m2]], scale = 0.5, checked = false },
            ITtw = { name = "Icecrown Tree Wall", wow = [[World\Expansion02\Doodads\IcecrownGlacier\Trees\IcecrownTree01.m2]], scale = 0.5, checked = false },
            ITtc = { name = "Icecrown Canopy Tree", wow = [[World\Expansion02\Doodads\IcecrownGlacier\Trees\IcecrownTree02.m2]], scale = 0.5, checked = false },
            OTtw = { name = "Outland Tree Wall", wow = [[World\Expansion01\Doodads\Terokkar\Trees\TerokkarTree01.m2]], scale = 0.5, checked = false },
            KTtw = { name = "Black Citadel Tree Wall", wow = [[World\Expansion01\Doodads\ShadowmoonValley\Trees\ShadowmoonTree01.m2]], scale = 0.5, checked = false },
            DTsh = { name = "Dungeon Mushroom Tree Wall", wow = [[World\Expansion01\Doodads\Zangar\Mushrooms\ZangarMushroom01.m2]], scale = 0.5, checked = false },
            GTsh = { name = "Underground Mushroom Tree Wall", wow = [[World\Expansion01\Doodads\Zangar\Mushrooms\ZangarMushroom02.m2]], scale = 0.5, checked = false },
            -- }}}
            -- {{{ common destructibles
            LTbr = { name = "Barrel", wow = [[World\Generic\Human\Passive Doodads\Barrel\Barrel01.m2]], checked = false },
            LTbx = { name = "Crates", wow = [[World\Generic\Human\Passive Doodads\Crates\Crate01.m2]], checked = false },
            LTcr = { name = "Crate", wow = [[World\Generic\Human\Passive Doodads\Crates\Crate01.m2]], checked = false },
            LTex = { name = "Barrel (explosive)", wow = [[World\Generic\Human\Passive Doodads\Barrel\Barrel01.m2]], checked = false },
            LTba = { name = "Barricade", wow = [[World\Generic\Human\Passive Doodads\Barricades\Barricade01.m2]], checked = false },
            LTrc = { name = "Rock Chunks", wow = [[World\Generic\PassiveDoodads\Rocks\GenericRock01.m2]], checked = false },
            DTrc = { name = "Dungeon Rock Chunks", wow = [[World\Generic\PassiveDoodads\Rocks\GenericRock02.m2]], checked = false },
            -- }}}
        },

        -- by the stock WC3 model a custom type points at (lower case)
        by_model = {
            ["doodads\\terrain\\lordaerontree\\lordaerontree.mdx"] = { name = "Summer Tree", wow = [[World\Azeroth\Elwynn\PassiveDoodads\Trees\ElwynnTreeCanopy01.m2]], scale = 0.5, checked = false },
            ["doodads\\terrain\\ashenvaletree\\ashenvaletree.mdx"] = { name = "Ashenvale Tree", wow = [[World\Kalimdor\Ashenvale\PassiveDoodads\AshenvaleTrees\AshenvaleTree01.m2]], scale = 0.5, checked = false },
            ["doodads\\terrain\\barrenstree\\barrenstree.mdx"] = { name = "Barrens Tree", wow = [[World\Kalimdor\Barrens\PassiveDoodads\Trees\BarrensTree01.m2]], scale = 0.5, checked = false },
            ["doodads\\terrain\\northrendtree\\northrendtree.mdx"] = { name = "Northrend Tree", wow = [[World\Expansion02\Doodads\Dragonblight\Trees\DragonblightTree01.m2]], scale = 0.5, checked = false },
        },

        -- by category letter, then tileset letter (any: every other tileset)
        classes = {
            -- {{{ P: plants
            P = {
                any = { name = "Plant", wow = [[World\Azeroth\Elwynn\PassiveDoodads\Bush\ElwynnBush01.m2]], checked = false },
                A = { name = "Ashenvale plant", wow = [[World\Kalimdor\Ashenvale\PassiveDoodads\Bushes\AshenvaleBush01.m2]], checked = false },
                B = { name = "Barrens plant", wow = [[World\Kalimdor\Barrens\PassiveDoodads\Bushes\BarrensBush01.m2]], checked = false },
                C = { name = "Felwood plant", wow = [[World\Kalimdor\Felwood\PassiveDoodads\Bushes\FelwoodBush01.m2]], checked = false },
                N = { name = "Northrend plant", wow = [[World\Expansion02\Doodads\Dragonblight\Bushes\DragonblightBush01.m2]], checked = false },
                W = { name = "Winter plant", wow = [[World\Azeroth\DunMorogh\PassiveDoodads\Bushes\DunMoroghBush01.m2]], checked = false },
                Z = { name = "Ruins plant", wow = [[World\Kalimdor\Azshara\PassiveDoodads\Bushes\AzsharaBush01.m2]], checked = false },
            },
            -- }}}
            -- {{{ R: rocks
            R = {
                any = { name = "Rock", wow = [[World\Generic\PassiveDoodads\Rocks\GenericRock01.m2]], checked = false },
                A = { name = "Ashenvale rock", wow = [[World\Kalimdor\Ashenvale\PassiveDoodads\Rocks\AshenvaleRock01.m2]], checked = false },
                B = { name = "Barrens rock", wow = [[World\Kalimdor\Barrens\PassiveDoodads\Rocks\BarrensRock01.m2]], checked = false },
                D = { name = "Dungeon rock", wow = [[World\Azeroth\BurningSteppes\PassiveDoodads\Rocks\BurningSteppesRock01.m2]], checked = false },
                G = { name = "Underground rock", wow = [[World\Azeroth\Badlands\PassiveDoodads\Rocks\BadlandsRock01.m2]], checked = false },
                I = { name = "Icecrown rock", wow = [[World\Expansion02\Doodads\IcecrownGlacier\Rocks\IcecrownRock01.m2]], checked = false },
                N = { name = "Northrend rock", wow = [[World\Expansion02\Doodads\Dragonblight\Rocks\DragonblightRock01.m2]], checked = false },
                O = { name = "Outland rock", wow = [[World\Expansion01\Doodads\Hellfire\Rocks\HellfireRock01.m2]], checked = false },
                W = { name = "Winter rock", wow = [[World\Azeroth\DunMorogh\PassiveDoodads\Rocks\DunMoroghRock01.m2]], checked = false },
            },
            -- }}}
        },
    },
    -- }}}

    -- {{{ units (war3mapUnits.doo): creatures' models
    units = {
        -- what a unit type with no row gets, so the server can still spawn it
        -- (counted as unmapped; the W client draws the WC3 model or a wire-frame)
        fallback = { name = "Unmapped unit", wow = [[World\Generic\Human\Passive Doodads\Crates\Crate01.m2]], checked = false },

        types = {
            -- {{{ Human
            hpea = { name = "Peasant", wow = [[Creature\HumanMalePeasant\HumanMalePeasant.m2]], checked = false },
            hfoo = { name = "Footman", wow = [[Creature\HumanMaleGuard\HumanMaleGuard.m2]], scale = 1.5, checked = false },
            hkni = { name = "Knight", wow = [[Creature\HumanMaleKnight\HumanMaleKnight.m2]], scale = 1.5, checked = false },
            hrif = { name = "Rifleman", wow = [[Creature\DwarfMaleWarriorLight\DwarfMaleWarriorLight.m2]], scale = 1.5, checked = false },
            hgry = { name = "Gryphon Rider", wow = [[Creature\Gryphon\Gryphon.m2]], radius = 1.5, reach = 2, checked = false },
            hgyr = { name = "Flying Machine", wow = [[Creature\GnomeCopter\GnomeCopter.m2]], checked = false },
            -- }}}
            -- {{{ Orc
            opeo = { name = "Peon", wow = [[Creature\Peon\Peon.m2]], checked = false },
            ogru = { name = "Grunt", wow = [[Creature\OrcMaleWarriorHeavy\OrcMaleWarriorHeavy.m2]], scale = 1.5, checked = false },
            orai = { name = "Raider", wow = [[Creature\Wolf\Wolf.m2]], radius = 1.5, reach = 2, checked = false },
            okod = { name = "Kodo Beast", wow = [[Creature\KodoBeast\KodoBeast.m2]], radius = 2, reach = 3, checked = false },
            otau = { name = "Tauren", wow = [[Creature\Tauren\Tauren.m2]], scale = 1.3, radius = 1.5, reach = 2, checked = false },
            owyv = { name = "Wind Rider", wow = [[Creature\WindRider\WindRider.m2]], radius = 1.5, reach = 2, checked = false },
            -- }}}
            -- {{{ Undead
            uaco = { name = "Acolyte", wow = [[Creature\Acolyte\Acolyte.m2]], checked = false },
            ugho = { name = "Ghoul", wow = [[Creature\Ghoul\Ghoul.m2]], scale = 1.3, checked = false },
            uabo = { name = "Abomination", wow = [[Creature\Abomination\Abomination.m2]], radius = 2, reach = 3, checked = false },
            ucry = { name = "Crypt Fiend", wow = [[Creature\Nerubian\Nerubian.m2]], radius = 1.5, reach = 2, checked = false },
            ugar = { name = "Gargoyle", wow = [[Creature\Gargoyle\Gargoyle.m2]], checked = false },
            uban = { name = "Banshee", wow = [[Creature\Banshee\Banshee.m2]], checked = false },
            uske = { name = "Skeleton Warrior", wow = [[Creature\Skeleton\Skeleton.m2]], checked = false },
            ufro = { name = "Frost Wyrm", wow = [[Creature\FrostWyrm\FrostWyrm.m2]], radius = 3, reach = 4, checked = false },
            -- }}}
            -- {{{ Night Elf
            ewsp = { name = "Wisp", wow = [[Creature\Wisp\Wisp.m2]], checked = false },
            earc = { name = "Archer", wow = [[Creature\NightElfFemaleArcher\NightElfFemaleArcher.m2]], scale = 1.5, checked = false },
            edry = { name = "Dryad", wow = [[Creature\Dryad\Dryad.m2]], checked = false },
            ehip = { name = "Hippogryph", wow = [[Creature\Hippogryph\Hippogryph.m2]], radius = 1.5, reach = 2, checked = false },
            emtg = { name = "Mountain Giant", wow = [[Creature\MountainGiant\MountainGiant.m2]], radius = 3, reach = 4, checked = false },
            -- }}}
            -- {{{ creeps
            nzom = { name = "Zombie", wow = [[Creature\Zombie\Zombie.m2]], checked = false },
            ngno = { name = "Gnoll", wow = [[Creature\Gnoll\Gnoll.m2]], checked = false },
            nmrl = { name = "Murloc", wow = [[Creature\Murloc\Murloc.m2]], checked = false },
            nkob = { name = "Kobold", wow = [[Creature\Kobold\Kobold.m2]], checked = false },
            nogr = { name = "Ogre", wow = [[Creature\Ogre\Ogre.m2]], radius = 1.5, reach = 2, checked = false },
            nwlf = { name = "Timber Wolf", wow = [[Creature\Wolf\Wolf.m2]], checked = false },
            nspr = { name = "Spider", wow = [[Creature\Spider\Spider.m2]], checked = false },
            nhar = { name = "Harpy", wow = [[Creature\Harpy\Harpy.m2]], checked = false },
            ncen = { name = "Centaur", wow = [[Creature\Centaur\Centaur.m2]], radius = 1.5, reach = 2, checked = false },
            nfrl = { name = "Furbolg", wow = [[Creature\Furbolg\Furbolg.m2]], checked = false },
            nsat = { name = "Satyr", wow = [[Creature\Satyr\Satyr.m2]], checked = false },
            ninf = { name = "Infernal", wow = [[Creature\Infernal\Infernal.m2]], radius = 2, reach = 3, checked = false },
            -- }}}
        },
    },
    -- }}}
}
