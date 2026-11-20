extends "res://scripts/stage_draw.gd"
## 까미 — 그림 스프라이트 리그 (몸·옷 7종, 눈 6종, 입 2종, 꼬리, 낚싯대 쥔 앞발).
## 표정/깜빡임/숨쉬기/통통해지기/흥분 떨림은 코드로 움직이고, 낚싯대는 기존 코드 그대로.

const ART := "res://assets/art/kkami/"
const OUTFITS := ["none", "hoodie", "captain", "wizard", "space", "royal", "pirate"]
# 몸 시트 한 칸(443px) 기준 측정값 (두들 화풍·둥근 실루엣·검은 털): 고양이 중심 x=222, 바닥 y=421,
# 머리 폭 238 (y=220), 코 (223,241), 턱 y≈280
const CELL_ANCHOR := Vector2(222, 421)
const EYES_Y := 207.0
const MOUTH_Y := 260.0
const NOSE_BOTTOM := 248.0   # 몸 그림에서 코 아래 끝 (입이 시작되는 곳)
const MOUTH_W := 15.0        # ω 한쪽 곡선 반지름 (몸 그림 px) — 양옆으로 넓게
const NECK_Y := 282.0
const SCALE := 0.49                 # 몸 시트 → 무대 (키 346px → 약 170px, 시안 M6 크기)
const PART_K := 140.0 / 225.0       # 부품 시트 → 몸 시트 (눈 한 쌍 폭 225px → 140px, 머리폭의 59% — 땡그랗고 큰 눈)
const TAIL_BASE := Vector2(128, 212)   # 꼬리 그림(테두리용 여백 12px 포함)에서 몸에 붙는 지점 # 꼬리 그림에서 몸에 붙는 지점 (아래쪽 끝)
const EYE_SPREAD := 3.0              # 눈 한 쌍 그림을 반으로 갈라 양쪽으로 더 벌리는 거리 (무대 px, 한쪽 기준)

var tex := {}
## 눈·입은 테두리 셰이더가 없는 별도 층에 그린다 (얼굴 부품 둘레에 라벤더 테두리가 생기지 않게)
var face: Node2D
var face_jobs: Array[Callable] = []

func _draw_face() -> void:
	for job in face_jobs: job.call()

func _ready() -> void:
	init_brush()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for o in OUTFITS: tex["body_" + o] = load(ART + "body_%s.png" % o)
	for n in ["eyes_sassy", "eyes_normal", "eyes_alert", "eyes_closed", "eyes_happy", "eyes_sad", "eyes_star", "mouth_closed", "mouth_open", "tail", "paw"]:
		tex[n] = load(ART + n + ".png")
	face = Node2D.new()
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.draw.connect(_draw_face)
	# 얼굴 층: 테두리 없이 털 밝기만 몸과 같게
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/lit_sprite.gdshader")
	fm.set_shader_parameter("fur_shift", Vector3(0.10, 0.08, 0.17))
	face.material = fm
	add_child(face)

func _process(_delta: float) -> void:
	queue_redraw()
	if face: face.queue_redraw()

func _draw() -> void:
	draw_cat(Game.clock)

## 몸 시트 좌표 → 무대 좌표 (발 밑 기준으로 통통함·숨쉬기 비율 적용)
func to_stage(cell: Vector2, anchor: Vector2, sx: float, sy: float) -> Vector2:
	return anchor + Vector2((cell.x - CELL_ANCHOR.x) * SCALE * sx, (cell.y - CELL_ANCHOR.y) * SCALE * sy)

## 부품을 중심 기준으로 그리기 (ci: 그릴 캔버스 — 기본은 몸 층)
func part(name: String, center: Vector2, k: float, mod := Color.WHITE, ci: CanvasItem = null, stretch := Vector2.ONE) -> void:
	if ci == null: ci = self
	var t: Texture2D = tex[name]
	var size := t.get_size() * k * stretch
	ci.draw_texture_rect(t, Rect2(center - size / 2.0, size), false, mod)

