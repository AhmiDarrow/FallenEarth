class_name SpriteLoader
extends RefCounted

static func load_texture(res_path: String) -> Texture2D:
	var tex := load(res_path) as Texture2D
	if tex != null:
		return tex
	var img := Image.new()
	if img.load(res_path) == OK:
		return ImageTexture.create_from_image(img)
	return null
