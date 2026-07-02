## SplashScreen — bridges startup to MainMenu when splash timer expires
extends Control

var _transitioned := false


func _ready() -> void:
	print("[Splash] Screen loaded.")
	# Use create_timer for reliable delay (avoids any Timer node/scene issues)
	get_tree().create_timer(3.0).timeout.connect(_on_Timer_timeout)

func _unhandled_input(event: InputEvent) -> void:
	# Allow skipping splash for testing (click or key)
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			print("[Splash] Skip input received")
			_on_Timer_timeout()
			get_viewport().set_input_as_handled()


func _on_Timer_timeout() -> void:
	if _transitioned:
		return
	_transitioned = true
	print("[Splash] Timer expired → going to menu.")
	var gm := get_node_or_null("/root/GameManager")
	if is_instance_valid(gm):
		print("[Splash] Calling on_splash_complete on GameManager")
		gm.on_splash_complete()
	else:
		push_error("[Splash] GameManager autoload not found at /root/GameManager")
