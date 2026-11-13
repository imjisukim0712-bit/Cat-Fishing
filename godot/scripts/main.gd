extends Control
## 까미와 밤낚시 — 화면 구성(HUD, 무대 틀, 말풍선, 상태줄, 축하 연출, 모달)
## 원본 HTML/CSS 레이아웃을 Godot Control 로 옮김. 게임 규칙은 Game 오토로드에 있다.

const STAGE_POS := Vector2(20, 62)
const STAGE_SIZE := Vector2(960, 540)

# ---- 색 (원본 CSS 변수) ----
const BG := Color("#0c1027")
const PANEL := Color("#202244e8")
const PANEL2 := Color("#30315be8")
const LINE := Color("#8178ba")
const GOLD := Color("#ffc24a")
const TEXT := Color("#e8edfb")
const DIM := Color("#aaaed1")

var stage_frame: Panel
var overlay: Control          # 무대 위 UI 레이어 (말풍선, 떠오르는 글자, 축하)
var status_box: PanelContainer
var status_label: RichTextLabel
var status_tween: Tween
var bubble: PanelContainer
var bubble_text: RichTextLabel
var bubble_tween: Tween
var bubble_timer: SceneTreeTimer

var coin_label: RichTextLabel
var aff_label: RichTextLabel
var weather_chip: PanelContainer
var weather_label: RichTextLabel
var creel_badge: Label
var sound_btn: Button

var celebrate: Control
var modal_layer: Control
var modal_id := ""
var result_timer: SceneTreeTimer

