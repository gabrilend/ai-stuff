--[[
Stock Names (Issue 518b)

Display names for stock unit and ability ids, for objects a map uses
without renaming. WRITTEN FROM MEMORY of the game, like the id table in
demo/wc3map/classify.lua: the game's own string tables are on the owner's
install. Anything not here shows its raw id.
]]

local names = {}

local function list(t, text)
    for id, name in text:gmatch("(%w%w%w%w)=([^;]+);") do t[id] = name end
end

names.UNITS = {}
list(names.UNITS, "hpea=Peasant;hfoo=Footman;hkni=Knight;hrif=Rifleman;hmtm=Mortar Team;" ..
    "hgyr=Flying Machine;hgry=Gryphon Rider;hmpr=Priest;hsor=Sorceress;hspt=Spell Breaker;" ..
    "hdhw=Dragonhawk Rider;hmil=Militia;hwat=Water Elemental;hbsh=Battle Ship;hdes=Frigate;" ..
    "htow=Town Hall;hkee=Keep;hcas=Castle;hhou=Farm;hbar=Barracks;hbla=Blacksmith;" ..
    "hlum=Lumber Mill;harm=Workshop;hars=Arcane Sanctum;hgra=Gryphon Aviary;halt=Altar of Kings;" ..
    "hvlt=Arcane Vault;hwtw=Scout Tower;hgtw=Guard Tower;hctw=Cannon Tower;hatw=Arcane Tower;" ..
    "hshy=Shipyard;hhes=High Elven Swordsman;nhea=High Elven Archer;" ..
    "opeo=Peon;ogru=Grunt;orai=Raider;otau=Tauren;ohun=Headhunter;otbk=Troll Berserker;" ..
    "ocat=Demolisher;oshm=Shaman;odoc=Witch Doctor;owyv=Wind Rider;okod=Kodo Beast;" ..
    "otbr=Troll Batrider;ospw=Spirit Walker;ogre=Great Hall;ostr=Stronghold;ofrt=Fortress;" ..
    "otrb=Orc Burrow;obar=Barracks;ofor=War Mill;obea=Beastiary;osld=Spirit Lodge;" ..
    "otto=Tauren Totem;oalt=Altar of Storms;ovln=Voodoo Lounge;owtw=Watch Tower;oshy=Shipyard;" ..
    "uaco=Acolyte;ugho=Ghoul;uabo=Abomination;ucry=Crypt Fiend;ugar=Gargoyle;umtw=Meat Wagon;" ..
    "unec=Necromancer;uban=Banshee;ufro=Frost Wyrm;uobs=Obsidian Statue;ushd=Shade;" ..
    "uske=Skeleton Warrior;unpl=Necropolis;unp1=Halls of the Dead;unp2=Black Citadel;" ..
    "uzig=Ziggurat;uzg1=Spirit Tower;uzg2=Nerubian Tower;usep=Crypt;ugrv=Graveyard;" ..
    "uslh=Slaughterhouse;utod=Temple of the Damned;ubon=Boneyard;usap=Sacrificial Pit;" ..
    "uaod=Altar of Darkness;utom=Tomb of Relics;ushp=Undead Shipyard;" ..
    "ewsp=Wisp;earc=Archer;esen=Huntress;edry=Dryad;edot=Druid of the Talon;" ..
    "edoc=Druid of the Claw;emtg=Mountain Giant;ehip=Hippogryph;efdr=Faerie Dragon;" ..
    "echm=Chimaera;ebal=Glaive Thrower;etol=Tree of Life;etoa=Tree of Ages;" ..
    "etoe=Tree of Eternity;emow=Moon Well;eaom=Ancient of War;eaoe=Ancient of Lore;" ..
    "eaow=Ancient of Wind;etrp=Ancient Protector;edob=Hunter's Hall;eate=Altar of Elders;" ..
    "eden=Ancient of Wonders;edos=Chimaera Roost;eshy=Night Elf Shipyard;" ..
    "ngol=Gold Mine;nmrk=Marketplace;ntav=Tavern;ngme=Goblin Merchant;ngad=Goblin Laboratory;" ..
    "nfoh=Fountain of Health;nmoo=Fountain of Mana;ntnt=Tent;" ..
    "nban=Bandit;nbrg=Brigand;nrog=Rogue;nenf=Enforcer;nbld=Bandit Lord;nogr=Ogre Warrior;" ..
    "nogm=Ogre Mauler;nomg=Ogre Magi;nogl=Ogre Lord;nftr=Forest Troll;nftb=Forest Troll Berserker;" ..
    "ngnl=Gnoll;ngnb=Gnoll Brute;nkob=Kobold;nwlf=Timber Wolf;nspr=Spider;nmrl=Murloc Tiderunner;" ..
    "nzom=Zombie;nmyr=Naga Myrmidon;nnsw=Naga Siren;nsnp=Snap Dragon;nchg=Chaos Grunt;" ..
    "nchp=Chaos Peon;nass=Assassin;ninf=Infernal;nbal=Doom Guard;nitr=Ice Troll;" ..
    "ncen=Centaur Outrunner;nfgu=Felguard;uktn=Kel'Thuzad;" ..
    "Hpal=Paladin;Hamg=Archmage;Hmkg=Mountain King;Hblm=Blood Mage;Obla=Blademaster;" ..
    "Ofar=Far Seer;Otch=Tauren Chieftain;Oshd=Shadow Hunter;Udea=Death Knight;Ulic=Lich;" ..
    "Udre=Dreadlord;Ucrl=Crypt Lord;Ekee=Keeper of the Grove;Emoo=Priestess of the Moon;" ..
    "Edem=Demon Hunter;Ewar=Warden;")

