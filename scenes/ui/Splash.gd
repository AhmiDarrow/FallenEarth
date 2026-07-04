extends CanvasLayer

signal splash_finished

@export var background_texture: Texture2D
@export var duration: float = 5.5

@onready var bg: TextureRect = $Background
@onready var overlay: ColorRect = $Overlay
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var particles: GPUParticles2D = $Particles

func _ready() -> void:
	if background_texture:
		bg.texture = background_texture
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	overlay.modulate.a = 0.6
	particles.emitting = false

	await get_tree().create_timer(0.3).timeout
	_play_sequence()

func _play_sequence() -> void:
	var tween := create_tween().set_parallel(false)

	tween.tween_property(bg, "modulate:a", 1.0, 1.5).set_ease(Tween.EASE_IN)

	tween.tween_callback(func(): particles.emitting = true)

	tween.tween_property(title_label, "modulate:a", 1.0, 1.0).set_delay(0.3)

	tween.tween_property(title_label, "scale", Vector2(1.05, 1.05), 0.5).set_delay(0.5)
	tween.parallel().tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.5).set_delay(1.0)

	tween.tween_property(overlay, "modulate:a", 0.3, 1.0)
	tween.parallel().tween_property(subtitle_label, "modulate:a", 1.0, 0.8)

	tween.tween_property(title_label, "modulate:a", 0.0, 0.8).set_delay(0.5)
	tween.parallel().tween_property(subtitle_label, "modulate:a", 0.0, 0.8)

	tween.tween_callback(func(): particles.emitting = false)

	tween.tween_property(overlay, "modulate:a", 0.0, 0.5)

	tween.tween_callback(_on_splash_complete)

func _on_splash_complete() -> void:
	splash_finished.emit()
	var gm := get_node_or_null("/root/GameManager")
	if is_instance_valid(gm) and gm.has_method("on_splash_complete"):
		gm.on_splash_complete()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			get_tree().create_tween().kill()
			_on_splash_complete()
			get_viewport().set_input_as_handled()
