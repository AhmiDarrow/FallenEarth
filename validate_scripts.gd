extends SceneTree

const SCENES := [
	"res://scenes/ui/Splash.tscn",
	"res://scenes/ui/MainMenu.tscn",
	"res://scenes/ui/Options.tscn",
	"res://scenes/WorldGeneration.tscn",
	"res://scenes/CharacterSelection.tscn",
	"res://scenes/HubWorld.tscn",
	"res://scenes/WorldMapScreen.tscn",
	"res://scenes/RiftInstance.tscn",
	"res://scenes/CombatLevel3D.tscn",
	"res://scenes/SettlementBuilding.tscn",
	"res://scenes/SettlementInterior.tscn",
	"res://scenes/CookingTable.tscn",
	"res://scenes/ui/CookingTableUI.tscn",
	"res://scenes/DialogueUI.tscn",
	"res://scenes/QuestTrackerUI.tscn",
	"res://scenes/TransitionScreen.tscn",
	"res://scenes/LocalMapView.tscn",
	"res://scenes/ui/CharacterMenu.tscn",
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
	"res://scripts/LocalMapView.gd",
	"res://scripts/TileSetService.gd",
	"res://scripts/HarvestNode.gd",
	"res://scripts/FloorPickup.gd",
	"res://scripts/SettlementNode.gd",
	"res://scripts/InventoryManager.gd",
	"res://scripts/ProgressionManager.gd",
	"res://scripts/LootRoller.gd",
	"res://scripts/PartyNPCManager.gd",
	"res://scripts/CraftingManager.gd",
	"res://scripts/TownManager.gd",
	"res://scripts/SettlementManager.gd",
	"res://scripts/EquipmentManager.gd",
	"res://scripts/HoverTooltip.gd",
	"res://scripts/ui/EquipmentScreen.gd",
	"res://scripts/ui/StatsScreen.gd",
	"res://scripts/ui/PartyScreen.gd",
	"res://scripts/BaseManager.gd",
	"res://scripts/BaseShopManager.gd",
	"res://scripts/Base.gd",
	"res://scripts/BaseNode.gd",
	"res://scripts/ui/HUD.gd",
	"res://scripts/ui/Hotbar.gd",
	"res://scripts/ui/Minimap.gd",
	"res://scripts/ui/InventoryScreen.gd",
	"res://scripts/ui/CraftingScreen.gd",
	"res://scripts/ui/CharacterMenu.gd",
	"res://scripts/ui/ShopInterface.gd",
	"res://scripts/ui/MissionBoardInterface.gd",
	"res://scripts/Settlement.gd",
	"res://scripts/SettlementInterior.gd",
	"res://scripts/RoomView.gd",
	"res://scripts/RiftInstance.gd",
	"res://scripts/CombatEncounterBuilder.gd",
	"res://scripts/EncounterDifficulty.gd",
	"res://scripts/RiftDungeonGenerator.gd",
	"res://scripts/ClassProgression.gd",
	"res://scripts/NPCGenerator.gd",
	"res://scripts/NPCManager.gd",
	"res://scripts/MissionGenerator.gd",
	"res://scripts/MissionManager.gd",
	"res://scripts/CookingTable.gd",
	"res://scripts/ui/CookingTableUI.gd",
	"res://scripts/Options.gd",
	"res://scripts/DisplayManager.gd",
	"res://scripts/DialogueManager.gd",
	"res://scripts/DialogueUI.gd",
	"res://scripts/NPCWanderer.gd",
	"res://scripts/QuestTracker.gd",
	"res://scripts/QuestTrackerUI.gd",
	"res://scripts/FloatingDamage.gd",
	"res://scripts/ui/MinimapOverhaul.gd",
	"res://scripts/TransitionScreen.gd",
	"res://scripts/LoadingTips.gd",
	"res://scripts/AmbientAudio.gd",
	"res://scripts/MusicManager.gd",
	"res://scripts/KeybindManager.gd",
	"res://scripts/ui/KeybindsScreen.gd",
	"res://scripts/ui/OptionsMenu.gd",
	"res://scripts/GraphicsManager.gd",
	"res://scripts/combat/v2/CombatLevel3D.gd",
	"res://scripts/combat/v2/CombatArena3D.gd",
	"res://scripts/combat/v2/CombatTile3D.gd",
	"res://scripts/combat/v2/CombatPawn3D.gd",
	"res://scripts/combat/v2/TacticsCamera3D.gd",
	"res://scripts/combat/v2/TacticsInput3D.gd",
	"res://scripts/combat/v2/UnitMovementService3D.gd",
	"res://scripts/combat/models/arena/arena_resource.gd",
	"res://scripts/combat/models/tile/tile_resource.gd",
	"res://scripts/combat/models/unit/unit_resource.gd",
	"res://scripts/combat/models/participant/participant_resource.gd",
	"res://scripts/combat/services/pathfinding/pathfinding_service.gd",
	"res://scripts/combat/services/turn/turn_service.gd",
	"res://scripts/combat/services/unit/unit_combat_service.gd",
	"res://scripts/combat/services/player/player_service.gd",
	"res://scripts/combat/services/opponent/opponent_service.gd",
	"res://scripts/combat/ui/TopPromptV110.gd",
	"res://scripts/combat/ui/ActionBarV110.gd",
	"res://scripts/ResourceVisualManager.gd",
	"res://assets/ui/UI_Colors.gd",
	"res://assets/ui/UI_Theme.gd",
	"res://scripts/StyleBoxHelper.gd",
	"res://scripts/StyleBoxHelper.gd",
	"res://scripts/ButtonStyleHelper.gd",
	"res://scripts/UIBackgrounds.gd",
]

func _initialize() -> void:
	var errors: Array[String] = []
	for path in SCRIPTS:
		var scr: GDScript = load(path) as GDScript
		if scr == null:
			errors.append("SCRIPT FAIL: " + path)
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
