## MobInstance — Standard Godot node for a single mob on the overworld.
## Uses AnimatedSprite2D. Loads .tres SpriteFrames if available;
## falls back to a single-frame animation from the static PNG.
## Poolable: reset() reuses the node for a different mob type.
class_name MobInstance
extends Node2D
const MobDataRef = preload("res://scripts/mob/MobData.gd")

var mob_data: MobDataRef = null
var _anim: AnimatedSprite2D = null


func _ready() -> void:
	_ensure_anim()


func _ensure_anim() -> void:
	if _anim != null:
		return
	_anim = AnimatedSprite2D.new()
	_anim.name = "AnimatedSprite"
	add_child(_anim)


## Configure from MobData. Loads .tres SpriteFrames or falls back to static PNG.
func setup(data: MobDataRef) -> void:
	mob_data = data
	_ensure_anim()

	# Prefer SpriteFrames from .tres
	var tres_path := data.sprite_frames_path()
	if ResourceLoader.exists(tres_path):
		var frames: SpriteFrames = load(tres_path) as SpriteFrames
		if frames != null:
			_anim.sprite_frames = frames
			_anim.centered = true
			_anim.play("idle")
			return

	# Fallback: create single-frame "idle" animation from static PNG
	var png_path := data.sprite_path()
	var tex: Texture2D = null
	if ResourceLoader.exists(png_path):
		tex = load(png_path) as Texture2D
	if tex != null:
		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", tex)
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 5.0)
		_anim.sprite_frames = frames
		_anim.centered = true
		_anim.play("idle")
	else:
		_anim.sprite_frames = null


## Play a named animation. Falls back to "idle" if the animation doesn't exist.
func play_animation(anim_name: String) -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	if _anim.sprite_frames.has_animation(anim_name):
		_anim.play(anim_name)
	else:
		_anim.play("idle")


## Called by pool to return to neutral state for reuse.
func reset() -> void:
	mob_data = null
	if _anim != null:
		_anim.sprite_frames = null
		_anim.stop()
