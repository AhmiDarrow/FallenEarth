## ProceduralMob — Procedurally drawn creatures/mobs for overworld encounters.
## Extends ProceduralRenderer. Supports archetypes: quadruped, insectoid, behemoth,
## aberrant, floater, mechanical. Each has distinct draw logic with idle/walk/attack states.
## Sprite definitions loaded from mob_sprites.json provide per-mob draw_params and color ranges.
## Mobs are enemies only. NPCs are handled separately via CharacterVisual.

class_name ProceduralMob
extends ProceduralRenderer

const SPRITE_DATA_PATH := "res://data/mob_sprites.json"

# Archetype name (data-driven)
var archetype: String = "quadruped"

# State
var anim: String = "idle"

# Body color (data-driven, e.g. from NPC data)
var body_color: Color = COLORS["rags"]

# Legs count per archetype
var leg_count: int = 4

# Sprite definition (from mob_sprites.json)
var sprite_id: String = ""
var draw_params: Dictionary = {}
var color_range: Dictionary = {}
var colorshift_preset: String = ""

# Sprite cache (loaded once)
static var _sprite_cache: Dictionary = {}
static var _cache_loaded: bool = false


func _setup() -> void:
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
		"floater":
			_draw_floater_body()
		"mechanical":
			_draw_mechanical_body()
		_:
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
		"floater":
			_draw_floater_head()
		"mechanical":
			_draw_mechanical_head()

	# Draw sprite-specific features (from draw_params)
	_draw_sprite_features()

	# Attack/state animation overlays
	if anim == "attack":
		_draw_attack_overlay()


# -------------------------------------------------------------------------
# BODY SHAPES
# -------------------------------------------------------------------------

func _draw_quadruped_body() -> void:
	var ratio: float = draw_params.get("body_ratio", 0.4)
	var shape: String = draw_params.get("body_shape", "rounded")
	match shape:
		"lean":
			# Lean predator body — elongated ellipse
			var blob = PackedVector2Array([
				Vector2(size.x * 0.1, size.y * 0.35),
				Vector2(size.x * 0.35, size.y * 0.25),
				Vector2(size.x * 0.6, size.y * 0.35),
				Vector2(size.x * 0.65, size.y * 0.5),
				Vector2(size.x * 0.55, size.y * 0.65),
				Vector2(size.x * 0.3, size.y * 0.65),
				Vector2(size.x * 0.1, size.y * 0.55),
			])
			draw_colored_polygon(blob, body_color)
		"toad":
			# Wide squat toad body
			draw_circle(Vector2(size.x * 0.4, size.y * 0.5), size.x * 0.45, body_color)
			# Throat sac
			if draw_params.get("throat_sac", false):
				var sac_size: float = size.x * draw_params.get("sac_size", 0.12)
				draw_circle(Vector2(size.x * 0.15, size.y * 0.55), sac_size, body_color.lightened(0.15))
		"stag", "elk", "raptor":
			# Tall quadruped with defined chest
			draw_circle(Vector2(size.x * 0.45, size.y * 0.5), size.x * ratio, body_color)
			# Chest highlight
			draw_circle(Vector2(size.x * 0.35, size.y * 0.45), size.x * 0.12, body_color.lightened(0.08))
		"serpent":
			# Segmented snake body
			var seg_count: int = draw_params.get("body_segments", 8)
			var seg_size: float = size.x * draw_params.get("segment_size", 0.08)
			for i in range(seg_count):
				var t: float = float(i) / float(maxi(seg_count - 1, 1))
				var sx: float = size.x * (0.15 + t * 0.5)
				var sy: float = size.y * 0.45 + sin(t * PI * 2) * size.y * 0.08
				draw_circle(Vector2(sx, sy), seg_size, body_color)
		_:
			# Default rounded quadruped
			draw_circle(Vector2(size.x * 0.45, size.y * 0.5), size.x * ratio, body_color)

	# Hump
	if draw_params.get("hump", false):
		draw_circle(Vector2(size.x * 0.4, size.y * 0.35), size.x * 0.12, body_color.lightened(0.05))

	# Mane
	if draw_params.get("mane", false):
		var mane_len: float = size.y * draw_params.get("mane_length", 0.1)
		for i in range(4):
			var mx: float = size.x * (0.3 + i * 0.05)
			draw_line(Vector2(mx, size.y * 0.3), Vector2(mx, size.y * 0.3 - mane_len), body_color.lightened(0.1))

	# Spine ridge
	if draw_params.get("spine_ridge", false):
		for i in range(5):
			var rx: float = size.x * (0.2 + i * 0.08)
			draw_line(Vector2(rx, size.y * 0.35), Vector2(rx, size.y * 0.28), body_color.darkened(0.15))


