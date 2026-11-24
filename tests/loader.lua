-- tests/loader.lua
-- Loads the addon exactly like the WoW client does: reads the .toc file and
-- runs every listed file with (addonName, namespace) as its varargs.
local Loader = {}

function Loader.load(root)
    root = root or "AtlasQuestRouter"
    local ns = {}
    for line in io.lines(root .. "/AtlasQuestRouter.toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then
            local path = root .. "/" .. line:gsub("\\", "/")
            local chunk = assert(loadfile(path))
            chunk("AtlasQuestRouter", ns)
        end
    end
    return ns
end

--- Parse an FSM file (same regex as savastakan/atlas Util.java), 0-based labels.
function Loader.loadFsm(ns, path)
    local graph = ns.Graph.new()
    local label, start = 0, nil
    for line in io.lines(path) do
        local s, i, o, n = line:match("^(%d*)%s%-%-%s(%d*)%s/%s(%d*)%s%->%s(%d*)")
        if s then
            s, i, o, n = tonumber(s), tonumber(i), tonumber(o), tonumber(n)
            graph:addEdge(s, n, 1, { input = i, output = o }, label)
            if s == 0 and start == nil then start = label end
            label = label + 1
        end
    end
    return graph, start
end

return Loader
