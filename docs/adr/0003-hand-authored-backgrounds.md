# Levels use hand-authored scrolling backgrounds, not procedural noise

Each level's background is a hand-authored scrolling asset (long PNG strip or TileMap), with specific landmarks placed to pace the stage — most importantly a pre-boss landmark that telegraphs the encounter. The existing procedural `MovingLandBackground` system (FastNoiseLite + recycled tile rows) is deprecated.

We picked this over keeping procedural (no visual progress cues, can't signal "boss coming" — which the noob/mid-tier audience needs per [[project-ocelot-target-audience]]) and a procedural/hand-authored hybrid (splice complexity doesn't pay off once hand-authored covers the moments that matter). The procedural system's only win was "infinite levels for free," which is irrelevant: we're building finite, stage-structured levels (see [[0002-hybrid-stage-difficulty]]).

Consequence: each level needs a long background asset (or a TileMap) per stage, with explicit landmarks at stage transitions and before the boss. This is the largest art commitment per new level — accept it as the cost of the genre.
