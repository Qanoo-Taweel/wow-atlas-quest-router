--[[--------------------------------------------------------------------------
  Data/QuestData.lua
  Quest catalogue. Each quest: accept -> objective(s) -> turn in.
  `seconds` is the expected time spent on the step itself (killing, looting,
  talking); travel time between steps is what ATLAS minimises.
  `requires` lists quests whose turn-in must happen first (quest chains).
  Titles are matched against the in-game quest log by /aqr import.
----------------------------------------------------------------------------]]
local _, ns = ...

local function q(id, name, faction, level, zone, steps, requires)
    local list = {}
    for i, s in ipairs(steps) do
        list[i] = { kind = s[1], at = s[2], seconds = s[3], text = s[4] }
    end
    return { id = id, name = name, faction = faction, level = level, zone = zone,
             steps = list, requires = requires or {} }
end

local A, H, N = "Alliance", "Horde", "Neutral"
local quests = {
    -- Alliance -------------------------------------------------------------
    q(1001, "Kobold Candles", A, 7, "Elwynn Forest", {
        { "accept", "goldshire", 15 }, { "objective", "fargodeep", 360, "Collect 8 Large Candles" },
        { "turnin", "goldshire", 15 } }),
    q(1002, "Wolves at the Northshire Gate", A, 5, "Elwynn Forest", {
        { "accept", "stormwind", 15 }, { "objective", "northshire", 240, "Slay 10 Timber Wolves" },
        { "turnin", "goldshire", 15 } }),
    q(1003, "Westfall Stew", A, 12, "Westfall", {
        { "accept", "sentinelhill", 15 }, { "objective", "moonbrook", 420, "Gather stew ingredients" },
        { "turnin", "sentinelhill", 15 } }),
    q(1004, "The Defias Brotherhood", A, 14, "Westfall", {
        { "accept", "sentinelhill", 15 }, { "objective", "moonbrook", 300, "Find the Defias hideout" },
        { "turnin", "stormwind", 20 } }, { 1003 }),
    q(1005, "Redridge Goulash", A, 18, "Redridge Mountains", {
        { "accept", "lakeshire", 15 }, { "objective", "stonewatch", 480, "Collect goulash meat" },
        { "turnin", "lakeshire", 15 } }),
    q(1006, "The Night Watch", A, 22, "Duskwood", {
        { "accept", "darkshire", 15 }, { "objective", "ravenhill", 420, "Clear the Raven Hill cemetery" },
        { "turnin", "darkshire", 15 } }),
    q(1007, "Stonesplinter Trouble", A, 12, "Loch Modan", {
        { "accept", "thelsamar", 15 }, { "objective", "stonesplinter", 360, "Defeat Stonesplinter troggs" },
        { "turnin", "thelsamar", 15 } }),
    q(1008, "Across the Thandol Span", A, 28, "Wetlands", {
        { "accept", "menethil", 15 }, { "objective", "thandol", 240, "Scout the Thandol Span" },
        { "turnin", "refugepointe", 15 } }),
    q(1009, "Southshore Bounty", A, 25, "Hillsbrad Foothills", {
        { "accept", "southshore", 15 }, { "objective", "hillsbrad", 420, "Collect farmhand bounties" },
        { "turnin", "southshore", 15 } }),
    q(1010, "Secrets of the Barrow Den", A, 8, "Teldrassil", {
        { "accept", "darnassus", 15 }, { "objective", "banethil", 360, "Recover the druid's satchel" },
        { "turnin", "darnassus", 15 } }),
    q(1011, "Word for Auberdine", A, 10, "Darkshore", {
        { "accept", "darnassus", 15 }, { "turnin", "auberdine", 15 } }, { 1010 }),
    q(1012, "Ashenvale Outrunners", A, 22, "Ashenvale", {
        { "accept", "astranaar", 15 }, { "objective", "blackfathom", 420, "Drive off the naga scouts" },
        { "turnin", "astranaar", 15 } }),
    q(1013, "Witch Hill Investigation", A, 36, "Dustwallow Marsh", {
        { "accept", "theramore", 15 }, { "objective", "witchhill", 420, "Investigate the burned farmhouse" },
        { "turnin", "theramore", 15 } }),
    -- Horde ----------------------------------------------------------------
    q(3001, "Raptor Thieves", H, 14, "The Barrens", {
        { "accept", "crossroads", 15 }, { "objective", "raptorgrounds", 360, "Collect 12 Raptor Heads" },
        { "turnin", "crossroads", 15 } }),
    q(3002, "Serpentbloom", H, 18, "The Barrens", {
        { "accept", "crossroads", 15 }, { "objective", "wailing", 420, "Gather 10 Serpentbloom" },
        { "turnin", "crossroads", 15 } }),
    q(3003, "Plainstrider Menace", H, 6, "Mulgore", {
        { "accept", "bloodhoof", 15 }, { "objective", "redrocks", 300, "Collect plainstrider beaks" },
        { "turnin", "bloodhoof", 15 } }),
    q(3004, "Trolls of the Echo Isles", H, 10, "Durotar", {
        { "accept", "razorhill", 15 }, { "objective", "echoisles", 360, "Defeat Zalazane's followers" },
        { "turnin", "orgrimmar", 20 } }),
    q(3005, "Bael'dun Digging", H, 24, "The Barrens", {
        { "accept", "taurajo", 15 }, { "objective", "baelmodan", 420, "Stop the excavation" },
        { "turnin", "taurajo", 15 } }),
    q(3006, "Agamand Remains", H, 7, "Tirisfal Glades", {
        { "accept", "brill", 15 }, { "objective", "agamand", 360, "Collect the Agamand remains" },
        { "turnin", "brill", 15 } }),
    q(3007, "Pyrewood Ambush", H, 14, "Silverpine Forest", {
        { "accept", "sepulcher", 15 }, { "objective", "pyrewood", 300, "Survive the night ambush" },
        { "turnin", "sepulcher", 15 } }),
    q(3008, "Raid on Hillsbrad Fields", H, 24, "Hillsbrad Foothills", {
        { "accept", "tarrenmill", 15 }, { "objective", "hillsbrad", 420, "Raid the fields" },
        { "turnin", "tarrenmill", 15 } }),
    q(3009, "Call to Arms: Arathi", H, 32, "Arathi Highlands", {
        { "accept", "hammerfall", 15 }, { "objective", "arathicircle", 360, "Read the binding stones" },
        { "turnin", "hammerfall", 15 } }),
    q(3010, "Grom'gol Raptor Hunt", H, 34, "Stranglethorn Vale", {
        { "accept", "gromgol", 15 }, { "objective", "nesingwary", 420, "Hunt jungle raptors" },
        { "turnin", "gromgol", 15 } }),
    q(3011, "Satyr Horns", H, 26, "Ashenvale", {
        { "accept", "splintertree", 15 }, { "objective", "satyrnaar", 420, "Collect satyr horns" },
        { "turnin", "splintertree", 15 } }),
    q(3012, "Report to Orgrimmar", H, 15, "Durotar", {
        { "accept", "crossroads", 15 }, { "turnin", "orgrimmar", 20 } }, { 3001 }),
    q(3013, "Ogres of Dustwallow", H, 38, "Dustwallow Marsh", {
        { "accept", "brackenwall", 15 }, { "objective", "witchhill", 420, "Thin the ogre ranks" },
        { "turnin", "brackenwall", 15 } }),
    -- Neutral --------------------------------------------------------------
    q(2001, "Field Samples of Tanaris", N, 44, "Tanaris", {
        { "accept", "gadgetzan", 15 }, { "objective", "marshals", 300, "Collect crater samples" },
        { "turnin", "gadgetzan", 15 } }),
    q(2002, "Crystals of Fire Plume", N, 50, "Un'Goro Crater", {
        { "accept", "marshals", 15 }, { "objective", "fireplume", 420, "Charge the red crystal" },
        { "turnin", "gadgetzan", 15 } }, { 2001 }),
    q(2003, "Pirate Hats Ahoy", N, 40, "Stranglethorn Vale", {
        { "accept", "bootybay", 15 }, { "objective", "wildshore", 420, "Collect 20 pirate hats" },
        { "turnin", "bootybay", 15 } }),
    q(2004, "Frostsaber Tracks", N, 55, "Winterspring", {
        { "accept", "everlook", 15 }, { "objective", "frostfire", 420, "Track the frostsabers" },
        { "turnin", "everlook", 15 } }),
    q(2005, "Silithid Samples", N, 56, "Silithus", {
        { "accept", "cenarionhold", 15 }, { "objective", "cenarionhold", 420, "Collect silithid carapaces" },
        { "turnin", "cenarionhold", 15 } }),
}

local catalog = {}
for _, def in ipairs(quests) do catalog[def.id] = def end

ns.QuestData = { catalog = catalog, list = quests }
