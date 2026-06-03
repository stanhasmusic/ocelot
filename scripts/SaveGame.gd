class_name SaveGame
extends Resource

# Two-tier save schema (PRD-07, ADR-0011).
#
#   Profile tier    — survives New Game: all-time high score + audio volumes.
#   Playthrough tier — wiped by New Game: campaign progress, the coin wallet,
#                      the persisted checkpoint, and the Hangar slots that
#                      PRD-08/09 will fill (reserved here so they need no
#                      migration later).
#
# Migrate/reset are pure data transforms with no node/scene dependencies, kept
# here (off the autoload) so they unit-test like CheckpointState. Bump
# SCHEMA_VERSION and add a branch to `migrate()` whenever the persisted shape
# changes.

const SCHEMA_VERSION: int = 2

# Defaults to the *oldest* schema: a v1 file on disk never stored this field, so
# it loads as 1 and triggers migration. Code writing a fresh save sets it to
# SCHEMA_VERSION explicitly (see GameManager.save_data).
@export var schema_version: int = 1

# --- Profile tier (survives New Game) ---
@export var high_score: int = 0
@export var master_volume: float = 1.0
@export var music_volume: float = 1.0
@export var sfx_volume: float = 1.0

# --- Playthrough tier (wiped by New Game) ---
@export var has_playthrough: bool = false
@export var campaign_level: int = 1               # 1-based furthest level reached
@export var coins: int = 0                         # persisted wallet
@export var checkpoint: Dictionary = {}            # CheckpointState.serialize()
@export var level_stars: Dictionary = {}           # best stars per level index
# Reserved for PRD-08/09 — persisted + reset here so those PRDs need no migration.
# Shapes are owned by PRD-08/09; this PRD treats them as opaque pass-through.
@export var owned_tiers: Dictionary = {}
@export var owned_gadgets: Array = []
@export var equipped_loadout: Array = []
# PRD-09 gadget slot capacity. Defaults to MIN_SLOTS so a pre-PRD-09 save (which
# never stored it) loads as 1 slot — same no-migration story as owned_tiers, so
# no SCHEMA_VERSION bump.
@export var gadget_slots: int = 1

# --- v1 legacy fields (migration source only; do not read at runtime) ---
# Kept so a v1 .tres still loads its value in for `migrate()` to map across.
@export var unlocked_level: int = 1


# Bring an out-of-date save up to the current schema in place. Returns the same
# instance for call chaining. No-op for an already-current save.
static func migrate(save: SaveGame) -> SaveGame:
	if save.schema_version < SCHEMA_VERSION:
		# v1 → v2: the 1-based "highest unlocked level" becomes campaign_level,
		# and the presence of a v1 save means the player had a run in progress,
		# so Continue should be available.
		save.campaign_level = maxi(1, save.unlocked_level)
		save.has_playthrough = true
		save.schema_version = SCHEMA_VERSION
	return save


# Clear the Playthrough tier (New Game). Leaves the Profile tier untouched.
func reset_playthrough() -> void:
	has_playthrough = false
	campaign_level = 1
	coins = 0
	checkpoint = {}
	level_stars = {}
	owned_tiers = {}
	owned_gadgets = []
	equipped_loadout = []
	gadget_slots = 1
