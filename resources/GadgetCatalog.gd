class_name GadgetCatalog
extends Resource

# Registry, prices, and per-gadget effect knobs for the Hangar gadget loadout
# (PRD-09), in the HangarTunables mould: every magnitude lives here so the
# balance loop tunes the .tres without code. The pure GadgetLoadout helper reads
# the prices; Player reads the effect knobs.
#
# Prices are conservative first-pass placeholders — PRD-11 (#39) takes over the
# real economy tuning (gadgets are "expression-slack", ADR-0011), so it owns
# these arrays/fields, not this PRD.

# --- Slot prices ---
# Slots start at 1 and buy up to 3, so two purchases (1→2, 2→3). Indexed by
# (current_slots - 1): current 1 → index 0, current 2 → index 1.
@export var slot_prices: Array[int] = [120, 220]

# --- Gadget prices ---
@export var coin_magnet_price: int = 70
@export var flare_price: int = 90
@export var spotter_price: int = 90
@export var auto_repair_price: int = 110

# --- Coin Magnet knobs ---
# Extra magnet radius (px) added to the player's per-input pull while equipped.
@export var magnet_bonus_px: float = 160.0

# --- Flare knobs ---
# Auto-fires on an otherwise-fatal hit: negate the lethal blow, clear enemy fire
# within `flare_radius`, grant `flare_iframes` of invincibility, then cool down
# for `flare_cooldown` before it can save the player again.
@export var flare_cooldown: float = 12.0
@export var flare_radius: float = 220.0
@export var flare_iframes: float = 1.0

# --- Spotter knobs ---
# Look-ahead horizon (s) for flagging an inbound aimed round (closest approach).
@export var spotter_lead: float = 0.6

# --- Auto-Repair knobs ---
# Heals `auto_repair_amount` HP every `auto_repair_interval` seconds once the
# player has been out of combat (undamaged) for `auto_repair_grace` seconds.
@export var auto_repair_grace: float = 5.0
@export var auto_repair_interval: float = 8.0
@export var auto_repair_amount: int = 1