func _draw_insectoid_body() -> void:
	var shape: String = draw_params.get("body_shape", "default")
	match shape:
		"crab":
			# Wide crab body with shell
			var shell_segs: int = draw_params.get("shell_segments", 3)
			var seg_w: float = size.x * 0.3
			var seg_h: float = size.y * 0.2
			for i in range(shell_segs):
				var y: float = size.y * 0.35 + i * seg_h
				var shade: float = 1.0 - float(i) * 0.05 * draw_params.get("shell_color_shift", 0.1)
				draw_rect(Rect2(Vector2(size.x * 0.15, y), Vector2(seg_w, seg_h)), body_color * shade)
			# Claws
			if draw_params.get("claws", false):
				draw_circle(Vector2(size.x * 0.05, size.y * 0.4), size.x * 0.08, body_color.lightened(0.1))
				draw_circle(Vector2(size.x * 0.65, size.y * 0.4), size.x * 0.08, body_color.lightened(0.1))
		"moth", "beetle", "beetle_heavy":
			# Oval body with wing cases
			var bw: float = size.x * 0.35
			var bh: float = size.y * 0.35
			draw_circle(Vector2(size.x * 0.4, size.y * 0.45), bw * 0.5, body_color)
			# Wing cases
			if draw_params.get("wing_count", 0) > 0:
				var ws: float = size.x * draw_params.get("wing_span", 0.3) * 0.5
				draw_circle(Vector2(size.x * 0.3, size.y * 0.4), ws, body_color.lightened(0.05))
				draw_circle(Vector2(size.x * 0.5, size.y * 0.4), ws, body_color.lightened(0.05))
		"spider":
			# Round abdomen + small cephalothorax
			draw_circle(Vector2(size.x * 0.45, size.y * 0.55), size.x * 0.25, body_color)
			draw_circle(Vector2(size.x * 0.25, size.y * 0.35), size.x * 0.12, body_color.darkened(0.1))
		"centipede":
			# Long segmented body
			var segs: int = draw_params.get("body_segments", 10)
			for i in range(segs):
				var t: float = float(i) / float(maxi(segs - 1, 1))
				var sx: float = size.x * (0.1 + t * 0.55)
				var sy: float = size.y * 0.45 + sin(t * PI * 1.5) * size.y * 0.05
				var seg_detail: String = draw_params.get("segment_detail", "default")
				if seg_detail == "bone":
					draw_circle(Vector2(sx, sy), size.x * 0.06, body_color.lightened(0.1))
					draw_line(Vector2(sx, sy - size.y * 0.04), Vector2(sx, sy + size.y * 0.04), body_color.darkened(0.2))
				else:
					draw_circle(Vector2(sx, sy), size.x * 0.06, body_color)
		"stationary":
			# Rooted plant with central bulb
			draw_circle(Vector2(size.x * 0.35, size.y * 0.4), size.x * 0.2, body_color)
		"serpent":
			# Same as quadruped serpent but insectoid coloring
			var seg_count: int = draw_params.get("body_segments", 8)
			for i in range(seg_count):
				var t: float = float(i) / float(maxi(seg_count - 1, 1))
				var sx: float = size.x * (0.15 + t * 0.5)
				var sy: float = size.y * 0.45 + sin(t * PI * 2) * size.y * 0.08
				draw_circle(Vector2(sx, sy), size.x * 0.06, body_color)
		_:
			# Default segmented insectoid
			var seg_w: float = size.x * 0.25
			var seg_h: float = size.y * 0.25
			for i in range(3):
				var y: float = size.y * 0.4 + i * seg_h
				draw_rect(Rect2(Vector2(-size.x * 0.1, y - seg_h * 0.5), Vector2(seg_w, seg_h)), body_color)


func _draw_behemoth_body() -> void:
	var shape: String = draw_params.get("body_shape", "bulky")
	match shape:
		"bulky":
			# Large spore hulk
			draw_circle(Vector2(size.x * 0.55, size.y * 0.55), size.x * 0.5, body_color)
			# Mushroom caps on back
			var cap_count: int = draw_params.get("mushroom_caps", 0)
			for i in range(cap_count):
				var cx: float = size.x * (0.25 + i * 0.1)
				var cy: float = size.y * 0.2
				draw_circle(Vector2(cx, cy), size.x * draw_params.get("cap_size", 0.1), body_color.lightened(0.12))
		"hulking":
			# Tall bipedal brute
			var bw: float = size.x * 0.4
			var bh: float = size.y * 0.5
			draw_rect(Rect2(Vector2(size.x * 0.2, size.y * 0.2), Vector2(bw, bh)), body_color)
			# Mushroom cap
			if draw_params.get("mushroom_cap", false):
				var cd: float = size.x * draw_params.get("cap_diameter", 0.2)
				draw_circle(Vector2(size.x * 0.4, size.y * 0.15), cd, body_color.lightened(0.1))
		"amorphous":
			# Shifting blob form
			var blob = PackedVector2Array()
			var points: int = 10
			for i in range(points):
				var angle: float = TAU * float(i) / float(points)
				var r: float = size.x * (0.3 + sin(angle * 3) * 0.1)
				blob.append(Vector2(
					size.x * 0.5 + cos(angle) * r,
					size.y * 0.5 + sin(angle) * r * 0.8
				))
			draw_colored_polygon(blob, body_color)
		"quadruped_heavy":
			# Massive war beast
			draw_circle(Vector2(size.x * 0.5, size.y * 0.5), size.x * 0.48, body_color)
			# Storm cloud aura
			if draw_params.get("storm_cloud", false):
				var cr: float = size.x * draw_params.get("cloud_radius", 0.4)
				var cloud_color: Color = body_color.darkened(0.2).lerp(COLORS["storm"], 0.3)
				draw_circle(Vector2(size.x * 0.5, size.y * 0.3), cr, cloud_color)
		"gatekeeper":
			# Massive mouth entity
			var bw: float = size.x * 0.6
			var bh: float = size.y * 0.6
			draw_circle(Vector2(size.x * 0.5, size.y * 0.5), size.x * 0.45, body_color)
			# Mouth
			var mouth_r: float = size.x * draw_params.get("mouth_size", 0.25)
			draw_circle(Vector2(size.x * 0.5, size.y * 0.5), mouth_r, body_color.darkened(0.3))
			# Teeth ring
			var teeth: int = draw_params.get("mouth_teeth", 12)
			for i in range(teeth):
				var angle: float = TAU * float(i) / float(teeth)
				var tx: float = size.x * 0.5 + cos(angle) * mouth_r * 0.8
				var ty: float = size.y * 0.5 + sin(angle) * mouth_r * 0.8
				draw_circle(Vector2(tx, ty), size.x * 0.02, COLORS["bone"])
		_:
			draw_circle(Vector2(size.x * 0.55, size.y * 0.55), size.x * 0.5, body_color)


