--[[--------------------------------------------------------------------------
  Domain/QuestLog.lua
  PATTERN: Repository (+ Observer through EventBus).

  Holds the quests the player is tracking. Publishes events so the guide window
  and the planner react without the log knowing about them.
  SOLID: Single Responsibility (storage of tracked quests only).
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local QuestLog = Class.define("QuestLog")

QuestLog.EVENTS = {
    ADDED = "QUEST_ADDED", REMOVED = "QUEST_REMOVED",
    STEP_DONE = "QUEST_STEP_DONE", CLEARED = "QUEST_LOG_CLEARED",
}

function QuestLog:init(eventBus, catalog)
    self.bus = eventBus
    self.catalog = catalog or {}     -- id -> quest definition (Data/QuestData.lua)
    self.quests = {}                 -- tracked Quest objects, in order
    self.byId = {}
end

function QuestLog:findDefinition(idOrName)
    local asNumber = tonumber(idOrName)
    if asNumber and self.catalog[asNumber] then return self.catalog[asNumber] end
    local needle = tostring(idOrName):lower()
    for _, def in pairs(self.catalog) do
        if def.name:lower() == needle then return def end
    end
    for _, def in pairs(self.catalog) do
        if def.name:lower():find(needle, 1, true) then return def end
    end
end

function QuestLog:add(idOrName)
    local def = self:findDefinition(idOrName)
    if not def then return nil, "unknown quest: " .. tostring(idOrName) end
    if self.byId[def.id] then return self.byId[def.id], "already tracked" end
    local quest = ns.Quest.new(def)
    table.insert(self.quests, quest)
    self.byId[quest.id] = quest
    self.bus:publish(QuestLog.EVENTS.ADDED, quest)
    return quest
end

function QuestLog:remove(id)
    local quest = self.byId[tonumber(id) or id]
    if not quest then return false end
    for i = #self.quests, 1, -1 do
        if self.quests[i] == quest then table.remove(self.quests, i) end
    end
    self.byId[quest.id] = nil
    self.bus:publish(QuestLog.EVENTS.REMOVED, quest)
    return true
end

function QuestLog:clear()
    self.quests, self.byId = {}, {}
    self.bus:publish(QuestLog.EVENTS.CLEARED)
end

function QuestLog:get(id) return self.byId[id] end
function QuestLog:all() return self.quests end
function QuestLog:count() return #self.quests end

function QuestLog:markStepDone(step)
    if step and not step.done then
        step.done = true
        self.bus:publish(QuestLog.EVENTS.STEP_DONE, step)
    end
end

--- Persist only ids + done flags (SavedVariables must stay small).
function QuestLog:serialize()
    local out = {}
    for _, quest in ipairs(self.quests) do
        local done = {}
        for i, step in ipairs(quest.steps) do done[i] = step.done end
        out[#out + 1] = { id = quest.id, done = done }
    end
    return out
end

function QuestLog:restore(saved)
    for _, entry in ipairs(saved or {}) do
        local quest = self:add(entry.id)
        if quest and entry.done then
            for i, step in ipairs(quest.steps) do step.done = entry.done[i] and true or false end
        end
    end
end

ns.QuestLog = QuestLog
