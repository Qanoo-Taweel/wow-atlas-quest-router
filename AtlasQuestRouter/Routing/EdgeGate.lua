--[[--------------------------------------------------------------------------
  Routing/EdgeGate.lua
  Closes edges at planning time. Used for one-use travel such as the
  Hearthstone: once ATLAS walks one hearth edge, every hearth edge closes,
  because the stone is on a 1 hour cooldown for the rest of the plan.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local EdgeGate = Class.define("EdgeGate")

function EdgeGate:init(graph)
    self.graph = graph
    self.closedTokens = {}
end

function EdgeGate:token(label)
    return self.graph:getEdge(label).payload.consumable
end

function EdgeGate:allows(label)
    local t = self:token(label)
    return t == nil or not self.closedTokens[t]
end

function EdgeGate:onTraverse(label)
    local t = self:token(label)
    if t then self.closedTokens[t] = true end
end

ns.EdgeGate = EdgeGate
