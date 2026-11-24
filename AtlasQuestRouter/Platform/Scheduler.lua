--[[--------------------------------------------------------------------------
  Platform/Scheduler.lua
  Runs ATLAS inside a coroutine so a long plan never freezes the game.

  ImmediateScheduler - runs to completion right away (tests, small plans)
  FrameScheduler     - resumes the coroutine once per rendered frame (WoW)
  Both implement IScheduler: run(fn, onDone).
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local IScheduler = Class.interface("IScheduler", { "run" })

local ImmediateScheduler = Class.define("ImmediateScheduler")
function ImmediateScheduler:run(fn, onDone)
    local co = coroutine.create(fn)
    local ok, result
    repeat
        ok, result = coroutine.resume(co)
        if not ok then error(result, 0) end
    until coroutine.status(co) == "dead"
    if onDone then onDone(result) end
    return result
end

local FrameScheduler = Class.define("FrameScheduler")
function FrameScheduler:init(createFrame)
    self.frame = createFrame("Frame")
    self.jobs = {}
    self.frame:SetScript("OnUpdate", function() self:tick() end)
    self.frame:Hide()
end
function FrameScheduler:run(fn, onDone)
    table.insert(self.jobs, { co = coroutine.create(fn), onDone = onDone })
    self.frame:Show()
end
function FrameScheduler:tick()
    local job = self.jobs[1]
    if not job then self.frame:Hide() return end
    local ok, result = coroutine.resume(job.co)
    if not ok then
        table.remove(self.jobs, 1)
        error(result, 0)
    elseif coroutine.status(job.co) == "dead" then
        table.remove(self.jobs, 1)
        if job.onDone then job.onDone(result) end
    end
end

Class.implements(ImmediateScheduler, IScheduler)
Class.implements(FrameScheduler, IScheduler)
ns.IScheduler = IScheduler
ns.ImmediateScheduler = ImmediateScheduler
ns.FrameScheduler = FrameScheduler
