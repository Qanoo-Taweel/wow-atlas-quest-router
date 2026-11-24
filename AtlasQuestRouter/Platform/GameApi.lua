--[[--------------------------------------------------------------------------
  Platform/GameApi.lua
  PATTERN: Adapter + Dependency Inversion.

  IGameApi is the ONLY door to the World of Warcraft client. WowGameApi adapts
  the real globals (UnitFactionGroup, GetZoneText, GetQuestLogTitle...) to it;
  tests use StubGameApi. Nothing above this file touches a WoW global, which is
  why the whole planner runs (and is tested) outside the game.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local IGameApi = Class.interface("IGameApi", {
    "playerProfile", "currentLocationName", "questLogTitles", "print", "now",
})

---------------------------------------------------------------------------
local WowGameApi = Class.define("WowGameApi")

function WowGameApi:init(env)
    self.env = env or _G
end

function WowGameApi:playerProfile()
    local G = self.env
    local faction = G.UnitFactionGroup and G.UnitFactionGroup("player") or "Alliance"
    local class
    if G.UnitClass then class = select(2, G.UnitClass("player")) end
    local level = G.UnitLevel and G.UnitLevel("player") or 1
    local bind = G.GetBindLocation and G.GetBindLocation() or nil
    local cooldowns = {}
    if G.GetItemCooldown then
        local start, duration = G.GetItemCooldown(6948)         -- Hearthstone item id
        if start and start > 0 and duration then
            cooldowns.hearthstone = start + duration - G.GetTime()
        end
    end
    -- riding: no API in Forever for "riding skill" that is reliable on all builds,
    -- so we use the player's saved choice (see /aqr speed)
    return { faction = faction, class = class, level = level, bindName = bind, cooldowns = cooldowns }
end

function WowGameApi:currentLocationName()
    local G = self.env
    local sub = G.GetSubZoneText and G.GetSubZoneText() or ""
    local zone = G.GetZoneText and G.GetZoneText() or ""
    return sub, zone
end

--- Titles of quests in the player's quest log (Classic/Forever API).
function WowGameApi:questLogTitles()
    local G = self.env
    local titles = {}
    if not G.GetNumQuestLogEntries then return titles end
    local n = G.GetNumQuestLogEntries()
    for i = 1, n do
        local title, _, _, isHeader = G.GetQuestLogTitle(i)
        if title and not isHeader then titles[#titles + 1] = title end
    end
    return titles
end

function WowGameApi:print(message)
    local frame = self.env.DEFAULT_CHAT_FRAME
    if frame then frame:AddMessage("|cff4fc3f7AtlasQuestRouter|r " .. message)
    else print(message) end
end

function WowGameApi:now()
    return self.env.GetTime and self.env.GetTime() or 0
end

---------------------------------------------------------------------------
--- Test double: everything is configurable, output is captured.
local StubGameApi = Class.define("StubGameApi")

function StubGameApi:init(state)
    self.state = state or {}
    self.printed = {}
end
function StubGameApi:playerProfile()
    local s = self.state
    return { faction = s.faction or "Alliance", class = s.class or "WARRIOR", level = s.level or 30,
             bindName = s.bindName, cooldowns = s.cooldowns or {} }
end
function StubGameApi:currentLocationName() return self.state.subzone or "", self.state.zone or "" end
function StubGameApi:questLogTitles() return self.state.questLog or {} end
function StubGameApi:print(message) self.printed[#self.printed + 1] = message end
function StubGameApi:now() return self.state.time or 0 end

Class.implements(WowGameApi, IGameApi)
Class.implements(StubGameApi, IGameApi)

ns.IGameApi = IGameApi
ns.WowGameApi = WowGameApi
ns.StubGameApi = StubGameApi
