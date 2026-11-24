-- AtlasClassic must reproduce the original Java ATLAS output exactly.
-- Expected outputs were produced by tools/java_reference.sh (real Atlas.java).
return function(ns, T, Loader)
    local cases = {}
    local fixtures = { "bbtas", "r_4_3_1", "r_10_4_2", "r_10_8_3", "r_25_4_4", "r_50_6_5", "r_100_10_6" }
    for _, name in ipairs(fixtures) do
        cases[#cases + 1] = { "identical to Atlas.java on " .. name, function()
            local graph, start = Loader.loadFsm(ns, "tests/fixtures/" .. name .. ".fsm")
            local expected = io.open("tests/fixtures/" .. name .. ".java.txt"):read("*l")
            local actual = ns.AtlasClassic.new():run(graph, start)
            T.eq(actual, expected, name)
        end }
    end
    cases[#cases + 1] = { "JavaHashSet ordering mimics bucket order", function()
        local order = ns.DfsOrderings.JavaHashSet.new():order({ 17, 3, 16, 1 })
        -- capacity 16: buckets 1,3,0,1 -> 16(0), 17(1), 1(1), 3(3)
        T.eq(table.concat(order, ","), "16,17,1,3")
    end }
    return cases
end
