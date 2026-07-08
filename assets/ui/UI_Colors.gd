## UI_Colors — Design system color tokens for Fallen Earth.
##
## Central source of truth for every color in the UI.
## Import via `class_name UI_Colors` (global) or `preload`.
class_name UI_Colors
extends RefCounted

# ---------------------------------------------------------------------------
# Backgrounds
# ---------------------------------------------------------------------------
const BG_DEEP       := Color(0.04, 0.04, 0.07)  # #0A0A12 — main panels, overlays
const BG_SURFACE    := Color(0.07, 0.07, 0.11)  # #12121C — cards, containers
const BG_ELEVATED   := Color(0.10, 0.10, 0.16)  # #1A1A28 — hovered, active
const BG_INPUT      := Color(0.04, 0.04, 0.07)  # #0A0A12 — text fields

# ---------------------------------------------------------------------------
# Borders
# ---------------------------------------------------------------------------
const BORDER_SUBTLE := Color(0.16, 0.16, 0.24)  # #2A2A3C — default borders
const BORDER_STRONG := Color(0.29, 0.29, 0.42)  # #4A4A6A — focus, active
const BORDER_INPUT  := Color(0.16, 0.16, 0.24)  # #2A2A3C — text field border

# ---------------------------------------------------------------------------
# Accents
# ---------------------------------------------------------------------------
const ACCENT_PRIMARY   := Color(0.83, 0.53, 0.29)  # #D4884A — rusted gold
const ACCENT_SECONDARY := Color(0.35, 0.56, 0.69)  # #5A8FB0 — faded steel
const ACCENT_DANGER    := Color(0.77, 0.25, 0.25)  # #C44040 — blood rust
const ACCENT_SUCCESS   := Color(0.29, 0.55, 0.36)  # #4A8C5C — toxic green
const ACCENT_NEON      := Color(0.42, 0.35, 0.80)  # #6A5ACD — muted purple

# ---------------------------------------------------------------------------
# Text
# ---------------------------------------------------------------------------
const TEXT_PRIMARY     := Color(0.91, 0.91, 0.93)  # #E8E8EE
const TEXT_SECONDARY   := Color(0.60, 0.60, 0.69)  # #9A9AB0
const TEXT_MUTED       := Color(0.42, 0.42, 0.50)  # #6A6A80
const TEXT_ACCENT      := Color(0.83, 0.53, 0.29)  # #D4884A
const TEXT_DANGER      := Color(0.77, 0.25, 0.25)  # #C44040
const TEXT_SUCCESS     := Color(0.29, 0.55, 0.36)  # #4A8C5C
const TEXT_LINK        := Color(0.35, 0.56, 0.69)  # #5A8FB0

# ---------------------------------------------------------------------------
# Bars
# ---------------------------------------------------------------------------
const HP_FILL    := Color(0.77, 0.25, 0.25)  # #C44040
const HP_BG      := Color(0.33, 0.16, 0.16)  # #542828
const MP_FILL    := Color(0.29, 0.42, 0.60)  # #4A6A9A
const MP_BG      := Color(0.16, 0.23, 0.35)  # #2A3A5A
const XP_FILL    := Color(0.29, 0.55, 0.36)  # #4A8C5C
const XP_BG      := Color(0.16, 0.29, 0.20)  # #2A4A34

# ---------------------------------------------------------------------------
# Rarity borders
# ---------------------------------------------------------------------------
const RARITY_COMMON    := Color(0.60, 0.60, 0.69)  # #9A9AB0
const RARITY_UNCOMMON  := Color(0.29, 0.55, 0.36)  # #4A8C5C
const RARITY_RARE      := Color(0.35, 0.56, 0.69)  # #5A8FB0
const RARITY_EPIC      := Color(0.42, 0.35, 0.80)  # #6A5ACD
const RARITY_LEGENDARY := Color(0.83, 0.53, 0.29)  # #D4884A

# ---------------------------------------------------------------------------
# Overlays
# ---------------------------------------------------------------------------
const OVERLAY_DARK  := Color(0.02, 0.02, 0.03, 0.85)
const OVERLAY_LIGHT := Color(0.04, 0.04, 0.07, 0.60)

# ---------------------------------------------------------------------------
# Glows
# ---------------------------------------------------------------------------
const GLOW_PRIMARY := Color(0.83, 0.53, 0.29)  # #D4884A
const GLOW_RIFT    := Color(0.42, 0.35, 0.80)  # #6A5ACD

# ---------------------------------------------------------------------------
# Minimap
# ---------------------------------------------------------------------------
const MM_PLAYER      := Color(0.40, 0.85, 1.00)  # #66D9FF
const MM_DISCOVERED  := Color(0.45, 0.50, 0.42)  # #73806A
const MM_CURRENT     := Color(1, 1, 1)
const MM_RIFT        := Color(1.00, 0.85, 0.20)  # #FFD930
const MM_RIFTSPIRE   := Color(1.00, 0.50, 0.15)  # #FF8026
const MM_MOB_HOSTILE := Color(1.00, 0.50, 0.40)  # #FF8066
const MM_MOB_NEUTRAL := Color(0.70, 0.85, 0.70)  # #B3D9B3
const MM_GRID_LINE   := Color(0.20, 0.20, 0.22, 0.5)

# ---------------------------------------------------------------------------
# Button style data
# ---------------------------------------------------------------------------
## Populate a StyleBoxFlat for a button variant.
## Pass the variant key ("primary", "secondary", "danger", "success", "ghost").
static func button_style(variant: String) -> Dictionary:
	match variant:
		"primary":
			return {bg = Color(0.12, 0.09, 0.19), border = ACCENT_PRIMARY, text = TEXT_PRIMARY}
		"secondary":
			return {bg = Color(0.10, 0.10, 0.16), border = ACCENT_SECONDARY, text = Color(0.69, 0.75, 0.88)}
		"danger":
			return {bg = Color(0.24, 0.09, 0.09), border = ACCENT_DANGER, text = Color(1.0, 0.80, 0.80)}
		"success":
			return {bg = Color(0.10, 0.18, 0.12), border = ACCENT_SUCCESS, text = Color(0.80, 1.0, 0.80)}
		"ghost":
			return {bg = Color.TRANSPARENT, border = Color.TRANSPARENT, text = TEXT_SECONDARY}
		_:
			return {bg = Color(0.12, 0.09, 0.19), border = ACCENT_PRIMARY, text = TEXT_PRIMARY}

# ---------------------------------------------------------------------------
# Font size tokens
# ---------------------------------------------------------------------------
const FS_HERO  := 42
const FS_H1    := 28
const FS_H2    := 22
const FS_H3    := 18
const FS_BODY  := 14
const FS_SMALL := 12
const FS_TINY  := 10
const FS_STAT  := 16
const FS_BUTTON := 16

# ---------------------------------------------------------------------------
# Spacing tokens
# ---------------------------------------------------------------------------
const SPACE_XS   := 4
const SPACE_SM   := 8
const SPACE_MD   := 12
const SPACE_LG   := 16
const SPACE_XL   := 24
const SPACE_2XL  := 32
const SPACE_3XL  := 48

# ---------------------------------------------------------------------------
# Corner radius & border width
# ---------------------------------------------------------------------------
const RADIUS_SM  := 2
const RADIUS_MD  := 4
const RADIUS_LG  := 6
const RADIUS_XL  := 8
const BORDER_WIDTH := 2
const BORDER_WIDTH_THIN := 1
