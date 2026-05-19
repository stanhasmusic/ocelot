# Follow-up: choose a test framework (or decide not to have one)

## Problem Statement

The project has no test infrastructure. As the codebase grows (hybrid difficulty model, `LevelBase` refactor, threat-tier sprite rewire, hand-authored background system), regressions become harder to catch by playthrough alone — and PRDs are starting to say "no automated tests because no framework exists" as boilerplate.

## Solution

Decide explicitly whether Ocelot should adopt a Godot test framework, and if so, which one. Document the decision as an ADR.

## Out of Scope

- Actually writing tests. This issue is the *decision* about whether to have a framework, not the work of authoring suites.

## Further Notes

- Likely candidates: [GUT](https://github.com/bitwes/Gut) (most mature for GDScript), [GdUnit4](https://github.com/MikeSchulze/gdUnit4) (more modern, IDE integration).
- A reasonable "no" outcome is also possible: solo project, mobile shooter, playthrough verification has worked so far. The ADR can record "we deliberately don't have tests, here's the threshold at which we'd reconsider."
- Reference back to PRD 0001 (tactical fixes), which is the first PRD to explicitly defer test-writing on this basis.
