--[[--------------------------------------------------------------------------
  Data/WorldData.lua
  The World of Warcraft Forever map as a graph description (data only).

  Coordinates are on our own 1000 x 700 overview map (Kalimdor left, Eastern
  Kingdoms right). They are approximations made for routing, not the game's
  map coordinates. 1 map unit ~ 38 yards.

  landmass: places you can walk between (Teldrassil is an island).
  kind:     city | town | flight (flight master only) | spot (quest area)
----------------------------------------------------------------------------]]
local _, ns = ...

local W = {}
W.YARDS_PER_UNIT = 38

-- id = { name, zone, landmass, x, y, kind }
local L = {
    -- Kalimdor -----------------------------------------------------------
    darnassus      = { "Darnassus", "Teldrassil", "Teldrassil", 175, 70, "city" },
    ruttheran      = { "Rut'theran Village", "Teldrassil", "Teldrassil", 200, 98, "town" },
    banethil       = { "Ban'ethil Barrow Den", "Teldrassil", "Teldrassil", 150, 92, "spot" },
    auberdine      = { "Auberdine", "Darkshore", "Kalimdor", 215, 152, "town" },
    moonglade      = { "Nighthaven", "Moonglade", "Kalimdor", 268, 100, "town" },
    everlook       = { "Everlook", "Winterspring", "Kalimdor", 362, 118, "town" },
    frostfire      = { "Frostfire Hot Springs", "Winterspring", "Kalimdor", 330, 92, "spot" },
    talonbranch    = { "Talonbranch Glade", "Felwood", "Kalimdor", 292, 150, "flight" },
    bloodvenom     = { "Bloodvenom Post", "Felwood", "Kalimdor", 258, 188, "flight" },
    blackfathom    = { "Blackfathom Deeps", "Ashenvale", "Kalimdor", 182, 212, "spot" },
    astranaar      = { "Astranaar", "Ashenvale", "Kalimdor", 236, 236, "town" },
    satyrnaar      = { "Satyrnaar", "Ashenvale", "Kalimdor", 332, 222, "spot" },
    splintertree   = { "Splintertree Post", "Ashenvale", "Kalimdor", 305, 246, "town" },
    stonetalonpeak = { "Stonetalon Peak", "Stonetalon Mountains", "Kalimdor", 162, 242, "flight" },
    sunrock        = { "Sun Rock Retreat", "Stonetalon Mountains", "Kalimdor", 190, 286, "town" },
    orgrimmar      = { "Orgrimmar", "Durotar", "Kalimdor", 382, 255, "city" },
    razorhill      = { "Razor Hill", "Durotar", "Kalimdor", 396, 296, "town" },
    echoisles      = { "Echo Isles", "Durotar", "Kalimdor", 410, 326, "spot" },
    crossroads     = { "The Crossroads", "The Barrens", "Kalimdor", 320, 314, "town" },
    raptorgrounds  = { "Raptor Grounds", "The Barrens", "Kalimdor", 345, 350, "spot" },
    wailing        = { "Wailing Caverns", "The Barrens", "Kalimdor", 298, 342, "spot" },
    ratchet        = { "Ratchet", "The Barrens", "Kalimdor", 378, 336, "town" },
    nijels         = { "Nijel's Point", "Desolace", "Kalimdor", 138, 300, "town" },
    shadowprey     = { "Shadowprey Village", "Desolace", "Kalimdor", 92, 358, "town" },
    thunderbluff   = { "Thunder Bluff", "Mulgore", "Kalimdor", 222, 352, "city" },
    redrocks       = { "Red Rocks", "Mulgore", "Kalimdor", 248, 328, "spot" },
    bloodhoof      = { "Bloodhoof Village", "Mulgore", "Kalimdor", 236, 396, "town" },
    taurajo        = { "Camp Taurajo", "The Barrens", "Kalimdor", 300, 386, "town" },
    baelmodan      = { "Bael Modan", "The Barrens", "Kalimdor", 282, 414, "spot" },
    brackenwall    = { "Brackenwall Village", "Dustwallow Marsh", "Kalimdor", 340, 396, "town" },
    witchhill      = { "Witch Hill", "Dustwallow Marsh", "Kalimdor", 362, 380, "spot" },
    theramore      = { "Theramore Isle", "Dustwallow Marsh", "Kalimdor", 388, 418, "town" },
    feathermoon    = { "Feathermoon Stronghold", "Feralas", "Kalimdor", 92, 446, "town" },
    mojache        = { "Camp Mojache", "Feralas", "Kalimdor", 184, 452, "town" },
    thalanaar      = { "Thalanaar", "Feralas", "Kalimdor", 226, 458, "flight" },
    freewind       = { "Freewind Post", "Thousand Needles", "Kalimdor", 292, 462, "town" },
    gadgetzan      = { "Gadgetzan", "Tanaris", "Kalimdor", 350, 530, "town" },
    marshals       = { "Marshal's Refuge", "Un'Goro Crater", "Kalimdor", 270, 545, "town" },
    fireplume      = { "Fire Plume Ridge", "Un'Goro Crater", "Kalimdor", 284, 570, "spot" },
    cenarionhold   = { "Cenarion Hold", "Silithus", "Kalimdor", 190, 582, "town" },
    -- Eastern Kingdoms ---------------------------------------------------
    undercity      = { "Undercity", "Tirisfal Glades", "EasternKingdoms", 680, 116, "city" },
    brill          = { "Brill", "Tirisfal Glades", "EasternKingdoms", 704, 106, "town" },
    agamand        = { "Agamand Mills", "Tirisfal Glades", "EasternKingdoms", 664, 92, "spot" },
    sepulcher      = { "The Sepulcher", "Silverpine Forest", "EasternKingdoms", 664, 176, "town" },
    pyrewood       = { "Pyrewood Village", "Silverpine Forest", "EasternKingdoms", 652, 206, "spot" },
    tarrenmill     = { "Tarren Mill", "Hillsbrad Foothills", "EasternKingdoms", 738, 204, "town" },
    hillsbrad      = { "Hillsbrad Fields", "Hillsbrad Foothills", "EasternKingdoms", 712, 214, "spot" },
    southshore     = { "Southshore", "Hillsbrad Foothills", "EasternKingdoms", 722, 236, "town" },
    chillwind      = { "Chillwind Camp", "Western Plaguelands", "EasternKingdoms", 762, 140, "flight" },
    lightshope     = { "Light's Hope Chapel", "Eastern Plaguelands", "EasternKingdoms", 852, 110, "town" },
    aeriepeak      = { "Aerie Peak", "The Hinterlands", "EasternKingdoms", 790, 190, "town" },
    revantusk      = { "Revantusk Village", "The Hinterlands", "EasternKingdoms", 842, 202, "town" },
    refugepointe   = { "Refuge Pointe", "Arathi Highlands", "EasternKingdoms", 770, 250, "town" },
    hammerfall     = { "Hammerfall", "Arathi Highlands", "EasternKingdoms", 812, 240, "town" },
    arathicircle   = { "Circle of East Binding", "Arathi Highlands", "EasternKingdoms", 792, 266, "spot" },
    thandol        = { "Thandol Span", "Wetlands", "EasternKingdoms", 746, 280, "spot" },
    menethil       = { "Menethil Harbor", "Wetlands", "EasternKingdoms", 724, 302, "town" },
    ironforge      = { "Ironforge", "Dun Morogh", "EasternKingdoms", 770, 346, "city" },
    thelsamar      = { "Thelsamar", "Loch Modan", "EasternKingdoms", 820, 340, "town" },
    stonesplinter  = { "Stonesplinter Valley", "Loch Modan", "EasternKingdoms", 830, 366, "spot" },
    thoriumpoint   = { "Thorium Point", "Searing Gorge", "EasternKingdoms", 764, 404, "flight" },
    kargath        = { "Kargath", "Badlands", "EasternKingdoms", 816, 400, "town" },
    flamecrest     = { "Flame Crest", "Burning Steppes", "EasternKingdoms", 770, 440, "flight" },
    morgansvigil   = { "Morgan's Vigil", "Burning Steppes", "EasternKingdoms", 806, 448, "flight" },
    stormwind      = { "Stormwind City", "Elwynn Forest", "EasternKingdoms", 714, 470, "city" },
    northshire     = { "Northshire Valley", "Elwynn Forest", "EasternKingdoms", 748, 462, "spot" },
    goldshire      = { "Goldshire", "Elwynn Forest", "EasternKingdoms", 734, 488, "town" },
    fargodeep      = { "Fargodeep Mine", "Elwynn Forest", "EasternKingdoms", 726, 504, "spot" },
    lakeshire      = { "Lakeshire", "Redridge Mountains", "EasternKingdoms", 800, 478, "town" },
    stonewatch     = { "Stonewatch Keep", "Redridge Mountains", "EasternKingdoms", 824, 470, "spot" },
    sentinelhill   = { "Sentinel Hill", "Westfall", "EasternKingdoms", 690, 516, "town" },
    moonbrook      = { "Moonbrook", "Westfall", "EasternKingdoms", 678, 546, "spot" },
    darkshire      = { "Darkshire", "Duskwood", "EasternKingdoms", 766, 524, "town" },
    ravenhill      = { "Raven Hill", "Duskwood", "EasternKingdoms", 730, 536, "spot" },
    stonard        = { "Stonard", "Swamp of Sorrows", "EasternKingdoms", 842, 506, "town" },
    nethergarde    = { "Nethergarde Keep", "Blasted Lands", "EasternKingdoms", 862, 546, "town" },
    nesingwary     = { "Nesingwary's Expedition", "Stranglethorn Vale", "EasternKingdoms", 724, 562, "spot" },
    gromgol        = { "Grom'gol Base Camp", "Stranglethorn Vale", "EasternKingdoms", 702, 584, "town" },
    bootybay       = { "Booty Bay", "Stranglethorn Vale", "EasternKingdoms", 716, 652, "town" },
    wildshore      = { "The Wild Shore", "Stranglethorn Vale", "EasternKingdoms", 700, 670, "spot" },
}

