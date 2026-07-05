## Phase5ItemsPropsTest — Test scene for Phase 5 items, props, and rift special cases.
## Demonstrates floating items, held equipment, prop interactions, and portal distortion.
extends Control

var _viewport  # Entity3DViewport (untyped)
var _current_entities: Array = []  # Array of EntityVisualComponent
var _spawn_index: int = 0

var _test_presets: Array[Dictionary] = [
	{
		"label": "Item - Energy Orb",
		"data": {
			"entity_id": "item_orb",
			"visual": {
				"base_type": "item",
				"style": "orb",
				"radius": 0.2,
				"color": [0.4, 0.7, 1.0],
				"material": {"type": "glow", "roughness": 0.3},
				"variation_seed": 11111,
				"scale_range": [0.8, 1.2]
			}
		}
	},
	{
		"label": "Item - Plasma Blade",
		"data": {
			"entity_id": "item_weapon",
			"visual": {
				"base_type": "item",
				"style": "weapon",
				"length": 0.7,
				"width": 0.05,
				"color": [0.6, 0.3, 0.9],
				"material": {"type": "metallic", "roughness": 0.2},
				"variation_seed": 22222,
				"scale_range": [0.9, 1.1]
			}
		}
	},
	{
		"label": "Item - Armor Plate",
		"data": {
			"entity_id": "item_armor",
			"visual": {
				"base_type": "item",
				"style": "armor",
				"radius": 0.25,
				"color": [0.5, 0.5, 0.55],
				"material": {"type": "metallic", "roughness": 0.3},
				"variation_seed": 33333,
				"scale_range": [0.9, 1.1]
			}
		}
	},
	{
		"label": "Item - Medkit",
		"data": {
			"entity_id": "item_consumable",
			"visual": {
				"base_type": "item",
				"style": "consumable",
				"radius": 0.12,
				"color": [0.3, 0.8, 0.4],
				"material": {"type": "glow", "roughness": 0.3},
				"variation_seed": 44444,
				"scale_range": [0.8, 1.2]
			}
		}
	},
	{
		"label": "Prop - Rusty Door",
		"data": {
			"entity_id": "prop_door",
			"visual": {
				"base_type": "prop",
				"prop_type": "door",
				"width": 1.2,
				"height": 2.4,
				"color": [0.4, 0.3, 0.25],
				"material": {"type": "organic", "roughness": 0.9},
				"variation_seed": 55555,
				"scale_range": [0.9, 1.1]
			}
		}
	},
	{
		"label": "Prop - Supply Crate",
		"data": {
			"entity_id": "prop_container",
			"visual": {
				"base_type": "prop",
				"prop_type": "container",
				"width": 0.8,
				"height": 0.6,
				"depth": 0.6,
				"color": [0.45, 0.35, 0.3],
				"material": {"type": "metallic", "roughness": 0.5},
				"variation_seed": 66666,
				"scale_range": [0.8, 1.2]
			}
		}
	},
	{
		"label": "Prop - Scrap Vehicle",
		"data": {
			"entity_id": "prop_vehicle",
			"visual": {
				"base_type": "prop",
				"prop_type": "vehicle",
				"length": 2.0,
				"width": 1.0,
				"height": 0.8,
				"color": [0.4, 0.4, 0.45],
				"material": {"type": "metallic", "roughness": 0.4},
				"variation_seed": 77777,
				"scale_range": [0.9, 1.1]
			}
		}
	},
	{
		"label": "Prop - Ruin Structure",
		"data": {
			"entity_id": "prop_structure",
			"visual": {
				"base_type": "prop",
				"prop_type": "structure",
				"width": 1.5,
				"height": 2.0,
				"depth": 1.5,
				"color": [0.5, 0.45, 0.4],
				"material": {"type": "organic", "roughness": 0.85},
				"variation_seed": 88888,
				"scale_range": [0.9, 1.1]
			}
		}
	},
	{
		"label": "Rift - Void Portal",
		"data": {
			"entity_id": "rift_void",
			"rift_type": 0,
			"visual": {
				"base_type": "rift",
				"radius": 1.5,
				"rift_type": 0,
				"material": {"type": "glow", "roughness": 0.1},
				"variation_seed": 99999,
				"scale_range": [0.8, 1.2]
			}
		}
	},
	{
		"label": "Rift - Life Portal",
		"data": {
			"entity_id": "rift_life",
			"rift_type": 1,
			"visual": {
				"base_type": "rift",
				"radius": 1.5,
				"rift_type": 1,
				"material": {"type": "glow", "roughness": 0.1},
				"variation_seed": 10101,
				"scale_range": [0.8, 1.2]
			}
		}
	}
]

