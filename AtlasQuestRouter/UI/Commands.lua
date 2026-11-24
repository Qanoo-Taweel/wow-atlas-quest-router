--[[--------------------------------------------------------------------------
  UI/Commands.lua
  PATTERNS: Command + Chain of Responsibility.

  "/aqr <verb> <args>" travels down a chain of handlers. The first handler
  whose verbs contain <verb> executes it; otherwise it forwards to the next.
  The last link (UnknownCommand) always answers, so nothing is ever lost.

      Help -> Add -> Remove -> List -> Clear -> Plan -> Next -> Back -> Show -> Hide
           -> From -> Speed -> Hearth -> Import -> Demo -> Unknown

  Each handler only talks to the Facade (AtlasQuestRouter), never to the
  planner or the graph directly (Law of Demeter, low coupling).
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local CommandHandler = Class.define("CommandHandler")
CommandHandler.verbs = {}
CommandHandler.usage = ""

function CommandHandler:setNext(handler) self.nextHandler = handler; return handler end

function CommandHandler:canHandle(verb)
    for _, v in ipairs(self.verbs) do if v == verb then return true end end
    return false
end

function CommandHandler:handle(verb, args, router)
    if self:canHandle(verb) then return self:execute(args, router) end
    if self.nextHandler then return self.nextHandler:handle(verb, args, router) end
end
CommandHandler.execute = Class.abstract("CommandHandler", "execute")

--- helper: define a command class in one line
local function command(name, verbs, usage, execute)
    local cls = Class.define(name, CommandHandler)
    cls.verbs, cls.usage, cls.execute = verbs, usage, execute
    return cls
end

local C = {}
C.Help = command("HelpCommand", { "help", "", "?" }, "help - this list", function(self, args, r)
    r:say("Commands (/aqr or /atlasroute):")
    local h = self
    while h do
        if h.usage ~= "" then r:say("  /aqr " .. h.usage) end
        h = h.nextHandler
    end
end)
C.Add = command("AddCommand", { "add", "track" }, "add <quest id or name> - track a quest", function(_, args, r)
    r:addQuest(args)
end)
C.Remove = command("RemoveCommand", { "remove", "rm" }, "remove <quest id> - stop tracking", function(_, args, r)
    r:removeQuest(args)
end)
C.List = command("ListCommand", { "list", "ls" }, "list - tracked quests", function(_, _, r) r:listQuests() end)
C.Clear = command("ClearCommand", { "clear" }, "clear - stop tracking everything", function(_, _, r) r:clearQuests() end)
C.Plan = command("PlanCommand", { "plan", "route" }, "plan - compute the ATLAS route from where you stand", function(_, _, r)
    r:plan()
end)
C.Next = command("NextCommand", { "next", "n", "skip" }, "next - mark the current step done", function(_, _, r) r:nextLeg() end)
C.Back = command("BackCommand", { "back", "prev" }, "back - go back one step", function(_, _, r) r:previousLeg() end)
C.Show = command("ShowCommand", { "show" }, "show - open the guide window", function(_, _, r) r:setGuideVisible(true) end)
C.Hide = command("HideCommand", { "hide" }, "hide - close the guide window", function(_, _, r) r:setGuideVisible(false) end)
C.From = command("FromCommand", { "from" }, "from <place> - plan from a place instead of here", function(_, args, r)
    r:setStartOverride(args)
end)
C.Speed = command("SpeedCommand", { "speed" }, "speed foot|60|100 - your ground speed", function(_, args, r)
    r:setRiding(args)
end)
C.Hearth = command("HearthCommand", { "hearth", "bind" }, "hearth <place> - where your hearthstone is set", function(_, args, r)
    r:setBind(args)
end)
C.Import = command("ImportCommand", { "import" }, "import - track known quests from your quest log", function(_, _, r)
    r:importQuestLog()
end)
C.Demo = command("DemoCommand", { "demo" }, "demo - track a sample quest set for your faction", function(_, _, r)
    r:demo()
end)
C.Unknown = command("UnknownCommand", {}, "", function() end)
function C.Unknown:canHandle() return true end
function C.Unknown:execute(args, r) r:say("Unknown command. Type /aqr help") end

--- Builds the chain in the order shown in the header comment.
local CommandChain = {}
function CommandChain.default()
    local order = { "Help", "Add", "Remove", "List", "Clear", "Plan", "Next", "Back", "Show", "Hide",
                    "From", "Speed", "Hearth", "Import", "Demo", "Unknown" }
    local head, tail
    for _, key in ipairs(order) do
        local handler = C[key].new()
        if not head then head = handler else tail:setNext(handler) end
        tail = handler
    end
    return head
end

--- "/aqr add Kobold Candles" -> verb "add", args "Kobold Candles"
function CommandChain.parse(input)
    input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local verb, args = input:match("^(%S+)%s*(.*)$")
    return (verb or ""):lower(), args or ""
end

ns.CommandHandler = CommandHandler
ns.Commands = C
ns.CommandChain = CommandChain
