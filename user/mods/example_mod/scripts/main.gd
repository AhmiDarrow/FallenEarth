## Example Mod — Demonstrates mod API usage.
extends Node


func _ready() -> void:
	ModAPI.log("example_mod", "Example Mod loaded successfully!")

	# Register an EventBus hook
	EventBus.before("item_acquired", _on_item_acquired, 100)
	EventBus.after("item_acquired", _on_item_acquired_after, 100)

	# Register mod settings
	ModAPI.register_setting("example_mod", "test_damage_multiplier", 1.0, "Test Damage Multiplier", "float")
	ModAPI.register_setting("example_mod", "enable_debug_overlay", false, "Enable Debug Overlay", "bool")

	ModAPI.log("example_mod", "Settings registered. Damage multiplier: %s" % ModAPI.get_setting("example_mod", "test_damage_multiplier"))


func _on_item_acquired(event_name: String, data: Dictionary) -> Dictionary:
	ModAPI.log("example_mod", "[before-hook] Item acquired: %s x%s" % [data.get("item_id", "?"), data.get("qty", 0)])
	return data


func _on_item_acquired_after(event_name: String, data: Dictionary) -> void:
	ModAPI.log("example_mod", "[after-hook] Item acquisition confirmed: %s" % data.get("item_id", "?"))
