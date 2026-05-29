# ISSUES

Open AFK issues from GitHub are provided at start of context. Parse them to understand what needs doing.

You will work on `ready-for-agent` labeled issues only, not `ready-for-human` ones.

You've also been passed the last few commits. Review these to understand what work has already been done.

If all AFK tasks are complete, output <promise>NO MORE TASKS</promise>.

# TASK SELECTION

Pick the next task. Prioritize in this order:

1. Critical bugfixes
2. Development infrastructure
3. Tracer bullets for new features — small end-to-end slices through all layers before expanding
4. Polish and quick wins
5. Refactors

# EXPLORATION

Explore the repo. Key things to know:
- Godot 4.5.1 project, 2D top-down shooter, GL Compatibility renderer, 540x960 mobile target
- No CLI build system — all runtime is Godot editor. Do not attempt `godot` CLI commands.
- Autoloaded singletons: `GameManager.gd`, `SoundManager.gd`
- Physics layers: 1=Player, 2=PlayerProjectile, 3=Enemy, 4=EnemyProjectile, 5=World, 6=PowerUp
- See `CLAUDE.md` for full architecture reference

# BRANCH FIRST

Before making **any** edits, create and check out a feature branch off an up-to-date `main`:

```
git checkout main && git pull --ff-only
git checkout -b <type>/<short-slug>-<issue-number>
```

Use `feat/` for features, `fix/` for bugfixes, `chore/` for infra — e.g. `feat/stage-engine-hardening-29`. Do **all** work on this branch; never commit to `main` directly. This way, if the run is interrupted mid-build, the work is left on a branch instead of leaving `main` dirty for the next run to trip over.

# IMPLEMENTATION

Use `/tdd` **only if a test framework is set up in the repo** (check for `addons/gut/` or `addons/gdunit4/`). If no framework is present, follow the issue body's "manual verification checklist" instead — this is the documented project posture per ADR 0004, not a gap to fill.

If the task you are working on is the one that **introduces** the test framework (the GUT setup follow-up issue referenced by [ADR 0004](../docs/adr/0004-defer-test-framework-until-first-testable-module.md)), set up GUT first, then `/tdd` for any subsequent tasks.

If the issue body marks the task as **HITL** (human-in-the-loop) — typically a merge gate for design or audio review — do the implementation work, push a branch, and leave a comment on the issue describing what to verify. Do **not** close HITL issues.

Before starting any task, read the issue body's "Blocked by" section. If a blocker exists and is still open, skip this task and pick another `ready-for-agent` issue with no open blockers. Do not work blocked tasks.

# FEEDBACK LOOP

Before committing, run gdlint on any changed `.gd` files:

```
gdlint path/to/changed_file.gd
```

Fix any errors it reports. Warnings are informational — use your judgement.

If gdlint is not installed: `pip install gdtoolkit`

# COMMIT

Make a git commit. The message must include:

1. Key decisions made
2. Files changed
3. Any blockers or notes for the next iteration

# THE ISSUE

If the task is complete, close the GitHub issue:
```
gh issue close <number> --repo stanhasmusic/ocelot
```

If not complete, add a comment with what was done:
```
gh issue comment <number> --repo stanhasmusic/ocelot --body "..."
```

# FINAL RULES

ONLY WORK ON A SINGLE TASK.
