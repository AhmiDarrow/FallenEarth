## ProgressionManager — Player XP, level, EC (currency) tracking.
##
## Phase 2 autoload. Player level starts at 1; XP-to-next is a fixed
## curve (50 + level * 25). XP gained from mob kills / quest completion
## accumulates. Level up fires the level_up signal; the HUD listens
## and updates the level number.
##
## EarthCoin (EC) is the in-game currency. spend_ec() returns false if
## the player can't afford.
##
## Persistence: like InventoryManager, this is non-persistent in
## Phase 2 — GameState.SaveManager will be extended in Phase 8 to
## read/write xp/level/ec. For now they reset on game close.
extends Node

const STARTING_LEVEL := 1
const STARTING_XP := 0
const STARTING_EC := 50
const MAX_LEVEL := 256  # matches ClassProgression.max_level

signal xp_changed(current_xp: int, xp_to_next: int)
signal level_up(new_level: int, levels_gained: int)
signal ec_changed(current_ec: int)

var level: int = STARTING_LEVEL
var xp: int = STARTING_XP
var ec: int = STARTING_EC


func _ready() -> void:
	print("[ProgressionManager] Initialized (L%d, %d EC)." % [level, ec])


# ---------------------------------------------------------------------------
# XP & Level
# ---------------------------------------------------------------------------

## XP required to advance from `current_level` to `current_level + 1`.
## Curve: 50 + level * 25. L1→L2: 75, L10→L11: 300, L100→L101: 2550, L255→L256: 6425.
func xp_to_next(current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return 0
	return 50 + current_level * 25


## Add `amount` XP. Triggers level-ups as needed. Returns levels gained.
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var levels_gained := 0
	# Loop in case of large XP gains that skip multiple levels.
	while xp >= xp_to_next(level) and level < MAX_LEVEL:
		xp -= xp_to_next(level)
		level += 1
		levels_gained += 1
	emit_signal("xp_changed", xp, xp_to_next(level))
	if levels_gained > 0:
		emit_signal("level_up", level, levels_gained)
		print("[ProgressionManager] Level up! Now L%d (gained %d)" % [level, levels_gained])
	return levels_gained


# ---------------------------------------------------------------------------
# EarthCoin
# ---------------------------------------------------------------------------

func add_ec(amount: int) -> void:
	if amount <= 0:
		return
	ec += amount
	emit_signal("ec_changed", ec)


## Spend `amount` EC. Returns true on success, false if insufficient.
func spend_ec(amount: int) -> bool:
	if amount <= 0:
		return true
	if ec < amount:
		return false
	ec -= amount
	emit_signal("ec_changed", ec)
	return true


# ---------------------------------------------------------------------------
# Snapshot / restore (used by SaveManager in Phase 8)
# ---------------------------------------------------------------------------

func get_snapshot() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"ec": ec,
	}


func restore_from_snapshot(snap: Dictionary) -> void:
	level = int(snap.get("level", STARTING_LEVEL))
	xp = int(snap.get("xp", STARTING_XP))
	ec = int(snap.get("ec", STARTING_EC))
	emit_signal("xp_changed", xp, xp_to_next(level))
	emit_signal("ec_changed", ec)
