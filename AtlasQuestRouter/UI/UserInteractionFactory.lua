--[[--------------------------------------------------------------------------
  UI/UserInteractionFactory.lua
  PATTERN: Factory Method (the GoF version: subclasses decide what to create).

      UserInteractionFactory              (abstract creator)
        + createInteractions()            template: asks for each kind
        # createInteraction(kind)         <<factory method>>, abstract
            ^                     ^
      WowUserInteractionFactory   HeadlessUserInteractionFactory
        chat    -> ChatInteraction        chat    -> HeadlessInteraction
        guide   -> GuideInteraction       guide   -> HeadlessInteraction

  Why: the facade needs "something that shows a plan". In the game that is a
  chat printer plus a step-by-step guide window; in tests and in the website export it is an
  in-memory recorder. The facade code is identical in both worlds; only the
  factory object passed to it changes.

  It also generalises user interactions: adding e.g. a minimap button or a
  world-map overlay = one more kind in createInteraction, no facade change.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local UserInteractionFactory = Class.define("UserInteractionFactory")

UserInteractionFactory.KINDS = { "chat", "guide" }

--- Template method: build every interaction the addon uses.
function UserInteractionFactory:createInteractions(callbacks)
    local out = {}
    for _, kind in ipairs(self.KINDS) do
        local interaction = self:createInteraction(kind, callbacks)
        Class.implements(interaction, ns.IUserInteraction)
        out[kind] = interaction
    end
    return out
end

--- The factory method. Subclasses must override.
UserInteractionFactory.createInteraction = Class.abstract("UserInteractionFactory", "createInteraction")

---------------------------------------------------------------------------
local WowUserInteractionFactory = Class.define("WowUserInteractionFactory", UserInteractionFactory)

function WowUserInteractionFactory:init(gameApi, createFrame, uiParent, world)
    self.gameApi, self.createFrame, self.uiParent, self.world = gameApi, createFrame, uiParent, world
end

function WowUserInteractionFactory:createInteraction(kind, callbacks)
    if kind == "chat" then
        return ns.ChatInteraction.new(self.gameApi)
    elseif kind == "guide" then
        return ns.GuideInteraction.new({
            createFrame = self.createFrame, parent = self.uiParent, world = self.world,
            callbacks = callbacks, getFacing = function() return self.gameApi:playerFacing() end,
        })
    end
    error("WowUserInteractionFactory: unknown interaction " .. tostring(kind))
end

---------------------------------------------------------------------------
local HeadlessUserInteractionFactory = Class.define("HeadlessUserInteractionFactory", UserInteractionFactory)

function HeadlessUserInteractionFactory:createInteraction()
    return ns.HeadlessInteraction.new()
end

ns.UserInteractionFactory = UserInteractionFactory
ns.WowUserInteractionFactory = WowUserInteractionFactory
ns.HeadlessUserInteractionFactory = HeadlessUserInteractionFactory
