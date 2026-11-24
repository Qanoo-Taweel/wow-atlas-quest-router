# Drawing the class diagram by hand

Draw 12 boxes in three columns. Each box: name on top (with the pattern in «guillemets»), methods below.
Arrows go from left to right.

```
 LEFT                         MIDDLE                              RIGHT
 ┌───────────────────────┐    ┌──────────────────────────────┐
 │ «Facade»              │───>│ «Chain of Responsibility»    │
 │ AtlasQuestRouter      │    │ CommandHandler               │
 │ +addQuest(id)         │    │ +setNext(handler)            │
 │ +plan()               │    │ +handle(verb, args, router)  │
 │ +nextLeg()            │    │ +execute(args, router)       │
 │ +runCommand(input)    │    └──────────────────────────────┘
 │ +save() / load()      │    ┌──────────────────────────────┐   creates  ┌─────────────────────┐
 └───────────────────────┘───>│ «Factory Method»             │ - - - - - >│ UserInteraction     │
          │  │  │             │ UserInteractionFactory       │            │ +notify(msg)        │
          │  │  │             │ +createInteractions()        │            │ +showPlan(plan)     │
          │  │  │             │ +createInteraction(kind)     │            │ +showProgress(plan) │
          │  │  │             └──────────────────────────────┘            └─────────────────────┘
          │  │  └────────────>┌──────────────────────────────┐
          │  │                │ «Repository + Observer»      │
          │  │                │ QuestLog                     │
          │  │                │ +add(id) +remove(id)         │
          │  │                │ +markStepDone(step)          │
          │  │                └──────────────────────────────┘
          │  └───────────────>┌──────────────────────────────┐            ┌─────────────────────┐   ┌──────────────────────────┐
          │                   │ QuestRoutePlanner            │───────────>│ «Builder»           │──>│ «Factory Method»         │
          │                   │ +plan(profile, quests, start)│            │ WorldGraphBuilder   │   │ TravelLinkFactory        │
          │                   └──────────────────────────────┘            │ +addWalkingNetwork()│   │ +create(mode, from, to)  │
          │                                  │                            │ +addFlightNetwork() │   └──────────────────────────┘
          │                                  │                            │ +addQuestSteps(q)   │   ┌──────────────────────────┐
          │                                  │                            │ +result()           │──>│ «Chain of Responsibility»│
          │                                  │                            └─────────────────────┘   │ AccessRule               │
          │                                  │                                                      │ +setNext(rule)           │
          │                                  └───────────>┌──────────────────────┐                  │ +handle(link, profile)   │
          v                                               │ «ATLAS» AtlasSolver  │───┐              └──────────────────────────┘
 ┌───────────────────────┐                                │ +solve(graph,start,R)│   │  ┌──────────────────────────┐
 │ «Adapter» IGameApi    │                                │ +extend(graph,start,R)│  └─>│ «Composite + Strategy»   │
 │ +playerProfile()      │                                └──────────────────────┘      │ EdgeScorer               │
 │ +questLogTitles()     │                                                              │ +score(edge) +adaptTo(g) │
 └───────────────────────┘                                                              └──────────────────────────┘
```

**Memory trick (top to bottom of the facade's arrows):** *C-U-Q-P-I*:
**C**ommands, **U**ser interactions, **Q**uest log, **P**lanner, **I**GameApi.
Then the planner's two children: **B**uilder (which uses a **F**actory and a **C**hain) and **A**TLAS (which uses the **S**corer).
