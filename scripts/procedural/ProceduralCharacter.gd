## ProceduralCharacter — Full procedurally drawn humanoids for any race/gender.
## Extends ProceduralRenderer; draw() builds a complete figure from data-driven parameters.
## Supports: race (Human/Mutant/Vesperid), gender, anim (idle/walk/run/attack), pose_frame,
##           equipment (weapon hand, armor slots), and direction.
## Autoload pattern: create instance, call setup_for(), draw(), hide() when done.

extends ProceduralRenderer

# Metadata
var race: String = "Human"
var gender: String = "male"
var anim: String = "idle"
var pose_frame: int = 0
var direction: int = 0  # 0-7: N,NE,E,SE,S,SW,W,NW,N (8-dirs)
var is_male: bool = true

# Equipment slots (drawn as overlay sprites)
var weapon_hand: String = "left"  # left / right
var armor_head: String = ""
var armor_torso: String = ""
var armor_arms: String = ""
var armor_legs: String = ""
var armor_back: String = ""

# Runtime data
var _drawn: bool = false
var _equipment_visible: bool = true

func _setup() -> void:
	# Clamp pose_frame to anim frame count
	if anim == "walk" or anim == "run":
		pose_frame = pose_frame % 8
	elif anim == "attack" or anim == "swing":
		pose_frame = pose_frame % 4
	elif anim == "idle":
		pose_frame = pose_frame % 4
	elif anim == "hurt":
		pose_frame = pose_frame % 3
	elif anim == "death":
		pose_frame = pose_frame % 2

func _draw() -> void:
	# Base body: rags-colored rectangle (simplified humanoid silhouette)
	draw_rect(Rect2(Vector2(0, 0), size), COLORS["rags"])

	# Head: circle + facial features (gender/race driven)
	var head_offset: Vector2 = Vector2(0, -size.y * 0.25)
	draw_circle(Vector2(size.x * 0.4, head_offset.y), size.x * 0.3, COLORS["skin"])

	# Draw gender-specific features
	if not is_male:
		# Female: larger eyes, subtle jaw line
		draw_line(head_offset + Vector2(-size.x * 0.1, 0), head_offset + Vector2(-size.x * 0.1, -size.y * 0.05), COLORS["skin"])
		draw_line(head_offset + Vector2(-size.x * 0.1, 0), head_offset + Vector2(-size.x * 0.1, -size.y * 0.08), COLORS["skin"])
		draw_line(head_offset + Vector2(size.x * 0.1, 0), head_offset + Vector2(size.x * 0.1, -size.y * 0.05), COLORS["skin"])
		draw_line(head_offset + Vector2(size.x * 0.1, 0), head_offset + Vector2(size.x * 0.1, -size.y * 0.08), COLORS["skin"])
	else:
		# Male: defined jaw
		draw_line(head_offset + Vector2(-size.x * 0.15, 0), head_offset + Vector2(-size.x * 0.15, -size.y * 0.06), COLORS["skin"])
		draw_line(head_offset + Vector2(-size.x * 0.15, 0), head_offset + Vector2(-size.x * 0.10, -size.y * 0.10), COLORS["skin"])
		draw_line(head_offset + Vector2(size.x * 0.15, 0), head_offset + Vector2(size.x * 0.15, -size.y * 0.06), COLORS["skin"])
		draw_line(head_offset + Vector2(size.x * 0.15, 0), head_offset + Vector2(size.x * 0.10, -size.y * 0.10), COLORS["skin"])

	# Race-specific facial features
	match race.to_lower():
		"mutant":
			# Mutant: pronounced brow ridge, broader jaw
			draw_line(head_offset + Vector2(-size.x * 0.15, 0), head_offset + Vector2(-size.x * 0.15, -size.y * 0.06), COLORS["skin"])
			draw_line(head_offset + Vector2(size.x * 0.15, 0), head_offset + Vector2(size.x * 0.15, -size.y * 0.06), COLORS["skin"])
			# Brow ridge
			draw_line(head_offset + Vector2(-size.x * 0.22, -size.y * 0.06), head_offset + Vector2(-size.x * 0.08, -size.y * 0.08), COLORS["skin"])
			draw_line(head_offset + Vector2(-size.x * 0.08, -size.y * 0.08), head_offset + Vector2(size.x * 0.08, -size.y * 0.08), COLORS["skin"])
			draw_line(head_offset + Vector2(size.x * 0.08, -size.y * 0.08), head_offset + Vector2(size.x * 0.22, -size.y * 0.06), COLORS["skin"])

		"vesperid":
			# Vesperid: pointed ears, elongated snout
			# Elongated snout
			draw_line(head_offset + Vector2(-size.x * 0.12, -size.y * 0.08), head_offset + Vector2(-size.x * 0.12, -size.y * 0.16), COLORS["skin"])
			draw_line(head_offset + Vector2(size.x * 0.12, -size.y * 0.08), head_offset + Vector2(size.x * 0.12, -size.y * 0.16), COLORS["skin"])
			# Pointed ears
			draw_line(head_offset + Vector2(-size.x * 0.18, -size.y * 0.10), head_offset + Vector2(-size.x * 0.26, -size.y * 0.22), COLORS["skin"])
			draw_line(head_offset + Vector2(-size.x * 0.26, -size.y * 0.22), head_offset + Vector2(-size.x * 0.18, -size.y * 0.08), COLORS["skin"])
			draw_line(head_offset + Vector2(size.x * 0.18, -size.y * 0.10), head_offset + Vector2(size.x * 0.26, -size.y * 0.22), COLORS["skin"])
			draw_line(head_offset + Vector2(size.x * 0.26, -size.y * 0.22), head_offset + Vector2(size.x * 0.18, -size.y * 0.08), COLORS["skin"])

		"human":
			# Human: simple eyes + mouth
			pass

		_:
			# Unknown race: neutral features
			pass

	# Limbs: lines that change with anim/pose_frame
	_draw_limbs()

	# Draw equipment overlays (weapon hand, armor slots)
	if _equipment_visible:
		_draw_equipment()

	# Direction indicator: subtle rotation hint (not applied to sprite, just visual guide)
	if anim != "idle" and anim != "run":
		var dir_offset: Vector2 = Vector2(size.x * 0.15, -size.y * 0.15)
		draw_line(dir_offset, dir_offset + Vector2(0, -size.y * 0.03), COLORS["highlight"])
		dir_offset = Vector2(-size.x * 0.15, -size.y * 0.15)
		draw_line(dir_offset, dir_offset + Vector2(0, -size.y * 0.03), COLORS["highlight"])

