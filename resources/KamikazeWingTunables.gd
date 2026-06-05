class_name KamikazeWingTunables
extends Resource

# Every feel value of the Kamikaze wing (PRD-13), in the EconomyTunables /
# HangarTunables mould — so the encounter tunes in a tight loop without code.
# Seeded CONSERVATIVE per the slower-defaults principle (a small V, a generous
# telegraph, an unhurried stagger, a moderate dive): the human dials the menace
# up from here, they don't have to talk it down.
#
# The coordinator (`KamikazeWing`) reads the formation/timing knobs; each member
# (`Kamikaze`) reads the per-plane knobs the coordinator hands it.

@export_group("Formation")
## Planes in the wing. A conservative V of ~5.
@export var count: int = 5
## Pixels between adjacent lanes; scales the whole spread linearly.
@export var spacing: float = 70.0
## Formation shape (VEE = centred chevron; LINE = flat row).
@export var shape: KamikazeChoreography.Shape = KamikazeChoreography.Shape.VEE

@export_group("Entry")
## Px/s a member slides down into its formation slot from off the top.
@export var entry_speed: float = 180.0

@export_group("Commit schedule")
## Seconds the formed wing holds before the first dive — the settle beat.
@export var hold_time: float = 1.5
## Seconds between successive commits down the formation (one at a time).
@export var stagger_gap: float = 1.1

@export_group("Dive")
## Telegraph length before a committed dive — bank/tilt + brighten. Generous so
## the encounter is readable and shootable.
@export var telegraph_seconds: float = 1.0
## Initial dive speed (px/s) at the commit instant.
@export var dive_speed: float = 320.0
## Dive acceleration (px/s^2) along the locked line.
@export var dive_accel: float = 260.0

@export_group("Member")
## Member HP — killable in 1–2 hits during the telegraph.
@export var member_hp: int = 2
## Coins paid for shooting a plane down (modest: above a Strafer, below a Convoy).
## A completed dive (despawn, not death) pays nothing.
@export var member_coin_value: int = 3
