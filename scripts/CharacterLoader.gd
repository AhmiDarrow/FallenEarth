# CharacterLoader.gd
# Loads base sprites by race+gender, layers equipment.
# Attach to character or use in manager.

extends Node

@onready var visual = $CharacterVisual  # instance of CharacterVisual.gd

func load_character(race: String, gender: String, equip: Dictionary = {}):
	visual.set_base_sprite(race, gender)
	visual.update_equipment(equip)
	# Add more: load animations, etc.

# Example usage in spawn:
# load_character("Human", "male", {"torso": "rags", "weapon": "sword"})
