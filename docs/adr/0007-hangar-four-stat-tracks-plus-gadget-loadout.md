# Hangar upgrades are four stat tracks plus a gadget loadout system

The Hangar offers five permanent-upgrade categories, mapped to the `upgrade_screen` art:

- **Guns** (0–3) — weapon power; drives the visible `lvl_0`→`lvl_3` plane sprite.
- **Armour** (0–3) — hits survived before death; stretches the `d0`→`d4` budget.
- **Engine** (0–3) — top speed + acceleration; doubles as the accessibility dial.
- **Bombs** (0–3) — max bomb stock carried + blast size/damage.
- **Items** — *not* a fifth stat bar but a **gadget loadout system**: the player buys a limited number of gadget slots and individual gadgets (Flare, Auto-Repair, Coin Magnet, Spotter, Decoy, …) and mixes them to taste.

We picked the gadget system over (a) a fifth linear stat bar (cheapest, but the whole Hangar collapses to "buy all five to max" with no decisions) and (b) a pre-mission consumable stockpile (risks a grindy consumable treadmill). The gadget loadout adds genuine build-crafting and a recurring reason to revisit the Hangar, which matters because the Hangar is the campaign's core metagame ([[0005-persistent-campaign-with-hangar-metagame]]). The user explicitly opened scope beyond "simple-ish" (see [[feedback-ambition-welcome]]), making the extra depth worth its cost. Gadgets like Flare and Auto-Repair also reinforce the noob-forgiving stance ([[project-ocelot-target-audience]]).

Consequence: the four stat tracks share one simple tiered-purchase UI, but Items needs a slot/equip UI and each gadget is a distinct behaviour to build and balance. Save data must persist owned tiers, owned gadgets, and the equipped loadout. Gadget count should start small (3–4) and grow; resist shipping a loadout screen with only one meaningful choice.
