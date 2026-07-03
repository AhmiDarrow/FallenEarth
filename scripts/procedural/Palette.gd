## Palette — Core color constants for all procedural drawing.
## Autoload singleton — referenced from ProceduralRenderer and all generated assets.

extends Node

const COLORS = {
	"ground_ash": Color("#5C4033"),
	"ground_rust": Color("#8B5A2B"),
	"toxic": Color("#00FF9F"),
	"skin": Color("#F4C38E"),
	"rags": Color("#4A3F35"),
	"accent": Color("#FF4500"),
	"shadow": Color("#1A1A1A"),
	"highlight": Color("#E8D4B8"),
	"blood": Color("#752828"),
	"mana": Color("#3388FF"),
	"stone": Color("#7A7A7A"),
	"metal": Color("#555555"),
	"wood": Color("#6B4E35"),
	"leaf": Color("#4A7A4A"),
	"cloud": Color("#EEEEEE"),
	"rune": Color("#B855FF"),
}

func get_color(key: String) -> Color:
	return COLORS.get(key, Color.WHITE)
