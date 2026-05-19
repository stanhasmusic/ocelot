# Defer test framework adoption until the first testable pure-logic module lands

Ocelot will not adopt a Godot test framework today. The trigger to revisit is the merge of issue #9 (`SpawnDirector` and `StageConfig`), at which point we adopt **GUT** and write initial tests for `SpawnDirector`'s weighted random selection, concurrency cap and aimed-shot gap, plus `StageIntroPlayer`'s clock-driven event firing.

We picked deferral over picking GUT or GdUnit4 now because the current codebase is dominated by scenes, signals, audio routing and art — all categories that are faster and more reliably verified by 60 seconds of editor playthrough than by automated tests. There is no pure-logic module today whose correctness can be asserted without rendering or scene-tree gymnastics. Setting up a framework with nothing to test is overhead that erodes when the first test gets written.

We picked GUT over GdUnit4 for the future setup because GUT is the de facto Godot-community standard with the most documentation and prior art for a solo developer to lean on; GdUnit4's more modern API and IDE integration are real but don't outweigh the docs gap at this scale.

Consequence: when issue #9 is about to merge, the implementing agent (or Stan) must open a follow-up issue "Set up GUT + initial tests for SpawnDirector and StageIntroPlayer" before merge. The deep-module shapes in PRD #8 were designed specifically to be testable from day one — losing that shape because the framework wasn't ready when #9 landed would forfeit the insurance.
