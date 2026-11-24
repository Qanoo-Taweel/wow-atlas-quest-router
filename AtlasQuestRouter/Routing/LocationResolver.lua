--[[--------------------------------------------------------------------------
  Routing/LocationResolver.lua
  Turns what the game tells us ("Goldshire", "Elwynn Forest") or what the
  player types ("sw", "booty") into a location id of WorldData.
  SOLID: Single Responsibility - name matching lives here and nowhere else.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local LocationResolver = Class.define("LocationResolver")

LocationResolver.ALIASES = {
    sw = "stormwind", stormwind = "stormwind", ["stormwind city"] = "stormwind",
    ["if"] = "ironforge", org = "orgrimmar", orgrimmar = "orgrimmar", uc = "undercity",
    tb = "thunderbluff", darn = "darnassus", bb = "bootybay", xroads = "crossroads",
}

local RANK = { city = 1, town = 2, flight = 3, spot = 4 }

function LocationResolver:init(world)
    self.world = world
end

function LocationResolver:byText(text)
    if not text or text == "" then return nil end
    local needle = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if self.world.locations[needle] then return needle end
    if LocationResolver.ALIASES[needle] then return LocationResolver.ALIASES[needle] end
    local partial
    for _, id in ipairs(self.world.locationOrder) do
        local name = self.world.locations[id].name:lower()
        if name == needle then return id end
        if not partial and name:find(needle, 1, true) then partial = id end
    end
    return partial
end

--- Best location for the player's current subzone / zone.
function LocationResolver:fromGame(subzone, zone)
    local exact = self:byText(subzone)
    if exact and subzone ~= "" then return exact end
    local best, bestRank
    for _, id in ipairs(self.world.locationOrder) do
        local loc = self.world.locations[id]
        if zone and loc.zone:lower() == zone:lower() then
            local r = RANK[loc.kind] or 9
            if not bestRank or r < bestRank then best, bestRank = id, r end
        end
    end
    return best
end

ns.LocationResolver = LocationResolver
