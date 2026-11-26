# Design patterns in Atlas Quest Router

For each pattern: **what** it is (one sentence), **where** it is, **why** we used it here, and **what would go wrong without it**.
The file names are clickable; every file also starts with a comment that repeats the "why".

---

## 1. Facade — `AtlasQuestRouter/AtlasQuestRouter.lua`

**What:** one simple interface in front of a complicated subsystem.

**Where:** class `AtlasQuestRouter` with `addQuest`, `removeQuest`, `listQuests`, `importQuestLog`, `plan`, `nextLeg`,
`setStartOverride`, `setRiding`, `setBind`, `runCommand`, `save`, `load`.

**Why here:** planning a route touches the quest log, the location resolver, the world graph builder, the travel link
factory, the access rule chain, the distance matrix, the ATLAS solver factory, the scheduler and two kinds of output.
Slash commands, guide window buttons, game events and tests would all need to know that order. With the facade they call
`router:plan()` and nothing else.

**Without it:** every command handler would repeat the same 10-line setup and break whenever the planner changes.

## 2. Factory Method — `AtlasQuestRouter/UI/UserInteractionFactory.lua`

**What:** a creator class declares a method that returns a product; subclasses decide which concrete product.

**Where:** abstract `UserInteractionFactory` with the template method `createInteractions()` that calls the factory
method `createInteraction(kind)`. `WowUserInteractionFactory` returns `ChatInteraction` and `GuideInteraction` (the step-by-step guide window);
`HeadlessUserInteractionFactory` returns `HeadlessInteraction` (in-memory, for tests).

**Why here:** the facade must "show the plan to the user", but in the game that means chat + the guide window and in tests it
means recording to memory. The facade receives a factory and never names a concrete UI class, so
`UserInteractionFactory` generalises every user interaction behind `IUserInteraction`.

**Without it:** `if inGame then ... else ... end` would be spread over the facade, and tests would need fake frames.

## 3. Factory Method (registry form) — `Travel/TravelLinkFactory.lua`, `Atlas/AtlasSolverFactory.lua`

**Where:** `TravelLinkFactory:create(mode, from, to, spec)` returns `WalkLink`, `FlightLink`, `BoatLink`, ...;
`AtlasSolverFactory.create("quest" | "fast" | "paper")` returns a fully configured `AtlasSolver`.

**Why here:** the graph builder works with *modes* coming from data files ("boat"), not with classes.
New modes / profiles are added with `register()` (Open/Closed).

## 4. Chain of Responsibility — `Travel/AccessRules.lua`

**What:** a request passes along a chain of handlers; each either handles it or passes it on.

**Where:** `FactionRule → ClassRule → LevelRule → CooldownRule`. `AccessRule:handle(link, profile)` runs `check`,
stops with a reason if it fails, otherwise calls the next rule.

**Why here:** "may this character use this boat / portal / hearthstone?" depends on several independent rules and the
list will grow (reputation, Forever unlocks). Each rule is a small class; the order is visible in
`AccessRuleChain.default()`.

## 5. Command + Chain of Responsibility — `UI/Commands.lua`

**Where:** every `/aqr` verb is a `CommandHandler` subclass (`AddCommand`, `PlanCommand`, ...). They are linked in a
chain ending with `UnknownCommand`, which always answers. `HelpCommand` walks the chain to print the usage of every
command, so help is never out of date.

**Why here:** adding a command never touches a big `if/elseif` switch.

## 6. Builder — `Routing/WorldGraphBuilder.lua`

**Where:** `reset(profile):addLocations():addWalkingNetwork():addFlightNetwork():addTransports():addTeleports():addHearthstone():addQuestSteps(quests):setStart(place):result()`.

**Why here:** the routing graph is complex and depends on the player. Building it in named steps makes each step
testable (the walking-connectivity test uses only the first two) and keeps the constructor of `Graph` simple.

## 7. Strategy — `Atlas/DfsOrderings.lua`, `Atlas/ScoreComponents.lua`

**Where:** `CheapestFirstOrdering`, `RequiredFirstOrdering`, `InsertionOrdering`, `ExpensiveFirstOrdering`,
`JavaHashSetOrdering` all implement `IDfsOrdering:order()`. The six score terms of the paper implement `IScoreComponent:score()`.

**Why here:** ATLAS is the same algorithm whatever the DFS order or scoring term; making them strategies lets the
solver stay unchanged while we reproduce Java exactly (`JavaHashSetOrdering`) or improve game routes (4 orderings).

## 8. Composite — `Atlas/EdgeScorer.lua`

**Where:** `EdgeScorer` implements `IScoreComponent` and contains `IScoreComponent`s; `score()` sums them.

**Why here:** the solver asks one object for `score(e)` and does not care that it is six heuristics with adaptive weights.

## 9. Observer — `Core/EventBus.lua` used by `Domain/QuestLog.lua`

**Where:** `QuestLog` publishes `QUEST_ADDED`, `QUEST_REMOVED`, `QUEST_LOG_CLEARED`, `QUEST_STEP_DONE`.
The facade subscribes and throws away the current plan when the quest set changes.

**Why here:** the quest log must not depend on the UI or the planner (Dependency Inversion).

## 10. Adapter — `Platform/GameApi.lua`, `Platform/GameEventBridge.lua`

**Where:** `IGameApi` (`playerProfile`, `currentLocationName`, `questLogTitles`, `print`, `now`);
`WowGameApi` adapts the WoW globals (`UnitFactionGroup`, `UnitClass`, `GetBindLocation`, `GetItemCooldown`,
`GetZoneText`, `GetQuestLogTitle`, `DEFAULT_CHAT_FRAME`); `StubGameApi` is the test double. `GameEventBridge` adapts WoW *events* (`QUEST_ACCEPTED`,
`QUEST_TURNED_IN`, `QUEST_LOG_UPDATE`, `ZONE_CHANGED`) into guide calls (`onQuestAccepted`, `onArrived`, ...), which is
how the guide moves on by itself.

**Why here:** the WoW API only exists inside the client. Because these two adapters are the only doors to it, every other file runs
and is tested in plain Lua.

## 11. Repository and Value Object — `Domain/QuestLog.lua`, `Domain/RoutePlan.lua`

`QuestLog` stores tracked quests and converts them to and from `SavedVariables`. `RoutePlan` and `Edge` are plain
data with a few helpers; they are passed around and rendered, never mutated by others (except the plan's cursor).

---

## SOLID checklist

| Principle | Where in the code |
|---|---|
| Single Responsibility | `LocationResolver` only maps names to places; `GuideInteraction` only draws. |
| Open/Closed | `TravelLinkFactory:register`, `AtlasSolverFactory.register`, new `AccessRule`, new `CommandHandler`. |
| Liskov Substitution | `StubGameApi` replaces `WowGameApi`; every `TravelLink` subclass is used through `seconds()`. |
| Interface Segregation | `IScheduler` has one method; ATLAS only sees `IRequirementSet`. |
| Dependency Inversion | `AtlasQuestRouter.new({ gameApi, interactionFactory, scheduler, planner })`; `Class.implements` checks contracts at load time. |
