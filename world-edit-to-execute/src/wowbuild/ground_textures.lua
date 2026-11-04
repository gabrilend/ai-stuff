--[[
ground_textures.lua - which WoW ground texture stands in for each WC3 ground type

Data only (issue W02a): read with loadfile in an empty environment, so it
holds tables, strings, numbers and booleans and nothing else.

A WC3 map paints its ground from up to 16 ground types out of the stock
tilesets (war3map.w3e lists them by id: "Ldrt", "Agrs", "cNc2" ...). The WoW
3.3.5a client paints with BLP textures named by path inside its own
archives. This table says, per WC3 tileset and per ground type, which WoW
texture path the converter writes into a chunk's texture list (MTEX).

Only paths are kept here. The textures themselves are Blizzard's and stay in
the owner's client folder; nothing is copied into this repository or into a
build folder (docs/wow-client-bridge.md, "Decisions made").

Fields of a ground row:
  name     the ground type's name in WC3's World Editor
  wow      the WoW 3.3.5a texture path (backslashes, as the client's archives
           name it)
  rgb      the WC3 ground's colour, roughly (0-255 each); when a chunk needs
           more than four textures, each one past the fourth is folded into
           the kept texture nearest to it by this colour
  checked  false: the path was written from memory of the 3.3.5a archives and
           has not been looked up in the owner's client. Set it true (and
           correct the path if needed) once a listfile or W01's reader shows
           the file is there. W01's archive reader can check every row at
           once; until then every row here is unchecked.

Per tileset:
  name     the tileset's name in the World Editor
  blight   the texture blighted ground uses on a map whose main tileset this is
  grounds  id -> ground row; ids "c<T>c1" and "c<T>c2" are the tileset's two
           cliff textures, which maps may also paint as ground

fallback: what a ground id with no row gets (a custom tileset's own id, or a
typo); every tile point painted with one is counted in the conversion report
as unmapped.
]]