# ================================================================= 스타일 헬퍼
static func sb(bg: Color, border := Color(0, 0, 0, 0), radius := 12, bw := 1, pad := Vector4(10, 6, 10, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x; s.content_margin_top = pad.y
	s.content_margin_right = pad.z; s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	if bg.a > .5 and border.a > 0:
		s.border_color = border.lightened(.08)
		s.shadow_color = Color(border, .13)
		s.shadow_size = 5
		s.border_width_top = maxi(1, bw)

	return s

# Visual-only sheen; it follows the existing Control size and never takes input.
func glass_sheen(control: Control, radius: float) -> void:
	control.draw.connect(func():
		var w := control.size.x
		var h := control.size.y
		if w < 8 or h < 8: return
		var r := minf(radius, minf(w, h) * .5)
		var depth := minf(16, h * .44)
		var points := PackedVector2Array([Vector2(r, 2), Vector2(w - r, 2), Vector2(w - 3, depth), Vector2(3, depth)])
		control.draw_polygon(points, PackedColorArray([Color("#d5ceff24"), Color("#d5ceff24"), Color("#d5ceff00"), Color("#d5ceff00")]))
		control.draw_line(Vector2(r, 2), Vector2(w - r, 2), Color("#eee9ff88"), 1, true)
	)
	control.resized.connect(control.queue_redraw)

func lbl(txt: String, size := 13, col := TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font if font else Data.font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func wrap_lbl(txt: String, width: float, size := 13, col := TEXT, font: Font = null) -> Label:
	var l := lbl(txt, size, col, font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l

func rich(size := 13, col := TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", Data.font_bold)
	r.add_theme_font_override("bold_font", Data.font_heavy)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", col)
	return r

## 이모지가 섞인 글자를 그림 아이콘으로 바꿔 보여주는 리치 텍스트
func etext(txt: String, size := 13, col := TEXT, font: Font = null, center := false) -> RichTextLabel:
	var r := rich(size, col)
	if font: r.add_theme_font_override("normal_font", font)
	r.text = ("[center]%s[/center]" if center else "%s") % Data.emoji_bb(txt, int(size * 1.35))
	return r

func icon_rect(name: String, px: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Data.icon(name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## 버튼 글자 앞의 이모지는 그림 아이콘으로 (예: "🪙 55" → 동전 그림 + "55")
func set_btn(b: Button, txt: String) -> void:
	var parts := Data.split_icon(txt)
	b.icon = Data.icon(parts[0]) if parts[0] != "" else null
	b.text = parts[1]
	var fs := b.get_theme_font_size("font_size")
	b.add_theme_constant_override("icon_max_width", int(fs * 1.5))
	b.expand_icon = false

## 원본 .mini / .btn 버튼
func btn(txt: String, kind := "mini", cb := Callable(), disabled := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bg := Color("#202343e8"); var bd := LINE; var fg := TEXT; var hover := Color("#22305a")
	var radius := 9; var pad := Vector4(10, 6, 10, 6); var size := 12
	match kind:
		"hud":
			bg = PANEL; hover = PANEL2; radius = 999; pad = Vector4(13, 7, 13, 7); size = 13
		"hud_gold":
			bg = Color("#45324be8"); bd = Color("#d3aa57"); fg = GOLD; hover = Color("#4a3a10"); radius = 999; pad = Vector4(13, 7, 13, 7); size = 13
		"buy":
			bg = Color("#2b3f1a"); bd = Color("#4d7226"); fg = Color("#c8f08a"); hover = Color("#365024")
		"sell":
			bg = Color("#45324be8"); bd = Color("#d3aa57"); fg = GOLD; hover = Color("#4a3a10")
		"feed":
			bg = Color("#3a1524"); bd = Color("#7a2a45"); fg = Color("#ffb1c8"); hover = Color("#4a1d30")
		"big_mini":
			radius = 12; pad = Vector4(8, 12, 8, 12); size = 14
		"x":
			bg = Color(0, 0, 0, 0); bd = Color(0, 0, 0, 0); fg = DIM; hover = Color(0, 0, 0, 0); pad = Vector4(4, 0, 4, 0); size = 24
	b.add_theme_stylebox_override("normal", sb(bg, bd, radius, 1, pad))
	b.add_theme_stylebox_override("hover", sb(hover, bd.lightened(0.15) if bd.a > 0 else bd, radius, 1, pad))
	b.add_theme_stylebox_override("pressed", sb(hover.darkened(0.1), bd, radius, 1, pad))
	b.add_theme_stylebox_override("disabled", sb(Color("#181d2c"), Color("#28304a"), radius, 1, pad))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", Data.font_heavy)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", Color.WHITE if kind == "x" else fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color("#4d566f"))
	if cb.is_valid(): b.pressed.connect(cb)
	if kind != "x": glass_sheen(b, radius)
	set_btn(b, txt)
	return b

func chip(content: Control, bg := PANEL, border := LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, border, 999, 1, Vector4(13, 7, 13, 7)))
	p.add_child(content)
	glass_sheen(p, 999)
	return p

func tag(txt: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(Color(0, 0, 0, 0), col, 99, 1, Vector4(7, 1, 7, 2)))
	p.add_child(lbl(txt, 10, col, Data.font_heavy))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func fish_art(id: String, sz: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Data.fish_texture(id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = sz
	tr.pivot_offset = sz / 2.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# ================================================================= 빌드
func _ready() -> void:
	var th := Theme.new()
	th.default_font = Data.font_bold
	th.default_font_size = 13
	theme = th

	_build_background()
	_build_hud()
	_build_stage()
	_build_footer()
	_build_modal_layer()

	Game.status_changed.connect(_on_status)
	Game.cat_said.connect(_on_cat_said)
	Game.popped.connect(_on_pop)
	Game.hud_changed.connect(refresh_hud)
	Game.weather_changed.connect(_refresh_weather)
	Game.result_ready.connect(_on_result_ready)
	Game.celebrate_started.connect(_on_celebrate)
	Game.celebrate_ended.connect(func(): celebrate.visible = false)
	Game.state_reset.connect(func(): close_modals())
	refresh_hud()
	_refresh_weather()
	_on_status(Game.STATUS_IDLE, false)

	# 개발용 스크린샷 투어: godot -- --shots=DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			var shots: Node = load("res://tools/autoshot.gd").new()
			shots.dir = a.trim_prefix("--shots=")
			shots.main = self
			add_child(shots)
		elif a == "--selftest":
			var st: Node = load("res://tools/selftest.gd").new()
			st.main = self
			add_child(st)

func _build_background() -> void:
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color("#17224a")); g.set_color(1, BG)
	g.set_offset(1, 0.6)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, -0.1)
	gt.fill_to = Vector2(1.25, 0.9)
	gt.width = 256; gt.height = 256
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _build_hud() -> void:
	var hud := HBoxContainer.new()
	hud.position = Vector2(20, 12)
	hud.size = Vector2(960, 40)
	hud.add_theme_constant_override("separation", 8)
	add_child(hud)

	var brand := HBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_constant_override("separation", 7)
	brand.add_child(icon_rect("kkami_head", 26))
	brand.add_child(lbl("까미와 밤낚시", 17, TEXT, Data.font_heavy))
	var small := lbl("Kkami's Midnight Fishing", 11, DIM)
	small.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(small)
	hud.add_child(brand)

	coin_label = etext("🪙 0", 13, GOLD, Data.font_heavy)
	hud.add_child(chip(coin_label, PANEL, LINE))
	aff_label = etext("💗 ♡♡♡♡♡ 0%", 13, TEXT, Data.font_heavy)
	hud.add_child(chip(aff_label))
	weather_label = etext("🌙 맑음", 13, TEXT, Data.font_heavy)
	weather_chip = chip(weather_label)
	weather_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	hud.add_child(weather_chip)

	var creel_btn := btn("🧺 어망", "hud", func(): open_creel())
	for k in ["normal", "hover", "pressed", "disabled"]:
		var st := (creel_btn.get_theme_stylebox(k) as StyleBoxFlat).duplicate() as StyleBoxFlat
		st.content_margin_right = 44
		creel_btn.add_theme_stylebox_override(k, st)
	creel_badge = lbl("0", 10, Color.WHITE, Data.font_heavy)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", sb(Color("#e0454f"), Color(0, 0, 0, 0), 999, 0, Vector4(6, 1, 6, 1)))
	badge.add_child(creel_badge)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	creel_btn.add_child(badge)
	creel_btn.resized.connect(func():
		badge.reset_size()
		badge.position = Vector2(creel_btn.size.x - 14 - badge.size.x, (creel_btn.size.y - badge.size.y) / 2.0))
	hud.add_child(creel_btn)

	hud.add_child(btn("🛒 상점", "hud_gold", func(): open_shop()))
	hud.add_child(btn("📖 도감", "hud", func(): open_dex()))
	sound_btn = btn("🔊", "hud", func(): Game.toggle_sound())
	hud.add_child(sound_btn)

func _build_stage() -> void:
	var shadow := Panel.new()
	shadow.position = STAGE_POS
	shadow.size = STAGE_SIZE
	var ss := sb(Color("#050914"), Color(0, 0, 0, 0), 18, 0, Vector4.ZERO)
	ss.shadow_color = Color(0, 0, 0, .6); ss.shadow_size = 30; ss.shadow_offset = Vector2(0, 18)
	shadow.add_theme_stylebox_override("panel", ss)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shadow)

	stage_frame = Panel.new()
	stage_frame.position = STAGE_POS
	stage_frame.size = STAGE_SIZE
	stage_frame.add_theme_stylebox_override("panel", sb(Color("#050914"), Color(0, 0, 0, 0), 18, 0, Vector4.ZERO))
	stage_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	stage_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stage_frame.gui_input.connect(_on_stage_input)
	add_child(stage_frame)

	var stage := Node2D.new()
	stage.set_script(load("res://scripts/stage.gd"))
	stage_frame.add_child(stage)

	# 테두리선은 클립 영역 위에 따로 그림
	var border := Panel.new()
	border.position = STAGE_POS
	border.size = STAGE_SIZE
	border.add_theme_stylebox_override("panel", sb(Color(0, 0, 0, 0), LINE, 18, 1, Vector4.ZERO))
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	overlay = Control.new()
	overlay.size = STAGE_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_frame.add_child(overlay)

	# 말풍선
	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", sb(Color("#272951de"), Color("#bfb1ff"), 16, 1, Vector4(15, 12, 15, 12)))
	glass_sheen(bubble, 16)
	bubble.position = Vector2(STAGE_SIZE.x * 0.21, STAGE_SIZE.y * 0.06)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 3)
	bv.add_child(lbl("까미  ✦", 11, Color("#ffb6df"), Data.font_heavy))
	bubble_text = rich(14, TEXT)
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_text.custom_minimum_size.x = 200
	bubble_text.add_theme_constant_override("line_separation", 4)
	bv.add_child(bubble_text)
	bubble.add_child(bv)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(26, 0), Vector2(48, 0), Vector2(37, 11)])
	tail.color = Color("#272951de")
	var tail_border := Line2D.new()
	tail_border.points = PackedVector2Array([Vector2(26, 0), Vector2(37, 11), Vector2(48, 0)])
	tail_border.width = 1
	tail_border.default_color = Color("#bfb1ff")
	tail_border.antialiased = true
	tail.add_child(tail_border)
	bubble.add_child(tail)
	bubble.resized.connect(func(): tail.position = Vector2(0, bubble.size.y - 0.5))
	bubble.modulate.a = 0.0
	overlay.add_child(bubble)

	# 축하 연출
	celebrate = Control.new()
	celebrate.size = STAGE_SIZE
	celebrate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celebrate.visible = false
	overlay.add_child(celebrate)

	# 상태줄 (무대 하단에 겹침)
	var cc := CenterContainer.new()
	cc.position = Vector2(STAGE_POS.x, STAGE_POS.y + STAGE_SIZE.y - 56)
	cc.size = Vector2(STAGE_SIZE.x, 46)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	status_box = PanelContainer.new()
	glass_sheen(status_box, 999)
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label = rich(14)
	status_box.add_child(status_label)
	cc.add_child(status_box)
	status_box.resized.connect(func(): status_box.pivot_offset = status_box.size / 2.0)

func _build_footer() -> void:
	var keys := rich(11, DIM)
	keys.add_theme_color_override("default_color", DIM)
	keys.add_theme_font_override("normal_font", Data.font_regular)
	keys.text = "[center]" + Data.emoji_bb("🎣", 15) + " [color=#e8edfb][b]스페이스[/b][/color] / [color=#e8edfb][b]클릭[/b][/color] = 던지기 · 챔질 · 릴 감기  ·  잡은 물고기는 팔거나 [color=#e8edfb][b]까미에게[/b][/color] 주세요[/center]"
	keys.position = Vector2(20, STAGE_POS.y + STAGE_SIZE.y + 9)
	keys.size = Vector2(960, 18)
	add_child(keys)
	var credit := lbl("제작자: 김지수 (imjisukim0712@gmail.com)", 10, Color("#3a4468"), Data.font_regular)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.position = Vector2(20, STAGE_POS.y + STAGE_SIZE.y + 30)
	credit.size = Vector2(960, 14)
	add_child(credit)

func _build_modal_layer() -> void:
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)

# ================================================================= HUD
func refresh_hud() -> void:
	coin_label.text = Data.emoji_bb("🪙 " + Data.comma(Game.S.coins), 18)
	creel_badge.text = str(Game.S.creel.size())
	var pct := Game.aff_pct()
	var hearts := mini(5, pct / 20)
	aff_label.text = Data.emoji_bb("💗 " + "♥".repeat(hearts) + "♡".repeat(5 - hearts) + " %d%%" % pct, 18)
	set_btn(sound_btn, "🔊" if Game.S.sound else "🔇")
	# 열려 있는 모달 내용 갱신
	match modal_id:
		"creel": _fill_creel()
		"shop": _fill_shop()

func _refresh_weather() -> void:
	var w: Dictionary = Data.WEATHER_BY_KEY[Game.weather.key]
	weather_label.text = Data.emoji_bb("%s %s" % [w.e, w.name], 18)
	weather_chip.tooltip_text = ("이 날씨에서만 %s을(를) 낚을 수 있어요" % Data.FISH_BY_ID[w.fish].n) if w.has("fish") else "평범한 밤"

# ================================================================= 상태줄 / 말풍선 / 글자
func _on_status(bb: String, hot: bool) -> void:
	status_label.text = bb
	if hot:
		status_box.add_theme_stylebox_override("panel", sb(Color(80 / 255.0, 10 / 255.0, 16 / 255.0, .85), Color("#e0454f"), 999, 1, Vector4(18, 8, 18, 8)))
	else:
		status_box.add_theme_stylebox_override("panel", sb(Color("#232c55e8"), Color("#a6baff"), 999, 1, Vector4(18, 8, 18, 8)))
	if status_tween: status_tween.kill()
	status_box.scale = Vector2.ONE
	if hot:
		status_tween = create_tween().set_loops()
		status_tween.tween_property(status_box, "scale", Vector2(1.06, 1.06), 0.35)
		status_tween.tween_property(status_box, "scale", Vector2.ONE, 0.35)

func _on_cat_said(txt: String, sec: float) -> void:
	bubble_text.text = Data.emoji_bb(txt, 18)
	var max_w := STAGE_SIZE.x * 0.46 - 30
	var tw := Data.font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	bubble_text.custom_minimum_size.x = minf(max_w, tw + 2)
	bubble.size = Vector2.ZERO
	bubble.reset_size()
	_fix_bubble_size.call_deferred()
	if bubble_tween: bubble_tween.kill()
	bubble.pivot_offset = Vector2(0, 40)
	bubble.scale = Vector2(.94, .94)
	bubble.position.y = STAGE_SIZE.y * 0.06 + 8
	bubble_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bubble_tween.tween_property(bubble, "modulate:a", 1.0, 0.25)
	bubble_tween.tween_property(bubble, "scale", Vector2.ONE, 0.25)
	bubble_tween.tween_property(bubble, "position:y", STAGE_SIZE.y * 0.06, 0.25)
	var my_timer := get_tree().create_timer(sec)
	bubble_timer = my_timer
	my_timer.timeout.connect(func():
		if bubble_timer != my_timer: return
		var t := create_tween()
		t.tween_property(bubble, "modulate:a", 0.0, 0.25))

func _fix_bubble_size() -> void:
	await get_tree().process_frame
	bubble.size = Vector2.ZERO
	bubble.reset_size()

func _on_pop(txt: String, x_pct: float, y_pct: float, col: Color) -> void:
	# 맨 앞 이모지는 그림 아이콘으로 (예: "🪙 +12" → 동전 그림 + "+12")
	var parts := Data.split_icon(txt)
	var l := HBoxContainer.new()
	l.add_theme_constant_override("separation", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parts[0] != "": l.add_child(icon_rect(parts[0], 26))
	var tl := lbl(parts[1], 20, col, Data.font_heavy)
	tl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .8))
	tl.add_theme_constant_override("shadow_offset_y", 2)
	tl.add_theme_constant_override("shadow_outline_size", 6)
	l.add_child(tl)
	overlay.add_child(l)
	l.reset_size()
	var base := Vector2(x_pct / 100.0 * STAGE_SIZE.x - l.size.x / 2.0, y_pct / 100.0 * STAGE_SIZE.y)
	l.position = base
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(.6, .6)
	l.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel()
	t.tween_property(l, "modulate:a", 1.0, 0.22)
	t.tween_property(l, "scale", Vector2(1.15, 1.15), 0.22)
	t.tween_property(l, "position:y", base.y - 14, 0.22)
	t.chain().set_parallel()
	t.tween_property(l, "modulate:a", 0.0, 0.88).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector2.ONE, 0.88)
	t.tween_property(l, "position:y", base.y - 52, 0.88).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(l.queue_free)

