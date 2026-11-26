# Simplified class diagram

The 12 central classes, each with its design pattern and its important methods.
Rendered version: [diagrams/class-diagram-simplified.svg](diagrams/class-diagram-simplified.svg)
(PNG for printing: [diagrams/class-diagram-simplified.png](diagrams/class-diagram-simplified.png)).
The complete diagram with every class is [diagrams/class-diagram-full.svg](diagrams/class-diagram-full.svg).

```
 ┌──────────────────────────┐    ┌──────────────────────────────┐
 │ «Facade»                 │───>│ «Chain of Responsibility»    │
 │ AtlasQuestRouter         │    │ CommandHandler               │
 │ +addQuest(id)            │    │ +setNext(handler)            │
 │ +plan()                  │    │ +handle(verb, args, router)  │
 │ +nextLeg()               │    │ +execute(args, router)       │
 │ +onQuestAccepted(title)  │    └──────────────────────────────┘
 │ +onArrived(place)        │    ┌──────────────────────────────┐  creates   ┌──────────────────────────┐
 │ +runCommand(input)       │───>│ «Factory Method»             │ - - - - - >│ UserInteraction          │
 │ +save() / load()         │    │ UserInteractionFactory       │            │ (Chat / GuideInteraction)│
 └──────────────────────────┘    │ +createInteractions()        │            │ +notify(msg)             │
        │   │   │                │ +createInteraction(kind)     │            │ +showPlan(plan)          │
        │   │   │                └──────────────────────────────┘            │ +showProgress(plan)      │
        │   │   │                                                            └──────────────────────────┘
        │   │   └───────────────>┌──────────────────────────────┐
        │   │                    │ «Repository + Observer»      │
        │   │                    │ QuestLog                     │
        │   │                    │ +add(id)  +remove(id)        │
        │   │                    │ +markStepDone(step)          │
        │   │                    └──────────────────────────────┘
        │   └───────────────────>┌──────────────────────────────┐            ┌─────────────────────┐   ┌──────────────────────────┐
        │                        │ QuestRoutePlanner            │───────────>│ «Builder»           │──>│ «Factory Method»         │
        │                        │ +plan(profile, quests, start)│            │ WorldGraphBuilder   │   │ TravelLinkFactory        │
        │                        └──────────────────────────────┘            │ +addWalkingNetwork()│   │ +create(mode, from, to)  │
        │                                       │                            │ +addFlightNetwork() │   └──────────────────────────┘
        │                                       │                            │ +addQuestSteps(q)   │   ┌──────────────────────────┐
        │                                       │                            │ +result()           │──>│ «Chain of Responsibility»│
        │                                       │                            └─────────────────────┘   │ AccessRule               │
        │                                       v                                                      │ +setNext(rule)           │
        v                                ┌───────────────────────┐                                     │ +handle(link, profile)   │
 ┌──────────────────────────┐            │ «ATLAS» AtlasSolver   │──┐                                  └──────────────────────────┘
 │ «Adapter» IGameApi       │            │ +solve(graph,start,R) │  │   ┌──────────────────────────┐
 │ +playerProfile()         │            │ +extend(graph,start,R)│  └──>│ «Composite + Strategy»   │
 │ +questLogTitles()        │            └───────────────────────┘      │ EdgeScorer               │
 └──────────────────────────┘                                           │ +score(label, ctx)       │
                                                                        │ +adaptTo(graph)          │
                                                                        └──────────────────────────┘
```

Reading order: the facade uses five collaborators (commands, user interactions, quest log, planner, game API).
The planner has two: the builder (which uses a factory and a chain) and ATLAS (which uses the scorer).