func _draw_aberrant_body() -> void:
	var shape: String = draw_params.get("body_shape", "blob")
	match shape:
		"wraith":
			# Cloaked ethereal form
			var cloak = PackedVector2Array([
				Vector2(size.x * 0.2, size.y * 0.1),
				Vector2(size.x * 0.5, size.y * 0.05),
				Vector2(size.x * 0.7, size.y * 0.2),
				Vector2(size.x * 0.65, size.y * 0.6),
				Vector2(size.x * 0.5, size.y * 0.75),
				Vector2(size.x * 0.25, size.y * 0.7),
				Vector2(size.x * 0.1, size.y * 0.4),
			])
			draw_colored_polygon(cloak, body_color)
			# Void aura
			if draw_params.get("void_aura", false):
				var ar: float = size.x * draw_params.get("aura_radius", 0.3)
				draw_circle(Vector2(size.x * 0.4, size.y * 0.35), ar, Color(body_color.r, body_color.g, body_color.b, 0.3))
		_:
			# Default irregular blob
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


func _draw_floater_body() -> void:
	var shape: String = draw_params.get("body_shape", "jellyfish")
	match shape:
		"jellyfish":
			# Dome body
			var dome = PackedVector2Array()
			for i in range(12):
				var angle: float = PI + TAU * float(i) / 11.0
				var r: float = size.x * 0.35
				dome.append(Vector2(
					size.x * 0.4 + cos(angle) * r,
					size.y * 0.35 + sin(angle) * r * 0.6
				))
			draw_colored_polygon(dome, body_color)
			# Glow
			if draw_params.get("glow_intensity", 0.0) > 0.0:
				var glow_a: float = draw_params.get("glow_intensity", 0.5)
				draw_circle(Vector2(size.x * 0.4, size.y * 0.35), size.x * 0.25, Color(body_color.r, body_color.g, body_color.b, glow_a * 0.4))
			# Tentacles
			var tent_count: int = draw_params.get("tentacle_count", 5)
			var tent_len: float = size.y * draw_params.get("tentacle_length", 0.3)
			for i in range(tent_count):
				var tx: float = size.x * (0.2 + i * 0.06)
				var sway: float = sin(pose_frame * 0.5 + i * 0.8) * size.x * 0.03
				draw_line(Vector2(tx, size.y * 0.5), Vector2(tx + sway, size.y * 0.5 + tent_len), body_color.lightened(0.1))
		"leech":
			# Elongated leech body
			var blob = PackedVector2Array([
				Vector2(size.x * 0.1, size.y * 0.35),
				Vector2(size.x * 0.3, size.y * 0.25),
				Vector2(size.x * 0.55, size.y * 0.3),
				Vector2(size.x * 0.65, size.y * 0.45),
				Vector2(size.x * 0.55, size.y * 0.6),
				Vector2(size.x * 0.3, size.y * 0.65),
				Vector2(size.x * 0.1, size.y * 0.55),
			])
			draw_colored_polygon(blob, body_color)
			# Spines
			var spine_count: int = draw_params.get("spine_count", 8)
			for i in range(spine_count):
				var t: float = float(i) / float(spine_count)
				var sx: float = size.x * (0.15 + t * 0.45)
				var sy: float = size.y * 0.3 + sin(t * PI) * size.y * 0.05
				draw_line(Vector2(sx, sy), Vector2(sx, sy - size.y * draw_params.get("spine_length", 0.15)), body_color.lightened(0.2))
		"cloud":
			# Amorphous cloud body
			for i in range(6):
				var angle: float = TAU * float(i) / 6.0
				var r: float = size.x * (0.2 + sin(angle * 2) * 0.05)
				draw_circle(Vector2(
					size.x * 0.4 + cos(angle) * r,
					size.y * 0.4 + sin(angle) * r
				), size.x * 0.15, body_color)
			# Spore particles
			var spore_count: int = draw_params.get("spore_count", 12)
			for i in range(spore_count):
				var angle: float = TAU * float(i) / float(spore_count)
				var orbit_r: float = size.x * 0.35
				var px: float = size.x * 0.4 + cos(angle + pose_frame * 0.1) * orbit_r
				var py: float = size.y * 0.4 + sin(angle + pose_frame * 0.1) * orbit_r
				draw_circle(Vector2(px, py), size.x * draw_params.get("spore_size", 0.04), body_color.lightened(0.3))
		"orbital":
			# Central orb with rings
			draw_circle(Vector2(size.x * 0.4, size.y * 0.4), size.x * 0.15, body_color)
			# Rings
			var ring_count: int = draw_params.get("ring_count", 2)
			for i in range(ring_count):
				var ring_r: float = size.x * draw_params.get("ring_radius", 0.3) * (1.0 + float(i) * 0.3)
				var tilt: float = deg_to_rad(draw_params.get("ring_tilt", 20) + float(i) * 15)
				# Ellipse approximation
				for j in range(16):
					var a1: float = TAU * float(j) / 16.0
					var a2: float = TAU * float(j + 1) / 16.0
					var p1 := Vector2(size.x * 0.4 + cos(a1) * ring_r, size.y * 0.4 + sin(a1) * ring_r * cos(tilt))
					var p2 := Vector2(size.x * 0.4 + cos(a2) * ring_r, size.y * 0.4 + sin(a2) * ring_r * cos(tilt))
					draw_line(p1, p2, body_color.lightened(0.2))
		_:
			# Default blob
			draw_circle(Vector2(size.x * 0.4, size.y * 0.4), size.x * 0.3, body_color)