# ================================================================= 축하 연출
class Rays extends Control:
	var kind := "legend"
	var ang := 0.0
	func _process(d: float) -> void:
		ang += d * TAU / (4.5 if kind == "trans" else 7.0)
		queue_redraw()
	func _draw() -> void:
		var ctr := size / 2.0
		var R := size.length()
		var cols: Array
		var step: float
		if kind == "myth":
			cols = [Color(1, .18, .23, .36), Color(1, .55, .24, .10), Color(1, .18, .23, 0)]; step = 7.0
		elif kind == "trans":
			cols = [Color(1, .96, .84, .36), Color(.61, .91, 1, .24), Color(1, .84, .96, .24), Color(1, .96, .84, 0)]; step = 6.0
		else:
			cols = [Color(1, .78, .27, .30), Color(1, .78, .27, 0)]; step = 9.0
		var n := int(360.0 / step)
		for i in n:
			var col: Color = cols[i % cols.size()]
			if col.a <= 0.0: continue
			var a0 := ang + deg_to_rad(i * step)
			var a1 := a0 + deg_to_rad(step)
			draw_colored_polygon(PackedVector2Array([ctr, ctr + Vector2(cos(a0), sin(a0)) * R, ctr + Vector2(cos(a1), sin(a1)) * R]), col)

