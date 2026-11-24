-- tests/run.lua : tiny xUnit-style runner (no dependencies, Lua 5.1)
--   lua5.1 tests/run.lua            run every spec
--   lua5.1 tests/run.lua atlas      run specs whose file name contains "atlas"
package.path = "tests/?.lua;" .. package.path
local Loader = require("loader")

local filter = arg[1]
local specs = { "spec_core", "spec_atlas_classic", "spec_atlas_solver", "spec_patterns",
                "spec_planner", "spec_facade" }

local passed, failed, failures = 0, 0, {}
local T = {}
function T.eq(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. (": expected %s, got %s"):format(tostring(expected), tostring(actual)), 2)
    end
end
function T.ok(value, message) if not value then error(message or "expected truthy value", 2) end end
function T.raises(fn, message)
    if pcall(fn) then error(message or "expected an error", 2) end
end

for _, name in ipairs(specs) do
    if not filter or name:find(filter, 1, true) then
        local ns = Loader.load()
        local cases = require(name)(ns, T, Loader)
        for _, case in ipairs(cases) do
            local ok, err = pcall(case[2])
            if ok then passed = passed + 1; io.write(".")
            else failed = failed + 1; io.write("F"); failures[#failures + 1] = name .. " > " .. case[1] .. "\n    " .. tostring(err) end
        end
    end
end
print(("\n%d passed, %d failed"):format(passed, failed))
for _, f in ipairs(failures) do print("FAIL " .. f) end
os.exit(failed == 0 and 0 or 1)