func _draw_mechanical_body() -> void:
	var shape: String = draw_params.get("body_shape", "mechanical")
	# Rigid geometric body
	var bw: float = size.x * 0.4
	var bh: float = size.y * 0.5
	draw_rect(Rect2(Vector2(size.x * 0.15, size.y * 0.2), Vector2(bw, bh)), body_color)
	# Core glow
	if draw_params.get("core_glow", false):
		var core_s: float = size.x * draw_params.get("core_size", 0.15)
		draw_circle(Vector2(size.x * 0.35, size.y * 0.45), core_s, body_color.lightened(0.3))
	# Hydraulic joints
	if draw_params.get("leg_style") == "hydraulic":
		for i in range(4):
			var jx: float = size.x * (0.18 + i * 0.08)
			draw_circle(Vector2(jx, size.y * 0.7), size.x * 0.03, COLORS["metal"])
	# Claws
	if draw_params.get("claw_count", 0) > 0:
		var claw_s: float = size.x * draw_params.get("claw_size", 0.18)
		draw_line(Vector2(size.x * 0.15, size.y * 0.4), Vector2(size.x * 0.0, size.y * 0.3), body_color.darkened(0.1))
		draw_line(Vector2(size.x * 0.15, size.y * 0.4), Vector2(size.x * 0.0, size.y * 0.5), body_color.darkened(0.1))
	# Drill arm
	if draw_params.get("drill_arm", false):
		var drill = PackedVector2Array([
			Vector2(size.x * 0.55, size.y * 0.35),
			Vector2(size.x * 0.8, size.y * 0.4),
			Vector2(size.x * 0.55, size.y * 0.5),
		])
		draw_colored_polygon(drill, body_color.darkened(0.1))
	# Magnetic field
	if draw_params.get("magnetic_field", false):
		var fr: float = size.x * draw_params.get("field_radius", 0.25)
		for i in range(3):
			var angle: float = TAU * float(i) / 3.0 + pose_frame * 0.2
			var fx: float = size.x * 0.35 + cos(angle) * fr
			var fy: float = size.y * 0.4 + sin(angle) * fr
			draw_circle(Vector2(fx, fy), size.x * 0.02, COLORS["mana"])


# -------------------------------------------------------------------------
# LEGS
# -------------------------------------------------------------------------