func _on_celebrate(f: Dictionary, tier: String, meow: String, kind: String, _dur: float) -> void:
	for ch in celebrate.get_children(): ch.queue_free()
	celebrate.visible = true

	var rays := Rays.new()
	rays.kind = kind
	rays.size = STAGE_SIZE
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celebrate.add_child(rays)

	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, .95)
	flash.size = STAGE_SIZE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celebrate.add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tier_col := Color("#ffb020"); var glow := Color(1, .67, .12, .9); var meow_col := Color("#ffe6a3")
	if kind == "myth":
		tier_col = Color("#ff3d3a"); glow = Color(1, .18, .23, .95); meow_col = Color("#ffd0d3")
	elif kind == "trans":
		tier_col = Color("#ffffff"); glow = Color(.61, .91, 1, .95); meow_col = Color("#fff4d6")
	var tl := lbl(tier, 54, tier_col, Data.font_heavy)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_color_override("font_outline_color", Color(.47, .2, 0, .55) if kind != "trans" else Color(.4, .5, .9, .5))
	tl.add_theme_constant_override("outline_size", 8)
	tl.add_theme_color_override("font_shadow_color", glow)
	tl.add_theme_constant_override("shadow_outline_size", 26)
	tl.add_theme_constant_override("shadow_offset_y", 0)
	box.add_child(tl)
	if kind == "trans":   # 초월: 무지갯빛으로 흐르는 글자
		var tt := create_tween().set_loops()
		for col in [Color("#9be8ff"), Color("#ffd6f5"), Color("#fff4d6"), Color.WHITE]:
			tt.tween_property(tl, "theme_override_colors/font_color", col, 0.55)

	var art := fish_art(f.id, Vector2(280, 175))
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	var wob := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	var half := 0.4 if kind == "trans" else 0.55
	art.rotation = deg_to_rad(-11)
	wob.tween_property(art, "rotation", deg_to_rad(11), half)
	wob.parallel().tween_property(art, "scale", Vector2(1.08, 1.08), half)
	wob.tween_property(art, "rotation", deg_to_rad(-11), half)
	wob.parallel().tween_property(art, "scale", Vector2.ONE, half)

	var nl := lbl("%s · %scm" % [f.n, Data.fmt_cm(f.cm)], 30, Color.WHITE, Data.font_heavy)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .8))
	nl.add_theme_constant_override("shadow_outline_size", 10)
	box.add_child(nl)
	var ml := lbl(meow, 20, meow_col, Data.font_heavy)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .7))
	ml.add_theme_constant_override("shadow_outline_size", 8)
	box.add_child(ml)
	var shk := create_tween().set_loops()
	shk.tween_property(ml, "position:x", 3.0, 0.06).as_relative()
	shk.tween_property(ml, "position:x", -3.0, 0.06).as_relative()

	var cc := CenterContainer.new()
	cc.size = STAGE_SIZE
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(box)
	celebrate.add_child(cc)
	# 팝 등장
	box.pivot_offset = Vector2(box.get_combined_minimum_size().x / 2.0, box.get_combined_minimum_size().y / 2.0)
	box.scale = Vector2(.2, .2); box.rotation = deg_to_rad(-14); box.modulate.a = 0.0
	var pop := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(box, "scale", Vector2.ONE, 0.6)
	pop.tween_property(box, "rotation", 0.0, 0.6)
	pop.tween_property(box, "modulate:a", 1.0, 0.3)

