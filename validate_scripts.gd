extends SceneTree

const SCENES := [
	"res://scenes/ui/Splash.tscn",
	"res://scenes/ui/MainMenu.tscn",
	"res://scenes/WorldGeneration.tscn",
	"res://scenes/CharacterSelection.tscn",
	"res://scenes/HubWorld.tscn",
	"res://scenes/WorldMapScreen.tscn",
	"res://scenes/RiftInstance.tscn",
	"res://scenes/TacticalCombat.tscn",
]

const SCRIPTS := [
	"res://scripts/GameState.gd",
	"res://scripts/SaveManager.gd",
	"res://scripts/GameManager.gd",
	"res://scripts/RiftRunner.gd",
	"res://scripts/WorldGenerator.gd",
	"res://scripts/WorldGeneration.gd",
	"res://scripts/MainMenu.gd",
	"res://scripts/CharacterSelection.gd",
	"res://scripts/HubWorld.gd",
	"res://scripts/WorldMapScreen.gd",
	"res://scripts/LocalMapGenerator.gd",
	"res://scripts/LocalMapRenderer.gd",
	"res://scripts/RiftInstance.gd",
	"res://scripts/CombatManager.gd",
	"res://scripts/CombatEncounterBuilder.gd",
	"res://scripts/EncounterDifficulty.gd",
	"res://scripts/RiftDungeonGenerator.gd",
	"res://scripts/ClassProgression.gd",
	"res://scripts/TacticalCombat.gd",
	"res://scripts/NPCGenerator.gd",
	"res://scripts/NPCManager.gd",
	"res://scripts/MissionGenerator.gd",
	"res://scripts/MissionManager.gd",
	"res://scenes/ui/Splash.gd",
]

func _initialize() -> void:
	var errors: Array[String] = []
	for path in SCRIPTS:
		var scr: GDScript = load(path) as GDScript
		if scr == null:
			errors.append("SCRIPT FAIL: " + path)
			# Attempt to get more error info if possible via try
			var test = load(path)
			if test == null:
				push_error("Failed load for: " + path)
	for path in SCENES:
		if not ResourceLoader.exists(path):
			errors.append("SCENE MISSING: " + path)
			continue
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			errors.append("SCENE LOAD FAIL: " + path)
	if errors.is_empty():
		print("[validate_scripts] All scripts and scenes OK.")
	else:
		for e in errors:
			push_error(e)
		print("[validate_scripts] %d error(s)." % errors.size())
	quit()