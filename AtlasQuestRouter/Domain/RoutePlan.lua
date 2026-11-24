--[[--------------------------------------------------------------------------
  Domain/RoutePlan.lua
  Value object returned by the planner: an ordered list of legs.
  Each leg is either travel (walk/flight/boat/...) or a quest step.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local RoutePlan = Class.define("RoutePlan")

function RoutePlan:init(legs, totalSeconds, meta)
    self.legs = legs or {}
    self.totalSeconds = totalSeconds or 0
    self.meta = meta or {}
    self.cursor = 1
end

function RoutePlan:stepLegs()
    local out = {}
    for _, leg in ipairs(self.legs) do
        if leg.kind == "step" then out[#out + 1] = leg end
    end
    return out
end

function RoutePlan:currentLeg() return self.legs[self.cursor] end

function RoutePlan:advance()
    if self.cursor <= #self.legs then self.cursor = self.cursor + 1 end
    return self:currentLeg()
end

function RoutePlan:isFinished() return self.cursor > #self.legs end

--- "1h 04m", "12m 30s", "45s"
function RoutePlan.formatSeconds(seconds)
    seconds = math.floor((seconds or 0) + 0.5)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    if m > 0 then return ("%dm %02ds"):format(m, s) end
    return ("%ds"):format(s)
end

ns.RoutePlan = RoutePlan