func _draw_legs() -> void:
	var count: int = draw_params.get("leg_count", leg_count)
	if count == 0:
		return
	var style: String = draw_params.get("leg_style", "default")
	var leg_spacing: float = size.x * 0.22
	var leg_h: float = size.y * 0.28

	match style:
		"thin":
			leg_h = size.y * 0.3
			leg_spacing = size.x * 0.18
		"thick", "thick_stubby":
			leg_h = size.y * 0.22
			leg_spacing = size.x * 0.25
		"long_thin":
			leg_h = size.y * 0.35
			leg_spacing = size.x * 0.2
		"long_slender":
			leg_h = size.y * 0.38
			leg_spacing = size.x * 0.2
		"jointed":
			# Jointed insect legs — angular
			for i in range(count):
				var lx: float = size.x * 0.25 + i * leg_spacing
				var ly: float = size.y * 0.45
				var mid_x: float = lx + size.x * 0.05
				var mid_y: float = ly + leg_h * 0.4
				draw_line(Vector2(lx, ly), Vector2(mid_x, mid_y), body_color.darkened(0.1))
				draw_line(Vector2(mid_x, mid_y), Vector2(mid_x - size.x * 0.03, ly + leg_h), body_color.darkened(0.1))
		"hydraulic":
			# Thick hydraulic legs
			for i in range(count):
				var lx: float = size.x * 0.2 + i * leg_spacing
				var ly: float = size.y * 0.7
				draw_rect(Rect2(Vector2(lx - 2, ly), Vector2(4, leg_h)), body_color.darkened(0.15))
		"taloned":
			# Bird-like raptor legs
			for i in range(count):
				var lx: float = size.x * 0.3 + i * leg_spacing
				var ly: float = size.y * 0.6
				draw_line(Vector2(lx, ly), Vector2(lx, ly + leg_h), body_color.darkened(0.1))
				# Talon
				draw_line(Vector2(lx, ly + leg_h), Vector2(lx - size.x * 0.03, ly + leg_h + 4), body_color.darkened(0.2))
				draw_line(Vector2(lx, ly + leg_h), Vector2(lx + size.x * 0.03, ly + leg_h + 4), body_color.darkened(0.2))
		"ethereal":
			# Fading transparent legs
			for i in range(count):
				var lx: float = size.x * 0.3 + i * leg_spacing
				var ly: float = size.y * 0.45
				draw_line(Vector2(lx, ly), Vector2(lx, ly + leg_h), Color(body_color.r, body_color.g, body_color.b, 0.5))
		_:
			for i in range(count):
				var lx: float = size.x * 0.3 + i * leg_spacing
				var ly: float = size.y * 0.45
				draw_rect(Rect2(Vector2(lx - leg_spacing * 0.08, ly - leg_h * 0.5), Vector2(leg_spacing * 0.16, leg_h)), body_color)

	# Root system (for stationary plants)
	if draw_params.get("root_count", 0) > 0:
		var root_count: int = draw_params.get("root_count", 6)
		var root_len: float = size.y * draw_params.get("root_length", 0.25)
		for i in range(root_count):
			var angle: float = PI * 0.3 + TAU * float(i) / float(root_count) * 0.5 + PI * 0.5
			var rx: float = size.x * 0.35 + cos(angle) * root_len
			var ry: float = size.y * 0.6 + sin(angle) * root_len * 0.5
			draw_line(Vector2(size.x * 0.35, size.y * 0.6), Vector2(rx, ry), body_color.darkened(0.15))


# -------------------------------------------------------------------------
# HEADS
# -------------------------------------------------------------------------

func _draw_quadruped_head() -> void:
	var head_s: float = size.x * draw_params.get("head_size", 0.12)
	var eye_count: int = draw_params.get("eye_count", 1)
	var eye_s: float = size.x * draw_params.get("eye_size", 0.08)

	# Head shape
	draw_circle(Vector2(size.x * 0.15, size.y * 0.15), head_s, body_color.darkened(0.05))

	# Eyes
	for i in range(eye_count):
		var ey: float = size.y * 0.12 + i * size.y * 0.06
		draw_circle(Vector2(size.x * 0.1, ey), eye_s, COLORS["skin"])

	# Antlers
	if draw_params.get("antlers", false):
		var branches: int = draw_params.get("antler_branches", 3)
		var antler_h: float = head_s * 1.5
		for side in [-1, 1]:
			var base_x: float = size.x * 0.15 + side * head_s * 0.3
			var base_y: float = size.y * 0.1
			# Main antler
			draw_line(Vector2(base_x, base_y), Vector2(base_x + side * size.x * 0.08, base_y - antler_h), body_color.darkened(0.15))
			# Branches
			for b in range(branches):
				var b_t: float = float(b + 1) / float(branches + 1)
				var bx: float = base_x + side * size.x * 0.08 * b_t
				var by: float = base_y - antler_h * b_t
				draw_line(Vector2(bx, by), Vector2(bx + side * size.x * 0.04, by - size.y * 0.04), body_color.darkened(0.15))

	# Crest
	if draw_params.get("crest", false):
		var crest_h: float = size.y * draw_params.get("crest_height", 0.1)
		for i in range(3):
			var cx: float = size.x * (0.1 + i * 0.03)
			draw_line(Vector2(cx, size.y * 0.08), Vector2(cx, size.y * 0.08 - crest_h), body_color.lightened(0.15))

	# Beak
	if draw_params.get("beak", false):
		var beak = PackedVector2Array([
			Vector2(size.x * 0.08, size.y * 0.12),
			Vector2(size.x * 0.0, size.y * 0.15),
			Vector2(size.x * 0.08, size.y * 0.18),
		])
		draw_colored_polygon(beak, body_color.darkened(0.2))

	# Eye bulge (toad)
	if draw_params.get("eye_bulge", false):
		draw_circle(Vector2(size.x * 0.08, size.y * 0.08), head_s * 0.8, body_color)
		draw_circle(Vector2(size.x * 0.08, size.y * 0.08), eye_s * 0.7, COLORS["skin"])

	# Tail
	if draw_params.get("tail", false):
		var tail_style: String = draw_params.get("tail_style", "short")
		var tail_start := Vector2(size.x * 0.65, size.y * 0.45)
		match tail_style:
			"barbed":
				var tail_end := Vector2(size.x * 0.85, size.y * 0.3)
				draw_line(tail_start, tail_end, body_color.darkened(0.1))
				draw_line(tail_end, Vector2(tail_end.x + 4, tail_end.y - 4), body_color.darkened(0.2))
				draw_line(tail_end, Vector2(tail_end.x + 4, tail_end.y + 4), body_color.darkened(0.2))
			"fan":
				for i in range(3):
					var angle: float = -0.3 + float(i) * 0.3
					var end := tail_start + Vector2(size.x * 0.2, angle * size.y * 0.15)
					draw_line(tail_start, end, body_color.lightened(0.05))
			_:
				draw_line(tail_start, tail_start + Vector2(size.x * 0.12, -size.y * 0.05), body_color.darkened(0.1))