func _ready() -> void:
	_viewport = get_node_or_null("Entity3DLayer")
	if _viewport == null:
		push_warning("[Phase5ItemsPropsTest] Entity3DLayer node not found — test scene inactive")
		return
	_setup_ui()
	_spawn_current()

func _setup_ui() -> void:
	$UI/Controls/PrevButton.pressed.connect(_on_prev)
	$UI/Controls/NextButton.pressed.connect(_on_next)
	$UI/Controls/SpawnAllButton.pressed.connect(_on_spawn_all)
	$UI/Controls/ClearButton.pressed.connect(_on_clear)

func _spawn_current() -> void:
	_clear_entities()
	if _spawn_index < 0 or _spawn_index >= _test_presets.size():
		return
	var preset: Dictionary = _test_presets[_spawn_index]
	var comp_script = load("res://scripts/procedural/EntityVisualComponent.gd")
	if comp_script == null:
		push_warning("[Phase5ItemsPropsTest] EntityVisualComponent.gd not found")
		return
	var comp = comp_script.new()
	comp.setup(preset["data"], _viewport)
	comp.set_animation_state("idle")
	_current_entities.append(comp)
	_update_info(preset["label"])

func _on_prev() -> void:
	_spawn_index -= 1
	if _spawn_index < 0:
		_spawn_index = _test_presets.size() - 1
	_spawn_current()

func _on_next() -> void:
	_spawn_index += 1
	if _spawn_index >= _test_presets.size():
		_spawn_index = 0
	_spawn_current()

func _on_spawn_all() -> void:
	_clear_entities()
	var comp_script = load("res://scripts/procedural/EntityVisualComponent.gd")
	if comp_script == null:
		push_warning("[Phase5ItemsPropsTest] EntityVisualComponent.gd not found")
		return
	var offset := 0.0
	for preset in _test_presets:
		var comp = comp_script.new()
		var data: Dictionary = preset["data"].duplicate(true)
		comp.setup(data, _viewport)
		if comp.entity_root:
			comp.entity_root.position.x = offset
		comp.set_animation_state("idle")
		_current_entities.append(comp)
		offset += 3.0
	_update_info("All Presets")

func _on_clear() -> void:
	_clear_entities()
	$UI/InfoLabel.text = "Cleared."

func _clear_entities() -> void:
	for comp in _current_entities:
		if comp:
			comp.detach()
	_current_entities.clear()

func _update_info(label: String) -> void:
	var info: RichTextLabel = $UI/InfoLabel
	if not info:
		return
	info.text = "[b]Phase 5: Items, Props & Special Cases[/b]\n"
	info.text += "[b]Current:[/b] %s\n" % label
	info.text += "[b]Preset:[/b] %d / %d\n" % [_spawn_index + 1, _test_presets.size()]
	info.text += "[b]Entities Active:[/b] %d\n" % _current_entities.size()
	info.text += "\n[i]Items: Floating + rotation animation[/i]\n"
	info.text += "[i]Props: Door, Container, Vehicle, Structure with highlights[/i]\n"
	info.text += "[i]Rifts: Portal distortion shader + energy tendrils[/i]"