W.locations = {}
W.locationOrder = {}
for id, v in pairs(L) do
    W.locations[id] = { id = id, name = v[1], zone = v[2], landmass = v[3], x = v[4], y = v[5], kind = v[6] }
    W.locationOrder[#W.locationOrder + 1] = id
end
table.sort(W.locationOrder)

-- Flight paths: faction -> list of { a, b } (both directions)
W.flights = {
    Alliance = {
        { "stormwind", "ironforge" }, { "stormwind", "sentinelhill" }, { "stormwind", "lakeshire" },
        { "stormwind", "darkshire" }, { "stormwind", "bootybay" }, { "stormwind", "morgansvigil" },
        { "darkshire", "lakeshire" }, { "darkshire", "nethergarde" }, { "lakeshire", "nethergarde" },
        { "morgansvigil", "ironforge" }, { "ironforge", "thelsamar" }, { "ironforge", "menethil" },
        { "ironforge", "thoriumpoint" }, { "thelsamar", "menethil" }, { "menethil", "refugepointe" },
        { "refugepointe", "southshore" }, { "refugepointe", "aeriepeak" }, { "southshore", "aeriepeak" },
        { "southshore", "ironforge" }, { "aeriepeak", "chillwind" }, { "chillwind", "lightshope" },
        { "southshore", "chillwind" },
        { "ruttheran", "auberdine" }, { "auberdine", "astranaar" }, { "auberdine", "stonetalonpeak" },
        { "astranaar", "stonetalonpeak" }, { "stonetalonpeak", "nijels" }, { "nijels", "feathermoon" },
        { "feathermoon", "thalanaar" }, { "astranaar", "theramore" }, { "theramore", "ratchet" },
        { "ratchet", "auberdine" }, { "theramore", "gadgetzan" }, { "gadgetzan", "thalanaar" },
        { "gadgetzan", "cenarionhold" }, { "gadgetzan", "marshals" }, { "marshals", "cenarionhold" },
        { "auberdine", "talonbranch" }, { "talonbranch", "everlook" }, { "astranaar", "talonbranch" },
        { "ruttheran", "moonglade" }, { "moonglade", "everlook" },
    },
    Horde = {
        { "undercity", "sepulcher" }, { "undercity", "tarrenmill" }, { "sepulcher", "tarrenmill" },
        { "tarrenmill", "hammerfall" }, { "hammerfall", "revantusk" }, { "tarrenmill", "revantusk" },
        { "tarrenmill", "lightshope" }, { "undercity", "lightshope" }, { "hammerfall", "kargath" },
        { "kargath", "thoriumpoint" }, { "kargath", "flamecrest" }, { "flamecrest", "stonard" },
        { "kargath", "stonard" }, { "stonard", "gromgol" }, { "gromgol", "bootybay" },
        { "undercity", "kargath" },
        { "orgrimmar", "crossroads" }, { "orgrimmar", "splintertree" }, { "orgrimmar", "thunderbluff" },
        { "orgrimmar", "bloodvenom" }, { "crossroads", "thunderbluff" }, { "crossroads", "ratchet" },
        { "crossroads", "taurajo" }, { "crossroads", "sunrock" }, { "crossroads", "brackenwall" },
        { "crossroads", "gadgetzan" }, { "thunderbluff", "sunrock" }, { "thunderbluff", "taurajo" },
        { "thunderbluff", "freewind" }, { "thunderbluff", "mojache" }, { "sunrock", "shadowprey" },
        { "shadowprey", "mojache" }, { "mojache", "freewind" }, { "freewind", "gadgetzan" },
        { "gadgetzan", "cenarionhold" }, { "gadgetzan", "marshals" }, { "marshals", "cenarionhold" },
        { "bloodvenom", "everlook" }, { "splintertree", "bloodvenom" }, { "everlook", "moonglade" },
        { "bloodvenom", "moonglade" }, { "brackenwall", "taurajo" },
    },
}

-- Scheduled transport: { mode, a, b, rideSeconds, intervalSeconds, faction }
-- expected wait = interval / 2 (you arrive at a random moment)
W.transports = {
    { "boat", "menethil", "theramore", 110, 240, "Alliance" },
    { "boat", "menethil", "auberdine", 120, 240, "Alliance" },
    { "boat", "auberdine", "ruttheran", 60, 180, "Alliance" },
    { "boat", "bootybay", "ratchet", 115, 240, "Neutral" },
    { "zeppelin", "orgrimmar", "undercity", 120, 240, "Horde" },
    { "zeppelin", "orgrimmar", "gromgol", 120, 240, "Horde" },
    { "zeppelin", "undercity", "gromgol", 120, 240, "Horde" },
    { "tram", "stormwind", "ironforge", 70, 60, "Alliance" },
}

-- Class teleports: { class, destination, faction }
W.teleports = {
    { "MAGE", "stormwind", "Alliance" }, { "MAGE", "ironforge", "Alliance" }, { "MAGE", "darnassus", "Alliance" },
    { "MAGE", "orgrimmar", "Horde" }, { "MAGE", "undercity", "Horde" }, { "MAGE", "thunderbluff", "Horde" },
    { "DRUID", "moonglade", "Neutral" },
}

-- Extra walking roads that nearest-neighbour linking would miss
W.roads = {
    { "gromgol", "bootybay" }, { "nesingwary", "gromgol" }, { "darkshire", "stonard" },
    { "menethil", "thandol" }, { "thandol", "refugepointe" }, { "southshore", "tarrenmill" },
    { "undercity", "brill" }, { "moonglade", "talonbranch" }, { "theramore", "brackenwall" },
    { "crossroads", "ratchet" }, { "orgrimmar", "razorhill" }, { "thunderbluff", "bloodhoof" },
    { "gadgetzan", "marshals" }, { "cenarionhold", "marshals" }, { "feathermoon", "mojache" },
    { "shadowprey", "nijels" }, { "darnassus", "ruttheran" },
}

-- Human-readable mode names (used by UI and website)
W.modeLabels = {
    walk = "Walk", flight = "Flight", boat = "Boat", zeppelin = "Zeppelin",
    tram = "Deeprun Tram", teleport = "Teleport", hearth = "Hearthstone",
}

ns.WorldData = W