# ================================================================= 모달 공통
func _modal_frame(title: String, sub: String, width := 560.0) -> Dictionary:
	var first_open := modal_layer.get_child_count() == 0
	_clear_modal()
	var dim := ColorRect.new()
	dim.color = Color(4 / 255.0, 7 / 255.0, 16 / 255.0, .78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: close_modals())
	modal_layer.add_child(dim)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.add_child(cc)
	var m := PanelContainer.new()
	var ms := sb(PANEL, LINE, 20, 1, Vector4(20, 20, 20, 20))
	ms.shadow_color = Color(0, 0, 0, .7); ms.shadow_size = 40; ms.shadow_offset = Vector2(0, 20)
	m.add_theme_stylebox_override("panel", ms)
	m.custom_minimum_size.x = width
	cc.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	if title != "":
		var head := HBoxContainer.new()
		var hv := VBoxContainer.new()
		hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hv.add_theme_constant_override("separation", 3)
		hv.add_child(etext(title, 19, TEXT, Data.font_heavy))
		var sl := rich(12, DIM)
		sl.add_theme_font_override("normal_font", Data.font_regular)
		sl.add_theme_color_override("default_color", DIM)
		sl.text = sub
		hv.add_child(sl)
		head.add_child(hv)
		var x := btn("×", "x", func(): close_modals())
		x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		head.add_child(x)
		v.add_child(head)
	# 등장 애니메이션 (처음 열 때만 — 내용 갱신 때는 깜빡이지 않게)
	if first_open:
		m.modulate.a = 0.0
		create_tween().tween_property(m, "modulate:a", 1.0, 0.18)
	return {"panel": m, "body": v}