func _draw_insectoid_head() -> void:
	var head_s: float = size.x * draw_params.get("head_size", 0.1)
	var eye_count: int = draw_params.get("eye_count", 2)
	var eye_s: float = size.x * draw_params.get("eye_size", 0.06)

	# Head
	draw_circle(Vector2(size.x * 0.12, size.y * 0.15), head_s, body_color.darkened(0.05))

	# Eyes
	for i in range(eye_count):
		var ey: float = size.y * 0.1 + i * size.y * 0.05
		draw_circle(Vector2(size.x * 0.08, ey), eye_s, COLORS["skin"])

	# Fangs
	if draw_params.get("fangs", false):
		draw_line(Vector2(size.x * 0.08, size.y * 0.2), Vector2(size.x * 0.04, size.y * 0.28), body_color.darkened(0.2))
		draw_line(Vector2(size.x * 0.12, size.y * 0.2), Vector2(size.x * 0.08, size.y * 0.28), body_color.darkened(0.2))

	# Mandibles
	if draw_params.get("mandibles", false):
		var mand_s: float = size.x * draw_params.get("mandible_size", 0.1)
		draw_line(Vector2(size.x * 0.08, size.y * 0.18), Vector2(size.x * 0.02, size.y * 0.18 + mand_s), body_color.darkened(0.15))
		draw_line(Vector2(size.x * 0.12, size.y * 0.18), Vector2(size.x * 0.06, size.y * 0.18 + mand_s), body_color.darkened(0.15))

	# Proboscis
	if draw_params.get("proboscis", false):
		draw_line(Vector2(size.x * 0.08, size.y * 0.2), Vector2(size.x * 0.04, size.y * 0.32), body_color.darkened(0.1))


func _draw_behemoth_head() -> void:
	var head_s: float = size.x * draw_params.get("head_size", 0.15)
	var eye_count: int = draw_params.get("eye_count", 1)
	var eye_s: float = size.x * draw_params.get("eye_size", 0.12)

	# Head
	draw_circle(Vector2(size.x * 0.12, size.y * 0.12), head_s, body_color.darkened(0.05))

	# Eyes
	for i in range(eye_count):
		var angle: float = TAU * float(i) / float(maxi(eye_count, 1))
		var ex: float = size.x * 0.12 + cos(angle) * head_s * 0.5
		var ey: float = size.y * 0.12 + sin(angle) * head_s * 0.5
		draw_circle(Vector2(ex, ey), eye_s * 0.7, COLORS["skin"])

	# Horns
	if draw_params.get("horn_count", 0) > 0:
		var horn_s: float = size.x * draw_params.get("horn_size", 0.15)
		for i in range(draw_params.get("horn_count", 2)):
			var side: float = -1.0 + float(i) * 2.0
			var hx: float = size.x * 0.12 + side * head_s * 0.4
			var hy: float = size.y * 0.05
			draw_line(Vector2(hx, hy), Vector2(hx + side * size.x * 0.06, hy - horn_s), body_color.darkened(0.15))


func _draw_aberrant_head() -> void:
	var eye_count: int = draw_params.get("eye_count", 3)
	var eye_s: float = size.x * draw_params.get("eye_size", 0.06)

	for i in range(eye_count):
		var ey: float = size.y * 0.1 + i * size.y * 0.08
		draw_circle(Vector2(size.x * 0.1, ey), eye_s, COLORS["skin"])

	# Claw hands (wraith)
	if draw_params.get("claw_hands", false):
		# Left hand
		draw_line(Vector2(size.x * 0.15, size.y * 0.45), Vector2(size.x * 0.0, size.y * 0.5), body_color.darkened(0.1))
		for i in range(3):
			var cx: float = size.x * 0.0 + i * size.x * 0.01
			var cy: float = size.y * 0.5 + i * size.y * 0.02
			draw_line(Vector2(cx, cy), Vector2(cx - size.x * 0.03, cy + size.y * 0.03), body_color.darkened(0.15))


func _draw_floater_head() -> void:
	var eye_count: int = draw_params.get("eye_count", 0)
	if eye_count == 0:
		return
	var eye_s: float = size.x * draw_params.get("eye_size", 0.08)

	for i in range(eye_count):
		var ex: float = size.x * 0.4
		var ey: float = size.y * 0.35
		draw_circle(Vector2(ex, ey), eye_s, COLORS["skin"])


func _draw_mechanical_head() -> void:
	var eye_count: int = draw_params.get("eye_count", 2)
	var eye_s: float = size.x * draw_params.get("eye_size", 0.08)

	# Visor / eye slits
	for i in range(eye_count):
		var ex: float = size.x * (0.2 + i * 0.08)
		var ey: float = size.y * 0.25
		draw_rect(Rect2(Vector2(ex, ey), Vector2(size.x * 0.06, eye_s)), body_color.lightened(0.3))


# -------------------------------------------------------------------------
# SPRITE FEATURES (from draw_params)
# -------------------------------------------------------------------------

