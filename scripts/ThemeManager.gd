## ThemeManager — Autoload singleton for runtime theme management.
## Manages theme registration, persistence, and live application.
## Mods can register custom themes via ModAPI.register_theme().
extends Node

signal theme_changed(theme_name: String)

const SETTINGS_PATH := "user://options.cfg"
const DEFAULT_THEME := "twilight"

var _themes: Dictionary = {}
var _current_theme: String = ""


func _ready() -> void:
	_register_builtin_themes()
	var saved := _load_saved_theme()
	apply_theme(saved if saved != "" else DEFAULT_THEME)


func _register_builtin_themes() -> void:
	register_theme("core", "twilight", "Twilight", _twilight_data())
	register_theme("core", "ember", "Ember", _ember_data())
	register_theme("core", "frost", "Frost", _frost_data())
	register_theme("core", "viridian", "Viridian", _viridian_data())
	register_theme("core", "nocturne", "Nocturne", _nocturne_data())
	register_theme("core", "abyss", "Abyss", _abyss_data())
	register_theme("core", "ochre", "Ochre", _ochre_data())
	register_theme("core", "terra", "Terra", {})  # original warm earth tones


func register_theme(mod_id: String, name: String, display_name: String, data: Dictionary) -> void:
	if _themes.has(name):
		push_warning("[ThemeManager] Theme '%s' already registered (by %s). Overwriting." % [name, _themes[name].mod_id])
	_themes[name] = {
		"mod_id": mod_id,
		"display_name": display_name,
		"data": data,
	}


func get_themes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for name in _themes:
		result.append({"name": name, "display_name": _themes[name].display_name})
	result.sort_custom(func(a, b): return a.display_name < b.display_name)
	return result


func get_current_theme() -> String:
	return _current_theme


func apply_theme(name: String) -> void:
	if not _themes.has(name):
		push_error("[ThemeManager] Unknown theme: '%s'" % name)
		return
	if _current_theme == name:
		return
	_current_theme = name
	MasterTheme.apply_theme_data(_themes[name].data)
	MasterTheme.apply_to(get_tree().root)
	_save_theme_setting(name)
	theme_changed.emit(name)


# ---------------------------------------------------------------------------
# Theme color data — each returns a dictionary of ALL color overrides.
# An empty dict = use MasterTheme defaults.
# ---------------------------------------------------------------------------