func _scroll(body: VBoxContainer, max_h: float) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, max_h)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	sc.add_child(inner)
	body.add_child(sc)
	return inner

func _fit_scroll(inner: VBoxContainer, max_h: float) -> void:
	var sc := inner.get_parent() as ScrollContainer
	await get_tree().process_frame
	if is_instance_valid(sc) and is_instance_valid(inner):
		sc.custom_minimum_size.y = minf(max_h, inner.get_combined_minimum_size().y)

func _row(bg := PANEL2, border := LINE) -> HBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, border, 14, 1, Vector4(13, 11, 13, 11)))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 11)
	p.add_child(h)
	return h

func _foot(body: VBoxContainer) -> HBoxContainer:
	var sep := HSeparator.new()
	var ss := StyleBoxLine.new(); ss.color = LINE; ss.thickness = 1
	sep.add_theme_stylebox_override("separator", ss)
	body.add_child(sep)
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 8)
	body.add_child(f)
	return f

func _clear_modal() -> void:
	for ch in modal_layer.get_children():
		modal_layer.remove_child(ch)
		ch.queue_free()

func open_modal(id: String) -> void:
	if modal_id == "result" and id != "result": Game.auto_keep_result()
	modal_id = id
	Game.modal_open = true

func close_modals() -> void:
	var was_result := modal_id == "result"
	_clear_modal()
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_id = ""
	Game.modal_open = false
	if was_result: Game.auto_keep_result()

# ================================================================= 어망
func open_creel() -> void:
	open_modal("creel")
	_fill_creel()

func _fill_creel() -> void:
	var fr := _modal_frame("🧺 어망", "팔아서 코인을 벌거나, 까미에게 주면 농담을 들려줘요.")
	var body: VBoxContainer = fr.body
	var S := Game.S
	if S.creel.is_empty():
		var e := etext("어망이 비었어요.\n낚싯대를 던져 물고기를 잡아보세요 🎣", 13, DIM, Data.font_regular, true)
		e.custom_minimum_size = Vector2(520, 90)
		e.add_theme_constant_override("line_separation", 4)
		var ec := CenterContainer.new()
		ec.custom_minimum_size.y = 90
		ec.add_child(e)
		body.add_child(ec)
	else:
		var inner := _scroll(body, 380)
		var order := {"trans": 0, "myth": 1, "legend": 2, "epic": 3, "rare": 4, "common": 5, "junk": 6}
		var list: Array = S.creel.duplicate()
		list.sort_custom(func(a, b): return order[a.r] < order[b.r] if order[a.r] != order[b.r] else a.price > b.price)
		for f in list:
			var ra: Dictionary = Data.RARITY[f.r]
			var h := _row()
			h.add_child(fish_art(f.id, Vector2(58, 42)))
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_theme_constant_override("separation", 2)
			var nm := HBoxContainer.new()
			nm.add_theme_constant_override("separation", 6)
			nm.add_child(lbl(f.n, 14, ra.col, Data.font_heavy))
			nm.add_child(tag(ra.name, ra.col))
			info.add_child(nm)
			info.add_child(etext("%scm · 🪙 %d" % [Data.fmt_cm(f.cm), f.price], 11, DIM))
			h.add_child(info)
			var uid: String = f.uid
			h.add_child(btn("팔기", "sell", func(): Game.sell_fish(uid)))
			var paw := btn("🐾", "feed", func(): Game.feed_fish(uid))
			paw.add_theme_font_size_override("font_size", 17)
			h.add_child(paw)
			inner.add_child(h.get_parent())
		_fit_scroll(inner, 380)
	var foot := _foot(body)
	var note := rich(11, DIM)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_color_override("default_color", DIM)
	if not S.creel.is_empty():
		note.text = Data.emoji_bb("%d마리 · 총 🪙 ", 15) % S.creel.size() + "[b][color=#e8edfb]%s[/color][/b]" % Data.comma(Game.creel_total())
	foot.add_child(note)
	foot.add_child(btn("전부 팔기", "sell", func(): Game.sell_all()))

# ================================================================= 상점
func open_shop() -> void:
	open_modal("shop")
	_fill_shop()

func _fill_shop() -> void:
	var fr := _modal_frame("🛒 부둣가 잡화점", "장비를 강화하고, 까미와 절친이 되면 특별한 옷도 골라주세요.")
	var body: VBoxContainer = fr.body
	var S := Game.S
	var inner := _scroll(body, 400)
	for u in Data.UPG:
		var lv: int = S.upg[u.k]
		var maxed: bool = lv >= u.max
		var cost := 0 if maxed else Data.upg_cost(u.k, lv)
		var can: bool = not maxed and S.coins >= cost
		var h := _row()
		h.add_child(icon_rect(u.k, 34))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		var nm := HBoxContainer.new()
		nm.add_theme_constant_override("separation", 6)
		nm.add_child(lbl(u.n, 14, TEXT, Data.font_heavy))
		nm.add_child(tag("Lv.%d%s" % [lv, " MAX" if maxed else " / %d" % u.max], DIM))
		info.add_child(nm)
		info.add_child(wrap_lbl("%s — %s" % [Data.upg_desc(u.k, lv), u.tip], 360, 11, DIM))
		info.add_child(_bar(float(lv) / u.max))
		h.add_child(info)
		var k: String = u.k
		h.add_child(btn("MAX" if maxed else "🪙 " + Data.comma(cost), "buy", func(): Game.buy_upgrade(k), not can))
		inner.add_child(h.get_parent())
	_fill_outfits(inner)
	_fit_scroll(inner, 400)
	var foot := _foot(body)
	var note := rich(11, DIM)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_color_override("default_color", DIM)
	note.text = Data.emoji_bb("보유 코인 🪙 ", 15) + "[b][color=#e8edfb]%s[/color][/b]" % Data.comma(S.coins)
	foot.add_child(note)
	foot.add_child(btn("기록 초기화", "mini", func(): _confirm_reset()))

