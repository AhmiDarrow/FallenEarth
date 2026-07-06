## AmbientAudio — Biome-specific ambient audio loops.
##
## Autoload singleton. Manages looping ambient sounds per biome.
## Audio files stored in res://audio/ by biome subdirectory.
extends Node

## Biome → array of audio stream paths (relative to res://)
var _biome_sounds: Dictionary = {
	"wasteland": ["res://audio/wasteland/wind_loop.ogg"],
	"forest": ["res://audio/forest/crickets_loop.ogg", "res://audio/forest/birds_loop.ogg"],
	"urban": ["res://audio/urban/industrial_hum.ogg"],
	"desert": ["res://audio/desert/hot_wind_loop.ogg"],
	"cave": ["res://audio/cave/water_drip_loop.ogg"],
	"rift": ["res://audio/rift/eerie_drone.ogg"],
	"settlement": ["res://audio/urban/industrial_hum.ogg"],
}

## World biome name → ambient key. The world has 10 distinct biomes
## (Ash Wastes, Rust Canyons, Neon Bogs, Scorched Plains, Ironwood
## Thicket, Glass Dunes, Corpse Fields, Stormspire Highlands, Toxin
## Marshes, Dead City Outskirts). Each gets mapped to the closest
## ambient bed that we actually have an .ogg for. Unknown / empty
## names fall back to "wasteland" (the most common biome).
var _biome_aliases: Dictionary = {
	"ash wastes": "wasteland",
	"rust canyons": "wasteland",
	"ironwood thicket": "forest",
	"scorched plains": "desert",
	"glass dunes": "desert",
	"neon bogs": "cave",
	"toxin marshes": "cave",
	"corpse fields": "cave",
	"stormspire highlands": "wasteland",
	"dead city outskirts": "urban",
}


## Map a world biome name to an ambient key. Returns "" if no match
## (callers can pass that to play_biome to stop without restart).
func map_biome(biome_name: String) -> String:
	if biome_name.is_empty():
		return ""
	var key: String = biome_name.to_lower().strip_edges()
	if _biome_sounds.has(key):
		return key
	if _biome_aliases.has(key):
		return _biome_aliases[key]
	# Default fallback — wasteland is the canonical "open badlands"
	# bed we have audio for, and matches the default starting biome.
	return "wasteland"

var _current_biome: String = ""
var _active_players: Array[AudioStreamPlayer] = []
var _volume_db: float = -6.0  # default SFX volume


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load volume from options
	_apply_volume_from_settings()


func _apply_volume_from_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://options.cfg") == OK:
		var sfx_vol: float = config.get_value("audio", "sfx", 0.8)
		_volume_db = linear_to_db(sfx_vol) if sfx_vol > 0.001 else -80.0


## Set the ambient soundscape to match the given biome key.
## Crossfades over fade_time seconds.
func play_biome(biome_key: String, fade_time: float = 1.0) -> void:
	if biome_key == _current_biome:
		return
	_current_biome = biome_key

	# Fade out old players
	for player in _active_players:
		if is_instance_valid(player):
			var tween := create_tween()
			tween.tween_property(player, "volume_db", -80.0, fade_time * 0.5)
			tween.tween_callback(player.queue_free)
	_active_players.clear()

	# Start new players
	var paths: Array = _biome_sounds.get(biome_key, []) as Array
	for path in paths:
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			continue
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "Master"
		player.volume_db = -80.0
		player.autoplay = true
		add_child(player)
		_active_players.append(player)
		# Fade in
		var tween := create_tween()
		tween.tween_property(player, "volume_db", _volume_db, fade_time)


## Stop all ambient sounds.
func stop_all(fade_time: float = 0.5) -> void:
	_current_biome = ""
	for player in _active_players:
		if is_instance_valid(player):
			var tween := create_tween()
			tween.tween_property(player, "volume_db", -80.0, fade_time)
			tween.tween_callback(player.queue_free)
	_active_players.clear()


## Update volume from settings (call when SFX slider changes).
func set_volume(linear_volume: float) -> void:
	_volume_db = linear_to_db(linear_volume) if linear_volume > 0.001 else -80.0
	for player in _active_players:
		if is_instance_valid(player):
			player.volume_db = _volume_db


func get_current_biome() -> String:
	return _current_biome