func _draw_limbs() -> void:
	# Base limb positions (neutral idle)
	var limb_offset: Vector2 = Vector2(0, 0)
	match anim:
		"idle":
			# Neutral idle — arms at sides, slight hip sway
			limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
			draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
			limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
			draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm

		"walk":
			# Walk cycle (4 frames: left arm right, right arm left, swap)
			var frame: int = pose_frame % 4
			if frame == 0:
				limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
				limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm
			elif frame == 1:
				limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
				limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm
			elif frame == 2:
				limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
				limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm
			else:
				limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
				limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm

		"run":
			# Run cycle (8 frames: arms swing more)
			var frame: int = pose_frame % 8
			if frame < 4:
				limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
				limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm
			else:
				limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
				limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm

		"attack" or "swing":
			# Attack: arm swings forward (frame 0-3)
			var frame: int = pose_frame % 4
			if frame == 0:
				limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
				limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm
			elif frame == 1:
				limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
				limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm
			elif frame == 2:
				limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
				limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm
			else:
				limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
				limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
				draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm

		"hurt":
			# Hurt: arms shield face, slight crouch
			limb_offset = Vector2(-size.x * 0.12, -size.y * 0.15)
			draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # left arm
			limb_offset = Vector2(size.x * 0.12, -size.y * 0.15)
			draw_line(limb_offset, limb_offset + Vector2(0, -size.y * 0.18), COLORS["rags"])  # right arm

		"death":
			# Death: limp arms, no animation
			pass

func _draw_equipment() -> void:
	# Weapon hand: draw a simple weapon shape
	if weapon_hand == "right":
		_draw_weapon_hand(size.x * 0.5, size.y * 0.2, COLORS["metal"])
	elif weapon_hand == "left":
		_draw_weapon_hand(-size.x * 0.5, size.y * 0.2, COLORS["metal"])

	# Armor head overlay
	if not armor_head.is_empty():
		_draw_armor_overlay(size.x * 0.35, size.y * 0.25, COLORS["metal"], armor_head)

	# Armor torso overlay
	if not armor_torso.is_empty():
		_draw_armor_overlay(size.x * 0.3, size.y * 0.28, COLORS["rags"], armor_torso)

	# Armor arms overlay
	if not armor_arms.is_empty():
		_draw_armor_overlay(size.x * 0.15, size.y * 0.18, COLORS["metal"], armor_arms)

	# Armor legs overlay
	if not armor_legs.is_empty():
		_draw_armor_overlay(size.x * 0.18, size.y * 0.22, COLORS["metal"], armor_legs)

	# Armor back overlay
	if not armor_back.is_empty():
		_draw_armor_overlay(size.x * 0.25, size.y * 0.15, COLORS["rags"], armor_back)

func _draw_weapon_hand(x: float, y: float, color: Color) -> void:
	# Simple weapon shape: lines forming a basic sword/axe silhouette
	var offset: Vector2 = Vector2(x, y)
	draw_line(offset + Vector2(0, -size.y * 0.02), offset + Vector2(0, -size.y * 0.15), color)
	draw_line(offset + Vector2(-size.x * 0.02, -size.y * 0.15), offset + Vector2(size.x * 0.02, -size.y * 0.15), color)

