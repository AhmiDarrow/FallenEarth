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
}

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
