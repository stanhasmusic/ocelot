class_name GadgetLoadout
extends RefCounted

# Pure slot/gadget/equip decision math for the Hangar gadget loadout (PRD-09), in
# the HangarUpgrades mould: static functions, no node / Input / Engine deps, so
# affordability, the slot cap, ownership, and equip rules all unit-test
# deterministically (ADR-0004). The GadgetLoadout node rolls the UI; this
# decides. Prices live in GadgetCatalog.
#
# Buying (slots + gadgets) is one-way within a Playthrough and spends coins;
# equip/unequip is free and reversible. Slots (1→3) are scarcer than the four
# gadgets by design, so which you run is a real choice — the equip cap is the
# whole point, enforced here.

const MIN_SLOTS: int = 1
const MAX_SLOTS: int = 3
const GADGETS: Array[String] = ["coin_magnet", "flare", "spotter", "auto_repair"]


static func is_known(id: String) -> bool:
	return GADGETS.has(id)


static func owns(owned_gadgets: Array, id: String) -> bool:
	return owned_gadgets.has(id)


static func is_equipped(equipped_loadout: Array, id: String) -> bool:
	return equipped_loadout.has(id)


# Price to buy the *next* slot from the current count, or -1 when already at the
# cap (MAX_SLOTS) or below the floor. Indexed by (current - MIN_SLOTS).
static func slot_price(current_slots: int, catalog: GadgetCatalog) -> int:
	if current_slots >= MAX_SLOTS or current_slots < MIN_SLOTS:
		return -1
	var idx: int = current_slots - MIN_SLOTS
	if idx < 0 or idx >= catalog.slot_prices.size():
		return -1
	return int(catalog.slot_prices[idx])


# Price of a gadget by id, or -1 for an unknown id.
static func gadget_price(id: String, catalog: GadgetCatalog) -> int:
	match id:
		"coin_magnet":
			return catalog.coin_magnet_price
		"flare":
			return catalog.flare_price
		"spotter":
			return catalog.spotter_price
		"auto_repair":
			return catalog.auto_repair_price
	return -1


# Decide a slot purchase. Returns { ok, gadget_slots, coins }. Refuses (ok=false,
# inputs echoed back) at the cap or when the wallet can't afford the next slot —
# no debt, no over-cap.
static func purchase_slot(gadget_slots: int, coins: int, catalog: GadgetCatalog) -> Dictionary:
	var refused := {"ok": false, "gadget_slots": gadget_slots, "coins": coins}
	var price: int = slot_price(gadget_slots, catalog)
	if price < 0 or coins < price:
		return refused
	return {"ok": true, "gadget_slots": gadget_slots + 1, "coins": coins - price}


# Decide a gadget purchase. Returns { ok, owned_gadgets, coins } with a *fresh*
# owned_gadgets so the caller's array is never mutated. Refuses for an unknown
# id, an already-owned gadget, or when unaffordable — no double-buy, no debt.
static func purchase_gadget(
	owned_gadgets: Array, coins: int, id: String, catalog: GadgetCatalog
) -> Dictionary:
	var refused := {"ok": false, "owned_gadgets": owned_gadgets.duplicate(), "coins": coins}
	if not is_known(id) or owns(owned_gadgets, id):
		return refused
	var price: int = gadget_price(id, catalog)
	if price < 0 or coins < price:
		return refused
	var bought: Array = owned_gadgets.duplicate()
	bought.append(id)
	return {"ok": true, "owned_gadgets": bought, "coins": coins - price}


# Decide an equip. Returns { ok, equipped_loadout } with a *fresh* array. Free
# (no coins). Refuses an unowned id, an already-equipped id, or a full loadout
# (len >= gadget_slots) — the equipped count never exceeds the slot count.
static func equip(
	owned_gadgets: Array, equipped_loadout: Array, gadget_slots: int, id: String
) -> Dictionary:
	var refused := {"ok": false, "equipped_loadout": equipped_loadout.duplicate()}
	if not owns(owned_gadgets, id):
		return refused
	if is_equipped(equipped_loadout, id):
		return refused
	if equipped_loadout.size() >= gadget_slots:
		return refused
	var equipped: Array = equipped_loadout.duplicate()
	equipped.append(id)
	return {"ok": true, "equipped_loadout": equipped}


# Decide an unequip. Returns { ok, equipped_loadout } with a *fresh* array. Free.
# Refuses an id that is not currently equipped.
static func unequip(equipped_loadout: Array, id: String) -> Dictionary:
	if not is_equipped(equipped_loadout, id):
		return {"ok": false, "equipped_loadout": equipped_loadout.duplicate()}
	var equipped: Array = equipped_loadout.duplicate()
	equipped.erase(id)
	return {"ok": true, "equipped_loadout": equipped}
