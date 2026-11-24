--[[--------------------------------------------------------------------------
  Platform/GameEventBridge.lua
  Turns raw World of Warcraft events into the facade's guide calls, so the
  guide advances by itself, like a leveling guide addon:

      QUEST_ACCEPTED(index)          -> router:onQuestAccepted(title)
      QUEST_COMPLETE + QUEST_TURNED_IN -> router:onQuestTurnedIn(title)
      QUEST_LOG_UPDATE               -> router:onObjectivesComplete(title)  (for finished quests)
      ZONE_CHANGED*                  -> router:onArrived(place)             (exact subzone match)

  PATTERNS: Adapter (WoW event vocabulary -> domain vocabulary) and Observer
  (it listens; the facade does not know about WoW events).
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local GameEventBridge = Class.define("GameEventBridge")

GameEventBridge.EVENTS = {
    "QUEST_ACCEPTED", "QUEST_COMPLETE", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
    "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
}

function GameEventBridge:init(router, gameApi, resolver)
    self.router, self.api, self.resolver = router, gameApi, resolver
    self.pendingTurnIn = nil
end

function GameEventBridge:handle(event, arg1)
    if event == "QUEST_ACCEPTED" then
        local title = self.api:questTitleAt(arg1)
        if title then self.router:onQuestAccepted(title) end
    elseif event == "QUEST_COMPLETE" then
        self.pendingTurnIn = self.api:questDialogTitle()     -- turn-in window opened
    elseif event == "QUEST_TURNED_IN" then
        if self.pendingTurnIn then self.router:onQuestTurnedIn(self.pendingTurnIn) end
        self.pendingTurnIn = nil
    elseif event == "QUEST_LOG_UPDATE" then
        for _, entry in ipairs(self.api:questLogEntries()) do
            if entry.complete then self.router:onObjectivesComplete(entry.title) end
        end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" then
        local subzone = self.api:currentLocationName()
        local place = self.resolver:exactSubzone(subzone)
        if place then self.router:onArrived(place) end
    end
end

--- Register on a real WoW frame.
function GameEventBridge:attach(frame)
    for _, event in ipairs(GameEventBridge.EVENTS) do frame:RegisterEvent(event) end
end

ns.GameEventBridge = GameEventBridge
