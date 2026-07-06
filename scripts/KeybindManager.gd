## KeybindManager — Stores and manages all player keybindings.
##
## Autoload singleton. Provides a dictionary of action → keycode mappings.
## Supports rebinding, saving/loading from user://keybinds.cfg, and
## resetting to defaults. Other scripts query is_action_pressed() or
## get_keycode() instead of hardcoding KEY_* constants.
extends Node

const SETTINGS_PATH := "user://keybinds.cfg"

## Default keybindings: action_name → PhysicalKeycode constant.
## These mirror the hardcoded keys from HubWorld._unhandled_input.
var _defaults: Dictionary = {
	"move_up":      KEY_W,
	"move_down":    KEY_S,
	"move_left":    KEY_A,
	"move_right":   KEY_D,
	"interact":     KEY_E,
	"inventory":    KEY_I,
	"equipment":    KEY_E,
	"crafting":     KEY_C,
	"party":        KEY_P,
	"stats":        KEY_S,
	"world_map":    KEY_M,
	"hotbar_1":     KEY_1,
	"hotbar_2":     KEY_2,
	"hotbar_3":     KEY_3,
	"hotbar_4":     KEY_4,
	"hotbar_5":     KEY_5,
	"hotbar_6":     KEY_6,
	"hotbar_7":     KEY_7,
	"hotbar_8":     KEY_8,
	"hotbar_9":     KEY_9,
	"hotbar_0":     KEY_0,
	"pause_menu":   KEY_ESCAPE,
	"tab_next":     KEY_TAB,
	"tab_prev":     KEY_TAB,  # Shift+Tab handled in code
}

## Human-readable labels for each action.
var _labels: Dictionary = {
	"move_up":      "Move Up",
	"move_down":    "Move Down",
	"move_left":    "Move Left",
	"move_right":   "Move Right",
	"interact":     "Interact / Gather",
	"inventory":    "Inventory",
	"equipment":    "Equipment",
	"crafting":     "Crafting",
	"party":        "Party",
	"stats":        "Stats",
	"world_map":    "World Map",
	"hotbar_1":     "Hotbar 1",
	"hotbar_2":     "Hotbar 2",
	"hotbar_3":     "Hotbar 3",
	"hotbar_4":     "Hotbar 4",
	"hotbar_5":     "Hotbar 5",
	"hotbar_6":     "Hotbar 6",
	"hotbar_7":     "Hotbar 7",
	"hotbar_8":     "Hotbar 8",
	"hotbar_9":     "Hotbar 9",
	"hotbar_0":     "Hotbar 0",
	"pause_menu":   "Pause / Menu",
	"tab_next":     "Next Tab",
	"tab_prev":     "Previous Tab",
}

## Groups for organized display. Each group is [label, Array of action names].
var _groups: Array[Array] = [
	["Movement", ["move_up", "move_down", "move_left", "move_right"]],
	["Gameplay", ["interact", "world_map", "pause_menu"]],
	["Character", ["inventory", "equipment", "crafting", "party", "stats"]],
	["Hotbar", ["hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5",
				 "hotbar_6", "hotbar_7", "hotbar_8", "hotbar_9", "hotbar_0"]],
	["UI", ["tab_next", "tab_prev"]],
]

## Active keybindings: action_name → PhysicalKeycode.
var _bindings: Dictionary = {}

## Set to true while waiting for the player to press a new key.
var _rebinding: bool = false
## The action currently being rebound.
var _rebinding_action: String = ""
## Callback invoked after rebind completes (or cancels). func(keycode)
var _rebind_callback: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_bindings()


## Returns the PhysicalKeycode for the given action, or 0 if unknown.
func get_keycode(action: String) -> int:
	return _bindings.get(action, _defaults.get(action, 0))


## Returns the human-readable label for an action.
func get_label(action: String) -> String:
	return _labels.get(action, action)


## Returns the display groups array.
func get_display_groups() -> Array[Array]:
	return _groups


## Returns a formatted key name string for display (e.g. "W", "Shift+Tab").
func get_key_name(keycode: int) -> String:
	if keycode == 0:
		return "Unbound"
	return OS.get_keycode_string(keycode)


## Returns true if the given InputEvent matches the action's keycode.
## Handles Shift+Tab for tab_prev.
func is_action_pressed(action: String, event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed):
		return false
	var kc: int = get_keycode(action)
	if action == "tab_prev":
		return event.keycode == KEY_TAB and event.shift_pressed
	return event.keycode == kc and not event.shift_pressed


## Starts the rebinding flow. Shows a prompt and waits for the next key press.
## on_complete(keycode: int) is called when done. Pass 0 for keycode on cancel.
func start_rebind(action: String, on_complete: Callable = Callable()) -> void:
	_rebinding = true
	_rebinding_action = action
	_rebind_callback = on_complete


## Returns true if the manager is currently waiting for a rebind key press.
func is_rebinding() -> bool:
	return _rebinding


## Returns the action currently being rebound.
func get_rebinding_action() -> String:
	return _rebinding_action


## Cancel an in-progress rebind.
func cancel_rebind() -> void:
	_rebinding = false
	_rebinding_action = ""
	_rebind_callback = Callable()


## Apply a new keycode for an action. Checks for conflicts.
## Returns OK on success, or an error message string on failure.
func apply_rebind(action: String, keycode: int) -> Variant:
	if keycode == 0:
		_bindings[action] = 0
		_save_bindings()
		return OK
	# Check for conflicts
	for other in _bindings:
		if other != action and _bindings[other] == keycode:
			return "Key already bound to: %s" % _labels.get(other, other)
	# Also check defaults for actions not yet rebound
	for other in _defaults:
		if other != action and not _bindings.has(other) and _defaults[other] == keycode:
			return "Key already bound to: %s" % _labels.get(other, other)
	_bindings[action] = keycode
	_save_bindings()
	return OK


## Reset all bindings to defaults.
func reset_all() -> void:
	_bindings.clear()
	_save_bindings()


## Reset a single action to its default.
func reset_action(action: String) -> void:
	_bindings.erase(action)
	_save_bindings()


func _input(event: InputEvent) -> void:
	if not _rebinding:
		return
	if not (event is InputEventKey and event.pressed):
		return
	# Escape cancels the rebind
	if event.keycode == KEY_ESCAPE:
		cancel_rebind()
		get_viewport().set_input_as_handled()
		return
	# Any other key is the new binding
	_rebinding = false
	var action: String = _rebinding_action
	_rebinding_action = ""
	var callback: Callable = _rebind_callback
	_rebind_callback = Callable()
	apply_rebind(action, event.keycode)
	get_viewport().set_input_as_handled()
	if callback.is_valid():
		callback.call(event.keycode)


func _save_bindings() -> void:
	var config := ConfigFile.new()
	for action in _bindings:
		config.set_value("keybinds", action, _bindings[action])
	config.save(SETTINGS_PATH)


func _load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for action in _defaults:
		if config.has_section_key("keybinds", action):
			_bindings[action] = config.get_value("keybinds", action, 0)