static func _twilight_data() -> Dictionary:
	return {
		"BG_DEEP": Color(0.102, 0.082, 0.149),
		"BG_SURFACE": Color(0.141, 0.118, 0.176),
		"BG_ELEVATED": Color(0.180, 0.157, 0.212),
		"BG_INPUT": Color(0.102, 0.082, 0.149),
		"BG_PANEL": Color(0.141, 0.118, 0.176),
		"BORDER_SUBTLE": Color(0.235, 0.208, 0.290),
		"BORDER_STRONG": Color(0.353, 0.314, 0.439),
		"BORDER_INPUT": Color(0.235, 0.208, 0.290),
		"ACCENT_PRIMARY": Color(0.494, 0.427, 0.718),
		"ACCENT_SECONDARY": Color(0.420, 0.620, 0.478),
		"ACCENT_DANGER": Color(0.804, 0.522, 0.251),
		"ACCENT_SUCCESS": Color(0.420, 0.620, 0.478),
		"ACCENT_NEON": Color(0.608, 0.561, 0.831),
		"TEXT_PRIMARY": Color(0.910, 0.863, 0.773),
		"TEXT_SECONDARY": Color(0.651, 0.620, 0.580),
		"TEXT_MUTED": Color(0.475, 0.451, 0.420),
		"TEXT_ACCENT": Color(0.608, 0.561, 0.831),
		"TEXT_DANGER": Color(0.804, 0.522, 0.251),
		"TEXT_SUCCESS": Color(0.420, 0.620, 0.478),
		"TEXT_LINK": Color(0.549, 0.671, 0.578),
		"HP_FILL": Color(0.804, 0.522, 0.251),
		"HP_BG": Color(0.329, 0.208, 0.118),
		"MP_FILL": Color(0.494, 0.427, 0.718),
		"MP_BG": Color(0.188, 0.157, 0.302),
		"XP_FILL": Color(0.420, 0.620, 0.478),
		"XP_BG": Color(0.176, 0.294, 0.212),
		"RARITY_COMMON": Color(0.651, 0.620, 0.580),
		"RARITY_UNCOMMON": Color(0.420, 0.620, 0.478),
		"RARITY_RARE": Color(0.494, 0.427, 0.718),
		"RARITY_EPIC": Color(0.608, 0.561, 0.831),
		"RARITY_LEGENDARY": Color(0.804, 0.522, 0.251),
		"OVERLAY_DARK": Color(0.080, 0.060, 0.118, 0.85),
		"OVERLAY_LIGHT": Color(0.102, 0.082, 0.149, 0.60),
		"SELECTED_BG": Color(0.180, 0.157, 0.212),
		"SELECTED_TINT": Color(0.494, 0.427, 0.718),
		"GLOW_PRIMARY": Color(0.494, 0.427, 0.718),
		"GLOW_RIFT": Color(0.804, 0.522, 0.251),
		"MM_PLAYER": Color(0.400, 0.851, 1.000),
		"MM_DISCOVERED": Color(0.451, 0.502, 0.424),
		"MM_CURRENT": Color(1, 1, 1),
		"MM_RIFT": Color(0.804, 0.522, 0.251),
		"MM_RIFTSPIRE": Color(1.000, 0.600, 0.200),
		"MM_MOB_HOSTILE": Color(1.000, 0.502, 0.400),
		"MM_MOB_NEUTRAL": Color(0.702, 0.851, 0.702),
		"MM_GRID_LINE": Color(0.200, 0.200, 0.220, 0.5),
	}


static func _ember_data() -> Dictionary:
	return {
		"BG_DEEP": Color(0.110, 0.055, 0.050),
		"BG_SURFACE": Color(0.180, 0.102, 0.090),
		"BG_ELEVATED": Color(0.235, 0.149, 0.118),
		"BG_INPUT": Color(0.110, 0.055, 0.050),
		"BG_PANEL": Color(0.180, 0.102, 0.090),
		"BORDER_SUBTLE": Color(0.353, 0.220, 0.157),
		"BORDER_STRONG": Color(0.502, 0.322, 0.220),
		"BORDER_INPUT": Color(0.353, 0.220, 0.157),
		"ACCENT_PRIMARY": Color(0.788, 0.659, 0.298),
		"ACCENT_SECONDARY": Color(0.627, 0.251, 0.251),
		"ACCENT_DANGER": Color(0.878, 0.251, 0.251),
		"ACCENT_SUCCESS": Color(0.627, 0.522, 0.251),
		"ACCENT_NEON": Color(0.910, 0.784, 0.294),
		"TEXT_PRIMARY": Color(0.957, 0.875, 0.773),
		"TEXT_SECONDARY": Color(0.702, 0.627, 0.549),
		"TEXT_MUTED": Color(0.502, 0.431, 0.373),
		"TEXT_ACCENT": Color(0.788, 0.659, 0.298),
		"TEXT_DANGER": Color(0.878, 0.251, 0.251),
		"TEXT_SUCCESS": Color(0.627, 0.522, 0.251),
		"TEXT_LINK": Color(0.788, 0.659, 0.298),
		"HP_FILL": Color(0.878, 0.251, 0.251),
		"HP_BG": Color(0.353, 0.110, 0.110),
		"MP_FILL": Color(0.788, 0.659, 0.298),
		"MP_BG": Color(0.322, 0.251, 0.110),
		"XP_FILL": Color(0.627, 0.522, 0.251),
		"XP_BG": Color(0.251, 0.204, 0.110),
		"RARITY_COMMON": Color(0.702, 0.627, 0.549),
		"RARITY_UNCOMMON": Color(0.627, 0.522, 0.251),
		"RARITY_RARE": Color(0.788, 0.659, 0.298),
		"RARITY_EPIC": Color(0.910, 0.784, 0.294),
		"RARITY_LEGENDARY": Color(0.878, 0.251, 0.251),
		"OVERLAY_DARK": Color(0.090, 0.040, 0.035, 0.85),
		"OVERLAY_LIGHT": Color(0.110, 0.055, 0.050, 0.60),
		"SELECTED_BG": Color(0.235, 0.149, 0.118),
		"SELECTED_TINT": Color(0.788, 0.659, 0.298),
		"GLOW_PRIMARY": Color(0.788, 0.659, 0.298),
		"GLOW_RIFT": Color(0.878, 0.251, 0.251),
		"MM_PLAYER": Color(0.400, 0.851, 1.000),
		"MM_DISCOVERED": Color(0.502, 0.400, 0.298),
		"MM_CURRENT": Color(1, 1, 1),
		"MM_RIFT": Color(0.788, 0.659, 0.298),
		"MM_RIFTSPIRE": Color(0.878, 0.502, 0.149),
		"MM_MOB_HOSTILE": Color(0.878, 0.400, 0.400),
		"MM_MOB_NEUTRAL": Color(0.702, 0.851, 0.702),
		"MM_GRID_LINE": Color(0.220, 0.180, 0.160, 0.5),
	}


