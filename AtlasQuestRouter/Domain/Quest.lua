--[[--------------------------------------------------------------------------
  Domain/Quest.lua
  Quest and QuestStep: plain domain objects. No WoW API, no routing.

  A quest is an ordered list of steps:  accept -> objective(s) -> turn-in.
  Every step happens at a Location id (see Data/WorldData.lua).
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local QuestStep = Class.define("QuestStep")

QuestStep.KIND = { ACCEPT = "accept", OBJECTIVE = "objective", TURN_IN = "turnin" }

function QuestStep:init(quest, index, kind, location, seconds, text)
    self.quest = quest
    self.index = index
    self.kind = kind
    self.location = location
    self.seconds = seconds or 30          -- time spent doing the step
    self.text = text or kind
    self.done = false
end

function QuestStep:id()
    return self.quest.id .. ":" .. self.index
end

function QuestStep:describe()
    local verb = ({ accept = "Accept", objective = "Do", turnin = "Turn in" })[self.kind] or self.kind
    if self.kind == "objective" then
        return ("%s: %s"):format(self.quest.name, self.text)
    end
    return ("%s \"%s\""):format(verb, self.quest.name)
end

local Quest = Class.define("Quest")

--- @param def table { id, name, level, faction, requires = {questId...}, steps = {{kind, at, seconds, text}} }
function Quest:init(def)
    self.id = def.id
    self.name = def.name
    self.level = def.level or 1
    self.faction = def.faction or "Neutral"
    self.zone = def.zone
    self.requires = def.requires or {}
    self.steps = {}
    for i, s in ipairs(def.steps or {}) do
        self.steps[i] = QuestStep.new(self, i, s.kind, s.at, s.seconds, s.text)
    end
end

function Quest:isComplete()
    for _, step in ipairs(self.steps) do
        if not step.done then return false end
    end
    return true
end

function Quest:nextStep()
    for _, step in ipairs(self.steps) do
        if not step.done then return step end
    end
end

ns.Quest = Quest
ns.QuestStep = QuestStep
