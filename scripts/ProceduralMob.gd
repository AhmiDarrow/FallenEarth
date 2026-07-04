## ProceduralMob — Procedurally drawn creatures/mobs for overworld encounters.
## Extends ProceduralRenderer. Supports archetypes: quadruped, insectoid, behemoth, aberrant.
## Each archetype has distinct draw logic with idle/walk/attack states.
## Called from EncounterBuilder when spawning procedural enemy mobs.

extends ProceduralRenderer

# Archetype name (data-driven)
var archetype: String = "quadruped"

# State
var anim: String = "idle"
# size, pose_frame, _drawn inherited from parent

# Body color (data-driven, e.g. from NPC data)
var body_color: Color = COLORS["rags"]

# Legs count per archetype
var leg_count: int = 4

func _setup() -> void:
	# Clamp pose_frame to anim frame count
	if anim == "walk" or anim == "run":
		pose_frame = pose_frame % 8
	elif anim == "attack" or anim == "swing":
		pose_frame = pose_frame % 4
	elif anim == "idle":
		pose_frame = pose_frame % 4

func _draw() -> void:
	# Base body silhouette — varies by archetype
	match archetype:
		"quadruped":
			_draw_quadruped_body()
		"insectoid":
			_draw_insectoid_body()
		"behemoth":
			_draw_behemoth_body()
		"aberrant":
			_draw_aberrant_body()
		_:
			# Unknown: fallback to simple blob
			draw_rect(Rect2(Vector2(0, 0), size), body_color)

	# Draw legs — count and spacing depend on archetype
	_draw_legs()

	# Archetype-specific head/eyes
	match archetype:
		"quadruped":
			_draw_quadruped_head()
		"insectoid":
			_draw_insectoid_head()
		"behemoth":
			_draw_behemoth_head()
		"aberrant":
			_draw_aberrant_head()

	# Attack/state animation overlays (e.g. swipe lines for insects)
	if anim == "attack":
		_draw_attack_overlay()

func _draw_quadruped_body() -> void:
	# Four-legged creature — simple rounded quadruped silhouette
	draw_circle(Vector2(size.x * 0.45, size.y * 0.5), size.x * 0.4, body_color)

func _draw_insectoid_body() -> void:
	# Insectoid — segmented abdomen, narrower thorax
	var seg_w = size.x * 0.25
	var seg_h = size.y * 0.25
	for i in range(3):
		var y = size.y * 0.4 + i * seg_h
		draw_rect(Rect2(Vector2(-size.x * 0.1, y - seg_h * 0.5), Vector2(seg_w, seg_h)), body_color)

func _draw_behemoth_body() -> void:
	# Behemoth — large, bulky, almost spherical
	draw_circle(Vector2(size.x * 0.55, size.y * 0.55), size.x * 0.5, body_color)

func _draw_aberrant_body() -> void:
	# Aberrant — irregular, pulsating blob
	var blob = PackedVector2Array([
		Vector2(0, 0),
		Vector2(size.x * 0.6, 0),
		Vector2(size.x * 0.55, size.y * 0.45),
		Vector2(size.x * 0.35, size.y * 0.5),
		Vector2(size.x * 0.25, size.y * 0.35),
		Vector2(size.x * 0.15, size.y * 0.45),
		Vector2(size.x * 0.1, size.y * 0.3),
		Vector2(size.x * 0.05, size.y * 0.25),
		Vector2(size.x * 0.1, size.y * 0.15),
		Vector2(size.x * 0.25, size.y * 0.1),
		Vector2(size.x * 0.45, size.y * 0.12),
		Vector2(size.x * 0.55, size.y * 0.2),
	])
	draw_colored_polygon(blob, body_color)

func _draw_legs() -> void:
	var leg_spacing: float = size.x * 0.22
	var leg_h: float = size.y * 0.28
	for i in range(leg_count):
		var lx = size.x * 0.3 + i * leg_spacing
		var ly = size.y * 0.45
		draw_rect(Rect2(Vector2(lx - leg_spacing * 0.08, ly - leg_h * 0.5), Vector2(leg_spacing * 0.16, leg_h)), body_color)

func _draw_quadruped_head() -> void:
	# Small head with single eye
	draw_circle(Vector2(size.x * 0.15, size.y * 0.15), size.x * 0.12, COLORS["skin"])
	draw_circle(Vector2(size.x * 0.15, size.y * 0.15 + size.y * 0.08), size.x * 0.1, COLORS["skin"])

func _draw_insectoid_head() -> void:
	# Insectoid — two large eyes on stalks
	var head_y = size.y * 0.15
	draw_circle(Vector2(size.x * 0.12, head_y), size.x * 0.1, COLORS["skin"])
	draw_circle(Vector2(size.x * 0.12, head_y + size.y * 0.08), size.x * 0.08, COLORS["skin"])

func _draw_behemoth_head() -> void:
	# Behemoth — single large eye on top
	draw_circle(Vector2(size.x * 0.12, size.y * 0.12), size.x * 0.12, COLORS["skin"])

func _draw_aberrant_head() -> void:
	# Aberrant — multiple small eyes
	for i in range(3):
		var ey = size.y * 0.1 + i * size.y * 0.08
		draw_circle(Vector2(size.x * 0.1, ey), size.x * 0.06, COLORS["skin"])

func _draw_attack_overlay() -> void:
	var frame: int = pose_frame % 4
	var color: Color = COLORS["highlight"]
	match archetype:
		"insectoid":
			# Insectoid: swipe lines from thorax
			var start = Vector2(size.x * 0.2, size.y * 0.4)
			var end = start + Vector2(0, -size.y * 0.15)
			draw_line(start, end, color)

		"behemoth":
			# Behemoth: ground slam
			draw_rect(Rect2(Vector2(size.x * 0.2, size.y * 0.35), Vector2(size.x * 0.6, size.y * 0.08)), color)

		"quadruped":
			# Quadruped: rear kick
			var kick = size.x * 0.3 + frame * size.x * 0.05
			draw_line(Vector2(kick, size.y * 0.4), Vector2(kick, size.y * 0.2), color)

		"aberrant":
			# Aberrant: pulsate outward
			var burst = size.x * 0.15 + frame * size.x * 0.05
			draw_circle(Vector2(burst, size.y * 0.15), size.x * 0.1, color)

# -------------------------------------------------------------------------
# Data-driven setup (called before draw)
# -------------------------------------------------------------------------

func setup_for(data: Dictionary) -> void:
	archetype = str(data.get("archetype", "quadruped"))
	body_color = COLORS.get(str(data.get("color", "rags")), COLORS["rags"])
	var sz = data.get("size", 48)
	size = sz if sz is Vector2 else Vector2(float(sz), float(sz))
	anim = str(data.get("anim", "idle"))
	pose_frame = int(data.get("pose_frame", 0))

# -------------------------------------------------------------------------
# Exposed getters
# -------------------------------------------------------------------------

func get_archetype() -> String:
	return archetype

func get_body_color() -> Color:
	return body_color
