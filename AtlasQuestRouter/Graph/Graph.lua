--[[--------------------------------------------------------------------------
  Graph/Graph.lua
  Directed multigraph whose *edges* carry the meaning (arc routing).

  Port of Graph.java / Edge.java from savastakan/atlas, extended with:
  * edge weights in seconds (travel time) and a payload (travel mode, quest step)
  * in/out degree bookkeeping needed by the ATLAS connectivity score (paper eq. 1)
  * deterministic iteration order (arrays, never `pairs`) so a plan is reproducible

  SOLID: Single Responsibility. The graph stores topology only. It knows
  nothing about quests, factions or WoW. Those live in Domain/ and Travel/.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

---------------------------------------------------------------------------
-- Edge: a value object
---------------------------------------------------------------------------
local Edge = Class.define("Edge")

function Edge:init(label, source, destination, weight, payload)
    self.label = label             -- unique integer id (1..n)
    self.source = source           -- node id
    self.destination = destination -- node id
    self.weight = weight or 1      -- cost (seconds for the world graph, 1 for FSMs)
    self.payload = payload or {}   -- free data: { kind = "flight", ... }
end

function Edge:isLoop()
    return self.source == self.destination
end

---------------------------------------------------------------------------
-- Graph
---------------------------------------------------------------------------
local Graph = Class.define("Graph")

function Graph:init()
    self.nodeOrder = {}   -- node ids in insertion order
    self.nodeData = {}    -- id -> arbitrary data
    self.outEdges = {}    -- id -> { label, label, ... } in insertion order
    self.inCount = {}     -- id -> number of incoming edges
    self.edges = {}       -- label -> Edge
    self.edgeTotal = 0
end

function Graph:addNode(id, data)
    if self.nodeData[id] == nil then
        table.insert(self.nodeOrder, id)
        self.nodeData[id] = data or {}
        self.outEdges[id] = {}
        self.inCount[id] = 0
    end
    return id
end

function Graph:hasNode(id)
    return self.nodeData[id] ~= nil
end

--- Add a directed edge. Missing endpoints are created (like Graph.java).
-- Labels may be given explicitly (FSM files use 0-based labels) or auto-assigned.
function Graph:addEdge(source, destination, weight, payload, label)
    self:addNode(source)
    self:addNode(destination)
    self.edgeTotal = self.edgeTotal + 1
    label = label or self.edgeTotal
    local edge = Edge.new(label, source, destination, weight, payload)
    self.edges[label] = edge
    table.insert(self.outEdges[source], label)
    self.inCount[destination] = self.inCount[destination] + 1
    return label
end

function Graph:getEdge(label) return self.edges[label] end
function Graph:getNode(id) return self.nodeData[id] end
function Graph:nodes() return self.nodeOrder end
function Graph:edgeCount() return self.edgeTotal end
function Graph:nodeCount() return #self.nodeOrder end

--- Labels of the edges leaving `node` (successor edges in arc-routing terms).
function Graph:edgesFrom(node)
    return self.outEdges[node] or {}
end

--- Labels of edges that may follow edge `label` in a walk.
function Graph:successors(label)
    return self:edgesFrom(self.edges[label].destination)
end

function Graph:outDegree(node) return #(self.outEdges[node] or {}) end
function Graph:inDegree(node) return self.inCount[node] or 0 end

--- Iterate all edges in label order: for label, edge in graph:eachEdge() do
function Graph:eachEdge()
    local labels = {}
    for label in pairs(self.edges) do labels[#labels + 1] = label end
    table.sort(labels)
    local i = 0
    return function()
        i = i + 1
        local label = labels[i]
        if label ~= nil then return label, self.edges[label] end
    end
end

ns.Edge = Edge
ns.Graph = Graph