func _draw_sprite_features() -> void:
	# Tentacles (floater)
	if draw_params.has("tentacle_count") and archetype == "floater":
		pass  # Already drawn in body

	# Web lines (spider)
	if draw_params.get("web_lines", false):
		var web_r: float = size.x * draw_params.get("web_radius", 0.4)
		for i in range(4):
			var angle: float = TAU * float(i) / 4.0
			var end := Vector2(
				size.x * 0.4 + cos(angle) * web_r,
				size.y * 0.4 + sin(angle) * web_r
			)
			draw_line(Vector2(size.x * 0.4, size.y * 0.4), end, Color(body_color.r, body_color.g, body_color.b, 0.4))

	# Energy tentacles (rift_maw)
	if draw_params.get("energy_tentacles", 0) > 0:
		var t_count: int = draw_params.get("energy_tentacles", 6)
		var t_len: float = size.y * draw_params.get("tentacle_length", 0.35)
		for i in range(t_count):
			var angle: float = TAU * float(i) / float(t_count)
			var sx: float = size.x * 0.5 + cos(angle) * size.x * 0.2
			var sy: float = size.y * 0.5 + sin(angle) * size.y * 0.2
			var ex: float = sx + cos(angle) * t_len
			var ey: float = sy + sin(angle) * t_len
			draw_line(Vector2(sx, sy), Vector2(ex, ey), body_color.lightened(0.2))

	# Arcs (arc_dynamo)
	if draw_params.get("arc_count", 0) > 0:
		var arc_c: int = draw_params.get("arc_count", 6)
		var arc_l: float = size.x * draw_params.get("arc_length", 0.2)
		for i in range(arc_c):
			var angle: float = TAU * float(i) / float(arc_c) + pose_frame * 0.3
			var sx: float = size.x * 0.4 + cos(angle) * size.x * 0.15
			var sy: float = size.y * 0.4 + sin(angle) * size.y * 0.15
			var ex: float = sx + cos(angle + 0.5) * arc_l
			var ey: float = sy + sin(angle + 0.5) * arc_l
			draw_line(Vector2(sx, sy), Vector2(ex, ey), COLORS["mana"])

	# Lightning aura (storm_herald)
	if draw_params.get("lightning_aura", false):
		var ar: float = size.x * draw_params.get("aura_radius", 0.35)
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0 + pose_frame * 0.15
			var lx: float = size.x * 0.5 + cos(angle) * ar
			var ly: float = size.y * 0.5 + sin(angle) * ar
			draw_line(Vector2(lx, ly), Vector2(lx + randf_range(-4, 4), ly + randf_range(-4, 4)), COLORS["storm"])

	# Growth tendrils (lifecycle_horror)
	if draw_params.get("growth_tendrils", 0) > 0:
		var gt: int = draw_params.get("growth_tendrils", 6)
		var gt_len: float = size.y * draw_params.get("tendril_length", 0.3)
		for i in range(gt):
			var angle: float = TAU * float(i) / float(gt)
			var sx: float = size.x * 0.5 + cos(angle) * size.x * 0.15
			var sy: float = size.y * 0.5 + sin(angle) * size.y * 0.15
			var mid_angle: float = angle + sin(pose_frame * 0.2 + i) * 0.3
			var mid := Vector2(sx + cos(mid_angle) * gt_len * 0.5, sy + sin(mid_angle) * gt_len * 0.5)
			var end := Vector2(sx + cos(angle) * gt_len, sy + sin(angle) * gt_len)
			draw_line(Vector2(sx, sy), mid, body_color.lightened(0.1))
			draw_line(mid, end, body_color.lightened(0.15))

	# Spore cloud (mycelial_behemoth)
	if draw_params.get("spore_cloud", false):
		var sr: float = size.x * draw_params.get("spore_radius", 0.3)
		for i in range(8):
			var angle: float = TAU * float(i) / 8.0 + pose_frame * 0.05
			var px: float = size.x * 0.4 + cos(angle) * sr
			var py: float = size.y * 0.3 + sin(angle) * sr * 0.6
			draw_circle(Vector2(px, py), size.x * 0.03, body_color.lightened(0.25))

	# Rattle tail (glass_serpent)
	if draw_params.get("rattle_tail", false):
		var tail_base := Vector2(size.x * 0.65, size.y * 0.45)
		for i in range(3):
			var rx: float = tail_base.x + i * size.x * 0.03
			var ry: float = tail_base.y + sin(pose_frame * 0.8 + i) * 3
			draw_circle(Vector2(rx, ry), size.x * 0.025, body_color.lightened(0.2))


# -------------------------------------------------------------------------
# ATTACK OVERLAY
# -------------------------------------------------------------------------

