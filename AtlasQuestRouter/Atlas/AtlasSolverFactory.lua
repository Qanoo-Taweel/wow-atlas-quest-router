--[[--------------------------------------------------------------------------
  Atlas/AtlasSolverFactory.lua
  PATTERN: Factory Method. Callers ask for a solver *profile* by name and get
  a fully wired IRouteSolver; they never call AtlasSolver.new with a dozen
  options themselves.

  Profiles (all of them are ATLAS, there is no other routing algorithm):
    "quest"   - weighted ATLAS + paper scoring + 4 DFS orderings (addon default)
    "fast"    - weighted ATLAS, single cheapest-first ordering (low-end PCs)
    "paper"   - weighted ATLAS + paper scoring, single ordering (closest to Algorithm 1)
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class
local O = ns.DfsOrderings

local AtlasSolverFactory = Class.define("AtlasSolverFactory")

AtlasSolverFactory.profiles = {
    quest = function()
        return ns.AtlasSolver.new({
            scorer = ns.EdgeScorer.paperDefault(),
            orderings = { O.CheapestFirst.new(), O.RequiredFirst.new(),
                          O.Insertion.new(), O.ExpensiveFirst.new() },
        })
    end,
    fast = function()
        return ns.AtlasSolver.new({ orderings = { O.CheapestFirst.new() } })
    end,
    paper = function()
        return ns.AtlasSolver.new({
            scorer = ns.EdgeScorer.paperDefault(),
            orderings = { O.Insertion.new() },
        })
    end,
}

--- Factory method.
function AtlasSolverFactory.create(profile)
    local build = AtlasSolverFactory.profiles[profile or "quest"]
    if not build then
        error("Unknown ATLAS profile: " .. tostring(profile), 2)
    end
    return build()
end

--- Extension point (Open/Closed): register a new profile without editing this file.
function AtlasSolverFactory.register(name, builder)
    AtlasSolverFactory.profiles[name] = builder
end

ns.AtlasSolverFactory = AtlasSolverFactory
