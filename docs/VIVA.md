# Exam cheat sheet (questions the professor may ask)

**What does the project do?**
A WoW Forever addon that tracks quests and computes the fastest order to do them, including how to travel. The order
comes from the ATLAS algorithm.

**Why is quest routing an ATLAS problem?**
ATLAS covers required *edges* of a graph at low cost (arc routing). We model every quest step as a required self-loop
edge at its place, and every road / flight / boat as an edge weighted in seconds. Covering all required edges with a
cheap walk = doing all quests quickly.

**Explain ATLAS in four sentences.**
From the last edge of the tour we do a DFS and take the reverse post-order: that is a DAG (back edges ignored).
We run a longest-path dynamic program on it: utility grows for each available quest step, cost grows with travel time.
We pick the end edge with the best `utility − cost` (ties broken by the paper's 6-term score) and backtrack `comeFrom`
to get the chain. We append the chain to the tour, mark served steps and repeat until nothing is left.

**Complexity?** One DFS + one DP per iteration = O(|V|+|E|); at most |R| iterations: O(|R|·(|V|+|E|)).
We run 4 DFS orderings per iteration, a constant factor.

**How do you know your ATLAS is correct?** `AtlasClassic.lua` is a port of `Atlas.java`; on 7 FSMs (up to 1,000 edges)
it prints exactly what the Java program prints. The test compares the strings.

**Did you use Dijkstra or A\*?** No. Every route is built by ATLAS. The only extra computation is the distance matrix
that the paper itself prescribes (section 3.4) as an input to the Savings and Proximity score terms.

**Why a Facade?** (`AtlasQuestRouter.lua`) Many callers (commands, buttons, events, tests) and a large subsystem.
The facade gives them one simple API, so changing the planner does not change the callers.

**Why a Factory Method / UserInteractionFactory?** The facade needs to show results, but in the game that is chat + a
window, in tests it is memory. Subclasses of the abstract creator decide what to create; the facade code is the same.

**Why Chain of Responsibility?** Travel permission rules (faction, class, level, cooldown) and slash commands: each
handler deals with what it knows and passes the rest on. Adding a rule or command is one new class.

**Why a Builder?** The world graph has many optional parts that depend on the player. Named steps make it readable
and each step testable.

**Why an Adapter?** WoW functions only exist inside the client. One adapter is the only place that calls them, so the
rest is tested outside the game.

**Where is Open/Closed?** Add a travel mode → subclass `TravelLink` + `TravelLinkFactory:register`. No existing file changes.

**Where is Dependency Inversion?** The facade gets `IGameApi`, `IScheduler`, `UserInteractionFactory` in its
constructor. ATLAS depends on `IRequirementSet`, `IDfsOrdering`, `IScoreComponent`, never on quests or WoW.

**Why does the hearthstone need special handling?** It is a one-use edge (1 h cooldown). `EdgeGate` closes all hearth
edges after the first use, and a DP path may use it at most once.

**What are the limitations?** Heuristic (not always optimal), approximate map, sample quest catalogue, not yet run in a
live client.
