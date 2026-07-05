## CraftingScreen — UI for the Crafting tab in CharacterMenu.
##
## Phase 3 ships the basic inventory-tab crafting: list recipes whose
## `station` is "none" (the always-available recipes) and let the player
## craft if they have ingredients and meet the level requirement. The
## Worktable / Armor Table / Blacksmith UIs (Phase 3 stations) live
## separately as scene popups triggered by E-press near a station.
##
## Layout:
##   - Top: filter bar (All / Consumable / Tool / Weapon / Armor)
##   - Middle: scrollable list of recipes. Each row: name, station tag,
##     level req, ingredient summary, craft button.
##   - Bottom: status line ("can't craft: missing 2 sticks" etc.)
class_name CraftingScreen
extends Control

const INVENTORY_PATH := "/root/InventoryManager"
const CRAFTING_PATH := "/root/CraftingManager"

const CATEGORIES := ["all", "consumable", "tool", "weapon", "armor"]

var _filter: String = "all"
var _list_vbox: VBoxContainer
var _status_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)
	# Filter bar
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	vbox.add_child(filters)
	for cat in CATEGORIES:
		var b := Button.new()
		b.text = cat.capitalize()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_filter_pressed.bind(cat))
		filters.add_child(b)
		if cat == "all":
			b.button_pressed = true
	# List
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(_list_vbox)
	# Status line
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(_status_label)


func _on_filter_pressed(cat: String) -> void:
	_filter = cat
	_refresh()


func _refresh() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()
	var cm: Node = get_node_or_null(CRAFTING_PATH)
	if cm == null:
		# CraftingManager is not yet registered as an autoload (it's
		# in this phase's data files but not in autoload list yet). Show
		# a "loading" message.
		var ph := Label.new()
		ph.text = "(CraftingManager loading...)"
		ph.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		_list_vbox.add_child(ph)
		return
	var recipes: Array = cm.unlocked_recipes if cm.has_method("unlocked_recipes") else []
	if recipes.is_empty():
		var ph := Label.new()
		ph.text = "(no recipes unlocked — level up to see more)"
		ph.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		_list_vbox.add_child(ph)
		return
	for rid in recipes:
		var recipe: Dictionary = cm.get_recipe(rid) if cm.has_method("get_recipe") else {}
		if recipe.is_empty():
			continue
		if _filter != "all" and str(recipe.get("category", "")) != _filter:
			continue
		_list_vbox.add_child(_make_recipe_row(rid, recipe, cm))


func _make_recipe_row(rid: String, recipe: Dictionary, cm: Node) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)
	var name := Label.new()
	name.text = "%s%s" % [recipe.get("name", rid), "" if str(recipe.get("station", "none")) == "none" else "  [station: %s]" % recipe.get("station", "?")]
	name.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(name)
	var ing_text: String = ""
	for ing in recipe.get("ingredients", []):
		if not (ing is Dictionary):
			continue
		if ing_text != "":
			ing_text += ", "
		ing_text += "%dx %s" % [int(ing.get("qty", 1)), ing.get("item", "?")]
	var meta := Label.new()
	meta.text = "Lv.%d · %s · %s" % [
		int(recipe.get("level_required", 1)),
		ing_text,
		recipe.get("category", "?"),
	]
	meta.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	meta.add_theme_font_size_override("font_size", 11)
	info.add_child(meta)
	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	craft_btn.disabled = not bool(cm.can_craft(rid) if cm.has_method("can_craft") else false)
	craft_btn.pressed.connect(_on_craft_pressed.bind(rid, cm))
	hbox.add_child(craft_btn)
	return row


func _on_craft_pressed(rid: String, cm: Node) -> void:
	if not cm.has_method("craft"):
		_status_label.text = "CraftingManager missing craft()"
		return
	var result: bool = bool(cm.craft(rid))
	if result:
		_status_label.text = "Crafted %s." % rid
		_refresh()
	else:
		_status_label.text = "Craft failed: missing ingredients or wrong level."