static func _frost_data() -> Dictionary:
	return {
		"BG_DEEP": Color(0.055, 0.075, 0.125),
		"BG_SURFACE": Color(0.102, 0.118, 0.188),
		"BG_ELEVATED": Color(0.145, 0.165, 0.251),
		"BG_INPUT": Color(0.055, 0.075, 0.125),
		"BG_PANEL": Color(0.102, 0.118, 0.188),
		"BORDER_SUBTLE": Color(0.220, 0.235, 0.353),
		"BORDER_STRONG": Color(0.322, 0.357, 0.502),
		"BORDER_INPUT": Color(0.220, 0.235, 0.353),
		"ACCENT_PRIMARY": Color(0.420, 0.710, 0.847),
		"ACCENT_SECONDARY": Color(0.290, 0.722, 0.722),
		"ACCENT_DANGER": Color(0.753, 0.314, 0.314),
		"ACCENT_SUCCESS": Color(0.290, 0.722, 0.722),
		"ACCENT_NEON": Color(0.561, 0.831, 0.910),
		"TEXT_PRIMARY": Color(0.816, 0.847, 0.910),
		"TEXT_SECONDARY": Color(0.580, 0.620, 0.702),
		"TEXT_MUTED": Color(0.420, 0.451, 0.522),
		"TEXT_ACCENT": Color(0.420, 0.710, 0.847),
		"TEXT_DANGER": Color(0.753, 0.314, 0.314),
		"TEXT_SUCCESS": Color(0.290, 0.722, 0.722),
		"TEXT_LINK": Color(0.420, 0.710, 0.847),
		"HP_FILL": Color(0.753, 0.314, 0.314),
		"HP_BG": Color(0.290, 0.145, 0.145),
		"MP_FILL": Color(0.420, 0.710, 0.847),
		"MP_BG": Color(0.145, 0.290, 0.373),
		"XP_FILL": Color(0.290, 0.722, 0.722),
		"XP_BG": Color(0.118, 0.302, 0.302),
		"RARITY_COMMON": Color(0.580, 0.620, 0.702),
		"RARITY_UNCOMMON": Color(0.290, 0.722, 0.722),
		"RARITY_RARE": Color(0.420, 0.710, 0.847),
		"RARITY_EPIC": Color(0.561, 0.831, 0.910),
		"RARITY_LEGENDARY": Color(0.753, 0.314, 0.314),
		"OVERLAY_DARK": Color(0.040, 0.055, 0.100, 0.85),
		"OVERLAY_LIGHT": Color(0.055, 0.075, 0.125, 0.60),
		"SELECTED_BG": Color(0.145, 0.165, 0.251),
		"SELECTED_TINT": Color(0.420, 0.710, 0.847),
		"GLOW_PRIMARY": Color(0.420, 0.710, 0.847),
		"GLOW_RIFT": Color(0.753, 0.314, 0.314),
		"MM_PLAYER": Color(0.400, 0.851, 1.000),
		"MM_DISCOVERED": Color(0.451, 0.502, 0.549),
		"MM_CURRENT": Color(1, 1, 1),
		"MM_RIFT": Color(0.420, 0.710, 0.847),
		"MM_RIFTSPIRE": Color(0.561, 0.831, 0.910),
		"MM_MOB_HOSTILE": Color(1.000, 0.502, 0.400),
		"MM_MOB_NEUTRAL": Color(0.702, 0.851, 0.702),
		"MM_GRID_LINE": Color(0.180, 0.200, 0.240, 0.5),
	}


