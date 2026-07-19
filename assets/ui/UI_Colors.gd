## UI_Colors — Delegates to MasterTheme. Kept for backward compatibility.
class_name UI_Colors
extends RefCounted

const MT := preload("res://assets/ui/MasterTheme.gd")

const BG_DEEP       := MT.BG_DEEP
const BG_SURFACE    := MT.BG_SURFACE
const BG_ELEVATED   := MT.BG_ELEVATED
const BG_INPUT      := MT.BG_INPUT

const BORDER_SUBTLE := MT.BORDER_SUBTLE
const BORDER_STRONG := MT.BORDER_STRONG
const BORDER_INPUT  := MT.BORDER_INPUT

const ACCENT_PRIMARY   := MT.ACCENT_PRIMARY
const ACCENT_SECONDARY := MT.ACCENT_SECONDARY
const ACCENT_DANGER    := MT.ACCENT_DANGER
const ACCENT_SUCCESS   := MT.ACCENT_SUCCESS
const ACCENT_NEON      := MT.ACCENT_NEON

const TEXT_PRIMARY     := MT.TEXT_PRIMARY
const TEXT_SECONDARY   := MT.TEXT_SECONDARY
const TEXT_MUTED       := MT.TEXT_MUTED
const TEXT_ACCENT      := MT.TEXT_ACCENT
const TEXT_DANGER      := MT.TEXT_DANGER
const TEXT_SUCCESS     := MT.TEXT_SUCCESS
const TEXT_LINK        := MT.TEXT_LINK

const HP_FILL    := MT.HP_FILL
const HP_BG      := MT.HP_BG
const MP_FILL    := MT.MP_FILL
const MP_BG      := MT.MP_BG
const XP_FILL    := MT.XP_FILL
const XP_BG      := MT.XP_BG

const RARITY_COMMON    := MT.RARITY_COMMON
const RARITY_UNCOMMON  := MT.RARITY_UNCOMMON
const RARITY_RARE      := MT.RARITY_RARE
const RARITY_EPIC      := MT.RARITY_EPIC
const RARITY_LEGENDARY := MT.RARITY_LEGENDARY

const OVERLAY_DARK  := MT.OVERLAY_DARK
const OVERLAY_LIGHT := MT.OVERLAY_LIGHT

const GLOW_PRIMARY := MT.GLOW_PRIMARY
const GLOW_RIFT    := MT.GLOW_RIFT

const MM_PLAYER      := MT.MM_PLAYER
const MM_DISCOVERED  := MT.MM_DISCOVERED
const MM_CURRENT     := MT.MM_CURRENT
const MM_RIFT        := MT.MM_RIFT
const MM_RIFTSPIRE   := MT.MM_RIFTSPIRE
const MM_MOB_HOSTILE := MT.MM_MOB_HOSTILE
const MM_MOB_NEUTRAL := MT.MM_MOB_NEUTRAL
const MM_GRID_LINE   := MT.MM_GRID_LINE

const FS_HERO  := MT.FS_HERO
const FS_H1    := MT.FS_H1
const FS_H2    := MT.FS_H2
const FS_H3    := MT.FS_H3
const FS_BODY  := MT.FS_BODY
const FS_SMALL := MT.FS_SMALL
const FS_TINY  := MT.FS_TINY
const FS_STAT  := MT.FS_STAT
const FS_BUTTON := MT.FS_BUTTON

const SPACE_XS  := MT.SPACE_XS
const SPACE_SM  := MT.SPACE_SM
const SPACE_MD  := MT.SPACE_MD
const SPACE_LG  := MT.SPACE_LG
const SPACE_XL  := MT.SPACE_XL
const SPACE_2XL := MT.SPACE_2XL
const SPACE_3XL := MT.SPACE_3XL

const RADIUS_SM := MT.RADIUS_SM
const RADIUS_MD := MT.RADIUS_MD
const RADIUS_LG := MT.RADIUS_LG
const RADIUS_XL := MT.RADIUS_XL

const BORDER_WIDTH      := MT.BORDER_WIDTH
const BORDER_WIDTH_THIN := MT.BORDER_WIDTH_THIN

static func button_style(variant: String) -> Dictionary:
	return MT._button_style_data(variant)
