class_name HudKit
extends RefCounted

# ENGINE CORE — small HUD building blocks: styled panels, labels,
# an HP bar, and the text formats (wanted stars, combo readout)
# that every game on this engine ends up rebuilding. Widgets are
# configured by argument; a game's theme (colors, positions) stays
# in the game layer, passed in.
#
# Written for the Engine Core gate (step 8) from the HUD code that
# lived in gate3d_main.gd (_build_hud / refresh_hud).

static func panel_style(bg: Color, radius: int = 4, margin: float = -1.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if margin >= 0.0:
		s.set_content_margin_all(margin)
	return s

static func make_label(text: String, pos: Vector2, font_size: int, color: Color = Color(1, 1, 1, 1)) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.text = text
	return l

static func make_hp_bar(pos: Vector2, bar_size: Vector2, max_value: float, value: float, bg: StyleBox, fill: StyleBox) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.custom_minimum_size = bar_size
	bar.size = bar_size
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

# "★★★☆☆☆" — filled stars first, total slots fixed.
static func stars_text(filled: int, total: int = 6) -> String:
	var t := ""
	for i in range(total):
		t += "★" if i < filled else "☆"
	return t

# Combo readout; empty below 2 (a single hit is not a combo).
static func combo_text(count: int, mult: float) -> String:
	if count > 1:
		return "COMBO x%.1f (%d)" % [mult, count]
	return ""
