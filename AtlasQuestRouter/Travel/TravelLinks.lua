--[[--------------------------------------------------------------------------
  Travel/TravelLinks.lua
  One class per way of travelling. Each link knows how long it takes for a
  given player profile and what it requires (faction, class, cooldown).

  SOLID:
    S - each class owns exactly one travel rule (walking speed, boat wait...)
    O - a new mode (e.g. a Forever portal) is a new subclass + one factory line
    L - every subclass is usable wherever a TravelLink is expected
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local ITravelLink = Class.interface("ITravelLink", { "seconds", "requirements" })

local function distanceUnits(world, a, b)
    local la, lb = world.locations[a], world.locations[b]
    local dx, dy = la.x - lb.x, la.y - lb.y
    return math.sqrt(dx * dx + dy * dy)
end

---------------------------------------------------------------------------
local TravelLink = Class.define("TravelLink")
function TravelLink:init(from, to, spec)
    self.from, self.to = from, to
    self.spec = spec or {}
    self.faction = self.spec.faction or "Neutral"
end
TravelLink.seconds = Class.abstract("TravelLink", "seconds")
--- What the player needs to use this link (checked by the AccessRule chain).
function TravelLink:requirements()
    return { faction = self.faction, class = self.spec.class, cooldown = self.spec.cooldown }
end
function TravelLink:payload(world, profile)
    return { kind = "travel", mode = self.mode, from = self.from, to = self.to }
end

---------------------------------------------------------------------------
local WalkLink = Class.define("WalkLink", TravelLink)
WalkLink.mode = "walk"
WalkLink.ROAD_FACTOR = 1.3     -- roads are not straight lines
function WalkLink:seconds(world, profile)
    local yards = distanceUnits(world, self.from, self.to) * world.YARDS_PER_UNIT * WalkLink.ROAD_FACTOR
    return yards / (profile.groundSpeed or 7)
end

local FlightLink = Class.define("FlightLink", TravelLink)
FlightLink.mode = "flight"
FlightLink.SPEED = 32          -- yards per second on a gryphon / wind rider
FlightLink.CURVE_FACTOR = 1.15
FlightLink.BOARDING = 5
function FlightLink:seconds(world, profile)
    local yards = distanceUnits(world, self.from, self.to) * world.YARDS_PER_UNIT * FlightLink.CURVE_FACTOR
    return FlightLink.BOARDING + yards / FlightLink.SPEED
end

local ScheduledLink = Class.define("ScheduledLink", TravelLink)
function ScheduledLink:seconds()
    -- ride time + expected wait (half of the departure interval)
    return self.spec.ride + self.spec.interval / 2
end

local BoatLink = Class.define("BoatLink", ScheduledLink);         BoatLink.mode = "boat"
local ZeppelinLink = Class.define("ZeppelinLink", ScheduledLink); ZeppelinLink.mode = "zeppelin"
local TramLink = Class.define("TramLink", ScheduledLink);         TramLink.mode = "tram"

local TeleportLink = Class.define("TeleportLink", TravelLink)
TeleportLink.mode = "teleport"
function TeleportLink:seconds() return 10 end   -- cast time

local HearthstoneLink = Class.define("HearthstoneLink", TravelLink)
HearthstoneLink.mode = "hearth"
function HearthstoneLink:init(from, to, spec)
    TravelLink.init(self, from, to, spec)
    self.spec.cooldown = "hearthstone"
end
HearthstoneLink.RESERVE_PENALTY = 300   -- planning-only cost: do not burn the stone on a short walk
function HearthstoneLink:seconds() return 10 end
function HearthstoneLink:payload()
    -- one use per plan: the planner's gate closes every hearth edge after the first one
    return { kind = "travel", mode = self.mode, from = self.from, to = self.to,
             consumable = "hearthstone", penalty = HearthstoneLink.RESERVE_PENALTY }
end

for _, cls in ipairs({ WalkLink, FlightLink, BoatLink, ZeppelinLink, TramLink, TeleportLink, HearthstoneLink }) do
    Class.implements(cls, ITravelLink)
end

ns.ITravelLink = ITravelLink
ns.TravelLink = TravelLink
ns.TravelLinks = {
    Walk = WalkLink, Flight = FlightLink, Boat = BoatLink, Zeppelin = ZeppelinLink,
    Tram = TramLink, Teleport = TeleportLink, Hearthstone = HearthstoneLink,
}
ns.distanceUnits = distanceUnits