func _draw_armor_overlay(x: float, y: float, color: Color, item: String) -> void:
	# Procedural armor overlay based on item name
	var offset: Vector2 = Vector2(x, y)
	match item.to_lower():
		"helm":
			draw_circle(offset + Vector2(0, -size.y * 0.1), size.x * 0.18, color)
			draw_line(offset + Vector2(-size.x * 0.1, -size.y * 0.1), offset + Vector2(-size.x * 0.1, -size.y * 0.06), color)
			draw_line(offset + Vector2(size.x * 0.1, -size.y * 0.1), offset + Vector2(size.x * 0.1, -size.y * 0.06), color)

		"vest":
			draw_rect(offset + Vector2(-size.x * 0.1, -size.y * 0.05), size.x * 0.2, size.y * 0.15, color)
			draw_line(offset + Vector2(-size.x * 0.1, -size.y * 0.05), offset + Vector2(-size.x * 0.1, -size.y * 0.15), color)
			draw_line(offset + Vector2(size.x * 0.1, -size.y * 0.05), offset + Vector2(size.x * 0.1, -size.y * 0.15), color)

		"gloves":
			draw_rect(offset + Vector2(-size.x * 0.05, -size.y * 0.1), size.x * 0.1, size.y * 0.08, color)
			draw_rect(offset + Vector2(size.x * 0.05, -size.y * 0.1), size.x * 0.1, size.y * 0.08, color)

		"boots":
			draw_rect(offset + Vector2(-size.x * 0.06, -size.y * 0.05), size.x * 0.12, size.y * 0.1, color)
			draw_rect(offset + Vector2(size.x * 0.06, -size.y * 0.05), size.x * 0.12, size.y * 0.1, color)

		"backpack":
			draw_rect(offset + Vector2(-size.x * 0.1, -size.y * 0.08), size.x * 0.2, size.y * 0.12, color)
			draw_line(offset + Vector2(-size.x * 0.1, -size.y * 0.08), offset + Vector2(-size.x * 0.1, -size.y * 0.16), color)
			draw_line(offset + Vector2(size.x * 0.1, -size.y * 0.08), offset + Vector2(size.x * 0.1, -size.y * 0.16), color)

		_:
			# Unknown item: draw a simple rectangular plate
			draw_rect(offset + Vector2(-size.x * 0.1, -size.y * 0.1), size.x * 0.2, size.y * 0.2, color)

func _process(delta: float) -> void:
	# Hook for subclasses — ProceduralCharacter does not need per-frame updates
	pass

# -------------------------------------------------------------------------
# Setup for data-driven configuration (called before draw)
# -------------------------------------------------------------------------

func setup_for(data: Dictionary) -> void:
	# data = {race: "Mutant", gender: "female", anim: "walk", pose_frame: 2,
	#         direction: 3, weapon_hand: "right", armor_head: "helm", ...}
	race = str(data.get("race", "Human"))
	gender = str(data.get("gender", "male"))
	anim = str(data.get("anim", "idle"))
	pose_frame = int(data.get("pose_frame", 0))
	direction = int(data.get("direction", 0))
	is_male = (gender.to_lower() == "male")
	weapon_hand = str(data.get("weapon_hand", "left"))
	armor_head = str(data.get("armor_head", ""))
	armor_torso = str(data.get("armor_torso", ""))
	armor_arms = str(data.get("armor_arms", ""))
	armor_legs = str(data.get("armor_legs", ""))
	armor_back = str(data.get("armor_back", ""))

func set_equipment(data: Dictionary) -> void:
	# data = {"head": "helm", "torso": "vest", "arms": "gloves", "legs": "boots", "back": "backpack"}
	armor_head = str(data.get("head", ""))
	armor_torso = str(data.get("torso", ""))
	armor_arms = str(data.get("arms", ""))
	armor_legs = str(data.get("legs", ""))
	armor_back = str(data.get("back", ""))

func set_equipment_visible(visible: bool) -> void:
	_equipment_visible = visible

# -------------------------------------------------------------------------
# Static helpers for race/gender representation (data-driven)
# -------------------------------------------------------------------------

static func get_race_id(race: String, gender: String) -> String:
	# Returns canonical key for race/gender combo (used by GameState)
	return "%s|%s" % [race.to_lower(), gender.to_lower()]

static func get_gender_id(gender: String) -> String:
	# Returns canonical gender key
	return gender.to_lower()

# -------------------------------------------------------------------------
# Exposed methods
# -------------------------------------------------------------------------

func get_race() -> String:
	return race

func get_gender() -> String:
	return gender

func get_anim() -> String:
	return anim

func get_pose_frame() -> int:
	return pose_frame

func get_direction() -> int:
	return direction

func get_equipment() -> Dictionary:
	return {
		"head": armor_head,
		"torso": armor_torso,
		"arms": armor_arms,
		"legs": armor_legs,
		"back": armor_back,
		"weapon_hand": weapon_hand,
	}
