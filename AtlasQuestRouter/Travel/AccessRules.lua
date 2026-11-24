--[[--------------------------------------------------------------------------
  Travel/AccessRules.lua
  PATTERN: Chain of Responsibility.

  "Can THIS player use THIS travel link?" is answered by a chain of small
  handlers. Each handler either rejects (and the chain stops) or passes the
  request to the next one:

      FactionRule -> ClassRule -> LevelRule -> CooldownRule -> (allowed)

  Why: the rules are independent and the list grows (riding skill, reputation,
  Forever-specific unlocks...). Adding one = one new class + one link in the
  chain; nothing else changes. Each rule has a single responsibility.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local AccessRule = Class.define("AccessRule")

function AccessRule:init() self.nextRule = nil end

--- Link the next handler; returns it so chains read left to right.
function AccessRule:setNext(rule)
    self.nextRule = rule
    return rule
end

--- Template: run this rule, then delegate.
function AccessRule:handle(link, profile)
    local ok, reason = self:check(link, profile)
    if not ok then return false, reason end
    if self.nextRule then return self.nextRule:handle(link, profile) end
    return true
end
AccessRule.check = Class.abstract("AccessRule", "check")

---------------------------------------------------------------------------
local FactionRule = Class.define("FactionRule", AccessRule)
function FactionRule:check(link, profile)
    local need = link:requirements().faction
    if need == "Neutral" or need == nil or need == profile.faction then return true end
    return false, "faction " .. need
end

local ClassRule = Class.define("ClassRule", AccessRule)
function ClassRule:check(link, profile)
    local need = link:requirements().class
    if need == nil or need == profile.class then return true end
    return false, "class " .. need
end

local LevelRule = Class.define("LevelRule", AccessRule)
function LevelRule:check(link, profile)
    local need = link.spec.minLevel
    if need == nil or (profile.level or 60) >= need then return true end
    return false, "level " .. need
end

local CooldownRule = Class.define("CooldownRule", AccessRule)
function CooldownRule:check(link, profile)
    local cd = link:requirements().cooldown
    if cd == nil then return true end
    local remaining = profile.cooldowns and profile.cooldowns[cd] or 0
    if remaining <= 0 then return true end
    return false, cd .. " on cooldown"
end

--- Builds the default chain. Kept in one place so the order is visible.
local AccessRuleChain = {}
function AccessRuleChain.default()
    local head = FactionRule.new()
    head:setNext(ClassRule.new()):setNext(LevelRule.new()):setNext(CooldownRule.new())
    return head
end

ns.AccessRule = AccessRule
ns.AccessRules = { Faction = FactionRule, Class = ClassRule, Level = LevelRule, Cooldown = CooldownRule }
ns.AccessRuleChain = AccessRuleChain
