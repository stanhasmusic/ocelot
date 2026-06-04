# Ocelot

A 2D top-down scrolling shooter, mobile-first (540×960, Godot 4.5.1) and also targeting PC. Setting is a **WWII period skin** (P-38, prop fighters, tanks, bunkers, battleships) over **modern systems** (persistent upgrade metagame, checkpoints, touch + keyboard/gamepad controls). This glossary defines the in-game vocabulary used to talk about progression, encounters, threats, and visual readability.

## Language

**Threat tier**:
The behavioural class of an enemy projectile — what the player has to *do* to dodge it. Colour-coded for readability at a glance.
_Avoid_: Difficulty, level (those refer to the encounter, not the projectile).

**Straight tier** (blue):
A projectile that travels on a fixed vector with no targeting. Predictable — dodged by stepping aside.

**Aimed tier** (orange):
A projectile fired toward the player's position at the moment of firing. Punishes standing still — dodged by movement.

**Pattern tier** (purple):
A projectile that's part of a multi-shot pattern (fan, spread, homing). Reserved for bosses and rare elites — dodged by reading the pattern.

**Player shot** (white/pale-gold):
Any projectile fired by the player — its own visual class, deliberately *outside* the blue/orange/purple threat palette so ownership is never ambiguous. The hue means "mine" and is fixed; firepower growth (**Guns tier**) reads through the *amount* of fire (count/size/brightness), never a shift in hue. _Avoid_: letting the player register drift toward the **aimed** orange.

