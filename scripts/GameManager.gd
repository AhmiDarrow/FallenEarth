## GameManager — Flow controller for scene navigation in Fallen Earth
## Handles Splash → MainMenu → CharacterSelection → Hub/Rift transitions.
extends Node

signal scene_changed(scene_path: String)
signal character_ready(race_key: String, class_key: String, origin: String, character_id: String)

# Scene paths
const SPLASH_SCENE := "res://scenes/ui/Splash.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const WORLD_GEN_SCENE := "res://scenes/WorldGeneration.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/CharacterSelection.tscn"
const HUB_SCENE := "res://scenes/HubWorld.tscn"
const WORLD_MAP_SCENE := "res://scenes/WorldMapScreen.tscn"
const RIFT_SCENE := "res://scenes/RiftInstance.tscn"
const TACTICAL_COMBAT_SCENE := "res://scenes/CombatLevel.tscn"

var _current_scene: String = ""

## Queued character data to forward when HubWorld loads
var _hub_character_data: Dictionary = {}


# ===================================================================
# Lifecycle
# ===================================================================

func _ready() -> void:
	print("[GameManager] Initialized. (Main scene should be Splash.tscn which drives the initial flow)")
	# Note: We no longer force-load Splash here because project.godot sets
	# run/main_scene to Splash.tscn. The Splash scene itself handles the timer
	# and calls on_splash_complete() to transition.


# ===================================================================
# Public API — Scene Navigation
# ===================================================================

## Non-async core: load packed scene and switch tree. Returns PackedScene.
func _do_change_scene(scene_path: String) -> PackedScene:
	if not ResourceLoader.exists(scene_path):
		push_error("[GameManager] Scene resource missing: %s" % scene_path)
		return PackedScene.new()
	
	var packed: PackedScene = load(scene_path) as PackedScene
	if not is_instance_valid(packed):
		push_error("[GameManager] Failed to load scene resource: %s" % scene_path)
		return PackedScene.new()
	
	print("[GameManager] Changing scene to: %s" % scene_path)
	var err: Error = get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_error("[GameManager] change_scene_to_packed failed with error: %s" % err)
		return PackedScene.new()
	
	_current_scene = scene_path
	scene_changed.emit(scene_path)
	print("[GameManager] Scene change requested: %s" % scene_path)
	return packed


## Wrapper that changes scene. For Hub, we queue data and rely primarily on GameState in target _ready.
func _load_scene(scene_path: String, forward_hub_data: bool = false) -> void:
	var packed: PackedScene = _do_change_scene(scene_path)
	if not is_instance_valid(packed):
		return
	
	# Queue only; actual apply prefers GameState reads in HubWorld._ready() (more robust than post-await cast)
	# The previous await+cast after destructive change was fragile.
	if forward_hub_data and not _hub_character_data.is_empty():
		var snapshot := _hub_character_data.duplicate(true)
		_hub_character_data = {}
		# Defer a best-effort set in case the receiver supports it
		call_deferred("_apply_hub_data_deferred", snapshot)
	else:
		_hub_character_data = {}


func _apply_hub_data_deferred(snapshot: Dictionary) -> void:
	var hub: HubWorld = get_tree().current_scene as HubWorld
	if is_instance_valid(hub) and not snapshot.is_empty():
		hub.set_character_data(snapshot)
		print("[GameManager] Character data (deferred) to HubWorld (%s)." % snapshot.get("id", "?"))


func go_to_menu(character_id: String = "", slot: int = -1) -> void:
	if slot >= 0 and character_id != "":
		print("[GameManager] Continuing character '%s' from slot %d → Menu" % [character_id, slot])
	else:
		print("[GameManager] No character data — fresh menu.")
		print("[GameManager] Queueing change to main menu via deferred...")
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU_SCENE)


func go_to_world_gen() -> void:
	print("[GameManager] Navigating to world generation (before character creation)")
	var packed: PackedScene = load(WORLD_GEN_SCENE) as PackedScene
	if not is_instance_valid(packed):
		push_error("[GameManager] Failed to load WorldGeneration scene at: " + WORLD_GEN_SCENE)
		return
	get_tree().call_deferred("change_scene_to_packed", packed)

func go_to_character_select() -> void:
	print("[GameManager] Navigating to character select")
	var packed: PackedScene = load(CHARACTER_SELECT_SCENE) as PackedScene
	if not is_instance_valid(packed):
		push_error("[GameManager] Failed to load CharacterSelection scene at: " + CHARACTER_SELECT_SCENE)
		return
	get_tree().call_deferred("change_scene_to_packed", packed)