static func _viridian_data() -> Dictionary:
	return {
		"BG_DEEP": Color(0.055, 0.102, 0.082),
		"BG_SURFACE": Color(0.102, 0.180, 0.149),
		"BG_ELEVATED": Color(0.145, 0.251, 0.188),
		"BG_INPUT": Color(0.055, 0.102, 0.082),
		"BG_PANEL": Color(0.102, 0.180, 0.149),
		"BORDER_SUBTLE": Color(0.220, 0.322, 0.271),
		"BORDER_STRONG": Color(0.322, 0.471, 0.400),
		"BORDER_INPUT": Color(0.220, 0.322, 0.271),
		"ACCENT_PRIMARY": Color(0.314, 0.722, 0.478),
		"ACCENT_SECONDARY": Color(0.251, 0.627, 0.627),
		"ACCENT_DANGER": Color(0.753, 0.376, 0.314),
		"ACCENT_SUCCESS": Color(0.314, 0.722, 0.478),
		"ACCENT_NEON": Color(0.478, 0.831, 0.627),
		"TEXT_PRIMARY": Color(0.816, 0.910, 0.847),
		"TEXT_SECONDARY": Color(0.580, 0.702, 0.627),
		"TEXT_MUTED": Color(0.420, 0.522, 0.451),
		"TEXT_ACCENT": Color(0.314, 0.722, 0.478),
		"TEXT_DANGER": Color(0.753, 0.376, 0.314),
		"TEXT_SUCCESS": Color(0.314, 0.722, 0.478),
		"TEXT_LINK": Color(0.251, 0.627, 0.627),
		"HP_FILL": Color(0.753, 0.376, 0.314),
		"HP_BG": Color(0.290, 0.157, 0.133),
		"MP_FILL": Color(0.251, 0.627, 0.627),
		"MP_BG": Color(0.102, 0.290, 0.251),
		"XP_FILL": Color(0.314, 0.722, 0.478),
		"XP_BG": Color(0.118, 0.290, 0.188),
		"RARITY_COMMON": Color(0.580, 0.702, 0.627),
		"RARITY_UNCOMMON": Color(0.314, 0.722, 0.478),
		"RARITY_RARE": Color(0.251, 0.627, 0.627),
		"RARITY_EPIC": Color(0.478, 0.831, 0.627),
		"RARITY_LEGENDARY": Color(0.753, 0.376, 0.314),
		"OVERLAY_DARK": Color(0.040, 0.080, 0.060, 0.85),
		"OVERLAY_LIGHT": Color(0.055, 0.102, 0.082, 0.60),
		"SELECTED_BG": Color(0.145, 0.251, 0.188),
		"SELECTED_TINT": Color(0.314, 0.722, 0.478),
		"GLOW_PRIMARY": Color(0.314, 0.722, 0.478),
		"GLOW_RIFT": Color(0.251, 0.627, 0.627),
		"MM_PLAYER": Color(0.400, 0.851, 1.000),
		"MM_DISCOVERED": Color(0.373, 0.549, 0.463),
		"MM_CURRENT": Color(1, 1, 1),
		"MM_RIFT": Color(0.314, 0.722, 0.478),
		"MM_RIFTSPIRE": Color(0.478, 0.831, 0.627),
		"MM_MOB_HOSTILE": Color(1.000, 0.502, 0.400),
		"MM_MOB_NEUTRAL": Color(0.702, 0.851, 0.702),
		"MM_GRID_LINE": Color(0.180, 0.220, 0.200, 0.5),
	}