names.ABILITIES = {}
list(names.ABILITIES, "AHbz=Blizzard;AHwe=Summon Water Elemental;AHab=Brilliance Aura;" ..
    "AHmt=Mass Teleport;AHtb=Storm Bolt;AHtc=Thunder Clap;AHbh=Bash;AHav=Avatar;" ..
    "AHhb=Holy Light;AHds=Divine Shield;AHad=Devotion Aura;AHre=Resurrection;" ..
    "AHfs=Flame Strike;AHbn=Banish;AHdr=Siphon Mana;AHpx=Phoenix;" ..
    "AOwk=Wind Walk;AOmi=Mirror Image;AOcr=Critical Strike;AOww=Bladestorm;" ..
    "AOcl=Chain Lightning;AOfs=Far Sight;AOsf=Feral Spirit;AOeq=Earthquake;AOsh=Shockwave;" ..
    "AOws=War Stomp;AOae=Endurance Aura;AOre=Reincarnation;AOhw=Healing Wave;AOhx=Hex;" ..
    "AOsw=Serpent Ward;AOvd=Big Bad Voodoo;AUdc=Death Coil;AUdp=Death Pact;AUau=Unholy Aura;" ..
    "AUan=Animate Dead;AUfn=Frost Nova;AUfa=Frost Armor;AUdr=Dark Ritual;AUdd=Death and Decay;" ..
    "AUcs=Carrion Swarm;AUsl=Sleep;AUav=Vampiric Aura;AUin=Inferno;AUim=Impale;" ..
    "AUts=Spiked Carapace;AUcb=Carrion Beetles;AUls=Locust Swarm;AEer=Entangling Roots;" ..
    "AEfn=Force of Nature;AEah=Thorns Aura;AEtq=Tranquility;AEst=Scout;AEsf=Starfall;" ..
    "AEar=Trueshot Aura;AEsh=Shadow Strike;AEbl=Blink;AEfk=Fan of Knives;AEsv=Vengeance;" ..
    "AEmb=Mana Burn;AEim=Immolation;AEev=Evasion;AEme=Metamorphosis;" ..
    "Aatk=Attack;Amov=Move;Ahar=Gather;Arep=Repair;AInv=Inventory;")

-- What stock workers build and stock buildings train, for the command
-- card's Build menu and train buttons (from memory, as above)
names.BUILDS = {
    hpea = { "htow", "hhou", "hbar", "hbla", "hlum", "hwtw", "halt", "harm", "hars", "hgra", "hvlt" },
    opeo = { "ogre", "otrb", "obar", "ofor", "oalt", "obea", "osld", "otto", "ovln", "owtw" },
    uaco = { "unpl", "uzig", "usep", "ugrv", "uslh", "utod", "ubon", "usap", "uaod", "utom" },
    ewsp = { "etol", "emow", "eaom", "eaoe", "eaow", "etrp", "edob", "eate", "eden", "edos" },
}
names.TRAINS = {
    htow = { "hpea" }, hkee = { "hpea" }, hcas = { "hpea" }, hbar = { "hfoo", "hrif", "hkni" },
    hars = { "hmpr", "hsor", "hspt" }, harm = { "hgyr", "hmtm" }, hgra = { "hgry", "hdhw" },
    ogre = { "opeo" }, ostr = { "opeo" }, ofrt = { "opeo" }, obar = { "ogru", "ohun", "ocat" },
    obea = { "orai", "okod", "owyv", "otbr" }, osld = { "oshm", "odoc", "ospw" }, otto = { "otau" },
    unpl = { "uaco" }, unp1 = { "uaco" }, unp2 = { "uaco" }, usep = { "ugho", "ucry", "ugar" },
    utod = { "unec", "uban" }, uslh = { "umtw", "uabo", "uobs" }, ubon = { "ufro" },
    etol = { "ewsp" }, etoa = { "ewsp" }, etoe = { "ewsp" }, eaom = { "earc", "esen", "ebal" },
    eaoe = { "edry", "edoc", "emtg" }, eaow = { "ehip", "edot", "efdr" }, edos = { "echm" },
}
-- what stock buildings upgrade to (halls, towers; from memory, as above)
names.UPGRADES = {
    htow = { "hkee" }, hkee = { "hcas" }, hwtw = { "hgtw", "hctw", "hatw" },
    ogre = { "ostr" }, ostr = { "ofrt" },
    unpl = { "unp1" }, unp1 = { "unp2" }, uzig = { "uzg1", "uzg2" },
    etol = { "etoa" }, etoa = { "etoe" },
}

-- what stock buildings research (from memory, as above; the install's
-- tables say for certain)
names.RESEARCHES = {
    hbla = { "Rhme", "Rhar", "Rhra", "Rhla" }, hbar = { "Rhde", "Rhri", "Rhan" },
    hars = { "Rhpt", "Rhst" }, hlum = { "Rhlh", "Rhac" },
    ofor = { "Rome", "Roar", "Rora" }, obar = { "Robs", "Rotr", "Ropg" },
    ugrv = { "Rume", "Ruar", "Rura" }, uslh = { "Rusp", "Rupc" },
    edob = { "Resm", "Resw", "Rerh" }, eaom = { "Reib", "Remk" },
}

-- {{{ names.unit / names.ability
function names.unit(id) return names.UNITS[id] end
function names.ability(id) return names.ABILITIES[id] end
-- }}}

return names
