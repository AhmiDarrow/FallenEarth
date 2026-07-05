## CookingTableUI — Recipe list for the cooking_table station.
##
## v0.6.0 follow-up. The UI populates a scrollable list of recipes
## from CraftingManager.recipes_for_station("cooking_table"). Each
## row shows the recipe name + ingredient check + a Craft button.
## The player can also close the UI with Esc.
class_name CookingTableUI extends Control

const CRAFTING_PATH := "/root/CraftingManager"
const INVENTORY_PATH := "/root/InventoryManager"

var _recipe_list: VBoxContainer
var _title: Label
var _instructions: Label
var _on_close: Callable = Callable()


func _ready() -> void:
	_title = get_node_or_null("Margin/VBox/Title") as Label
	_recipe_list = get_node_or_null("Margin/VBox/RecipeList") as VBoxContainer
	_instructions = get_node_or_null("Margin/VBox/Instructions") as Label
	if _title != null:
		_title.text = "Cooking Table"
	if _instructions != null:
		_instructions.text = "Cook raw ingredients into food and potions. Esc to close."
	_populate_recipes()


## Sets a callback invoked when the UI is closed (via Esc).
func set_on_close(cb: Callable) -> void:
	_on_close = cb


func _populate_recipes() -> void:
	if _recipe_list == null:
		return
	for child in _recipe_list.get_children():
		child.queue_free()
	var cm: Node = get_node_or_null(CRAFTING_PATH)
	if cm == null:
		return
	var recipe_ids: Array = cm.recipes_for_station("cooking_table")
	if recipe_ids.is_empty():
		var empty := Label.new()
		empty.text = "No recipes available."
		_recipe_list.add_child(empty)
		return
	for rid in recipe_ids:
		var row := _build_recipe_row(str(rid))
		if row != null:
			_recipe_list.add_child(row)


func _build_recipe_row(rid: String) -> Control:
	var cm: Node = get_node_or_null(CRAFTING_PATH)
	if cm == null:
		return null
	var r: Dictionary = cm.get_recipe(rid)
	if r.is_empty():
		return null
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 32)
	# Recipe name + ingredients label
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = str(r.get("name", rid))
	info.add_child(name_label)
	var ing_label := Label.new()
	var ing_parts: Array = []
	for ing in r.get("ingredients", []):
		if not (ing is Dictionary):
			continue
		ing_parts.append("%dx %s" % [int(ing.get("qty", 1)), str(ing.get("item", ""))])
	ing_label.text = "Needs: " + ", ".join(ing_parts)
	ing_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	info.add_child(ing_label)
	row.add_child(info)
	# Craft button
	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	craft_btn.pressed.connect(_on_craft_pressed.bind(rid))
	row.add_child(craft_btn)
	return row


func _on_craft_pressed(recipe_id: String) -> void:
	var cm: Node = get_node_or_null(CRAFTING_PATH)
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if cm == null or inv == null:
		return
	if not cm.can_craft(recipe_id, inv):
		# Shake the button or flash red — for v0.6.0 just print
		print("[CookingTableUI] Cannot craft %s (missing ingredients)" % recipe_id)
		return
	if cm.craft(recipe_id, inv):
		print("[CookingTableUI] Crafted %s" % recipe_id)
	else:
		print("[CookingTableUI] Failed to craft %s" % recipe_id)
	# Refresh the list (item counts changed)
	_populate_recipes()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close()


func _close() -> void:
	if _on_close.is_valid():
		_on_close.call()
	else:
		queue_free()
