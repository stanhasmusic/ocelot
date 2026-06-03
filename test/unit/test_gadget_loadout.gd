extends GutTest

# PRD-09 — the pure gadget loadout decision math (GadgetLoadout): prices,
# slot/gadget purchase, and equip/unequip rules. Same "assert external
# behaviour, not private state, never mutate the caller's inputs" discipline as
# the PRD-08 Hangar tests; no autoload or scene deps — a fresh GadgetCatalog.new()
# carries the table defaults. The persisted-shape guarantees (gadget_slots
# round-trip, New-Game reset, empty-slot default) live with the other SaveGame
# tests in test_save_game.gd.

var _c: GadgetCatalog


func before_each() -> void:
	_c = GadgetCatalog.new()


# --- prices ---

func test_slot_price_walks_then_caps() -> void:
	assert_eq(GadgetLoadout.slot_price(1, _c), 120, "slot 1→2 costs 120")
	assert_eq(GadgetLoadout.slot_price(2, _c), 220, "slot 2→3 costs 220")
	assert_eq(GadgetLoadout.slot_price(3, _c), -1, "a maxed slot count has no next price")


func test_gadget_price_known_and_unknown() -> void:
	assert_eq(GadgetLoadout.gadget_price("coin_magnet", _c), 70)
	assert_eq(GadgetLoadout.gadget_price("flare", _c), 90)
	assert_eq(GadgetLoadout.gadget_price("auto_repair", _c), 110)
	assert_eq(GadgetLoadout.gadget_price("rocket_boots", _c), -1, "unknown gadget has no price")


# --- slot purchase ---

func test_purchase_slot_raises_capacity_and_deducts() -> void:
	var result := GadgetLoadout.purchase_slot(1, 200, _c)
	assert_true(result["ok"], "an affordable slot buy succeeds")
	assert_eq(result["gadget_slots"], 2, "capacity rises to 2")
	assert_eq(result["coins"], 80, "200 - 120 = 80 left")


func test_purchase_slot_refused_when_unaffordable() -> void:
	var result := GadgetLoadout.purchase_slot(1, 119, _c)
	assert_false(result["ok"], "can't afford the 120 slot")
	assert_eq(result["gadget_slots"], 1, "capacity unchanged on refusal")
	assert_eq(result["coins"], 119, "coins unchanged on refusal")


func test_purchase_slot_refused_at_cap() -> void:
	var result := GadgetLoadout.purchase_slot(3, 9999, _c)
	assert_false(result["ok"], "a maxed slot count refuses even with a full wallet")
	assert_eq(result["gadget_slots"], 3, "stays at the cap")


# --- gadget purchase ---

func test_purchase_gadget_marks_owned_and_deducts() -> void:
	var result := GadgetLoadout.purchase_gadget([], 100, "flare", _c)
	assert_true(result["ok"], "an affordable gadget buy succeeds")
	assert_true(result["owned_gadgets"].has("flare"), "the gadget is now owned")
	assert_eq(result["coins"], 10, "100 - 90 = 10 left")


func test_purchase_gadget_refused_when_already_owned() -> void:
	var result := GadgetLoadout.purchase_gadget(["flare"], 9999, "flare", _c)
	assert_false(result["ok"], "no double-buy")
	assert_eq(result["owned_gadgets"], ["flare"], "ownership unchanged")
	assert_eq(result["coins"], 9999, "wallet unchanged on refusal")


func test_purchase_gadget_refused_when_unaffordable() -> void:
	var result := GadgetLoadout.purchase_gadget([], 69, "coin_magnet", _c)
	assert_false(result["ok"], "can't afford the 70 gadget")
	assert_eq(result["owned_gadgets"].size(), 0, "nothing owned on refusal")


func test_purchase_gadget_refused_for_unknown_id() -> void:
	var result := GadgetLoadout.purchase_gadget([], 9999, "rocket_boots", _c)
	assert_false(result["ok"], "an unknown gadget is refused")


func test_purchase_gadget_does_not_mutate_caller_array() -> void:
	var owned := ["flare"]
	GadgetLoadout.purchase_gadget(owned, 1000, "spotter", _c)  # success path
	assert_eq(owned, ["flare"], "the input array is not mutated on success")
	GadgetLoadout.purchase_gadget(owned, 0, "spotter", _c)  # refusal path
	assert_eq(owned, ["flare"], "the input array is not mutated on refusal")


# --- equip / unequip ---

func test_equip_fills_a_free_slot() -> void:
	var result := GadgetLoadout.equip(["flare"], [], 1, "flare")
	assert_true(result["ok"], "an owned gadget equips into a free slot")
	assert_eq(result["equipped_loadout"], ["flare"])


func test_equip_refused_when_unowned() -> void:
	var result := GadgetLoadout.equip([], [], 1, "flare")
	assert_false(result["ok"], "can't equip what you don't own")
	assert_eq(result["equipped_loadout"].size(), 0)


func test_equip_refused_when_already_equipped() -> void:
	var result := GadgetLoadout.equip(["flare"], ["flare"], 3, "flare")
	assert_false(result["ok"], "can't equip the same gadget twice")
	assert_eq(result["equipped_loadout"], ["flare"])


func test_equip_refused_when_loadout_full() -> void:
	# One slot, already filled — a second gadget can't be equipped.
	var result := GadgetLoadout.equip(["flare", "spotter"], ["flare"], 1, "spotter")
	assert_false(result["ok"], "the equipped count never exceeds the slot count")
	assert_eq(result["equipped_loadout"], ["flare"], "loadout unchanged on refusal")


func test_equip_does_not_mutate_caller_array() -> void:
	var equipped := ["flare"]
	GadgetLoadout.equip(["flare", "spotter"], equipped, 3, "spotter")
	assert_eq(equipped, ["flare"], "the input array is not mutated")


func test_unequip_frees_a_slot() -> void:
	var result := GadgetLoadout.unequip(["flare", "spotter"], "flare")
	assert_true(result["ok"], "an equipped gadget unequips")
	assert_eq(result["equipped_loadout"], ["spotter"], "only the named gadget leaves")


func test_unequip_refused_when_not_equipped() -> void:
	var result := GadgetLoadout.unequip(["flare"], "spotter")
	assert_false(result["ok"], "can't unequip what isn't equipped")
	assert_eq(result["equipped_loadout"], ["flare"], "loadout unchanged on refusal")


func test_unequip_does_not_mutate_caller_array() -> void:
	var equipped := ["flare", "spotter"]
	GadgetLoadout.unequip(equipped, "flare")
	assert_eq(equipped, ["flare", "spotter"], "the input array is not mutated")
