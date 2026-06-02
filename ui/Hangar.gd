extends Control

# The Hangar (PRD-08): the between-levels spend screen. Four tiered tracks —
# Guns / Armour / Engine / Bombs — bought out of the persisted coin wallet and
# applied at the next level's start. The purchase decision + tier→effect math
# lives in the pure HangarUpgrades / HangarTunables; this node only renders the
# rows and drives the spend seam (GameManager.purchase_tier). Reached from
# LevelComplete's [To Hangar]; [Deploy] enters GameManager.next_level.

const TRACK_LABELS: Dictionary = {
	"guns": "GUNS",
	"armour": "ARMOUR",
	"engine": "ENGINE",
	"bombs": "BOMBS",
}

# Per-track row controls, keyed by track → { "tier": Label, "price": Label, "buy": Button }.
var _rows: Dictionary = {}
var _deploying: bool = false

@onready var _coins_label: Label = $Layout/CoinsLabel
@onready var _tracks: VBoxContainer = $Layout/TracksContainer
@onready var _deploy_button: Button = $Layout/DeployButton


func _ready() -> void:
	for track in HangarUpgrades.TRACKS:
		_build_row(track)
	_deploy_button.pressed.connect(_on_deploy)
	GameManager.on_coins_changed.connect(_on_coins_changed)
	_refresh()

	# Keyboard/controller focus: the first track's Buy if it can be acted on,
	# otherwise Deploy (the user playtests on a pad).
	var first_buy: Button = _rows[HangarUpgrades.TRACKS[0]]["buy"]
	if not first_buy.disabled:
		first_buy.grab_focus()
	else:
		_deploy_button.grab_focus()


func _build_row(track: String) -> void:
	# The row fills the container width; the name label takes the slack (EXPAND)
	# while the tier/price/buy columns keep compact fixed widths, so the row never
	# overflows the 540 px (9:16) viewport regardless of font tweaks.
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = TRACK_LABELS[track]
	name_label.custom_minimum_size = Vector2(120, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 30)
	row.add_child(name_label)

	var tier_label := Label.new()
	tier_label.custom_minimum_size = Vector2(90, 0)
	tier_label.add_theme_font_size_override("font_size", 28)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(tier_label)

	var price_label := Label.new()
	price_label.custom_minimum_size = Vector2(96, 0)
	price_label.add_theme_font_size_override("font_size", 24)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(price_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(110, 60)
	buy_button.add_theme_font_size_override("font_size", 24)
	buy_button.pressed.connect(_on_buy.bind(track))
	row.add_child(buy_button)

	_tracks.add_child(row)
	_rows[track] = {"tier": tier_label, "price": price_label, "buy": buy_button}


func _on_buy(track: String) -> void:
	# The seam refuses unaffordable/maxed buys itself; we just refresh the UI.
	GameManager.purchase_tier(track)
	_refresh()


func _on_coins_changed(_total: int) -> void:
	_refresh()


# Repaint every row: a buy changes the wallet, so affordability of *all* tracks
# can flip, not just the one bought.
func _refresh() -> void:
	_coins_label.text = "COINS: " + str(GameManager.coins)
	for track in HangarUpgrades.TRACKS:
		_refresh_row(track)


func _refresh_row(track: String) -> void:
	var controls: Dictionary = _rows[track]
	var current: int = GameManager.tier(track)
	controls["tier"].text = _pips(current)

	var price: int = HangarUpgrades.price_for(track, current, GameManager.HANGAR_TUNABLES)
	var buy: Button = controls["buy"]
	if price < 0:
		controls["price"].text = "—"
		buy.text = "MAX"
		buy.disabled = true
	else:
		controls["price"].text = str(price) + " ⛁"
		buy.text = "BUY"
		buy.disabled = GameManager.coins < price


# A compact "filled/empty" tier readout, e.g. tier 2 → "●●○".
func _pips(tier: int) -> String:
	var pips := ""
	for i in HangarUpgrades.MAX_TIER:
		pips += "●" if i < tier else "○"
	return pips


func _on_deploy() -> void:
	if _deploying:
		return
	_deploying = true
	var dest: String = GameManager.next_level
	if dest.is_empty():
		# Defensive: the Hangar should only open when a next level exists.
		dest = "res://ui/MainMenu.tscn"
	get_tree().change_scene_to_file(dest)
