--[[--------------------------------------------------------------------------
  UI/UserInteraction.lua
  Every way the addon talks to the player is a UserInteraction:

    ChatInteraction      - prints to the chat frame
    GuideInteraction     - the step-by-step guide window with an arrow
    HeadlessInteraction  - collects output in memory (tests, website export)

  The facade only knows the abstract UserInteraction (Liskov + Dependency
  Inversion); concrete ones are created by the UserInteractionFactory.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local IUserInteraction = Class.interface("IUserInteraction", { "notify", "showPlan", "showProgress" })

local UserInteraction = Class.define("UserInteraction")
UserInteraction.notify = Class.abstract("UserInteraction", "notify")
function UserInteraction:showPlan(plan, lines) end          -- optional hooks: default no-op
function UserInteraction:showProgress(plan, lines) end
function UserInteraction:setVisible(visible) end

---------------------------------------------------------------------------
local ChatInteraction = Class.define("ChatInteraction", UserInteraction)
function ChatInteraction:init(gameApi) self.api = gameApi end
function ChatInteraction:notify(message) self.api:print(message) end
function ChatInteraction:showPlan(plan, lines)
    self.api:print(("ATLAS route: %d legs, %s total (%d iterations, %.0f ms)"):format(
        #plan.legs, ns.RoutePlan.formatSeconds(plan.totalSeconds), plan.meta.iterations or 0, plan.meta.elapsedMs or 0))
    for i = 1, math.min(#lines, 8) do self.api:print(lines[i]) end
    if #lines > 8 then self.api:print(("... %d more steps in the guide window (/aqr show)"):format(#lines - 8)) end
end
function ChatInteraction:showProgress(plan, lines)
    local leg = lines[plan.cursor]
    if leg then self.api:print("Next: " .. leg) else self.api:print("Route finished. Well done!") end
end

---------------------------------------------------------------------------
local HeadlessInteraction = Class.define("HeadlessInteraction", UserInteraction)
function HeadlessInteraction:init() self.messages, self.plans, self.visible = {}, {}, false end
function HeadlessInteraction:notify(message) self.messages[#self.messages + 1] = message end
function HeadlessInteraction:showPlan(plan, lines) self.plans[#self.plans + 1] = { plan = plan, lines = lines } end
function HeadlessInteraction:showProgress(plan, lines) self.lastProgress = plan.cursor end
function HeadlessInteraction:setVisible(v) self.visible = v end

Class.implements(ChatInteraction, IUserInteraction)
Class.implements(HeadlessInteraction, IUserInteraction)

ns.IUserInteraction = IUserInteraction
ns.UserInteraction = UserInteraction
ns.ChatInteraction = ChatInteraction
ns.HeadlessInteraction = HeadlessInteraction