static func _nocturne_data() -> Dictionary:
	return {
		"BG_DEEP": Color(0.055, 0.055, 0.078),
		"BG_SURFACE": Color(0.102, 0.102, 0.141),
		"BG_ELEVATED": Color(0.157, 0.157, 0.204),
		"BG_INPUT": Color(0.055, 0.055, 0.078),
		"BG_PANEL": Color(0.102, 0.102, 0.141),
		"BORDER_SUBTLE": Color(0.235, 0.235, 0.290),
		"BORDER_STRONG": Color(0.353, 0.353, 0.439),
		"BORDER_INPUT": Color(0.235, 0.235, 0.290),
		"ACCENT_PRIMARY": Color(0.847, 0.376, 0.690),
		"ACCENT_SECONDARY": Color(0.314, 0.627, 0.910),
		"ACCENT_DANGER": Color(0.753, 0.251, 0.502),
		"ACCENT_SUCCESS": Color(0.314, 0.753, 0.753),
		"ACCENT_NEON": Color(0.910, 0.439, 0.753),
		"TEXT_PRIMARY": Color(0.910, 0.863, 0.875),
		"TEXT_SECONDARY": Color(0.651, 0.620, 0.651),
		"TEXT_MUTED": Color(0.475, 0.451, 0.475),
		"TEXT_ACCENT": Color(0.847, 0.376, 0.690),
		"TEXT_DANGER": Color(0.753, 0.251, 0.502),
		"TEXT_SUCCESS": Color(0.314, 0.753, 0.753),
		"TEXT_LINK": Color(0.314, 0.627, 0.910),
		"HP_FILL": Color(0.753, 0.251, 0.502),
		"HP_BG": Color(0.302, 0.102, 0.196),
		"MP_FILL": Color(0.314, 0.627, 0.910),
		"MP_BG": Color(0.118, 0.251, 0.373),
		"XP_FILL": Color(0.314, 0.753, 0.753),
		"XP_BG": Color(0.118, 0.302, 0.302),
		"RARITY_COMMON": Color(0.651, 0.620, 0.651),
		"RARITY_UNCOMMON": Color(0.314, 0.753, 0.753),
		"RARITY_RARE": Color(0.314, 0.627, 0.910),
		"RARITY_EPIC": Color(0.847, 0.376, 0.690),
		"RARITY_LEGENDARY": Color(0.910, 0.439, 0.753),
		"OVERLAY_DARK": Color(0.040, 0.040, 0.060, 0.85),
		"OVERLAY_LIGHT": Color(0.055, 0.055, 0.078, 0.60),
		"SELECTED_BG": Color(0.157, 0.157, 0.204),
		"SELECTED_TINT": Color(0.847, 0.376, 0.690),
		"GLOW_PRIMARY": Color(0.847, 0.376, 0.690),
		"GLOW_RIFT": Color(0.314, 0.627, 0.910),
		"MM_PLAYER": Color(0.400, 0.851, 1.000),
		"MM_DISCOVERED": Color(0.451, 0.424, 0.502),
		"MM_CURRENT": Color(1, 1, 1),
		"MM_RIFT": Color(0.847, 0.376, 0.690),
		"MM_RIFTSPIRE": Color(0.910, 0.439, 0.753),
		"MM_MOB_HOSTILE": Color(1.000, 0.502, 0.400),
		"MM_MOB_NEUTRAL": Color(0.702, 0.702, 0.851),
		"MM_GRID_LINE": Color(0.200, 0.200, 0.240, 0.5),
	}