func _draw_attack_overlay() -> void:
	var frame: int = pose_frame % 4
	var color: Color = COLORS["highlight"]
	match archetype:
		"insectoid":
			var start = Vector2(size.x * 0.2, size.y * 0.4)
			var end = start + Vector2(0, -size.y * 0.15)
			draw_line(start, end, color)
		"behemoth":
			draw_rect(Rect2(Vector2(size.x * 0.2, size.y * 0.35), Vector2(size.x * 0.6, size.y * 0.08)), color)
		"quadruped":
			var kick = size.x * 0.3 + frame * size.x * 0.05
			draw_line(Vector2(kick, size.y * 0.4), Vector2(kick, size.y * 0.2), color)
		"aberrant":
			var burst = size.x * 0.15 + frame * size.x * 0.05
			draw_circle(Vector2(burst, size.y * 0.15), size.x * 0.1, color)
		"floater":
			# Pulse ring
			var pulse_r = size.x * (0.2 + frame * 0.05)
			for i in range(8):
				var angle: float = TAU * float(i) / 8.0
				var px: float = size.x * 0.4 + cos(angle) * pulse_r
				var py: float = size.y * 0.4 + sin(angle) * pulse_r
				draw_circle(Vector2(px, py), size.x * 0.02, color)
		"mechanical":
			# Spark burst
			for i in range(4):
				var angle: float = TAU * float(i) / 4.0 + frame * 0.5
				var sx: float = size.x * 0.3 + cos(angle) * size.x * 0.15
				var sy: float = size.y * 0.35 + sin(angle) * size.y * 0.15
				draw_line(Vector2(sx, sy), Vector2(sx + cos(angle) * 8, sy + sin(angle) * 8), COLORS["mana"])


# -------------------------------------------------------------------------
# DATA-DRIVEN SETUP
# -------------------------------------------------------------------------

func setup_for(data: Dictionary) -> void:
	archetype = str(data.get("archetype", "quadruped"))
	body_color = COLORS.get(str(data.get("color", "rags")), COLORS["rags"])
	var sz = data.get("size", 48)
	size = sz if sz is Vector2 else Vector2(float(sz), float(sz))
	anim = str(data.get("anim", "idle"))
	pose_frame = int(data.get("pose_frame", 0))

	# Load sprite definition if sprite_id provided
	var sid: String = str(data.get("sprite_id", ""))
	if not sid.is_empty():
		load_sprite(sid)


## Load a sprite definition by ID and apply its draw_params and color_range.
func load_sprite(id: String) -> void:
	if not _cache_loaded:
		_load_sprite_cache()
	var sprite: Dictionary = _sprite_cache.get(id, {})
	if sprite.is_empty():
		return
	sprite_id = id
	archetype = str(sprite.get("archetype", archetype))
	draw_params = sprite.get("draw_params", {}).duplicate(true)
	color_range = sprite.get("color_range", {}).duplicate(true)


## Apply a colorshift preset (from mob_sprites.json colorshift_presets).
func apply_colorshift(preset_name: String) -> void:
	if not _cache_loaded:
		_load_sprite_cache()
	var presets: Dictionary = _sprite_cache.get("_colorshift_presets", {})
	var preset: Dictionary = presets.get(preset_name, {})
	if preset.is_empty():
		return
	_apply_color_range(preset)


## Apply color_range shifts to body_color.
func apply_color_range(range_data: Dictionary = {}) -> void:
	if range_data.is_empty():
		range_data = color_range
	if range_data.is_empty():
		return
	_apply_color_range(range_data)


func _apply_color_range(range_data: Dictionary) -> void:
	var base_key: String = str(range_data.get("base", ""))
	var base_color: Color = COLORS.get(base_key, body_color)
	var hue_s: float = range_data.get("hue_shift", 0.0)
	var sat_s: float = range_data.get("sat_shift", 0.0)
	var var_s: float = range_data.get("var_shift", 0.0)

	# Apply shifts with randomization
	var h: float = base_color.h + hue_s * randf_range(-1.0, 1.0)
	var s: float = clampf(base_color.s + sat_s * randf_range(-1.0, 1.0), 0.0, 1.0)
	var v: float = clampf(base_color.v + var_s * randf_range(-1.0, 1.0), 0.0, 1.0)
	if h < 0.0: h += 1.0
	elif h > 1.0: h -= 1.0
	body_color = Color.from_hsv(h, s, v)


# -------------------------------------------------------------------------
# SPRITE CACHE
# -------------------------------------------------------------------------

static func _load_sprite_cache() -> void:
	var file: FileAccess = FileAccess.open(SPRITE_DATA_PATH, FileAccess.READ)
	if not file:
		push_warning("[ProceduralMob] Missing sprite data: %s" % SPRITE_DATA_PATH)
		_cache_loaded = true
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var sprites: Dictionary = parsed.get("sprites", {})
		for key in sprites:
			_sprite_cache[key] = sprites[key]
		_sprite_cache["_colorshift_presets"] = parsed.get("colorshift_presets", {})
	_cache_loaded = true


## Get available sprite IDs for a given spawn context.
static func get_sprites_for_context(context: String) -> Array[String]:
	if not _cache_loaded:
		_load_sprite_cache()
	var result: Array[String] = []
	for key in _sprite_cache:
		if key.begins_with("_"):
			continue
		var sprite: Dictionary = _sprite_cache[key]
		if sprite.get("spawn_context", "upworld") == context or context == "all":
			result.append(key)
	return result


## Get sprite definition by ID.
static func get_sprite(id: String) -> Dictionary:
	if not _cache_loaded:
		_load_sprite_cache()
	return _sprite_cache.get(id, {})


# -------------------------------------------------------------------------
# EXPOSED GETTERS
# -------------------------------------------------------------------------

func get_archetype() -> String:
	return archetype

func get_body_color() -> Color:
	return body_color

func get_sprite_id() -> String:
	return sprite_id
