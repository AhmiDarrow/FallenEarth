## MusicManager — Track-based music system with crossfade.
##
## Autoload singleton. Plays background music tracks for different game states.
## Audio files stored in res://audio/ by category subdirectory.
extends Node

## Track key → audio stream path
var _tracks: Dictionary = {
	"settlement": "res://audio/settlement/settlement_theme.ogg",
	"combat": "res://audio/combat/combat_theme.ogg",
	"exploration": "res://audio/exploration/exploration_theme.ogg",
	"rift": "res://audio/rift/rift_theme.ogg",
	"main_menu": "res://audio/main_menu/main_menu_theme.ogg",
}

var _current_track: String = ""
var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null
var _active_player: AudioStreamPlayer = null
var _volume_db: float = -3.0  # default music volume
var _crossfading: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a = AudioStreamPlayer.new()
	_player_a.bus = "Master"
	_player_a.volume_db = -80.0
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.bus = "Master"
	_player_b.volume_db = -80.0
	add_child(_player_b)

	_active_player = _player_a
	_apply_volume_from_settings()


func _apply_volume_from_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://options.cfg") == OK:
		var music_vol: float = config.get_value("audio", "music", 0.7)
		_volume_db = linear_to_db(music_vol) if music_vol > 0.001 else -80.0


## Play the given track. Crossfades over fade_time seconds.
func play_track(track_key: String, fade_time: float = 1.0) -> void:
	if track_key == _current_track and _active_player.playing:
		return
	if not _tracks.has(track_key):
		push_warning("[MusicManager] Unknown track: %s" % track_key)
		return

	var path: String = _tracks[track_key]
	if not ResourceLoader.exists(path):
		# Track file not yet added — skip silently
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return

	_current_track = track_key

	# Determine which player is active and which is idle
	var old_player: AudioStreamPlayer = _active_player
	var new_player: AudioStreamPlayer = _player_b if _active_player == _player_a else _player_a
	_active_player = new_player

	# Set up new player
	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()

	# Crossfade
	_crossfading = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(old_player, "volume_db", -80.0, fade_time * 0.5)
	tween.tween_property(new_player, "volume_db", _volume_db, fade_time)
	tween.chain().tween_callback(_on_crossfade_complete)


func _on_crossfade_complete() -> void:
	_crossfading = false
	if _active_player == _player_a:
		_player_b.stop()
	else:
		_player_a.stop()


## Stop all music with optional fade.
func stop(fade_time: float = 0.5) -> void:
	_current_track = ""
	var tween := create_tween()
	tween.tween_property(_active_player, "volume_db", -80.0, fade_time)
	tween.tween_callback(_active_player.stop)


## Update volume from settings (call when music slider changes).
func set_volume(linear_volume: float) -> void:
	_volume_db = linear_to_db(linear_volume) if linear_volume > 0.001 else -80.0
	if _active_player.playing and not _crossfading:
		_active_player.volume_db = _volume_db


func get_current_track() -> String:
	return _current_track
