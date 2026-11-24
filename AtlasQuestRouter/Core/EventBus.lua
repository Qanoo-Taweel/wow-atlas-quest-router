--[[--------------------------------------------------------------------------
  Core/EventBus.lua
  PATTERN: Observer (publish / subscribe).

  Why: the QuestLog should not know that a tracker frame, a chat printer or a
  test exists. It just publishes "QUEST_ADDED"; whoever cares subscribes.
  SOLID: Open/Closed. New listeners are added without editing the publisher.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local EventBus = Class.define("EventBus")

function EventBus:init()
    self.listeners = {}
end

--- Subscribe to an event. Returns an unsubscribe function.
function EventBus:subscribe(eventName, callback)
    local list = self.listeners[eventName]
    if not list then
        list = {}
        self.listeners[eventName] = list
    end
    table.insert(list, callback)
    return function()
        for i = #list, 1, -1 do
            if list[i] == callback then table.remove(list, i) end
        end
    end
end

--- Publish an event to every subscriber, in subscription order.
function EventBus:publish(eventName, ...)
    local list = self.listeners[eventName]
    if not list then return 0 end
    -- copy so listeners may unsubscribe while we iterate
    local snapshot = {}
    for i = 1, #list do snapshot[i] = list[i] end
    for i = 1, #snapshot do snapshot[i](...) end
    return #snapshot
end

ns.EventBus = EventBus
