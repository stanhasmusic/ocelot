class_name InputAssistTunables
extends Resource

# Per-scheme assist knobs (PRD-03 / ADR-0006). One shared difficulty curve runs
# across every input; the precise-vs-imprecise gap is absorbed here, not by a
# separate per-platform content curve. These are the *only* per-device dials.
#
# Conservative defaults: minimal assist so the baseline still demands skill;
# dial the imprecise inputs up during the Together playtest loop (out of scope
# here). Mouse is the tuned proxy and stays unassisted.

# Auto-swap feel. Exposed so the swap can be made instant-but-stable without a
# recompile; consumed by the InputScheme resolver.
@export var swap_debounce_seconds: float = 0.1
@export var stick_deadzone: float = 0.2

# Pickup-magnet radius (px). 0 = straight fall (today's behaviour). Bigger for
# the imprecise velocity branch; the positional/mouse proxy stays 0.
@export var magnet_radius_positional: float = 0.0
@export var magnet_radius_velocity: float = 60.0

# Effective hurtbox scale. 1.0 = unchanged; < 1.0 shrinks the hurtbox so
# near-misses that look like misses do not kill imprecise inputs.
@export var hitbox_forgiveness_positional: float = 1.0
@export var hitbox_forgiveness_velocity: float = 0.9

# Reserved movement/aim-snap strength for the velocity branch. No manual aim in
# a fixed-fire shmup yet, so 0 = off; kept so the dial exists when it is needed.
@export var aim_snap_velocity: float = 0.0

func magnet_radius(scheme: int) -> float:
	if scheme == InputScheme.Scheme.VELOCITY:
		return magnet_radius_velocity
	return magnet_radius_positional

func hitbox_forgiveness(scheme: int) -> float:
	if scheme == InputScheme.Scheme.VELOCITY:
		return hitbox_forgiveness_velocity
	return hitbox_forgiveness_positional