func go_to_world_map() -> void:
	print("[GameManager] Navigating to strategic world map")
	if not ResourceLoader.exists(WORLD_MAP_SCENE):
		push_error("[GameManager] WorldMapScreen scene missing.")
		return
	var packed: PackedScene = load(WORLD_MAP_SCENE) as PackedScene
	if is_instance_valid(packed):
		get_tree().call_deferred("change_scene_to_packed", packed)
		_current_scene = WORLD_MAP_SCENE
		scene_changed.emit(WORLD_MAP_SCENE)


func go_to_hub(character_data: Dictionary) -> void:
	print("[GameManager] Navigating to Hub with character: %s (%s)" % [
		character_data.get("id", "?"), character_data.get("race", "?")])
	
	if ResourceLoader.exists(HUB_SCENE):
		_hub_character_data = character_data.duplicate()
		# Use deferred scene change for consistency with other navs and to let current scene cleanup
		var packed: PackedScene = load(HUB_SCENE) as PackedScene
		if is_instance_valid(packed):
			get_tree().call_deferred("change_scene_to_packed", packed)
			# Best effort data forward (HubWorld also reads GameState on _ready)
			call_deferred("_apply_hub_data_deferred", _hub_character_data.duplicate(true))
			_hub_character_data = {}
			_current_scene = HUB_SCENE
			scene_changed.emit(HUB_SCENE)
		else:
			push_error("[GameManager] Failed to load Hub scene")
	else:
		print("[GameManager] HubScene not ready — staying on selection screen.")


func go_to_tactical_combat(encounter: Dictionary) -> void:
	print("[GameManager] Starting tactical combat (%s)" % encounter.get("source", "?"))
	var gs: GameState = GameState
	if is_instance_valid(gs):
		gs.set_pending_combat(encounter)
	if not ResourceLoader.exists(TACTICAL_COMBAT_SCENE):
		push_error("[GameManager] TacticalCombat scene missing.")
		return
	var packed: PackedScene = load(TACTICAL_COMBAT_SCENE) as PackedScene
	if is_instance_valid(packed):
		get_tree().call_deferred("change_scene_to_packed", packed)
		_current_scene = TACTICAL_COMBAT_SCENE
		scene_changed.emit(TACTICAL_COMBAT_SCENE)


func go_to_rift(rift_id: String, biome_key: String = "Ash Wastes", rift_data: Dictionary = {}) -> void:
	print("[GameManager] Entering rift '%s' in biome '%s'" % [rift_id, biome_key])
	var gs: GameState = GameState
	if is_instance_valid(gs):
		var ctx := rift_data.duplicate(true) if not rift_data.is_empty() else {"rift_id": rift_id, "biome_key": biome_key}
		if not ctx.has("rift_id"):
			ctx["rift_id"] = rift_id
		if not ctx.has("biome_key"):
			ctx["biome_key"] = biome_key
		gs.set_pending_rift(ctx)
	if ResourceLoader.exists(RIFT_SCENE):
		var packed: PackedScene = load(RIFT_SCENE) as PackedScene
		if is_instance_valid(packed):
			# Pass rift info via GameState or direct; for now use call_deferred and let scene init from runner
			get_tree().call_deferred("change_scene_to_packed", packed)
			_current_scene = RIFT_SCENE
			scene_changed.emit(RIFT_SCENE)
			# After load, the RiftInstance will start the run
		else:
			push_error("[GameManager] Failed to load Rift scene")
	else:
		push_error("[GameManager] Rift scene not found at %s. Create RiftInstance.tscn first." % RIFT_SCENE)


# ===================================================================
# Character Creation Hook — called by CharacterSelection commit
# ===================================================================

func on_character_selected(race_key: String, class_key: String) -> void:
	var gs: GameState = GameState
	if is_instance_valid(gs):
		character_ready.connect(_on_character_ready)
		print("[GameManager] Character selected: race=%s class=%s → loading Hub" % [race_key, class_key])
		go_to_hub({"id": "pending", "race": race_key, "class": class_key})
	else:
		push_error("[GameManager] GameState autoload not available during character selection.")


# ===================================================================
# Splash-screen callback
# ===================================================================

func on_splash_complete() -> void:
	go_to_menu()  # fresh start


# ===================================================================
# Helpers
# ===================================================================

func _on_character_ready(race_key: String, class_key: String, origin: String, character_id: String) -> void:
	print("[GameManager] Character '%s' (%s/%s, origin=%s) ready." % [character_id, race_key, class_key, origin])
