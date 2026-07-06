extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	print("=== Audio Smoke Test ===")
	# Defer one frame so the autoload singletons' _ready() has
	# a chance to run before we poke at their internal state.
	_run_deferred.call_deferred()


func _run_deferred() -> void:
	_test_audio_imports_loop_true()
	_test_audio_streams_load()
	_test_ambient_audio_map_biome()
	_test_music_manager_plays_track()
	_test_ambient_audio_plays_biome()
	_test_scene_wiring_calls()
	_print_summary()
	quit()


func _test_audio_imports_loop_true() -> void:
	print("\n--- Test: All audio .import files have loop=true ---")
	var expected_loops: Array[String] = [
		"res://audio/cave/water_drip_loop.ogg.import",
		"res://audio/combat/combat_theme.ogg.import",
		"res://audio/desert/hot_wind_loop.ogg.import",
		"res://audio/exploration/exploration_theme.ogg.import",
		"res://audio/forest/birds_loop.ogg.import",
		"res://audio/forest/crickets_loop.ogg.import",
		"res://audio/main_menu/main_menu_theme.ogg.import",
		"res://audio/rift/eerie_drone.ogg.import",
		"res://audio/rift/rift_theme.ogg.import",
		"res://audio/settlement/settlement_theme.ogg.import",
		"res://audio/urban/industrial_hum.ogg.import",
		"res://audio/wasteland/wind_loop.ogg.import",
	]
	for path in expected_loops:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_fail("Missing .import: %s" % path)
			continue
		var text: String = file.get_as_text()
		file.close()
		if not text.contains("loop=true"):
			_fail("%s does not have loop=true" % path)
			continue
	_pass("All 12 audio .import files have loop=true")


func _test_audio_streams_load() -> void:
	print("\n--- Test: AudioStream resources load ---")
	var paths: Array[String] = [
		"res://audio/cave/water_drip_loop.ogg",
		"res://audio/combat/combat_theme.ogg",
		"res://audio/desert/hot_wind_loop.ogg",
		"res://audio/exploration/exploration_theme.ogg",
		"res://audio/forest/birds_loop.ogg",
		"res://audio/forest/crickets_loop.ogg",
		"res://audio/main_menu/main_menu_theme.ogg",
		"res://audio/rift/eerie_drone.ogg",
		"res://audio/rift/rift_theme.ogg",
		"res://audio/settlement/settlement_theme.ogg",
		"res://audio/urban/industrial_hum.ogg",
		"res://audio/wasteland/wind_loop.ogg",
	]
	for p in paths:
		if not ResourceLoader.exists(p):
			_fail("ResourceLoader.exists returned false for %s" % p)
			continue
		var stream: Resource = load(p)
		if stream == null:
			_fail("load() returned null for %s" % p)
			continue
		if not (stream is AudioStream):
			_fail("Loaded resource is not an AudioStream: %s" % p)
			continue
	_pass("All 12 AudioStream resources loaded as AudioStream")


func _test_ambient_audio_map_biome() -> void:
	print("\n--- Test: AmbientAudio.map_biome covers world biomes ---")
	# Force the autoload to instantiate so we can call it.
	# (In headless mode autoloads run but map_biome is just a method.)
	var aa: Node = get_root().get_node_or_null("AmbientAudio")
	if aa == null:
		_fail("AmbientAudio autoload not found in tree")
		return
	var samples: Dictionary = {
		"Ash Wastes": "wasteland",
		"ash wastes": "wasteland",
		"Rust Canyons": "wasteland",
		"Ironwood Thicket": "forest",
		"Scorched Plains": "desert",
		"Glass Dunes": "desert",
		"Neon Bogs": "cave",
		"Toxin Marshes": "cave",
		"Corpse Fields": "cave",
		"Stormspire Highlands": "wasteland",
		"Dead City Outskirts": "urban",
		"": "",
	}
	for biome in samples:
		var got: String = aa.call("map_biome", biome) as String
		var want: String = samples[biome]
		if got != want:
			_fail("map_biome(%s) returned '%s', expected '%s'" % [biome, got, want])
			return
	_pass("map_biome maps all 10 world biomes (and empty → '')")


func _test_music_manager_plays_track() -> void:
	print("\n--- Test: MusicManager.play_track starts a track ---")
	var mm: Node = get_root().get_node_or_null("MusicManager")
	if mm == null:
		_fail("MusicManager autoload not found in tree")
		return
	mm.call("play_track", "main_menu")
	var stored: String = str(mm.get("_current_track"))
	if stored != "main_menu":
		_fail("MusicManager._current_track was '%s', expected 'main_menu'" % stored)
		return
	# In headless there is no audio driver, so the AudioStreamPlayer
	# won't actually be playing. We only verify state + that the
	# track was registered.
	_pass("MusicManager.play_track('main_menu') accepted and stored")


func _test_ambient_audio_plays_biome() -> void:
	print("\n--- Test: AmbientAudio.play_biome sets current biome ---")
	var aa: Node = get_root().get_node_or_null("AmbientAudio")
	if aa == null:
		_fail("AmbientAudio autoload not found")
		return
	aa.call("play_biome", "wasteland", 0.1)
	var got: String = str(aa.get("_current_biome"))
	if got != "wasteland":
		_fail("AmbientAudio._current_biome was '%s', expected 'wasteland'" % got)
		return
	aa.call("stop_all", 0.1)
	if str(aa.get("_current_biome")) != "":
		_fail("AmbientAudio._current_biome was not cleared by stop_all")
		return
	_pass("AmbientAudio.play_biome / stop_all round-trip works")


func _test_scene_wiring_calls() -> void:
	print("\n--- Test: scene scripts call MusicManager/AmbientAudio ---")
	var wired: Array[String] = [
		"res://scripts/MainMenu.gd",
		"res://scripts/HubWorld.gd",
		"res://scripts/SettlementInterior.gd",
		"res://scripts/RiftInstance.gd",
		"res://scripts/TacticalCombat.gd",
		"res://scripts/WorldMapScreen.gd",
	]
	for path in wired:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_fail("Could not open %s" % path)
			continue
		var text: String = file.get_as_text()
		file.close()
		if not text.contains("MusicManager"):
			_fail("%s does not reference MusicManager" % path)
			continue
		if not text.contains("AmbientAudio"):
			_fail("%s does not reference AmbientAudio" % path)
			continue
		_pass("%s wires both MusicManager and AmbientAudio" % path.replace("res://scripts/", ""))


func _pass(test_name: String) -> void:
	print("ok %s" % test_name)


func _fail(test_name: String) -> void:
	print("FAIL %s" % test_name)
	_failures.append(test_name)


func _print_summary() -> void:
	print("\n=== Summary ===")
	if _failures.is_empty():
		print("All checks passed. (failures.size=0)")
	else:
		print("Some checks failed. (failures.size=%d)" % _failures.size())
		for f in _failures:
			print("  FAILED: %s" % f)