static func _abyss_data() -> Dictionary:
	return {
		"BG_DEEP": Color(0.035, 0.035, 0.035),
		"BG_SURFACE": Color(0.071, 0.071, 0.071),
		"BG_ELEVATED": Color(0.110, 0.110, 0.110),
		"BG_INPUT": Color(0.035, 0.035, 0.035),
		"BG_PANEL": Color(0.071, 0.071, 0.071),
		"BORDER_SUBTLE": Color(0.180, 0.180, 0.180),
		"BORDER_STRONG": Color(0.290, 0.290, 0.290),
		"BORDER_INPUT": Color(0.180, 0.180, 0.180),
		"ACCENT_PRIMARY": Color(0.627, 0.565, 0.439),
		"ACCENT_SECONDARY": Color(0.376, 0.471, 0.565),
		"ACCENT_DANGER": Color(0.565, 0.314, 0.314),
		"ACCENT_SUCCESS": Color(0.376, 0.565, 0.439),
		"ACCENT_NEON": Color(0.627, 0.565, 0.439),
		"TEXT_PRIMARY": Color(0.627, 0.627, 0.627),
		"TEXT_SECONDARY": Color(0.439, 0.439, 0.439),
		"TEXT_MUTED": Color(0.290, 0.290, 0.290),
		"TEXT_ACCENT": Color(0.627, 0.565, 0.439),
		"TEXT_DANGER": Color(0.565, 0.314, 0.314),
		"TEXT_SUCCESS": Color(0.376, 0.565, 0.439),
		"TEXT_LINK": Color(0.376, 0.471, 0.565),
		"HP_FILL": Color(0.565, 0.314, 0.314),
		"HP_BG": Color(0.220, 0.125, 0.125),
		"MP_FILL": Color(0.376, 0.471, 0.565),
		"MP_BG": Color(0.125, 0.180, 0.220),
		"XP_FILL": Color(0.376, 0.565, 0.439),
		"XP_BG": Color(0.125, 0.220, 0.165),
		"RARITY_COMMON": Color(0.439, 0.439, 0.439),
		"RARITY_UNCOMMON": Color(0.376, 0.565, 0.439),
		"RARITY_RARE": Color(0.376, 0.471, 0.565),
		"RARITY_EPIC": Color(0.627, 0.565, 0.439),
		"RARITY_LEGENDARY": Color(0.565, 0.314, 0.314),
		"OVERLAY_DARK": Color(0.020, 0.020, 0.020, 0.85),
		"OVERLAY_LIGHT": Color(0.035, 0.035, 0.035, 0.60),
		"SELECTED_BG": Color(0.110, 0.110, 0.110),
		"SELECTED_TINT": Color(0.627, 0.565, 0.439),
		"GLOW_PRIMARY": Color(0.627, 0.565, 0.439),
		"GLOW_RIFT": Color(0.565, 0.314, 0.314),
		"MM_PLAYER": Color(0.400, 0.851, 1.000),
		"MM_DISCOVERED": Color(0.373, 0.373, 0.373),
		"MM_CURRENT": Color(1, 1, 1),
		"MM_RIFT": Color(0.627, 0.565, 0.439),
		"MM_RIFTSPIRE": Color(0.565, 0.565, 0.565),
		"MM_MOB_HOSTILE": Color(0.627, 0.400, 0.400),
		"MM_MOB_NEUTRAL": Color(0.502, 0.502, 0.502),
		"MM_GRID_LINE": Color(0.180, 0.180, 0.200, 0.4),
	}