func _bar(k: float) -> Control:
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", sb(Color("#0b1122"), Color(0, 0, 0, 0), 99, 0, Vector4.ZERO))
	bg.custom_minimum_size = Vector2(0, 6)
	var fill := TextureRect.new()
	var g := Gradient.new(); g.set_color(0, Color("#4a8cff")); g.set_color(1, Color("#8ad4ff"))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.width = 64; gt.height = 4
	fill.texture = gt
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bg.add_child(fill)
	bg.resized.connect(func(): fill.custom_minimum_size = Vector2(bg.size.x * k, 6))
	return bg

func _fill_outfits(inner: VBoxContainer) -> void:
	var S := Game.S
	var sep := HSeparator.new()
	var ss := StyleBoxLine.new(); ss.color = LINE; ss.thickness = 1
	sep.add_theme_stylebox_override("separator", ss)
	inner.add_child(sep)
	if S.aff < Data.AFF_MAX:
		inner.add_child(etext("🔒 엔드 콘텐츠 · 까미 옷입히기", 14, TEXT, Data.font_heavy))
		var lock := PanelContainer.new()
		var ls := sb(Color("#1c1a37"), Color("#68527d"), 14, 1, Vector4(16, 22, 16, 22))
		lock.add_theme_stylebox_override("panel", ls)
		var lv := VBoxContainer.new()
		var a := lbl("까미 호감도 100% 필요", 15, Color("#e8c8ff"), Data.font_heavy)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var b := lbl("현재 %d%% · 물고기를 선물해 마음을 열어주세요." % Game.aff_pct(), 12, DIM)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.add_child(a); lv.add_child(b)
		lock.add_child(lv)
		inner.add_child(lock)
		return
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	title.add_child(etext("✨ 엔드 콘텐츠 · 까미 옷입히기", 14, TEXT, Data.font_heavy))
	title.add_child(tag("해금 완료", Color("#c8f08a")))
	inner.add_child(title)
	var base_eq: bool = S.outfit == "none"
	inner.add_child(_outfit_row("none", "기본 까미", "검은 털이 제일 멋지다는 까미의 주장", -1, base_eq, false,
		"착용 중" if base_eq else "입기", false, "none"))
	for i in Data.OUTFITS.size():
		var o: Dictionary = Data.OUTFITS[i]
		var owned: bool = S.ownedOutfits.has(o.id)
		var equipped: bool = S.outfit == o.id
		var prereq = null if i == 0 else Data.OUTFITS[i - 1]
		var prereq_owned: bool = prereq == null or S.ownedOutfits.has(prereq.id)
		var locked := not owned and not prereq_owned
		var can_buy: bool = not locked and S.coins >= o.price
		var label := "착용 중" if equipped else ("입기" if owned else ("🔒 잠김" if locked else "🪙 " + Data.comma(o.price)))
		inner.add_child(_outfit_row("lock" if locked else o.id, o.n, ("%s 먼저 구매해야 해금돼요" % prereq.n) if locked else o.d,
			o.bonus, equipped, locked, label, not owned and not can_buy, o.id))

func _outfit_row(ico: String, nm: String, ds: String, bonus: int, equipped: bool, locked: bool, label: String, disabled: bool, id: String) -> Control:
	var h := _row(PANEL2, Color("#ffb020") if equipped else LINE)
	if ico == "lock":
		h.add_child(icon_rect("lock", 40))
	else:
		var thumb := TextureRect.new()   # 그 옷을 입은 그림 까미
		var at := AtlasTexture.new()   # 시트 칸의 빈 여백을 잘라 고양이(모자 포함)만 크게
		at.atlas = load("res://assets/art/kkami/body_%s.png" % ico)
		at.region = Rect2(84, 24, 283, 378)
		thumb.texture = at
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.custom_minimum_size = Vector2(44, 56)
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(thumb)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.add_child(lbl(nm, 14, TEXT, Data.font_heavy))
	if equipped: top.add_child(tag("착용 중", Color("#ffb020")))
	if bonus >= 0: top.add_child(tag("고등급 확률 +%d%%" % bonus, Color("#8ad4ff")))
	info.add_child(top)
	info.add_child(wrap_lbl(ds, 340, 11, DIM))
	h.add_child(info)
	h.add_child(btn(label, "buy", func(): Game.buy_or_equip_outfit(id), disabled))
	var row := h.get_parent()
	if locked: row.modulate.a = 0.45
	return row

