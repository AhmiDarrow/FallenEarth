## CombatFeedback — Parent node that spawns floating damage numbers + HP bars.
##
## Listens to CombatManager signals and spawns visual feedback.
extends Node2D

const FloatingDamageScript = preload("res://scripts/FloatingDamage.gd")
const CombatHPBarScript = preload("res://scripts/CombatHPBar.gd")

const MAX_FLOATING := 10

var _hp_bars: Dictionary = {}  # unit_id -> CombatHPBar
var _floating_count: int = 0
var _kill_count: int = 0
var _kill_label: Label = null
var _combat: Node = null
var _grid_size: int = 7
var _cell_size: float = 24.0


func setup(combat_node: Node) -> void:
	_combat = combat_node
	if _combat == null:
		return
	# Connect signals
	if _combat.has_signal("unit_updated"):
		_combat.unit_updated.connect(_on_unit_updated)
	if _combat.has_signal("log_message"):
		_combat.log_message.connect(_on_log_message)
	# Create kill counter label
	_kill_label = Label.new()
	_kill_label.name = "KillCounter"
	_kill_label.text = "Kills: 0"
	_kill_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_kill_label.add_theme_font_size_override("font_size", 12)
	_kill_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_kill_label.add_theme_constant_override("outline_size", 2)
	_kill_label.position = Vector2(10, 10)
	_kill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_label.visible = false
	add_child(_kill_label)


func setup_hp_bars(units: Array[Dictionary], grid_size: int = 7, cell_size: float = 24.0) -> void:
	_grid_size = grid_size
	_cell_size = cell_size
	_clear_hp_bars()
	# Match BattleGridView's _unit_layer.position = -total * 0.5 so
	# bars align with the units' on-grid pixel positions.
	var half: float = float(_grid_size) * _cell_size * 0.5
	for unit in units:
		var uid: String = str(unit.get("id", ""))
		if uid.is_empty():
			continue
		var bar = CombatHPBarScript.new()
		var team: String = str(unit.get("team", "enemy"))
		var hp: int = int(unit.get("hp", 0))
		var max_hp: int = int(unit.get("max_hp", hp))
		bar.setup(uid, team, hp, max_hp)
		var pos: Vector2 = unit.get("pos", Vector2.ZERO)
		bar.position = Vector2(
			pos.x * _cell_size + _cell_size * 0.5 - half,
			pos.y * _cell_size - half - 14
		)
		add_child(bar)
		_hp_bars[uid] = bar


func _clear_hp_bars() -> void:
	for uid in _hp_bars:
		var bar: Node = _hp_bars[uid]
		if bar != null and is_instance_valid(bar):
			bar.queue_free()
	_hp_bars.clear()


func _on_unit_updated(unit_id: String) -> void:
	if _combat == null:
		return
	var units: Array[Dictionary] = _combat.get_units()
	for unit in units:
		if str(unit.get("id", "")) == unit_id:
			var hp: int = int(unit.get("hp", 0))
			var max_hp: int = int(unit.get("max_hp", hp))
			# Update HP bar
			if _hp_bars.has(unit_id):
				var bar = _hp_bars[unit_id]
				if bar != null and is_instance_valid(bar):
					bar.update_hp(hp, max_hp)
			# Check for death
			if hp <= 0:
				_kill_count += 1
				_update_kill_counter()
			break


func _on_log_message(text: String) -> void:
	# Parse damage from log messages like "X hits Y for Z."
	if not text.contains("hits") or not text.contains("for"):
		return
	# Extract damage amount
	var parts: PackedStringArray = text.split("for ")
	if parts.size() < 2:
		return
	var dmg_str: String = parts[1].replace(".", "").strip_edges()
	var dmg: int = int(dmg_str) if dmg_str.is_valid_int() else 0
	if dmg <= 0:
		return
	# Find target unit
	var target_name: String = ""
	if text.contains(" hits "):
		target_name = text.split(" hits ")[1].split(" ")[0]
	# Spawn floating damage
	_spawn_floating_damage(dmg, "physical")


func _spawn_floating_damage(amount: int, damage_type: String) -> void:
	if _floating_count >= MAX_FLOATING:
		return
	var floating = FloatingDamageScript.new()
	floating.setup(amount, damage_type, Vector2(randf_range(100, 300), randf_range(100, 200)))
	add_child(floating)
	_floating_count += 1
	floating.tree_exited.connect(func(): _floating_count -= 1)


func _update_kill_counter() -> void:
	if _kill_label != null and is_instance_valid(_kill_label):
		_kill_label.text = "Kills: %d" % _kill_count
		_kill_label.visible = true


func get_kill_count() -> int:
	return _kill_count


func reset() -> void:
	_kill_count = 0
	_floating_count = 0
	_clear_hp_bars()
	if _kill_label != null and is_instance_valid(_kill_label):
		_kill_label.visible = false
