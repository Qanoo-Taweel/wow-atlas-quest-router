--[[--------------------------------------------------------------------------
  Travel/TravelLinkFactory.lua
  PATTERN: Factory Method (with a registry).

  The graph builder says "make me a 'boat' link from A to B" and receives the
  right TravelLink subclass. It never writes BoatLink.new itself, so adding a
  travel mode never touches the builder (Open/Closed + Dependency Inversion).
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class
local T = ns.TravelLinks

local TravelLinkFactory = Class.define("TravelLinkFactory")

function TravelLinkFactory:init()
    self.creators = {
        walk = T.Walk, flight = T.Flight, boat = T.Boat, zeppelin = T.Zeppelin,
        tram = T.Tram, teleport = T.Teleport, hearth = T.Hearthstone,
    }
end

--- The factory method.
function TravelLinkFactory:create(mode, from, to, spec)
    local cls = self.creators[mode]
    if not cls then error("TravelLinkFactory: unknown travel mode '" .. tostring(mode) .. "'", 2) end
    return cls.new(from, to, spec)
end

function TravelLinkFactory:register(mode, cls)
    Class.implements(cls, ns.ITravelLink)
    self.creators[mode] = cls
end

ns.TravelLinkFactory = TravelLinkFactory