static func _ochre_data() -> Dictionary:
	return {
		"BG_DEEP": Color(0.078, 0.078, 0.102),
		"BG_SURFACE": Color(0.118, 0.118, 0.149),
		"BG_ELEVATED": Color(0.165, 0.165, 0.196),
		"BG_INPUT": Color(0.078, 0.078, 0.102),
		"BG_PANEL": Color(0.118, 0.118, 0.149),
		"BORDER_SUBTLE": Color(0.235, 0.235, 0.290),
		"BORDER_STRONG": Color(0.400, 0.400, 0.471),
		"BORDER_INPUT": Color(0.235, 0.235, 0.290),
		"ACCENT_PRIMARY": Color(1.000, 0.690, 0.200),
		"ACCENT_SECONDARY": Color(0.290, 0.627, 0.878),
		"ACCENT_DANGER": Color(0.878, 0.502, 0.200),
		"ACCENT_SUCCESS": Color(0.290, 0.627, 0.878),
		"ACCENT_NEON": Color(1.000, 0.784, 0.400),
		"TEXT_PRIMARY": Color(0.910, 0.890, 0.839),
		"TEXT_SECONDARY": Color(0.682, 0.667, 0.624),
		"TEXT_MUTED": Color(0.518, 0.502, 0.463),
		"TEXT_ACCENT": Color(1.000, 0.690, 0.200),
		"TEXT_DANGER": Color(0.878, 0.502, 0.200),
		"TEXT_SUCCESS": Color(0.290, 0.627, 0.878),
		"TEXT_LINK": Color(0.290, 0.627, 0.878),
		"HP_FILL": Color(0.878, 0.502, 0.200),
		"HP_BG": Color(0.353, 0.200, 0.090),
		"MP_FILL": Color(0.290, 0.627, 0.878),
		"MP_BG": Color(0.110, 0.251, 0.373),
		"XP_FILL": Color(0.627, 0.627, 0.627),
		"XP_BG": Color(0.220, 0.220, 0.251),
		"RARITY_COMMON": Color(0.682, 0.667, 0.624),
		"RARITY_UNCOMMON": Color(0.290, 0.627, 0.878),
		"RARITY_RARE": Color(1.000, 0.690, 0.200),
		"RARITY_EPIC": Color(1.000, 0.784, 0.400),
		"RARITY_LEGENDARY": Color(0.878, 0.502, 0.200),
		"OVERLAY_DARK": Color(0.060, 0.060, 0.080, 0.85),
		"OVERLAY_LIGHT": Color(0.078, 0.078, 0.102, 0.60),
		"SELECTED_BG": Color(0.165, 0.165, 0.196),
		"SELECTED_TINT": Color(1.000, 0.690, 0.200),
		"GLOW_PRIMARY": Color(1.000, 0.690, 0.200),
		"GLOW_RIFT": Color(0.290, 0.627, 0.878),
		"MM_PLAYER": Color(0.502, 0.878, 1.000),
		"MM_DISCOVERED": Color(0.451, 0.451, 0.502),
		"MM_CURRENT": Color(1, 1, 1),
		"MM_RIFT": Color(1.000, 0.690, 0.200),
		"MM_RIFTSPIRE": Color(1.000, 0.502, 0.149),
		"MM_MOB_HOSTILE": Color(0.878, 0.502, 0.200),
		"MM_MOB_NEUTRAL": Color(0.702, 0.702, 0.702),
		"MM_GRID_LINE": Color(0.200, 0.200, 0.240, 0.5),
	}


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _save_theme_setting(name: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("general", "theme", name)
	cfg.save(SETTINGS_PATH)


func _load_saved_theme() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	return cfg.get_value("general", "theme", "")
