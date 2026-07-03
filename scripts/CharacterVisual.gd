# CharacterVisual.gd
# Base sprite by race + gender (neutral clothing).
# Equipment layered on top as separate sprites (synced animation/position).
# Class does NOT affect base sprite - only stats/abilities. Gear visuals from EquipmentManager.

extends Node2D

@onready var base_sprite: Sprite2D = $BaseSprite
@onready var head_overlay: Sprite2D = $Equipment/Head if has_node("Equipment/Head") else null
@onready var torso_overlay: Sprite2D = $Equipment/Torso if has_node("Equipment/Torso") else null
@onready var legs_overlay: Sprite2D = $Equipment/Legs if has_node("Equipment/Legs") else null
@onready var arms_overlay: Sprite2D = $Equipment/Arms if has_node("Equipment/Arms") else null
@onready var weapon_overlay: Sprite2D = $Equipment/Weapon if has_node("Equipment/Weapon") else null
@onready var back_overlay: Sprite2D = $Equipment/Back if has_node("Equipment/Back") else null

var current_race: String = "Human"
var current_gender: String = "male"
var current_anim: String = "idle"
var current_frame: int = 0

# Procedural fallback
var _use_procedural_graphics: bool = false
var _procedural_character: Node = null

func _ready():
	if not is_instance_valid(base_sprite):
		push_error("[CharacterVisual] BaseSprite node required")

	# Procedural fallback if enabled
	_use_procedural_graphics = GameState.use_procedural_graphics if has_node("/root/GameState") else false
	if _use_procedural_graphics and not has_node("ProceduralCharacter"):
		var proc = ProceduralCharacter.new()
		proc.name = "ProceduralCharacter"
		add_child(proc)
		_procedural_character = proc

func set_base_sprite(race: String, gender: String):
	current_race = race
	current_gender = gender
	_update_base_texture()

func _update_base_texture():
	# Procedural fallback if enabled and no assets found
	if _use_procedural_graphics and _procedural_character is not null:
		# Try to load assets normally
		if DirAccess.dir_exists_absolute("res://assets/characters/%s_%s/" % [current_race.to_lower(), current_gender.to_lower()]):
			# Assets exist — use real sprite
			if is_instance_valid(base_sprite):
				base_sprite.visible = true
			return

		# No assets — fall back to procedural
		if not is_instance_valid(_procedural_character):
			_procedural_character = ProceduralCharacter.new()
			_procedural_character.name = "ProceduralCharacter"
			add_child(_procedural_character)

		_procedural_character.setup_for({
			"race": current_race,
			"gender": current_gender,
			"anim": current_anim,
			"pose_frame": current_frame,
			"direction": 0,
			"weapon_hand": "left",
			"armor_head": "",
			"armor_torso": "",
			"armor_arms": "",
			"armor_legs": "",
			"armor_back": "",
		})
		_procedural_character.draw()
		# Hide the base sprite when using procedural
		if is_instance_valid(base_sprite):
			base_sprite.visible = false
		return

	# Normal asset loading
	if not is_instance_valid(base_sprite):
		return

	# Smart selection for hand-drawn batch gens (high numbers = newer attempts).
	# Prefer files for the current pose with the highest numeric suffix (e.g. 00016 over 00001).
	# This helps pick better character figures as more renders complete.
	# Known good examples: vesperid_female side 00014 (full isolated hooded figure matching style).
	var race_l = current_race.to_lower()
	var gender_l = current_gender.to_lower()
	var dir_path = "res://assets/characters/%s_%s/" % [race_l, gender_l]

	if not DirAccess.dir_exists_absolute(dir_path):
		return

	var da = DirAccess.open(dir_path)
	if not da:
		return

	var best_path = ""
	var best_num = -1
	var pose_keys = [current_anim, "idle", "front", "side", "back"]

	da.list_dir_begin()
	var f = da.get_next()
	while f != "":
		if f.ends_with(".png") and f.begins_with("char_"):
			var lf = f.to_lower()
			var match_pose = false
			for k in pose_keys:
				if k in lf:
					match_pose = true
					break
			if match_pose:
				var num = -1
				var m = f.find("_000")
				if m != -1:
					var numstr = f.substr(m + 4, 2)  # rough 00-99
					if numstr.is_valid_int():
						num = numstr.to_int()
				if num > best_num:
					best_num = num
					best_path = dir_path + f
		f = da.get_next()
	da.list_dir_end()

	if best_path == "":
		# fallback: any char_ file
		da = DirAccess.open(dir_path)
		da.list_dir_begin()
		f = da.get_next()
		while f != "":
			if f.begins_with("char_") and f.ends_with(".png"):
				best_path = dir_path + f
				break
			f = da.get_next()
		da.list_dir_end()

	if best_path != "":
		if ResourceLoader.exists(best_path):
			base_sprite.texture = load(best_path)
		elif FileAccess.file_exists(best_path):
			var img := Image.new()
			if img.load(best_path) == OK:
				base_sprite.texture = ImageTexture.create_from_image(img)