func _confirm_reset() -> void:
	modal_id = "confirm"
	var fr := _modal_frame("", "", 400)
	var body: VBoxContainer = fr.body
	var q := wrap_lbl("모든 기록(코인·도감·업그레이드·까미 호감도·구매한 의상)을 지울까요?", 360, 14, TEXT)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(q)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var no := btn("취소", "big_mini", func(): open_shop())
	var yes := btn("초기화", "feed", func(): Game.reset_all())
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no); row.add_child(yes)
	body.add_child(row)

# ================================================================= 도감
func open_dex() -> void:
	open_modal("dex")
	var S := Game.S
	var sub := "수집 [b][color=#e8edfb]%d[/color][/b] / %d 종 · 총 [b][color=#e8edfb]%d[/color][/b]마리 낚음" % [S.dex.size(), Data.FISH.size(), S.totalCatch]
	var fr := _modal_frame("📖 어류 도감", sub)
	var inner := _scroll(fr.body, 430)
	for rk in Data.RORDER:
		var ra: Dictionary = Data.RARITY[rk]
		var head := lbl(ra.name, 12, ra.col, Data.font_heavy)
		inner.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for f in Data.FISH:
			if f.r != rk: continue
			var d = S.dex.get(f.id)
			var cell := PanelContainer.new()
			cell.add_theme_stylebox_override("panel", sb(PANEL2, LINE, 12, 1, Vector4(6, 9, 6, 9)))
			cell.custom_minimum_size = Vector2(96, 0)
			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 1)
			if d == null:
				cell.modulate.a = 0.35
				var q := lbl("?", 26, DIM, Data.font_heavy); q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				q.custom_minimum_size.y = 54; q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				cv.add_child(q)
				var n := lbl("???", 11, TEXT); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cv.add_child(n)
				var cnt := lbl("미발견", 10, DIM); cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cv.add_child(cnt)
			else:
				var art := fish_art(f.id, Vector2(80, 54))
				art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				cv.add_child(art)
				var n := lbl(f.n, 11, ra.col)
				n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				n.custom_minimum_size.x = 84
				cv.add_child(n)
				var cnt := lbl("×%d · 최대 %scm" % [d.c, Data.fmt_cm(d.best)], 10, DIM)
				cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cnt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				cnt.custom_minimum_size.x = 84
				cv.add_child(cnt)
			cell.add_child(cv)
			grid.add_child(cell)
		inner.add_child(grid)

# ================================================================= 결과
func _on_result_ready(f: Dictionary, delay: float) -> void:
	var tm := get_tree().create_timer(delay)
	result_timer = tm
	tm.timeout.connect(func():
		if result_timer == tm and Game.mode == "over" and Game.pending_fish == f: _open_result(f))

func _open_result(f: Dictionary) -> void:
	open_modal("result")
	var ra: Dictionary = Data.RARITY[f.r]
	var fr := _modal_frame("", "", 400)
	var body: VBoxContainer = fr.body
	body.add_theme_constant_override("separation", 6)
	var art := fish_art(f.id, Vector2(240, 138))
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(art)
	art.rotation = deg_to_rad(-7)
	var wob := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	wob.tween_property(art, "rotation", deg_to_rad(7), 0.8)
	wob.tween_property(art, "rotation", deg_to_rad(-7), 0.8)
	art.tree_exiting.connect(wob.kill)

	var nl := lbl(f.n, 23, ra.col, Data.font_heavy)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(nl)
	var meta := HBoxContainer.new()
	meta.alignment = BoxContainer.ALIGNMENT_CENTER
	meta.add_theme_constant_override("separation", 8)
	meta.add_child(tag(ra.name, ra.col))
	meta.add_child(lbl("%scm" % Data.fmt_cm(f.cm), 13, DIM))
	body.add_child(meta)
	var pl := etext("예상가 🪙 %s" % Data.comma(f.price), 17, GOLD, Data.font_heavy, true)
	pl.custom_minimum_size.x = 360
	body.add_child(pl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for spec in [["🧺 어망에 넣기", "big_mini", "keep"], ["🪙 바로 팔기", "sell", "sell"], ["🐾 까미 주기", "feed", "feed"]]:
		var act: String = spec[2]
		var b := btn(spec[0], spec[1], func(): _result_action(act))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for k in ["normal", "hover", "pressed"]:
			var s: StyleBoxFlat = b.get_theme_stylebox(k)
			s.set_corner_radius_all(12); s.content_margin_top = 12; s.content_margin_bottom = 12
		b.add_theme_font_size_override("font_size", 14)
		row.add_child(b)
	var spacer := Control.new(); spacer.custom_minimum_size.y = 8
	body.add_child(spacer)
	body.add_child(row)

func _result_action(act: String) -> void:
	modal_id = ""   # 자동 보관이 일어나지 않게 먼저 비움
	match act:
		"keep": Game.result_keep()
		"sell": Game.result_sell()
		"feed": Game.result_feed()
	close_modals()

# ================================================================= 입력
func _on_stage_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Game.action()

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo: return
	match e.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if modal_id != "": close_modals()
			else: Game.action()
		KEY_ESCAPE:
			close_modals()
		KEY_S: open_shop()
		KEY_C: open_creel()
		KEY_D: open_dex()
