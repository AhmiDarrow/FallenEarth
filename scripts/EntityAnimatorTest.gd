## EntityAnimatorTest — Test scene for Phase 4 EntityAnimator functionality.
## Demonstrates procedural animation states (Idle, Walk, Combat, Dead) for different entity types.
extends Control

var _viewport  # Entity3DViewport (untyped — class not yet implemented)
var _current_entity  # EntityVisualComponent (untyped — class not yet implemented)
var _entity_data: Dictionary = {
	"entity_id": "test_humanoid",
	"visual": {
		"base_type": "humanoid",
		"torso": {"height": 1.0, "radius": 0.35, "color": [0.8, 0.7, 0.6]},
		"head": {"scale": 0.2, "attachments": []},
		"limbs": {"count": 4, "leg_height": 0.6, "arm_height": 0.5},
		"material": {"type": "organic", "roughness": 0.8},
		"variation_seed": 12345,
		"scale_range": [0.9, 1.1]
	}
}

func _ready() -> void:
	_viewport = get_node_or_null("Entity3DLayer")
	if _viewport == null:
		push_warning("[EntityAnimatorTest] Entity3DLayer node not found — test scene inactive")
		return
	_setup_ui()
	_spawn_entity("humanoid")

func _setup_ui() -> void:
	$VBoxContainer/HBoxContainer/IdleButton.pressed.connect(_on_idle_pressed)
	$VBoxContainer/HBoxContainer/WalkButton.pressed.connect(_on_walk_pressed)
	$VBoxContainer/HBoxContainer/CombatButton.pressed.connect(_on_combat_pressed)
	$VBoxContainer/HBoxContainer/DeadButton.pressed.connect(_on_dead_pressed)

func _spawn_entity(entity_type: String) -> void:
	if _current_entity:
		_current_entity.detach()

	var data: Dictionary = _entity_data.duplicate(true)
	data["entity_id"] = "test_%s" % entity_type
	data["visual"]["base_type"] = entity_type

	match entity_type:
		"rift":
			data["visual"] = {
				"base_type": "rift",
				"radius": 1.5,
				"material": {"type": "glow", "roughness": 0.1},
				"variation_seed": 54321,
				"scale_range": [0.8, 1.2]
			}
		"beast":
			data["visual"] = {
				"base_type": "beast",
				"body": {"length": 1.2, "height": 0.6, "color": [0.35, 0.3, 0.25]},
				"head": {"scale": 0.18},
				"material": {"type": "organic", "roughness": 0.85},
				"variation_seed": 67890,
				"scale_range": [0.8, 1.2]
			}

	_current_entity = null
	var comp_script = load("res://scripts/procedural/EntityVisualComponent.gd")
	if comp_script == null:
		push_warning("[EntityAnimatorTest] EntityVisualComponent.gd not found")
		return
	_current_entity = comp_script.new()
	_current_entity.setup(data, _viewport)
	_current_entity.set_animation_state("idle")
	_update_info()

func _on_idle_pressed() -> void:
	if _current_entity:
		_current_entity.set_animation_state("idle")
		_update_info()

func _on_walk_pressed() -> void:
	if _current_entity:
		_current_entity.set_animation_state("walk")
		_update_info()

func _on_combat_pressed() -> void:
	if _current_entity:
		_current_entity.set_animation_state("combat")
		_update_info()

func _on_dead_pressed() -> void:
	if _current_entity:
		_current_entity.set_animation_state("dead")
		_update_info()

func _update_info() -> void:
	var info: RichTextLabel = $VBoxContainer/EntityInfo
	if not info or not _current_entity:
		return

	var entity_type: String = _entity_data["visual"]["base_type"]
	var state: String = "idle"
	if _current_entity.animator:
		state = _current_entity.animator.State.keys()[_current_entity.animator.current_state].to_lower()

	info.text = "[b]Entity Type:[/b] %s\n" % entity_type
	info.text += "[b]Current State:[/b] %s\n" % state
	info.text += "[b]Animation Speed:[/b] %.1f\n" % (_current_entity.animator.anim_speed if _current_entity.animator else 1.0)
	info.text += "[b]Entity ID:[/b] %s" % _current_entity.entity_id