func _update_base_texture():
	# Smart selection for hand-drawn batch gens (high numbers = newer attempts from the improved prompt).
	# Prefer files for the current pose with the highest numeric suffix (e.g. 00016 over 00001).
	# This helps pick better character figures as more renders complete.
	# Known good examples: vesperid_female side 00014 (full isolated hooded figure matching style).
	var race_l = current_race.to_lower()
	var gender_l = current_gender.to_lower()
	var dir_path = "res://assets/characters/%s_%s/" % [race_l, gender_l]

	if not DirAccess.dir_exists_absolute(dir_path):
		return

	var da = DirAccess.open(dir_path)
	if not da:
		return

	var best_path = ""
	var best_num = -1
	var pose_keys = [current_anim, "idle", "front", "side", "back"]

	da.list_dir_begin()
	var f = da.get_next()
	while f != "":
		if f.ends_with(".png") and f.begins_with("char_"):
			var lf = f.to_lower()
			var match_pose = false
			for k in pose_keys:
				if k in lf:
					match_pose = true
					break
			if match_pose:
				var num = -1
				var m = f.find("_000")
				if m != -1:
					var numstr = f.substr(m + 4, 2)  # rough 00-99
					if numstr.is_valid_int():
						num = numstr.to_int()
				if num > best_num:
					best_num = num
					best_path = dir_path + f
		f = da.get_next()
	da.list_dir_end()

	if best_path == "":
		# fallback: any char_ file
		da = DirAccess.open(dir_path)
		da.list_dir_begin()
		f = da.get_next()
		while f != "":
			if f.begins_with("char_") and f.ends_with(".png"):
				best_path = dir_path + f
				break
			f = da.get_next()
		da.list_dir_end()

	if best_path != "":
		if ResourceLoader.exists(best_path):
			base_sprite.texture = load(best_path)
		elif FileAccess.file_exists(best_path):
			var img := Image.new()
			if img.load(best_path) == OK:
				base_sprite.texture = ImageTexture.create_from_image(img)

func update_equipment(equipment_data: Dictionary):
	# equipment_data = {"head": "simple_helm", "torso": "leather_vest", "weapon": "pipe_club", ...}
	# Supports current generated assets: flat files like equip_torso_leather_vest_00001_.png + subdir attempts
	var slots = {
		"head": head_overlay,
		"torso": torso_overlay,
		"legs": legs_overlay,
		"arms": arms_overlay,
		"weapon": weapon_overlay,
		"back": back_overlay
	}
	for slot in slots:
		var overlay = slots[slot]
		if overlay == null:
			continue
		if not equipment_data.has(slot) or equipment_data[slot] == "":
			overlay.visible = false
			continue

		var item = equipment_data[slot]
		var candidates = []
		# Try exact subdir first (if user puts organized files)
		candidates.append("res://assets/equipment/%s/%s.png" % [slot, item])
		candidates.append("res://assets/equipment/%s/equip_%s_%s_00001_.png" % [slot, slot, item])
		# Flat root level (current generated naming)
		candidates.append("res://assets/equipment/equip_%s_%s_00001_.png" % [slot, item])
		candidates.append("res://assets/equipment/equip_%s_%s_00002_.png" % [slot, item])
		# Try by item name fragment at root
		var root_dir = "res://assets/equipment/"
		# also try direct filename match
		candidates.append(root_dir + item + ".png")

		var found = false
		for p in candidates:
			if ResourceLoader.exists(p) or FileAccess.file_exists(p):
				if ResourceLoader.exists(p):
					overlay.texture = load(p)
				else:
					var img := Image.new()
					if img.load(p) == OK:
						overlay.texture = ImageTexture.create_from_image(img)
				overlay.visible = true
				_sync_overlay(overlay)
				found = true
				break
		if not found:
			# Last resort: scan root for file containing the item name
			var da = DirAccess.open("res://assets/equipment/")
			if da:
				da.list_dir_begin()
				var f = da.get_next()
				while f != "":
					if f.ends_with(".png") and (item in f.to_lower() or slot in f.to_lower()):
						var full = "res://assets/equipment/" + f
						if ResourceLoader.exists(full) or FileAccess.file_exists(full):
							if ResourceLoader.exists(full):
								overlay.texture = load(full)
							else:
								var img := Image.new()
								if img.load(full) == OK:
									overlay.texture = ImageTexture.create_from_image(img)
							overlay.visible = true
							_sync_overlay(overlay)
							found = true
							break
					f = da.get_next()
				da.list_dir_end()
			if not found:
				overlay.visible = false

func _sync_overlay(overlay: Sprite2D):
	if is_instance_valid(base_sprite) and is_instance_valid(overlay):
		overlay.position = base_sprite.position
		overlay.scale = base_sprite.scale
		overlay.flip_h = base_sprite.flip_h

func play_animation(anim_name: String, frame: int = 0):
	current_anim = anim_name
	current_frame = frame
	_update_base_texture()
	var overlays = [head_overlay, torso_overlay, legs_overlay, arms_overlay, weapon_overlay, back_overlay]
	for ov in overlays:
		if is_instance_valid(ov) and ov.visible:
			_sync_overlay(ov)

func _process(delta):
	if is_instance_valid(base_sprite):
		var overlays = [head_overlay, torso_overlay, legs_overlay, arms_overlay, weapon_overlay, back_overlay]
		for ov in overlays:
			if is_instance_valid(ov) and ov.visible:
				_sync_overlay(ov)

# Usage:
# - In character scene: instance this, with child nodes for overlays under $Equipment.
# - Call set_base_sprite(race, gender) from spawn (RaceManager + AppearanceManager).
# - Call update_equipment(dict) from EquipmentManager when gear changes.
# - Call play_animation("walk", frame) or similar to drive layers.


# In HubWorld or a CharacterDisplay node, use:
# var visual = CharacterVisual.new()
# add_child(visual)
# visual.set_base_sprite(race, gender)
# visual.update_equipment(equip_dict)