return {
    format = 1,

    fallback = { name = "Unmapped ground", wow = [[Tileset\Generic\Grey.blp]], rgb = { 128, 128, 128 }, checked = false },

    tilesets = {
        -- {{{ A: Ashenvale -> Ashenvale
        A = {
            name = "Ashenvale",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Adrt = { name = "Dirt", wow = [[Tileset\Ashenvale\AshenvaleDirt.blp]], rgb = { 104, 84, 60 }, checked = false },
                Adrd = { name = "Rough Dirt", wow = [[Tileset\Ashenvale\AshenvaleDirtRough.blp]], rgb = { 92, 74, 54 }, checked = false },
                Agrs = { name = "Grass", wow = [[Tileset\Ashenvale\AshenvaleGrass.blp]], rgb = { 54, 92, 52 }, checked = false },
                Arck = { name = "Rock", wow = [[Tileset\Ashenvale\AshenvaleRock.blp]], rgb = { 100, 100, 96 }, checked = false },
                Agrd = { name = "Lumpy Grass", wow = [[Tileset\Ashenvale\AshenvaleGrassDark.blp]], rgb = { 44, 78, 44 }, checked = false },
                Avin = { name = "Vines", wow = [[Tileset\Ashenvale\AshenvaleVines.blp]], rgb = { 48, 70, 36 }, checked = false },
                Adrg = { name = "Grassy Dirt", wow = [[Tileset\Ashenvale\AshenvaleGrassDirt.blp]], rgb = { 80, 86, 54 }, checked = false },
                Alvd = { name = "Leaves", wow = [[Tileset\Ashenvale\AshenvaleLeaves.blp]], rgb = { 110, 76, 48 }, checked = false },
                cAc1 = { name = "Cliff (dirt)", wow = [[Tileset\Ashenvale\AshenvaleRockCliff.blp]], rgb = { 96, 90, 80 }, checked = false },
                cAc2 = { name = "Cliff (grass)", wow = [[Tileset\Ashenvale\AshenvaleRockMoss.blp]], rgb = { 74, 88, 66 }, checked = false },
            },
        },
        -- }}}
        -- {{{ B: Barrens -> The Barrens
        B = {
            name = "Barrens",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Bdrt = { name = "Dirt", wow = [[Tileset\Barrens\BarrensBaseDirt.blp]], rgb = { 150, 112, 70 }, checked = false },
                Bdrh = { name = "Rough Dirt", wow = [[Tileset\Barrens\BarrensDirtRough.blp]], rgb = { 136, 100, 64 }, checked = false },
                Bdrr = { name = "Pebbles", wow = [[Tileset\Barrens\BarrensPebbles.blp]], rgb = { 140, 120, 96 }, checked = false },
                Bdrg = { name = "Grassy Dirt", wow = [[Tileset\Barrens\BarrensGrassDirt.blp]], rgb = { 128, 116, 66 }, checked = false },
                Bdsr = { name = "Desert", wow = [[Tileset\Barrens\BarrensSand.blp]], rgb = { 190, 156, 104 }, checked = false },
                Bdsd = { name = "Dark Desert", wow = [[Tileset\Barrens\BarrensSandDark.blp]], rgb = { 160, 122, 80 }, checked = false },
                Bflr = { name = "Rock", wow = [[Tileset\Barrens\BarrensRock01.blp]], rgb = { 128, 104, 84 }, checked = false },
                Bgrr = { name = "Grass", wow = [[Tileset\Barrens\BarrensBaseGrass.blp]], rgb = { 120, 120, 56 }, checked = false },
                cBc1 = { name = "Cliff (dirt)", wow = [[Tileset\Barrens\BarrensRockCliff.blp]], rgb = { 124, 96, 72 }, checked = false },
                cBc2 = { name = "Cliff (grass)", wow = [[Tileset\Barrens\BarrensRockGrass.blp]], rgb = { 112, 104, 66 }, checked = false },
            },
        },
        -- }}}
        -- {{{ C: Felwood -> Felwood
        C = {
            name = "Felwood",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Cdrt = { name = "Dirt", wow = [[Tileset\Felwood\FelwoodDirt.blp]], rgb = { 84, 70, 56 }, checked = false },
                Cdrd = { name = "Rough Dirt", wow = [[Tileset\Felwood\FelwoodDirtRough.blp]], rgb = { 74, 62, 50 }, checked = false },
                Cpos = { name = "Poison", wow = [[Tileset\Felwood\FelwoodOoze.blp]], rgb = { 80, 120, 40 }, checked = false },
                Crck = { name = "Rock", wow = [[Tileset\Felwood\FelwoodRock.blp]], rgb = { 86, 82, 80 }, checked = false },
                Cvin = { name = "Vines", wow = [[Tileset\Felwood\FelwoodVines.blp]], rgb = { 52, 66, 40 }, checked = false },
                Cgrs = { name = "Grass", wow = [[Tileset\Felwood\FelwoodGrass.blp]], rgb = { 58, 76, 44 }, checked = false },
                Clvg = { name = "Leaves", wow = [[Tileset\Felwood\FelwoodLeaves.blp]], rgb = { 90, 62, 44 }, checked = false },
                cCc1 = { name = "Cliff (dirt)", wow = [[Tileset\Felwood\FelwoodRockCliff.blp]], rgb = { 80, 74, 66 }, checked = false },
                cCc2 = { name = "Cliff (grass)", wow = [[Tileset\Felwood\FelwoodRockMoss.blp]], rgb = { 64, 72, 54 }, checked = false },
            },
        },
        -- }}}
        -- {{{ D: Dungeon -> Burning Steppes
        D = {
            name = "Dungeon",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Ddrt = { name = "Dirt", wow = [[Tileset\BurningSteppes\BurningSteppesDirt.blp]], rgb = { 86, 70, 58 }, checked = false },
                Dbrk = { name = "Brick", wow = [[Tileset\BlackrockMountain\BRMBrick.blp]], rgb = { 104, 84, 74 }, checked = false },
                Drds = { name = "Red Stones", wow = [[Tileset\BurningSteppes\BurningSteppesRedStone.blp]], rgb = { 120, 64, 50 }, checked = false },
                Dlvc = { name = "Lava Cracks", wow = [[Tileset\BurningSteppes\BurningSteppesLavaCrack.blp]], rgb = { 110, 50, 30 }, checked = false },
                Dlav = { name = "Lava", wow = [[Tileset\BurningSteppes\BurningSteppesLava.blp]], rgb = { 200, 80, 20 }, checked = false },
                Ddkr = { name = "Dark Rocks", wow = [[Tileset\BurningSteppes\BurningSteppesRockDark.blp]], rgb = { 50, 46, 46 }, checked = false },
                Dgrs = { name = "Grey Stones", wow = [[Tileset\BurningSteppes\BurningSteppesStone.blp]], rgb = { 100, 100, 100 }, checked = false },
                Dsqd = { name = "Square Tiles", wow = [[Tileset\BlackrockMountain\BRMFloorTile.blp]], rgb = { 96, 90, 86 }, checked = false },
                cDc1 = { name = "Cliff (rock)", wow = [[Tileset\BurningSteppes\BurningSteppesRockCliff.blp]], rgb = { 70, 60, 56 }, checked = false },
                cDc2 = { name = "Cliff (tiles)", wow = [[Tileset\BlackrockMountain\BRMWall.blp]], rgb = { 90, 80, 76 }, checked = false },
            },
        },
        -- }}}
        -- {{{ F: Lordaeron Fall -> Tirisfal Glades
        F = {
            name = "Lordaeron Fall",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Fdrt = { name = "Dirt", wow = [[Tileset\Tirisfal\TirisfalDirt.blp]], rgb = { 110, 86, 60 }, checked = false },
                Fdro = { name = "Rough Dirt", wow = [[Tileset\Tirisfal\TirisfalDirtRough.blp]], rgb = { 98, 78, 56 }, checked = false },
                Fdrg = { name = "Grassy Dirt", wow = [[Tileset\Tirisfal\TirisfalGrassDirt.blp]], rgb = { 112, 96, 56 }, checked = false },
                Frok = { name = "Rock", wow = [[Tileset\Tirisfal\TirisfalRock.blp]], rgb = { 104, 100, 94 }, checked = false },
                Fgrs = { name = "Grass", wow = [[Tileset\Tirisfal\TirisfalGrass.blp]], rgb = { 124, 104, 50 }, checked = false },
                Fgrd = { name = "Dark Grass", wow = [[Tileset\Tirisfal\TirisfalGrassDark.blp]], rgb = { 100, 84, 44 }, checked = false },
                cFc1 = { name = "Cliff (dirt)", wow = [[Tileset\Tirisfal\TirisfalRockCliff.blp]], rgb = { 100, 92, 82 }, checked = false },
                cFc2 = { name = "Cliff (grass)", wow = [[Tileset\Tirisfal\TirisfalRockGrass.blp]], rgb = { 108, 96, 66 }, checked = false },
            },
        },
        -- }}}
        -- {{{ G: Underground -> Badlands
        G = {
            name = "Underground",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Gdrt = { name = "Dirt", wow = [[Tileset\Badlands\BadlandsDirt.blp]], rgb = { 96, 78, 62 }, checked = false },
                Gbrk = { name = "Brick", wow = [[Tileset\Badlands\BadlandsBrick.blp]], rgb = { 104, 86, 76 }, checked = false },
                Grds = { name = "Red Stones", wow = [[Tileset\Badlands\BadlandsRedRock.blp]], rgb = { 124, 70, 54 }, checked = false },
                Glvc = { name = "Lava Cracks", wow = [[Tileset\BurningSteppes\BurningSteppesLavaCrack.blp]], rgb = { 110, 50, 30 }, checked = false },
                Glav = { name = "Lava", wow = [[Tileset\BurningSteppes\BurningSteppesLava.blp]], rgb = { 200, 80, 20 }, checked = false },
                Gdkr = { name = "Dark Rocks", wow = [[Tileset\Badlands\BadlandsRockDark.blp]], rgb = { 56, 50, 48 }, checked = false },
                Ggrs = { name = "Grey Stones", wow = [[Tileset\Badlands\BadlandsStone.blp]], rgb = { 104, 102, 100 }, checked = false },
                Gsqd = { name = "Square Tiles", wow = [[Tileset\Badlands\BadlandsTile.blp]], rgb = { 98, 92, 88 }, checked = false },
                cGc1 = { name = "Cliff (rock)", wow = [[Tileset\Badlands\BadlandsRockCliff.blp]], rgb = { 90, 74, 64 }, checked = false },
                cGc2 = { name = "Cliff (tiles)", wow = [[Tileset\Badlands\BadlandsRockLayered.blp]], rgb = { 100, 84, 72 }, checked = false },
            },
        },
        -- }}}
        -- {{{ I: Icecrown Glacier -> Icecrown
        I = {
            name = "Icecrown Glacier",
            blight = { name = "Blight", wow = [[Tileset\Expansion02\Icecrown\IcecrownBlight.blp]], rgb = { 70, 60, 90 }, checked = false },
            grounds = {
                Idrt = { name = "Dirt", wow = [[Tileset\Expansion02\Icecrown\IcecrownDirt.blp]], rgb = { 96, 92, 100 }, checked = false },
                Idtr = { name = "Rough Dirt", wow = [[Tileset\Expansion02\Icecrown\IcecrownDirtRough.blp]], rgb = { 86, 82, 92 }, checked = false },
                Idki = { name = "Dark Ice", wow = [[Tileset\Expansion02\Icecrown\IcecrownIceDark.blp]], rgb = { 70, 90, 120 }, checked = false },
                Ibkb = { name = "Black Bricks", wow = [[Tileset\Expansion02\Icecrown\IcecrownBrickBlack.blp]], rgb = { 40, 40, 48 }, checked = false },
                Irbk = { name = "Runed Bricks", wow = [[Tileset\Expansion02\Icecrown\IcecrownBrickRune.blp]], rgb = { 60, 70, 90 }, checked = false },
                Itbk = { name = "Tiled Bricks", wow = [[Tileset\Expansion02\Icecrown\IcecrownBrickTile.blp]], rgb = { 80, 84, 96 }, checked = false },
                Iice = { name = "Ice", wow = [[Tileset\Expansion02\Icecrown\IcecrownIce.blp]], rgb = { 150, 180, 210 }, checked = false },
                Ibsq = { name = "Black Squares", wow = [[Tileset\Expansion02\Icecrown\IcecrownTileBlack.blp]], rgb = { 36, 38, 46 }, checked = false },
                Isnw = { name = "Snow", wow = [[Tileset\Expansion02\Icecrown\IcecrownSnow.blp]], rgb = { 220, 226, 236 }, checked = false },
                cIc1 = { name = "Cliff (rock)", wow = [[Tileset\Expansion02\Icecrown\IcecrownRockCliff.blp]], rgb = { 90, 92, 104 }, checked = false },
                cIc2 = { name = "Cliff (snow)", wow = [[Tileset\Expansion02\Icecrown\IcecrownRockSnow.blp]], rgb = { 170, 176, 190 }, checked = false },
            },
        },
        -- }}}
        -- {{{ J: Dalaran Ruins -> Alterac Mountains
        J = {
            name = "Dalaran Ruins",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Jdrt = { name = "Dirt", wow = [[Tileset\Alterac\AlteracDirt.blp]], rgb = { 104, 88, 66 }, checked = false },
                Jdtr = { name = "Rough Dirt", wow = [[Tileset\Alterac\AlteracDirtRough.blp]], rgb = { 94, 80, 62 }, checked = false },
                Jblm = { name = "Black Marble", wow = [[Tileset\Alterac\AlteracMarbleDark.blp]], rgb = { 50, 50, 56 }, checked = false },
                Jbtl = { name = "Brick", wow = [[Tileset\Alterac\AlteracBrick.blp]], rgb = { 120, 90, 76 }, checked = false },
                Jsqd = { name = "Square Tiles", wow = [[Tileset\Alterac\AlteracTileSquare.blp]], rgb = { 110, 104, 96 }, checked = false },
                Jrtl = { name = "Round Tiles", wow = [[Tileset\Alterac\AlteracTileRound.blp]], rgb = { 116, 108, 98 }, checked = false },
                Jgsb = { name = "Grass", wow = [[Tileset\Alterac\AlteracGrass.blp]], rgb = { 70, 96, 56 }, checked = false },
                Jhdg = { name = "Grass Trim", wow = [[Tileset\Alterac\AlteracGrassDark.blp]], rgb = { 56, 84, 48 }, checked = false },
                Jwmb = { name = "White Marble", wow = [[Tileset\Alterac\AlteracMarbleWhite.blp]], rgb = { 196, 192, 184 }, checked = false },
                cJc1 = { name = "Cliff (dirt)", wow = [[Tileset\Alterac\AlteracRockCliff.blp]], rgb = { 96, 90, 82 }, checked = false },
                cJc2 = { name = "Cliff (tiles)", wow = [[Tileset\Alterac\AlteracRuinWall.blp]], rgb = { 110, 104, 96 }, checked = false },
            },
        },
        -- }}}
        -- {{{ K: Black Citadel -> Shadowmoon Valley
        K = {
            name = "Black Citadel",
            blight = { name = "Blight", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonBlight.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Kdrt = { name = "Dirt", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonDirt.blp]], rgb = { 70, 64, 62 }, checked = false },
                Kfsl = { name = "Light Dirt", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonDirtLight.blp]], rgb = { 96, 88, 82 }, checked = false },
                Kdtr = { name = "Rough Dirt", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonDirtRough.blp]], rgb = { 62, 56, 54 }, checked = false },
                Kfst = { name = "Flat Stones", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonStoneFlat.blp]], rgb = { 80, 76, 76 }, checked = false },
                Ksmb = { name = "Small Bricks", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonBrickSmall.blp]], rgb = { 64, 58, 58 }, checked = false },
                Klgb = { name = "Large Bricks", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonBrickLarge.blp]], rgb = { 72, 66, 64 }, checked = false },
                Ksqt = { name = "Square Tiles", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonTile.blp]], rgb = { 84, 78, 76 }, checked = false },
                Kdkt = { name = "Dark Tiles", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonTileDark.blp]], rgb = { 44, 40, 42 }, checked = false },
                cKc1 = { name = "Cliff (rock)", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonRockCliff.blp]], rgb = { 60, 54, 54 }, checked = false },
                cKc2 = { name = "Cliff (tiles)", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonRockFel.blp]], rgb = { 66, 80, 50 }, checked = false },
            },
        },
        -- }}}
        -- {{{ L: Lordaeron Summer -> Elwynn Forest
        L = {
            name = "Lordaeron Summer",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Ldrt = { name = "Dirt", wow = [[Tileset\Elwynn\ElwynnDirtBase.blp]], rgb = { 120, 94, 62 }, checked = false },
                Ldro = { name = "Rough Dirt", wow = [[Tileset\Elwynn\ElwynnDirtMud.blp]], rgb = { 104, 82, 58 }, checked = false },
                Ldrg = { name = "Grassy Dirt", wow = [[Tileset\Elwynn\ElwynnGrassDirt.blp]], rgb = { 100, 100, 60 }, checked = false },
                Lrok = { name = "Rock", wow = [[Tileset\Elwynn\ElwynnRockBase.blp]], rgb = { 112, 110, 104 }, checked = false },
                Lgrs = { name = "Grass", wow = [[Tileset\Elwynn\ElwynnGrassBase.blp]], rgb = { 70, 112, 50 }, checked = false },
                Lgrd = { name = "Dark Grass", wow = [[Tileset\Elwynn\ElwynnGrassHighlight.blp]], rgb = { 54, 92, 40 }, checked = false },
                cLc1 = { name = "Cliff (dirt)", wow = [[Tileset\Elwynn\ElwynnRockCliff.blp]], rgb = { 104, 98, 88 }, checked = false },
                cLc2 = { name = "Cliff (grass)", wow = [[Tileset\Elwynn\ElwynnRockMoss.blp]], rgb = { 84, 100, 70 }, checked = false },
            },
        },
        -- }}}
        -- {{{ N: Northrend -> Dragonblight
        N = {
            name = "Northrend",
            blight = { name = "Blight", wow = [[Tileset\Expansion02\Icecrown\IcecrownBlight.blp]], rgb = { 70, 60, 90 }, checked = false },
            grounds = {
                Ndrt = { name = "Dirt", wow = [[Tileset\Expansion02\Dragonblight\DragonblightDirt.blp]], rgb = { 100, 90, 80 }, checked = false },
                Ndrd = { name = "Dark Dirt", wow = [[Tileset\Expansion02\Dragonblight\DragonblightDirtDark.blp]], rgb = { 74, 66, 60 }, checked = false },
                Nrck = { name = "Rock", wow = [[Tileset\Expansion02\Dragonblight\DragonblightRock.blp]], rgb = { 108, 108, 112 }, checked = false },
                Ngrs = { name = "Grass", wow = [[Tileset\Expansion02\GrizzlyHills\GrizzlyHillsGrass.blp]], rgb = { 80, 96, 66 }, checked = false },
                Nice = { name = "Ice", wow = [[Tileset\Expansion02\Dragonblight\DragonblightIce.blp]], rgb = { 160, 190, 214 }, checked = false },
                Nsnw = { name = "Snow", wow = [[Tileset\Expansion02\Dragonblight\DragonblightSnow.blp]], rgb = { 224, 230, 238 }, checked = false },
                Nsnr = { name = "Rocky Snow", wow = [[Tileset\Expansion02\Dragonblight\DragonblightSnowRock.blp]], rgb = { 180, 184, 192 }, checked = false },
                cNc1 = { name = "Cliff (rock)", wow = [[Tileset\Expansion02\Dragonblight\DragonblightRockCliff.blp]], rgb = { 104, 104, 110 }, checked = false },
                cNc2 = { name = "Cliff (snow)", wow = [[Tileset\Expansion02\Dragonblight\DragonblightRockSnow.blp]], rgb = { 176, 180, 190 }, checked = false },
            },
        },
        -- }}}
        -- {{{ O: Outland -> Hellfire Peninsula
        O = {
            name = "Outland",
            blight = { name = "Blight", wow = [[Tileset\Expansion01\ShadowmoonValley\ShadowmoonBlight.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Odrt = { name = "Dirt", wow = [[Tileset\Expansion01\Hellfire\HellfireDirt.blp]], rgb = { 130, 74, 48 }, checked = false },
                Odtr = { name = "Light Dirt", wow = [[Tileset\Expansion01\Hellfire\HellfireDirtLight.blp]], rgb = { 156, 96, 62 }, checked = false },
                Osmb = { name = "Rough Dirt", wow = [[Tileset\Expansion01\Hellfire\HellfireDirtRough.blp]], rgb = { 118, 68, 46 }, checked = false },
                Ofst = { name = "Cracked Dirt", wow = [[Tileset\Expansion01\Hellfire\HellfireDirtCracked.blp]], rgb = { 140, 80, 50 }, checked = false },
                Olgb = { name = "Flat Stones", wow = [[Tileset\Expansion01\Hellfire\HellfireStoneFlat.blp]], rgb = { 112, 84, 70 }, checked = false },
                Orok = { name = "Rock", wow = [[Tileset\Expansion01\Hellfire\HellfireRock.blp]], rgb = { 100, 70, 58 }, checked = false },
                Ofsl = { name = "Light Flat Stones", wow = [[Tileset\Expansion01\Hellfire\HellfireStoneLight.blp]], rgb = { 140, 112, 94 }, checked = false },
                Oaby = { name = "Abyss", wow = [[Tileset\Expansion01\Netherstorm\NetherstormVoid.blp]], rgb = { 20, 10, 30 }, checked = false },
                cOc1 = { name = "Cliff (rock)", wow = [[Tileset\Expansion01\Hellfire\HellfireRockCliff.blp]], rgb = { 104, 70, 56 }, checked = false },
                cOc2 = { name = "Cliff (dirt)", wow = [[Tileset\Expansion01\Hellfire\HellfireRockLayered.blp]], rgb = { 120, 78, 56 }, checked = false },
            },
        },
        -- }}}
        -- {{{ Q: Village Fall -> Duskwood
        Q = {
            name = "Village Fall",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Qdrt = { name = "Dirt", wow = [[Tileset\Duskwood\DuskwoodDirt.blp]], rgb = { 96, 80, 60 }, checked = false },
                Qdrr = { name = "Rough Dirt", wow = [[Tileset\Duskwood\DuskwoodDirtRough.blp]], rgb = { 86, 72, 56 }, checked = false },
                Qcrp = { name = "Crops", wow = [[Tileset\Duskwood\DuskwoodFarmland.blp]], rgb = { 120, 96, 56 }, checked = false },
                Qcbp = { name = "Cobble Path", wow = [[Tileset\Duskwood\DuskwoodCobblestone.blp]], rgb = { 104, 98, 90 }, checked = false },
                Qstp = { name = "Stone Path", wow = [[Tileset\Duskwood\DuskwoodStonePath.blp]], rgb = { 112, 106, 98 }, checked = false },
                Qgrs = { name = "Short Grass", wow = [[Tileset\Duskwood\DuskwoodGrass.blp]], rgb = { 100, 94, 50 }, checked = false },
                Qrck = { name = "Rocks", wow = [[Tileset\Duskwood\DuskwoodRock.blp]], rgb = { 96, 94, 90 }, checked = false },
                Qgrt = { name = "Thick Grass", wow = [[Tileset\Duskwood\DuskwoodGrassDark.blp]], rgb = { 84, 80, 44 }, checked = false },
                cQc1 = { name = "Cliff (dirt)", wow = [[Tileset\Duskwood\DuskwoodRockCliff.blp]], rgb = { 92, 86, 78 }, checked = false },
                cQc2 = { name = "Cliff (grass)", wow = [[Tileset\Duskwood\DuskwoodRockMoss.blp]], rgb = { 86, 86, 64 }, checked = false },
            },
        },
        -- }}}
        -- {{{ V: Village -> Westfall
        V = {
            name = "Village",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Vdrt = { name = "Dirt", wow = [[Tileset\Westfall\WestfallDirt.blp]], rgb = { 128, 102, 70 }, checked = false },
                Vdrr = { name = "Rough Dirt", wow = [[Tileset\Westfall\WestfallDirtRough.blp]], rgb = { 114, 92, 64 }, checked = false },
                Vcrp = { name = "Crops", wow = [[Tileset\Westfall\WestfallFarmland.blp]], rgb = { 140, 116, 64 }, checked = false },
                Vcbp = { name = "Cobble Path", wow = [[Tileset\Elwynn\ElwynnCobblestoneBase.blp]], rgb = { 116, 110, 102 }, checked = false },
                Vstp = { name = "Stone Path", wow = [[Tileset\Westfall\WestfallStonePath.blp]], rgb = { 124, 118, 108 }, checked = false },
                Vgrs = { name = "Short Grass", wow = [[Tileset\Westfall\WestfallGrass.blp]], rgb = { 112, 120, 56 }, checked = false },
                Vrck = { name = "Rocks", wow = [[Tileset\Westfall\WestfallRock.blp]], rgb = { 112, 108, 100 }, checked = false },
                Vgrt = { name = "Thick Grass", wow = [[Tileset\Westfall\WestfallGrassThick.blp]], rgb = { 96, 108, 48 }, checked = false },
                cVc1 = { name = "Cliff (dirt)", wow = [[Tileset\Westfall\WestfallRockCliff.blp]], rgb = { 112, 100, 86 }, checked = false },
                cVc2 = { name = "Cliff (grass)", wow = [[Tileset\Westfall\WestfallRockGrass.blp]], rgb = { 100, 104, 70 }, checked = false },
            },
        },
        -- }}}
        -- {{{ W: Lordaeron Winter -> Dun Morogh
        W = {
            name = "Lordaeron Winter",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Wdrt = { name = "Dirt", wow = [[Tileset\DunMorogh\DunMoroghDirt.blp]], rgb = { 104, 90, 76 }, checked = false },
                Wdro = { name = "Rough Dirt", wow = [[Tileset\DunMorogh\DunMoroghDirtRough.blp]], rgb = { 94, 82, 70 }, checked = false },
                Wsng = { name = "Grassy Snow", wow = [[Tileset\DunMorogh\DunMoroghSnowGrass.blp]], rgb = { 180, 190, 180 }, checked = false },
                Wrok = { name = "Rock", wow = [[Tileset\DunMorogh\DunMoroghRock.blp]], rgb = { 110, 110, 114 }, checked = false },
                Wgrs = { name = "Grass", wow = [[Tileset\DunMorogh\DunMoroghGrass.blp]], rgb = { 90, 104, 76 }, checked = false },
                Wsnw = { name = "Snow", wow = [[Tileset\DunMorogh\DunMoroghSnow.blp]], rgb = { 226, 230, 236 }, checked = false },
                cWc1 = { name = "Cliff (dirt)", wow = [[Tileset\DunMorogh\DunMoroghRockCliff.blp]], rgb = { 104, 102, 104 }, checked = false },
                cWc2 = { name = "Cliff (snow)", wow = [[Tileset\DunMorogh\DunMoroghRockSnow.blp]], rgb = { 180, 184, 190 }, checked = false },
            },
        },
        -- }}}
        -- {{{ X: Dalaran -> Dalaran (Northrend)
        X = {
            name = "Dalaran",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Xdrt = { name = "Dirt", wow = [[Tileset\Expansion02\Dalaran\DalaranDirt.blp]], rgb = { 108, 92, 72 }, checked = false },
                Xdtr = { name = "Rough Dirt", wow = [[Tileset\Expansion02\Dalaran\DalaranDirtRough.blp]], rgb = { 98, 84, 66 }, checked = false },
                Xblm = { name = "Black Marble", wow = [[Tileset\Expansion02\Dalaran\DalaranMarbleDark.blp]], rgb = { 54, 52, 60 }, checked = false },
                Xbtl = { name = "Brick", wow = [[Tileset\Expansion02\Dalaran\DalaranBrick.blp]], rgb = { 124, 96, 84 }, checked = false },
                Xsqd = { name = "Square Tiles", wow = [[Tileset\Expansion02\Dalaran\DalaranTileSquare.blp]], rgb = { 120, 112, 120 }, checked = false },
                Xrtl = { name = "Round Tiles", wow = [[Tileset\Expansion02\Dalaran\DalaranTileRound.blp]], rgb = { 126, 116, 124 }, checked = false },
                Xgsb = { name = "Grass", wow = [[Tileset\Expansion02\Dalaran\DalaranGrass.blp]], rgb = { 76, 104, 60 }, checked = false },
                Xhdg = { name = "Grass Trim", wow = [[Tileset\Expansion02\Dalaran\DalaranGrassTrim.blp]], rgb = { 62, 92, 52 }, checked = false },
                Xwmb = { name = "White Marble", wow = [[Tileset\Expansion02\Dalaran\DalaranMarbleWhite.blp]], rgb = { 204, 200, 206 }, checked = false },
                cXc1 = { name = "Cliff (dirt)", wow = [[Tileset\Expansion02\Dalaran\DalaranRockCliff.blp]], rgb = { 100, 94, 90 }, checked = false },
                cXc2 = { name = "Cliff (tiles)", wow = [[Tileset\Expansion02\Dalaran\DalaranWall.blp]], rgb = { 120, 112, 120 }, checked = false },
            },
        },
        -- }}}
        -- {{{ Y: Cityscape -> Stormwind
        Y = {
            name = "Cityscape",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Ydrt = { name = "Dirt", wow = [[Tileset\Stormwind\StormwindDirt.blp]], rgb = { 112, 94, 72 }, checked = false },
                Ydtr = { name = "Rough Dirt", wow = [[Tileset\Stormwind\StormwindDirtRough.blp]], rgb = { 100, 86, 68 }, checked = false },
                Yblm = { name = "Black Marble", wow = [[Tileset\Stormwind\StormwindMarbleDark.blp]], rgb = { 52, 52, 58 }, checked = false },
                Ybtl = { name = "Brick", wow = [[Tileset\Stormwind\StormwindBrick.blp]], rgb = { 126, 98, 82 }, checked = false },
                Ysqd = { name = "Square Tiles", wow = [[Tileset\Stormwind\StormwindTileSquare.blp]], rgb = { 128, 122, 114 }, checked = false },
                Yrtl = { name = "Round Tiles", wow = [[Tileset\Stormwind\StormwindTileRound.blp]], rgb = { 132, 126, 118 }, checked = false },
                Ygsb = { name = "Grass", wow = [[Tileset\Stormwind\StormwindGrass.blp]], rgb = { 74, 108, 54 }, checked = false },
                Yhdg = { name = "Grass Trim", wow = [[Tileset\Stormwind\StormwindGrassTrim.blp]], rgb = { 60, 94, 46 }, checked = false },
                Ywmb = { name = "White Marble", wow = [[Tileset\Stormwind\StormwindMarbleWhite.blp]], rgb = { 206, 202, 196 }, checked = false },
                cYc1 = { name = "Cliff (dirt)", wow = [[Tileset\Stormwind\StormwindRockCliff.blp]], rgb = { 106, 100, 92 }, checked = false },
                cYc2 = { name = "Cliff (tiles)", wow = [[Tileset\Stormwind\StormwindWall.blp]], rgb = { 124, 118, 110 }, checked = false },
            },
        },
        -- }}}
        -- {{{ Z: Sunken Ruins -> Azshara
        Z = {
            name = "Sunken Ruins",
            blight = { name = "Blight", wow = [[Tileset\Felwood\FelwoodCorruptedGround.blp]], rgb = { 70, 50, 80 }, checked = false },
            grounds = {
                Zdrt = { name = "Dirt", wow = [[Tileset\Azshara\AzsharaDirt.blp]], rgb = { 118, 100, 74 }, checked = false },
                Zdtr = { name = "Rough Dirt", wow = [[Tileset\Azshara\AzsharaDirtRough.blp]], rgb = { 106, 90, 68 }, checked = false },
                Zdrg = { name = "Grassy Dirt", wow = [[Tileset\Azshara\AzsharaGrassDirt.blp]], rgb = { 96, 100, 64 }, checked = false },
                Zbks = { name = "Small Bricks", wow = [[Tileset\Azshara\AzsharaBrickSmall.blp]], rgb = { 110, 112, 104 }, checked = false },
                Zsan = { name = "Sand", wow = [[Tileset\Tanaris\TanarisSandBase01.blp]], rgb = { 196, 172, 120 }, checked = false },
                Zbkl = { name = "Large Bricks", wow = [[Tileset\Azshara\AzsharaBrickLarge.blp]], rgb = { 116, 118, 110 }, checked = false },
                Ztil = { name = "Round Tiles", wow = [[Tileset\Azshara\AzsharaTile.blp]], rgb = { 120, 124, 116 }, checked = false },
                Zgrs = { name = "Grass", wow = [[Tileset\Azshara\AzsharaGrass.blp]], rgb = { 70, 104, 64 }, checked = false },
                Zvin = { name = "Dark Grass", wow = [[Tileset\Azshara\AzsharaGrassDark.blp]], rgb = { 52, 84, 52 }, checked = false },
                cZc1 = { name = "Cliff (dirt)", wow = [[Tileset\Azshara\AzsharaRockCliff.blp]], rgb = { 106, 100, 90 }, checked = false },
                cZc2 = { name = "Cliff (grass)", wow = [[Tileset\Azshara\AzsharaRockMoss.blp]], rgb = { 84, 100, 76 }, checked = false },
            },
        },
        -- }}}
    },
}
