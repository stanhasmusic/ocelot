extends Control

# The gadget loadout screen (PRD-09): the build-variety surface beside the four
# stat tracks (PRD-08). The player spends coins on slots (1→3) and gadgets, then
# equips owned gadgets into the slots they can run at once. Buying spends and is
# one-way within a Playthrough; equip/unequip is free and reversible. The
# own/equip/slot decision math lives in the pure GadgetLoadout helper; this node
# only renders rows and drives the GameManager seams. Reached from the Hangar's
# [Loadout]; [Back] returns there.
#
# Built responsive to the 540×960 viewport: the name/desc column EXPANDs while
# the action column keeps a compact fixed width, so rows never overflow.

# Display name + one-line description per gadget id, in catalog order.
const GADGET_INFO: Dictionary = {
	"coin_magnet": {"name": "COIN MAGNET", "desc": "Coins drift toward you."},
	"flare": {"name": "FLARE", "desc": "Auto-saves one fatal hit, then cools down."},
	"spotter": {"name": "SPOTTER", "desc": "Flags incoming aimed fire."},
	"auto_repair": {"name": "AUTO-REPAIR", "desc": "Heals slowly out of combat."},
}

# Per-gadget row controls, keyed by id → { "action": Button }.
var _rows: Dictionary = {}

@onready var _coins_label: Label = $Layout/CoinsLabel
@onready var _slots_label: Label = $Layout/SlotsRow/SlotsLabel
@onready var _buy_slot_button: Button = $Layout/SlotsRow/BuySlotButton
@onready var _gadgets: VBoxContainer = $Layout/GadgetsContainer
@onready var _back_button: Button = $Layout/BackButton


func _ready() -> void:
	for id in GadgetLoadout.GADGETS:
		_build_row(id)
	_buy_slot_button.pressed.connect(_on_buy_slot)
	_back_button.pressed.connect(_on_back)
	_refresh()

	# Pad/keyboard focus: first actionable gadget, else Buy-Slot, else Back.
	var focus_target: Control = _back_button
	for id in GadgetLoadout.GADGETS:
		var action: Button = _rows[id]["action"]
		if not action.disabled:
			focus_target = action
			break
	if focus_target == _back_button and not _buy_slot_button.disabled:
		focus_target = _buy_slot_button
	focus_target.grab_focus()


func _build_row(id: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	# Name + desc take the slack so the row fits any viewport width.
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = GADGET_INFO[id]["name"]
	name_label.add_theme_font_size_override("font_size", 26)
	text_box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = GADGET_INFO[id]["desc"]
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_child(desc_label)

	row.add_child(text_box)

	var action := Button.new()
	action.custom_minimum_size = Vector2(150, 64)
	action.add_theme_font_size_override("font_size", 20)
	action.pressed.connect(_on_gadget_action.bind(id))
	row.add_child(action)

	_gadgets.add_child(row)
	_rows[id] = {"action": action}


# The gadget action button is state-aware: buy when unowned, equip when owned but
# benched, unequip when equipped (the toggle frees a slot).
func _on_gadget_action(id: String) -> void:
	if not GameManager.owned_gadgets.has(id):
		GameManager.purchase_gadget(id)
	elif GameManager.equipped_loadout.has(id):
		GameManager.unequip_gadget(id)
	else:
		GameManager.equip_gadget(id)
	_refresh()


func _on_buy_slot() -> void:
	# The seam refuses a maxed/unaffordable slot itself; we just repaint.
	GameManager.purchase_gadget_slot()
	_refresh()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://ui/Hangar.tscn")


# Repaint everything: any buy/equip changes the wallet or free-slot count, which
# can flip the affordability/availability of every other row.
func _refresh() -> void:
	_coins_label.text = "COINS: " + str(GameManager.coins)
	_refresh_slots()
	for id in GadgetLoadout.GADGETS:
		_refresh_gadget(id)


func _refresh_slots() -> void:
	var slots: int = GameManager.gadget_slots
	var used: int = GameManager.equipped_loadout.size()
	# A compact strip: filled for an in-use slot, open ring for a free one.
	var strip := ""
	for i in slots:
		strip += "●" if i < used else "○"
	_slots_label.text = "SLOTS " + strip + " (%d/%d)" % [used, slots]

	var price: int = GadgetLoadout.slot_price(slots, GameManager.GADGET_CATALOG)
	if price < 0:
		_buy_slot_button.text = "MAX"
		_buy_slot_button.disabled = true
	else:
		_buy_slot_button.text = "BUY " + str(price) + "⛁"
		_buy_slot_button.disabled = GameManager.coins < price


func _refresh_gadget(id: String) -> void:
	var action: Button = _rows[id]["action"]
	var owned: bool = GameManager.owned_gadgets.has(id)
	var equipped: bool = GameManager.equipped_loadout.has(id)

	if equipped:
		action.text = "EQUIPPED ✓"
		action.disabled = false  # toggles off (unequip is free)
	elif owned:
		var has_free_slot: bool = GameManager.equipped_loadout.size() < GameManager.gadget_slots
		action.text = "EQUIP"
		action.disabled = not has_free_slot
	else:
		var price: int = GadgetLoadout.gadget_price(id, GameManager.GADGET_CATALOG)
		action.text = "BUY " + str(price) + "⛁"
		action.disabled = GameManager.coins < price