## 눈 한 쌍 그림을 좌우 반으로 나눠 spread 만큼 바깥으로 벌려 그리기
func eyes_split(name: String, center: Vector2, k: float, spread: float, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	var t: Texture2D = tex[name]
	var size := t.get_size()
	var half := Vector2(size.x / 2.0, size.y)
	var dst := half * k
	var top := center.y - dst.y / 2.0
	ci.draw_texture_rect_region(t, Rect2(Vector2(center.x - dst.x - spread, top), dst), Rect2(Vector2.ZERO, half))
	ci.draw_texture_rect_region(t, Rect2(Vector2(center.x + spread, top), dst), Rect2(Vector2(half.x, 0), half))

func draw_cat(tm: float) -> void:
	face_jobs.clear()
	var fat := Game.fat_show
	var excited := Game.mode == "bite" or Game.mode == "fight"
	var jitter := sin(tm * 26) * 1.6 if excited else 0.0
	var breathe := sin(tm * 1.9)
	var anchor := Vector2(CAT.x + jitter, CAT.y - 12)
	var sx := 1.0 + fat * 0.22
	var sy := (1.0 + fat * 0.04) * (1.0 + breathe * 0.006)
	xf()

	fill_ell(anchor.x, anchor.y - 2, 50 + fat * 10, 7, c("#1d1238", .45))    # 그림자

	# 꼬리 (몸 뒤, 붙는 지점을 축으로 흔들기)
	var tw := sin(tm * (7.5 if excited else 2.1)) * 0.5
	var tail_t: Texture2D = tex.tail
	var tk := SCALE * PART_K * 0.95
	var pivot := anchor + Vector2(-38 * sx, -10)
	xf(pivot, -0.08 + tw * 0.22)
	draw_texture_rect(tail_t, Rect2(-TAIL_BASE * tk, tail_t.get_size() * tk), false)
	xf()

	# 몸 (옷 포함)
	var outfit: String = Game.S.outfit if OUTFITS.has(Game.S.outfit) else "none"
	var body: Texture2D = tex["body_" + outfit]
	var top_left := to_stage(Vector2.ZERO, anchor, sx, sy)
	draw_texture_rect(body, Rect2(top_left, body.get_size() * SCALE * Vector2(sx, sy)), false)

	# 표정
	var mood := Game.cat_mood
	var blinking := Game.blink > 0.0 and mood != "star"
	var eyes := "eyes_sassy"     # 평소: 시안처럼 눈꺼풀이 살짝 내려온 새침한 눈
	match mood:
		"alert": eyes = "eyes_normal"   # 입질: 땡그랗게 커진 눈
		"happy": eyes = "eyes_happy"
		"sad": eyes = "eyes_sad"
		"star": eyes = "eyes_star"
	if blinking and mood in ["idle", "alert"]: eyes = "eyes_closed"
	var pk := SCALE * PART_K * (0.5 * (1.0 + sx))   # 통통해지면 얼굴도 살짝 넓게
	var eye_pos := to_stage(Vector2(223, EYES_Y), anchor, sx, sy)
	var star_pulse := 1.0 + (sin(tm * 9) * 0.08 if mood == "star" else 0.0)
	if eyes == "eyes_sassy": star_pulse = 1.15
	if mood == "alert": star_pulse = 1.1   # 입질: 눈이 더 동그랗게 커짐
	face_jobs.append(eyes_split.bind(eyes, eye_pos, pk * star_pulse, EYE_SPREAD * sx, face))
	# 고양이 입 (ω): 코 밑 짧은 선 + 양옆 둥근 곡선. 신나거나 입질 땐 그 아래로 혀가 보이게 벌림
	var open := mood in ["star", "alert", "happy"]
	face_jobs.append(draw_mouth.bind(face, to_stage(Vector2(223, NOSE_BOTTOM), anchor, sx, sy), SCALE * (0.5 * (1.0 + sx)), open, tm))

	# 목도리 (레벨업 훈장 느낌)
	if Game.S.upg.charm > 1:
		var neck := to_stage(Vector2(223, NECK_Y), anchor, sx, sy)
		var cols := ["#e0454f", "#ff8a3d", "#63e6ff", "#b06bff", "#ffd166"]
		fill_ell(neck.x, neck.y - 1, 29 * sx, 9, c("#3d2346"), 0, 0, PI)
		fill_ell(neck.x, neck.y, 27 * sx, 7, c(cols[mini(4, Game.S.upg.charm - 1)]), 0, 0, PI)
		circle(neck.x, neck.y + 5, 5.6, c("#3d2346"))
		circle(neck.x, neck.y + 5, 4.2, c("#ffd166"))

	# 낚싯대 + 대를 쥔 앞발 (흥분 떨림은 몸과 같이)
	xf(Vector2(jitter, 0))
	draw_rod()
	# 앞발도 테두리 없는 얼굴 층에 (낚싯대 위에 깔끔하게 얹힘)
	face_jobs.append(part.bind("paw", ROD_HAND + Vector2(-2 + jitter, 3), SCALE * PART_K * 0.95, Color.WHITE, face))
	xf()

## ω 고양이 입. k: 몸 그림 px → 무대 px
func draw_mouth(ci: CanvasItem, nose: Vector2, k: float, open: bool, tm: float) -> void:
	var line_c := Color("#f6eeff")
	var w := MOUTH_W * k
	var lw := maxf(1.6, 4.2 * k)
	var c := nose + Vector2(0, 7.0 * k)
	if open:
		# 벌린 입: 둥근 아래턱 + 분홍 혀 (말할 때처럼 살짝 여닫힘)
		var depth := w * (1.55 + 0.15 * sin(tm * 9.0))
		var top := c.y + w * 0.55
		var pts := PackedVector2Array()
		for i in 21:
			var a := PI * i / 20.0
			pts.append(Vector2(c.x + cos(a) * w * 1.2, top + sin(a) * depth))
		ci.draw_colored_polygon(pts, Color("#b3375f"))
		var tongue := PackedVector2Array()
		for i in 21:
			var a := PI * i / 20.0
			tongue.append(Vector2(c.x + cos(a) * w * 0.78, top + depth * 0.42 + sin(a) * depth * 0.52))
		ci.draw_colored_polygon(tongue, Color("#ff9ab3"))
		pts.append(pts[0])
		ci.draw_polyline(pts, line_c, lw * 0.8, true)
	# 코 밑 선
	ci.draw_line(nose, c, line_c, lw, true)
	# 양옆 둥근 곡선 (ω)
	ci.draw_arc(c + Vector2(-w, 0), w, 0.0, PI, 16, line_c, lw, true)
	ci.draw_arc(c + Vector2(w, 0), w, 0.0, PI, 16, line_c, lw, true)

func draw_rod() -> void:
	var a := Game.rod_angle(); var L := 176.0
	var h := ROD_HAND
	var d := Vector2(cos(a), sin(a))
	var tip := h + d * L
	var plum := c("#3d2346")
	line(h - d * 26, h + d * 16, plum, 10, true)
	line(h - d * 26, h + d * 16, c("#c9875a"), 6.5, true)   # 손잡이
	var cols := ["#ffb082", "#ffc58f", "#ffd36b", "#a8e6a0", "#9fd8ff", "#b6a2ff", "#ffb020", "#ff8ac7"]
	var bend := 26.0 if (Game.mode == "fight" or Game.mode == "bite") else (8.0 if Game.mode == "wait" else 2.0)
	var rod := quad_pts(h + d * 14, h + d * L * 0.55 + Vector2(0, bend * 0.4), tip + Vector2(0, bend))
	stroke(rod, plum, 9.5, true)
	stroke(rod, c(cols[mini(cols.size() - 1, Game.S.upg.rod - 1)]), 6.0, true)
	var reel := h + Vector2(cos(a + 1.4), sin(a + 1.4)) * 13   # 릴
	circle(reel.x, reel.y, 8.6, plum)
	circle(reel.x, reel.y, 7, c("#e6dcfa"))
	circle(reel.x, reel.y, 2.6, plum)
