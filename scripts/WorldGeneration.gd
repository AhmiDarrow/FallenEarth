## WorldGeneration — Simple screen for choosing seed and generating the overworld before character creation.
extends Control

@onready var seed_edit: LineEdit = $MainVBox/SeedHBox/SeedEdit
@onready var generate_btn: Button = $MainVBox/ButtonsHBox/GenerateButton
@onready var continue_btn: Button = $MainVBox/ButtonsHBox/ContinueButton
@onready var status_label: RichTextLabel = $MainVBox/StatusLabel
@onready var candidates_container: VBoxContainer = $MainVBox/CandidatesContainer  # Assume added in scene or create dynamically

var world_generator: WorldGenerator = null
var generated_seed: String = ""
var generated_world: Dictionary = {}
var start_tile_key: String = ""
var start_tile_info: Dictionary = {}
var _candidate_buttons: Array = []

const DEFAULT_SEED := "UNDEREARTH_001"

func _ready() -> void:
	generate_btn.pressed.connect(_on_generate_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	
	# Optional: random button
	if has_node("MainVBox/SeedHBox/RandomButton"):
		$MainVBox/SeedHBox/RandomButton.pressed.connect(_on_random_seed_pressed)
	
	seed_edit.text = DEFAULT_SEED
	continue_btn.disabled = true
	status_label.text = "[i]Enter a seed and generate the hexagonal sphere world (RimWorld-inspired). Then choose starting grid.[/i]"
	
	# Ensure candidates container
	if not has_node("MainVBox/CandidatesContainer"):
		var cont := VBoxContainer.new()
		cont.name = "CandidatesContainer"
		$MainVBox.add_child(cont)
		candidates_container = cont
		candidates_container.visible = false
	
	# Auto-load the generator
	world_generator = load("res://scripts/WorldGenerator.gd").new()
	if world_generator == null or not world_generator.initialize():
		status_label.text = "[color=red]Failed to load biome data! Check data/biomes.json[/color]"
		generate_btn.disabled = true

func _on_random_seed_pressed() -> void:
	seed_edit.text = "SEED_" + str(randi() % 100000)

func _on_generate_pressed() -> void:
	var chosen_seed = seed_edit.text.strip_edges()
	if chosen_seed.is_empty():
		chosen_seed = DEFAULT_SEED
		seed_edit.text = chosen_seed
	
	status_label.text = "[i]Generating hexagonal sphere world for seed: " + chosen_seed + "...[/i]"
	
	if world_generator == null or not world_generator.initialize():
		status_label.text = "[color=red]World generator not ready. Check biomes.json.[/color]"
		return
	
	generated_world = world_generator.generate(chosen_seed)
	generated_seed = chosen_seed
	
	var cands = world_generator.get_starting_candidates(3)
	var info_str = ""
	if cands.size() > 0:
		start_tile_key = cands[0]["key"]
		start_tile_info = cands[0]["tile"]
		info_str = "\nDefault start: " + start_tile_info.get("name", "Unknown") + " (q,r: " + start_tile_key + ")"
	
	status_label.text = "[color=green]Hex sphere generated![/color]\n" + \
		"Seed: " + chosen_seed + "\n" + \
		"Tiles: " + str(generated_world.size()) + info_str + \
		"\nSelect a starting grid below (RimWorld-style site selection):"
	
	_show_start_candidates(cands)
	
	continue_btn.disabled = false
	print("[WorldGeneration] Hex sphere generated with seed: ", chosen_seed)

func _on_continue_pressed() -> void:
	if generated_world.is_empty():
		push_warning("Generate the world first!")
		return
	
	# Store in GameState: world + start tile (RimWorld style player choice)
	var gs := get_node_or_null("/root/GameState")
	if is_instance_valid(gs) and gs.has_method("set_world_data"):
		gs.call("set_world_data", generated_seed, generated_world)
		if gs.has_method("set_start_tile"):
			gs.call("set_start_tile", start_tile_key, start_tile_info)

	var nm := get_node_or_null("/root/NPCManager")
	if is_instance_valid(nm) and nm.has_method("generate_for_world"):
		var roster: Variant = nm.call("generate_for_world", generated_seed, generated_world, start_tile_key)
		var npc_count: int = roster.size() if roster is Dictionary else 0
		print("[WorldGeneration] Procedural NPC roster: %d unique recruits for this seed." % npc_count)
	
	print("[WorldGeneration] World hex sphere ready. Start tile: ", start_tile_key, ". Proceeding to character selection.")
	
	var gm := get_node_or_null("/root/GameManager")
	if is_instance_valid(gm) and gm.has_method("go_to_character_select"):
		gm.call_deferred("go_to_character_select")
	else:
		push_error("GameManager not found")

func _show_start_candidates(cands: Array) -> void:
	# Clear previous
	for btn in _candidate_buttons:
		if is_instance_valid(btn): btn.queue_free()
	_candidate_buttons.clear()
	
	if not has_node("MainVBox/CandidatesContainer"):
		var cont = VBoxContainer.new()
		cont.name = "CandidatesContainer"
		$MainVBox.add_child(cont)
		candidates_container = cont
	
	candidates_container.visible = true
	if has_node("MainVBox/CandidatesLabel"):
		get_node("MainVBox/CandidatesLabel").visible = true
	
	for cand in cands:
		var tile = cand["tile"]
		var key = cand["key"]
		var btn := Button.new()
		var biome = tile.get("name", "Unknown")
		var desc = "Temp:%.1f Rain:%.1f Elev:%.1f Rift:%.1f" % [
			tile.get("temperature", 0), tile.get("rainfall", 0), tile.get("elevation", 0), tile.get("rift_chance", 0)
		]
		btn.text = "%s (%s) - %s" % [biome, key, desc]
		btn.pressed.connect(_on_start_tile_selected.bind(key, tile))
		candidates_container.add_child(btn)
		_candidate_buttons.append(btn)

func _on_start_tile_selected(key: String, tile: Dictionary) -> void:
	start_tile_key = key
	start_tile_info = tile
	status_label.text += "\n\nSelected start: %s at %s" % [tile.get("name", "?"), key]
	for btn in _candidate_buttons:
		if is_instance_valid(btn):
			btn.modulate = Color(1,1,1) if btn.text.find(key) == -1 else Color(1,1,0.5)
	print("[WorldGeneration] Player chose starting grid: ", key)