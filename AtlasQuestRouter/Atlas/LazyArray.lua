--[[--------------------------------------------------------------------------
  Atlas/LazyArray.lua
  "Lazy Array Reset" from the ATLAS paper (Kabaca, Samir, Takan, section 3.4).

  ATLAS runs one dynamic-programming pass per iteration. Re-creating the
  pathLong / cost / comeFrom arrays every time costs O(|E|). Instead we remember
  which indices were touched and reset only those: O(k), k = edges visited.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local LazyArray = Class.define("LazyArray")

function LazyArray:init(default)
    self.default = default
    self.values = {}
    self.touched = {}
    self.touchedCount = 0
end

function LazyArray:get(index)
    local value = self.values[index]
    if value == nil then return self.default end
    return value
end

function LazyArray:set(index, value)
    if self.values[index] == nil then
        self.touchedCount = self.touchedCount + 1
        self.touched[self.touchedCount] = index
    end
    self.values[index] = value
end

function LazyArray:has(index)
    return self.values[index] ~= nil
end

--- O(k) reset: only the indices written since the last reset are cleared.
function LazyArray:reset()
    local values, touched = self.values, self.touched
    for i = 1, self.touchedCount do
        values[touched[i]] = nil
        touched[i] = nil
    end
    self.touchedCount = 0
end

ns.LazyArray = LazyArray
