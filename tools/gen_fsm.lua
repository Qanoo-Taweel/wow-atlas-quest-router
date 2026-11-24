-- tools/gen_fsm.lua <states> <inputs> <seed>
-- Writes a deterministic random complete FSM in the KISS-like format that
-- savastakan/atlas Util.java reads:  "state -- input / output -> next"
local states, inputs, seed = tonumber(arg[1]) or 10, tonumber(arg[2]) or 4, tonumber(arg[3]) or 1
local x = seed
local function rand(n)            -- tiny LCG, same numbers on every machine
    x = (x * 1103515245 + 12345) % 2147483648
    return x % n
end
for s = 0, states - 1 do
    for i = 0, inputs - 1 do
        -- s+1 for input 0 keeps the machine strongly connected (a ring)
        local nextState = (i == 0) and ((s + 1) % states) or rand(states)
        print(("%d -- %d / %d -> %d"):format(s, i, rand(2), nextState))
    end
end