**Armor** (on a target):
A damage-type modifier on heavy ground/sea targets: they take *reduced* damage from the player's **guns** and *bonus* damage from explosives (**bombs**, **missiles**). Armor makes explosives the efficient tool, never a required one — guns can always still chip an armored target down. _Avoid_: confusing with the player's **Armour tier** (that's player toughness).

**Campaign**:
The ordered sequence of levels that forms the game's WWII arc — **four levels**, in escalating order: **Pacific Beachhead → Countryside → City → Naval** (the naval engagement is the finale). One pass through it is a **Playthrough**.

**Playthrough**:
One forward pass through the campaign (L1→L4). Coins and permanent upgrades are kept *across levels within* a Playthrough, and the Playthrough is saved so it can be quit and resumed; death sends the player to a **checkpoint**, never a reset. Progress is forward-only — the **Hangar** between levels is the only branch. _Avoid_: "run" (overloaded — could also mean a single **life**).

**New Game**:
Starts a fresh **Playthrough**. Coins, owned upgrades, and campaign progress all reset to zero — nothing carries across Playthroughs. The game is a self-contained arcade arc (weak → strong in one push), replayed from scratch for score and to try different builds.

**Level**:
The player-facing unit shown on Level Select. Each level is themed to a single **biome / front** (the four: Pacific Beachhead, Countryside, City, Naval). One level contains a fixed number of stages and a final boss.

**Hangar** (a.k.a. Airfield):
The between-levels screen, set on an airfield. Where the player spends **coins** on **permanent upgrades** before deploying to the next level. The only place permanent upgrades are bought.

**Coins**:
Meta-currency earned during missions (kills, pickups). Persists between levels *within a* **Playthrough** and is spent in the Hangar; reset to zero on a **New Game**. Each level pays its coins only on first clear within a Playthrough (no farming by replay). Distinct from **score**, which is for ranking only — the one bridge between them is one-way and terminal: on campaign completion any *unspent* coins cash out to a one-time score bonus (the arcade end-of-run mop-up), so coins stranded after the last Hangar — notably all of the finale level, which has no Hangar after it — still count for ranking.

**Permanent upgrade**:
An upgrade bought in the Hangar with coins and kept for the rest of the campaign. Organised into tiered categories (Guns, Armour, Engine, Bombs, Items). _Avoid_: "power-up" (that's an in-run pickup).

**Pickup**:
An item collected mid-level that grants a temporary or single-life boost (e.g. fire-pattern swap, wingman, extra bomb, repair, coins). Lost on death/level end — never permanent. _Avoid_: "upgrade" (that's the permanent Hangar kind).

**Guns tier**:
The player's permanent weapon power level (Hangar category, tiers 0–3). Drives the visible P-38 sprite (`lvl_0`→`lvl_3`) and raw damage/projectile count. The *permanent* half of firepower.

**Fire pattern**:
The *shape* of the player's fire, set temporarily by an in-run pickup — **concentrated** (straight, focused forward damage) or **spread** (diagonal, wider coverage, less focus). Independent of Guns tier (which sets power). Resets on death.

**Wingman**:
A temporary escort drone gained from a pickup that flies alongside the player and adds fire. Lost on death.

**Damage state**:
The player plane's visible health, shown in two reinforcing places: drawn on the plane sprite itself (`d0` pristine → `d4` critical/smoking) *and* mirrored in the HUD (a cockpit damage gauge). Each hit advances the state; death occurs past the last survivable state. _Note_: earlier design had this sprite-only; the HUD readout was added once the cockpit-bezel art revealed a dedicated damage gauge — two readouts aid noob readability.

**Armour tier**:
The player's permanent toughness level (Hangar category, tiers 0–3) — increases the number of hits the plane survives before death (stretches the `d0`→`d4` budget).

**Life**:
A respawn cushion. A fatal hit costs one life and respawns the player in place with brief invulnerability; only when lives run out does the player drop to the stage **checkpoint**. Replenished by the `life_up` pickup.

**Engine tier**:
The player's permanent movement upgrade (Hangar category, tiers 0–3) — raises top speed and acceleration. Also the de-facto accessibility dial: a faster plane dodges more easily.

**Bomb**:
The screen-clearing action — clears nearby enemy projectiles and deals area damage. A limited stock, replenished by the `bomb` pickup. **Bombs tier** (Hangar, 0–3) raises max stock carried and blast size/damage.

**Gadget**:
An equippable **Item** bought in the Hangar that modifies how a run plays (e.g. **Flare**, **Auto-Repair**, **Coin Magnet**, **Spotter**). Gadgets occupy a limited number of slots, so the player mixes and matches rather than running everything at once. The build-variety layer of the metagame.

**Flare**:
A defensive **gadget** that clears nearby enemy projectiles to save the player from an otherwise-fatal moment: **auto-triggered** on an otherwise-fatal hit (negate the blow + brief invulnerability), then on a **cooldown** before it can save again. Auto-only — no input binding of its own (resolved in PRD-09; an earlier draft floated a manual activation). Smaller, radius-limited, and more frequent than a **bomb**.

**Stage**:
An internal escalation within a level. Each stage ends with its own boss fight; clearing the last stage clears the level. Currently 3 stages per level. Stages 1–2 end in a **mini-boss**; the final stage ends in the level's named **boss**.

**Mini-boss**:
The tougher-than-an-elite enemy that closes a non-final stage. A single heavy unit (big ship, big tank, gun platform) with one weak-point and aimed fire — no phases. Reuses heavy enemy art rather than a bespoke boss sprite.

**Boss**:
The bespoke, named set-piece that closes a level's final stage (e.g. BIG MAMA, Double Trouble). A multi-part structure fought across escalating, telegraphed **phases**.

**Weak-point** (a.k.a. part):
A destructible component of a boss — a turret, engine, or gun emplacement (each with its own `_hit`/`_destroyed` art and **armor**). Destroying weak-points weakens the boss and drives **phase** transitions.

**Phase**:
A stage of a boss fight that begins at an HP/weak-point threshold and changes the boss's attack pattern, usually escalating. Telegraphed so the pattern is learnable (and readable early with the **Spotter** gadget).

**Checkpoint**:
A stage boundary. On death the player retries from the start of the current stage, not the start of the level. Coins banked before the checkpoint are kept.

**Stage intro**:
The first ~30–45 seconds of every stage. Hand-authored timeline of spawns that teaches the stage's new enemy or pattern before procedural spawning takes over. Also where the "STAGE N" banner shows.

**Procedural body**:
The portion of a stage after the intro, where enemies are drawn from a weighted spawn table with knobs for rate and difficulty scaling.

**Encounter**:
A sequence of enemy spawns culminating in a boss. One per stage; ends when the stage boss dies.

**Enemy archetype**:
A behaviour-first enemy role (movement + threat tier), reskinned with biome-appropriate art and drawn from the **procedural body**'s spawn table. The current set: **Strafer** (air, straight — formation fodder), **Diver** (air, aimed — dives at the player), **Gunship** (air, aimed — slow/tanky burst-fire), **Emplacement** (static ground, aimed — tracks & fires while scrolling past), **Tank** (mobile ground, aimed — turret tracks, fires shells), **Convoy** (ground, little/no threat — coin reward), **Warship** (naval, straight+aimed — high HP, multi-turret), **Elite** (any domain — see below).

**Elite**:
A rare, tougher enemy and the *only* non-boss permitted to fire **pattern-tier** (purple) projectiles. The sanctioned exception to the boss-gated pattern rule — a difficulty-spike tool that preserves "purple = read the pattern" without diluting it.

**Signature enemy**:
A hand-built, level-specific enemy or set-piece layered on top of the archetype backbone for identity (e.g. the Train in the Countryside, a Kamikaze wing on the Pacific beachhead). Usually introduced in that level's **stage intro**.

## Relationships

- A **campaign** is an ordered sequence of **levels**; the **Hangar** sits between consecutive levels
- A **level** contains N **stages** (currently 3); clearing the last stage clears the level
- Each **level** is themed to exactly one **biome / front**
- A **stage** is one **stage intro** followed by one **procedural body**, ending in a boss (mini-boss for stages 1–2, named **boss** for the final stage); each **stage** boundary is a **checkpoint**
- **Coins** are earned in levels and spent only in the **Hangar** on **permanent upgrades**; **pickups** are collected in-level and never persist
- Every **enemy projectile** belongs to exactly one **threat tier**
- A **threat tier** maps to exactly one colour (blue / orange / purple)
- **Player shots** never share a colour with any **threat tier**
- An **encounter** may use projectiles from any combination of tiers; pattern-tier is boss-gated, with **elites** the one sanctioned non-boss exception
- An **enemy archetype** maps to one threat tier and is reskinned per biome; **signature enemies** are the per-level exception built for identity

## Example dialogue

> **Dev:** "I'm adding a new turret enemy that leads the player by 30°. What sprite does its bullet use?"
> **Designer:** "It's leading the player, so it's **aimed tier** — orange. Doesn't matter what the turret looks like; the bullet colour is decided by behaviour, not by the shooter."

## Flagged ambiguities

- "Bullet" was used both for any projectile and for the player's basic shot. Resolved: **projectile** is the umbrella term; **player shot** is specifically the player's. Rocket, fan, shell, etc. are all projectiles.
