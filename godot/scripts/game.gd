extends Node
## 까미와 밤낚시 — 게임 상태와 규칙 (원본 index.html 의 로직을 그대로 옮김)
## 화면(UI/스테이지)은 시그널로만 알려주고, 그리는 쪽은 이 노드의 값을 읽기만 한다.

signal status_changed(bbcode: String, hot: bool)
signal cat_said(text: String, seconds: float)
signal popped(text: String, x_pct: float, y_pct: float, col: Color)
signal hud_changed
signal weather_changed
signal result_ready(fish: Dictionary, delay: float)
signal celebrate_started(fish: Dictionary, tier: String, meow: String, kind: String, dur: float)
signal celebrate_ended
signal state_reset

# ---- 무대 좌표 (원본 캔버스 960x540 그대로) ----
const W := 960.0
const H := 540.0
const WATER := 318.0
const CAT := Vector2(186, 318)                 # 고양이 발밑
const ROD_HAND := Vector2(186 + 32, 318 - 66)   # 까미 가슴 앞 (그림 까미 기준)
const SAVE_PATH := "user://kkami-fishing-v1.json"

const STATUS_IDLE := "클릭 또는 [color=#ffc24a]스페이스[/color]로 낚싯대를 던져요"

# ---- 저장 상태 S ----
var S := {}

# ---- 런타임 상태 R ----
var mode := "idle"          # idle | power | cast | wait | bite | fight | reelin | over
var t := 0.0                # 모드 경과시간
var clock := 0.0            # 전체 경과시간 (그리기용)
var power := 0.0
var pdir := 1.0
var last_power := 0.0
var fx := 0.0
var fy := WATER
## 찌가 떨어지는 수면 높이: 수평선(WATER)보다 아래 바다 위. 멀리 던질수록 수평선 쪽(원근)
var surf := WATER + 40.0
var cast_from := Vector2.ZERO
var cast_to := Vector2.ZERO
var bite_at := 0.0
var bite_win := 0.0
var nibble := 0.0
var fish = null             # Dictionary | null
var fight = null            # Dictionary | null
var parts: Array = []
var ripples: Array = []
var shake := 0.0
var flash := 0.0
var celebrating := false
var cat_mood := "idle"      # idle | alert | happy | star | sad
var mood_t := 0.0
var blink := 0.0
var next_blink := 2.0
var reel_t := 0.0
var fat_show := 0.0
var weather := {"key": "clear", "t": 0.0, "dur": 9999.0}
var rain: Array = []
var meteors: Array = []
var meteor_cd := 1.2
var lightning := 0.0

var pending_fish = null     # 결과 창에서 처리 대기 중인 물고기
var modal_open := false     # UI 가 모달을 띄우면 true (입력 차단)

func _ready() -> void:
	randomize()
	S = _load()
	Sfx.enabled = S.sound
	set_weather(pick_weather_key(""), false)
	set_status(STATUS_IDLE)
	_later(0.9, func(): cat_say("밤이 좋다. 물고기도 자고 있거든. …그럼 어떻게 잡지? 아무튼 던져봐.", 6.0))

# =========================================================== 저장
func default_state() -> Dictionary:
	return {
		"coins": 0, "creel": [], "dex": {},
		"upg": {"rod": 1, "reel": 1, "float": 1, "bait": 1, "charm": 1},
		"aff": 0, "fed": 0, "ownedOutfits": [], "outfit": "none",
		"jokeBag": [], "sound": true, "totalCatch": 0,
	}

func _load() -> Dictionary:
	var st := default_state()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f else null
		if parsed is Dictionary:
			for k in parsed: st[k] = parsed[k]
	# JSON 은 숫자를 float 로 돌려주므로 정수형으로 되돌림
	for k in ["coins", "aff", "fed", "totalCatch"]: st[k] = int(st[k])
	for k in st.upg: st.upg[k] = int(st.upg[k])
	for k in default_state().upg:
		if not st.upg.has(k): st.upg[k] = 1
	for id in st.dex: st.dex[id] = {"c": int(st.dex[id].c), "best": float(st.dex[id].best)}
	var bag := []
	for i in st.jokeBag: bag.append(int(i))
	st.jokeBag = bag
	# 옷 데이터 정리 (원본과 동일)
	var owned := []
	for id in st.ownedOutfits:
		if Data.OUTFIT_BY_ID.has(id) and not owned.has(id): owned.append(id)
	st.ownedOutfits = owned
	if st.outfit != "none" and (not Data.OUTFIT_BY_ID.has(st.outfit) or not owned.has(st.outfit)): st.outfit = "none"
	# 어망 데이터도 최신 이름·등급을 따르도록 동기화
	for f in st.creel:
		f.price = int(f.price); f.cm = float(f.cm)
		var def = Data.FISH_BY_ID.get(f.id)
		if def: f.n = def.n; f.e = def.e; f.r = def.r
	return st

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(S))

func reset_all() -> void:
	S = default_state()
	Sfx.enabled = S.sound
	save()
	mode = "idle"; fish = null; fight = null; pending_fish = null
	hud_changed.emit()
	state_reset.emit()
	set_status("처음부터 다시! 클릭 또는 [color=#ffc24a]스페이스[/color]로 던져요")
	cat_say("어? 나 기억 잃었어. 누구세요? …농담이야. 다시 시작하자.", 5.0)

# =========================================================== 헬퍼
func _later(sec: float, cb: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(cb)

func set_status(bb: String, hot := false) -> void:
	status_changed.emit(bb, hot)

func cat_say(text: String, sec := 5.2) -> void:
	cat_said.emit(text, sec)
	Sfx.meow()

func pop_text(text: String, x_pct: float, y_pct: float, col: Color) -> void:
	popped.emit(text, x_pct, y_pct, col)

# =========================================================== 날씨
func pick_weather_key(exclude: String) -> String:
	var pool := Data.WEATHERS.filter(func(w): return w.key != exclude)
	var total := 0.0
	for w in pool: total += w.w
	var r := randf() * total
	for w in pool:
		r -= w.w
		if r <= 0.0: return w.key
	return pool[-1].key

func current_weather_fish_id():
	return Data.WEATHER_BY_KEY[weather.key].get("fish")

func set_weather(key: String, announce: bool) -> void:
	var w: Dictionary = Data.WEATHER_BY_KEY[key]
	weather = {"key": key, "t": 0.0, "dur": w.min + randf() * (w.max - w.min)}
	weather_changed.emit()
	if announce:
		pop_text("%s %s" % [w.e, w.name], 50, 14, Color("#9be8ff"))
		cat_say(Data.WEATHER_LINES[key].pick_random(), 4.6)

func roll_weather() -> void:
	set_weather(pick_weather_key(weather.key), true)

# =========================================================== 업그레이드 파생값 (U)
func wx() -> Dictionary: return Data.WEATHER_FX.get(weather.key, Data.WEATHER_FX.clear)
func u_zone() -> float: return (0.20 + 0.019 * (S.upg.rod - 1)) * wx().zoneMul
func u_speed_mul() -> float: return maxf(.5, 1.0 - 0.065 * (S.upg.reel - 1))
func u_wait_time() -> float: return maxf(0.4, ((1.3 + randf() * 3.4) - 0.26 * (S.upg.float - 1)) * wx().waitMul)
func u_window() -> float: return 0.72 + 0.09 * (S.upg.float - 1)
func u_bait_mul() -> float: return 1.0 + 0.30 * (S.upg.bait - 1)
func u_price_mul() -> float: return (1.0 + 0.13 * (S.upg.charm - 1)) * wx().priceMul
func u_outfit_mul() -> float:
	var o = Data.OUTFIT_BY_ID.get(S.outfit)
	return 1.0 + o.bonus / 100.0 if o else 1.0
func u_weather_fish_chance() -> float: return 0.006 * u_bait_mul() * u_outfit_mul()

# =========================================================== 물고기 뽑기
func build_fish(def: Dictionary, pw: float) -> Dictionary:
	var g := (randf() + randf() + randf()) / 3.0
	var size_mul: float = wx().sizeMul
	var lo: float = def.cm[0]; var hi: float = def.cm[1]
	var cm := snappedf(lo + (hi - lo) * minf(1.0, g * 0.75 + pw * 0.25 + size_mul), 0.1)
	var size_ratio := (cm - lo) / maxf(1.0, hi - lo)
	var price := maxi(1, Data.js_round(def.p * (0.65 + size_ratio * 0.85) * u_price_mul()))
	return {"uid": "f%d%d" % [Time.get_ticks_usec(), randi() % 100000], "id": def.id, "n": def.n,
		"e": def.e, "r": def.r, "cm": cm, "price": price}

func roll_fish(pw: float) -> Dictionary:
	var wf_id = current_weather_fish_id()
	if wf_id and randf() < u_weather_fish_chance():
		return build_fish(Data.FISH_BY_ID[wf_id], pw)
	var bm := u_bait_mul() * u_outfit_mul() * float(wx().rareMul) * (1.0 + pw * 0.55)   # 멀리 던질수록 대물, 옷·날씨도 한몫
	var weights := []
	for k in Data.RORDER:
		var base: float = Data.RARITY[k].w
		if k == "junk": weights.append(base / (1.0 + pw * 0.9) / (1.0 + (S.upg.bait - 1) * 0.18))
		elif k == "common": weights.append(base)
		else: weights.append(base * bm)
	var total := 0.0
	for x in weights: total += x
	var r := randf() * total
	var pk := "common"
	for i in Data.RORDER.size():
		r -= weights[i]
		if r <= 0.0:
			pk = Data.RORDER[i]; break
	var pool := Data.FISH.filter(func(f): return f.r == pk)
	return build_fish(pool.pick_random(), pw)

# =========================================================== 액션 (스페이스 / 클릭)
func action() -> void:
	if modal_open or celebrating: return
	match mode:
		"idle": start_power()
		"power": do_cast()
		"wait": early_pull()
		"bite": hook_it()
		"fight": fight_tap()

func start_power() -> void:
	mode = "power"; t = 0.0; power = 0.0; pdir = 1.0
	set_status("한 번 더 눌러 [color=#ffc24a]세기[/color]를 결정해요 — 멀리 던질수록 대물!")

func do_cast() -> void:
	last_power = power
	mode = "cast"; t = 0.0
	cast_from = rod_tip()
	surf = WATER + 46.0 - power * 22.0
	cast_to = Vector2(400 + power * 470, surf - 4)
	Sfx.cast()
	set_status("휘이잉—")

func after_splash() -> void:
	mode = "wait"; t = 0.0
	bite_at = u_wait_time()
	nibble = bite_at * (0.45 + randf() * 0.3)
	fish = roll_fish(last_power)
	var dist := Data.js_round(6 + last_power * 24)
	set_status("찌를 지켜보는 중… [color=#ffc24a]%dm[/color] 지점" % dist)

func early_pull() -> void:
	mode = "idle"; t = 0.0; fish = null
	set_status("너무 성급했어요. 다시 던져볼까요?")
	cat_say("성격 급하긴. 물고기도 마음의 준비가 필요해.", 3.2)
	Sfx.miss()

func start_bite() -> void:
	mode = "bite"; t = 0.0; bite_win = u_window()
	cat_mood = "alert"; mood_t = 0.0
	set_status("[b]지금!![/b] 챔질!", true)
	Sfx.bite()
	splash(fx, surf, 10, 1.0)

func hook_it() -> void:
	var ra: Dictionary = Data.RARITY[fish.r]
	mode = "fight"; t = 0.0
	fight = {
		"pos": randf(), "dir": -1.0 if randf() < .5 else 1.0,
		"spd": ra.spd * u_speed_mul(),
		"zc": 0.5, "zw": u_zone() * ra.zone,
		"hits": 0, "need": ra.need, "miss": 0, "maxMiss": maxi(1, 3 + int(wx().missBonus)),
		"flashT": 0.0, "flashOk": false, "lock": 0.0,
	}
	new_zone()
	set_status("걸렸다! [color=#ffc24a]초록 구간[/color]에서 눌러 릴을 감아요", true)
	Sfx.tone(700, .1, "square", .13)

func new_zone() -> void:
	var half: float = fight.zw / 2.0
	fight.zc = half + randf() * (1.0 - fight.zw)

func fight_tap() -> void:
	var f: Dictionary = fight
	if f.lock > 0.0: return
	f.lock = 0.09
	var in_zone: bool = absf(f.pos - f.zc) <= f.zw / 2.0
	if in_zone:
		f.hits += 1; f.flashT = 0.28; f.flashOk = true
		Sfx.hit(f.hits)
		pop_text("좋아!", 50 + randf() * 10, 78, Color("#8af08a"))
		if f.hits >= f.need:
			succeed(); return
		f.spd *= 1.06; new_zone()
	else:
		f.miss += 1; f.flashT = 0.28; f.flashOk = false
		shake = maxf(shake, 6)
		Sfx.miss()
		pop_text("빗나감!", 50 + randf() * 10, 78, Color("#ff8a8a"))
		if f.miss >= f.maxMiss:
			fail(); return
		f.spd *= 1.03; new_zone()

func fail() -> void:
	mode = "idle"; t = 0.0
	cat_mood = "sad"; mood_t = 0.0
	var nm: String = fish.n if fish else "뭔가"
	set_status("놓쳤다… [color=#ffc24a]%s[/color]이(가) 도망갔어요" % nm)
	Sfx.escape()
	splash(fx, surf, 14, 1.2)
	fish = null; fight = null
	if randf() < 0.45:
		cat_say(["괜찮아. 물고기는 많고 내 잠은 짧아.", "봤어? 방금 걔가 너 비웃고 갔어.", "난 원래 저 정도 크기는 안 먹어. (거짓말)"].pick_random(), 3.2)

func succeed() -> void:
	var f: Dictionary = fish
	mode = "reelin"; t = 0.0; reel_t = 0.0
	fight = null
	S.totalCatch += 1
	var d: Dictionary = S.dex.get(f.id, {"c": 0, "best": 0.0})
	d.c += 1; d.best = maxf(d.best, f.cm)
	S.dex[f.id] = d
	save()
	Sfx.catch_s()
	splash(fx, surf, 18, 1.4)

func show_result(f: Dictionary) -> void:
	pending_fish = f
	cat_mood = "star" if f.r in ["legend", "myth", "trans"] else ("sad" if f.r == "junk" else "happy")
	mood_t = 0.0
	if f.r in ["trans", "myth", "legend"]:
		legendary_party(f)
	elif f.r == "epic":
		flash = 0.5; shake = 10
		burst(fx, surf - 40, 40, ["#b06bff", "#e0b3ff", "#ffffff"])
		Sfx.fanfare()
		pop_text("영웅 등급!", 50, 40, Color("#d7a6ff"))
	else:
		Sfx.coin()
	var delay: float = {"trans": 3.8, "myth": 3.2, "legend": 2.6, "epic": 0.9}.get(f.r, 0.26)
	result_ready.emit(f, delay)
	set_status(STATUS_IDLE)

## 전설·신화·초월 축하 난리
func legendary_party(f: Dictionary) -> void:
	var is_trans: bool = f.r == "trans"
	var is_myth: bool = f.r == "myth"
	celebrating = true
	flash = 1.0; shake = 40.0 if is_trans else (34.0 if is_myth else 26.0)
	Sfx.fanfare()
	Sfx.meow()
	var tier := "초월 등급!!!" if is_trans else ("신화 등급!!!" if is_myth else "전설 등급!!!")
	var meow: String
	if is_trans:
		meow = ["이, 이게 낚여?! 집사 너 지금 신화를 낚싯대로 끌어올린 거야!!",
			"나 진짜 심장 멎는 줄 알았어. 이건 액자가 아니라 신전에 모셔야 돼.",
			"오늘부로 전설 갱신이야. 아니, 전설을 넘어섰어. 냐아아아앙!!!"].pick_random()
	else:
		meow = ["냐아아아앙!!! 이거 실화냥?!", "집사!! 집사!!! 이거 봐!!! 이거 보라고!!!",
			"나 지금 털 다 섰어. 진짜야. 만져봐.", "오늘 밤은 잠 다 잤다. 냐옹!!!"].pick_random()
	var dur := 3.7 if is_trans else (3.1 if is_myth else 2.5)
	celebrate_started.emit(f, tier, meow, f.r, dur)
	# 폭죽 연발
	var cols := ["#fff4d6", "#9be8ff", "#ffd6f5", "#ffffff", "#fff"] if is_trans \
		else (["#ff2d3a", "#ff8c3c", "#fff3c4", "#ffffff", "#ffd0d3"] if is_myth \
		else ["#ffd166", "#ff7a18", "#fff3c4", "#ffffff", "#ff5d8f", "#63e6ff"])
	var shots := 13 if is_trans else (10 if is_myth else 7)
	for i in shots:
		_later(0.26 * (i + 1), func():
			burst(120 + randf() * 720, 80 + randf() * 200, 46, cols)
			shake = maxf(shake, 12)
			Sfx.tone(600 + randf() * 900, .1, "triangle", .09))
	_later(dur, func():
		celebrating = false
		celebrate_ended.emit())

# =========================================================== 결과 처리 / 어망 / 먹이
func resume_fishing() -> void:
	mode = "idle"; t = 0.0; fish = null; fight = null
	set_status(STATUS_IDLE)

func result_keep() -> void:
	if pending_fish:
		S.creel.append(pending_fish); save(); hud_changed.emit()
	pending_fish = null
	resume_fishing()

func result_sell() -> void:
	if pending_fish:
		S.coins += pending_fish.price; save(); hud_changed.emit(); Sfx.coin()
		pop_text("🪙 +%d" % pending_fish.price, 50, 46, Color("#ffc24a"))
	pending_fish = null
	resume_fishing()

func result_feed() -> void:
	if pending_fish: do_feed(pending_fish)
	pending_fish = null
	resume_fishing()

## 결과 창을 버튼 없이 닫으면 어망에 자동 보관
func auto_keep_result() -> void:
	if mode != "over": return
	if pending_fish:
		S.creel.append(pending_fish)
		pending_fish = null
		save(); hud_changed.emit()
		pop_text("🧺 어망에 자동 보관", 50, 43, Color("#c8f08a"))
	resume_fishing()

func _creel_index(uid: String) -> int:
	for i in S.creel.size():
		if S.creel[i].uid == uid: return i
	return -1

func sell_fish(uid: String) -> void:
	var i := _creel_index(uid)
	if i < 0: return
	var f: Dictionary = S.creel.pop_at(i)
	S.coins += f.price; save(); hud_changed.emit(); Sfx.coin()

func feed_fish(uid: String) -> void:
	var i := _creel_index(uid)
	if i < 0: return
	do_feed(S.creel.pop_at(i))

func creel_total() -> int:
	var total := 0
	for f in S.creel: total += f.price
	return total

func sell_all() -> void:
	if S.creel.is_empty(): return
	var total := creel_total()
	S.coins += total; S.creel = []; save(); hud_changed.emit()
	Sfx.coin(); Sfx.tone(1320, .1, "square", .1, .07)
	cat_say("전부 팔았네. %s코인. …내 몫은?" % Data.comma(total), 4.2)

## 까미 먹이 주기 (이스터에그)
func do_feed(f: Dictionary) -> void:
	var gain: int = {"junk": 0, "common": 3, "rare": 6, "epic": 12, "legend": 25, "myth": 45, "trans": 80}[f.r]
	var outfit_was_locked: bool = S.aff < Data.AFF_MAX
	S.aff += gain; S.fed += 1
	var special: bool = f.r in ["legend", "myth", "trans"]
	cat_mood = "sad" if f.r == "junk" else ("star" if special else "happy")
	mood_t = 0.0
	var n := 84 if f.r == "trans" else (64 if f.r == "myth" else (46 if special else 16))
	var cols := ["#fff4d6", "#9be8ff", "#ffd6f5", "#fff"] if f.r == "trans" else \
		(["#ff2d3a", "#ff8c3c", "#ffd0d3", "#fff"] if f.r == "myth" else \
		(["#ffd166", "#ff5d8f", "#63e6ff", "#fff"] if special else ["#ff9ab5", "#ffd6e4", "#fff"]))
	burst(CAT.x + 20, WATER - 150, n, cols)

	var line: String
	if f.r == "junk":
		line = ["…이걸 나한테 준다고? 나 고양이야. 재활용은 네가 해.", "집사. 우리 사이에 이러기야?",
			"냄새는 좋은데 맛이 없어 보여. 아니 냄새도 별로야."].pick_random()
	elif f.id == "catfish":
		line = Data.CATFISH_LINE
	elif f.id == "godzilla":
		line = Data.GODZILLA_LINE
		var gift := 1500 + randi() % 1500
		S.coins += gift
		_later(5.4, func(): cat_say("도쿄 재건축 성금이래. 나도 몰라, 그냥 생겼어. 🪙%d" % gift, 5.2))
	elif f.r == "trans":
		line = Data.TRANS_LINES.get(f.id, Data.TRANS_JOKES.pick_random())
		var gift := 2200 + randi() % 3200
		S.coins += gift
		_later(5.8, func(): cat_say("초월적인 존재가 코인을 놓고 갔어. 나도 무서웠어. 🪙%d" % gift, 5.6))
	elif f.r == "myth":
		line = Data.MYTH_JOKES.pick_random()
		var gift := 700 + randi() % 800
		S.coins += gift
		_later(5.4, func(): cat_say("신화의 기운이 코인으로 변했어. 내가 한 건 아니고. 🪙%d" % gift, 5.2))
	elif f.r == "legend":
		line = Data.LEGEND_JOKES.pick_random()
		var gift := 200 + randi() % 300
		S.coins += gift
		_later(5.4, func(): cat_say("아 맞다. 이거 받아. 내가 어제 부둣가에서 주웠어. 🪙%d" % gift, 5.2))
	else:
		line = next_joke()

	# 호감도 마일스톤
	var ms = feed_milestone()
	if ms:
		_later(5.6, func(): cat_say(ms.text, 7.0))
		S.coins += ms.coins
	if outfit_was_locked and S.aff >= Data.AFF_MAX:
		burst(CAT.x + 20, WATER - 150, 72, ["#ffd166", "#ff5df7", "#63e6ff", "#fff"])
		pop_text("🔓 까미 옷입히기 해금!", 50, 34, Color("#ffd166"))
		_later(6.6, func(): cat_say("집사, 우리 이제 완전 절친이지? 상점에 내 옷이 들어왔대. 비싼 걸로 사줘.", 7.6))

	save(); hud_changed.emit()
	cat_say(line, 6.2)
	Sfx.meow()
	if f.r != "junk": pop_text("💗 +%d" % gain, 20, 30, Color("#ffb1c8"))

func next_joke() -> String:
	if S.jokeBag.is_empty():
		var bag := range(Data.JOKES.size())
		bag.shuffle()
		S.jokeBag = bag
	return Data.JOKES[S.jokeBag.pop_back()]

func feed_milestone():
	var M := {
		5:  {"text": "너 은근히 성실하다. 좋아, 오늘부터 네 무릎은 내 자리야. 🪙150", "coins": 150},
		12: {"text": "…사실 나 낚시할 줄 알아. 앞발로. 근데 젖는 게 싫어서 너 시키는 거야. 🪙400", "coins": 400},
		22: {"text": "집사. 나 요즘 좀 무거워진 것 같지 않아? 착시야. 물고기 더 줘. 🪙800", "coins": 800},
		35: {"text": "비밀 하나 알려줄게. 보름달 뜬 밤에 제일 멀리 던지면… 아니다, 직접 해봐. 🪙1500", "coins": 1500},
	}
	return M.get(S.fed)

# =========================================================== 상점
func buy_upgrade(k: String) -> void:
	var u: Dictionary = {}
	for x in Data.UPG:
		if x.k == k: u = x
	var lv: int = S.upg[k]
	if lv >= u.max: return
	var cost := Data.upg_cost(k, lv)
	if S.coins < cost: return
	S.coins -= cost; S.upg[k] = lv + 1; save()
	hud_changed.emit()
	Sfx.coin(); Sfx.tone(880, .12, "triangle", .14, .06); Sfx.tone(1174, .16, "triangle", .13, .14)
	cat_say(["%s 업그레이드! 이제 좀 낚시꾼 같네." % u.n, "오, %s Lv.%d. 기대할게. 부담 가져." % [u.n, lv + 1],
		"장비만 좋아지고 실력은 그대로면 곤란한데?"].pick_random(), 3.6)

func buy_or_equip_outfit(id: String) -> void:
	if S.aff < Data.AFF_MAX: return
	if id == "none":
		S.outfit = "none"; save(); hud_changed.emit()
		cat_say("역시 자연스러운 검은 털이 최고지. 관리비도 안 들고.", 3.8)
		return
	var o = Data.OUTFIT_BY_ID.get(id)
	if not o: return
	if not S.ownedOutfits.has(id):
		var idx := -1
		for i in Data.OUTFITS.size():
			if Data.OUTFITS[i].id == id: idx = i
		var prereq = Data.OUTFITS[idx - 1] if idx > 0 else null
		if prereq and not S.ownedOutfits.has(prereq.id): return
		if S.coins < o.price: return
		S.coins -= o.price
		S.ownedOutfits.append(id)
		Sfx.coin(); Sfx.tone(1046, .12, "triangle", .13, .08); Sfx.tone(1396, .18, "triangle", .12, .18)
	S.outfit = id
	save(); hud_changed.emit()
	cat_mood = "star"; mood_t = 0.0
	burst(CAT.x + 10, WATER - 120, 46, ["#ffd166", "#ff5df7", "#63e6ff", "#fff"])
	cat_say("%s 어때? 잘 어울리는 건 알아. 더 크게 말해봐." % o.n, 4.8)

func toggle_sound() -> void:
	S.sound = not S.sound
	Sfx.enabled = S.sound
	save(); hud_changed.emit()
	if S.sound: Sfx.tone(880, .1, "triangle", .12)

func aff_pct() -> int:
	return mini(100, int(floor(float(S.aff) / Data.AFF_MAX * 100.0)))

# =========================================================== 낚싯대
func rod_angle() -> float:
	match mode:
		"power":  return -1.05 - power * 0.55
		"cast":   return -1.05 + minf(1.0, t / 0.28) * 0.85
		"wait":   return -0.62 + sin(t * 1.1) * 0.02
		"bite":   return -0.42
		"fight":  return -0.75 + sin(t * 13.0) * 0.10 + (fight.pos * 0.12 if fight else 0.0)
		"reelin": return -1.10
	return -0.80

func rod_tip() -> Vector2:
	var a := rod_angle()
	return ROD_HAND + Vector2(cos(a), sin(a)) * 176.0

# =========================================================== 파티클
func splash(x: float, y: float, n: int, scale: float) -> void:
	for i in n:
		parts.append({"x": x, "y": y, "vx": (randf() - .5) * 180 * scale, "vy": -randf() * 230 * scale - 40,
			"g": 520.0, "r": 1.6 + randf() * 3, "c": Color(170 / 255.0, 220 / 255.0, 1.0), "a": 1.0,
			"life": .9, "t": 0.0, "sq": false, "rot": 0.0, "vr": 0.0})
	ripples.append({"x": x, "y": y, "r": 6.0, "a": .55})

func burst(x: float, y: float, n: int, cols: Array) -> void:
	for i in n:
		var a := randf() * TAU
		var s := 90 + randf() * 330
		parts.append({"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s - 70, "g": 340.0,
			"r": 2.2 + randf() * 3.6, "c": Color(cols.pick_random()), "a": 1.0,
			"life": 1.3 + randf() * .7, "t": 0.0, "sq": true, "rot": randf() * TAU, "vr": (randf() - .5) * 12})

# =========================================================== 날씨 이펙트
func _update_weather_fx(dt: float) -> void:
	var key: String = weather.key
	if key == "rain":
		if rain.is_empty():
			for i in 70:
				rain.append({"x": randf() * W, "y": randf() * H, "spd": 260 + randf() * 220, "len": 10 + randf() * 10})
		for d in rain:
			d.y += d.spd * dt; d.x -= d.spd * 0.18 * dt
			if d.y > H or d.x < -20:
				d.y = -10 - randf() * 40; d.x = randf() * (W + 80) - 40
	elif not rain.is_empty():
		rain.clear()

	if key == "meteor":
		meteor_cd -= dt
		if meteor_cd <= 0.0:
			meteor_cd = 0.5 + randf() * 0.9
			meteors.append({"x": randf() * W * 0.7 + W * 0.15, "y": -20.0, "ang": 1.05 + randf() * 0.25,
				"spd": 640 + randf() * 260, "t": 0.0, "life": 0.55 + randf() * 0.2, "len": 70 + randf() * 60})
	for i in range(meteors.size() - 1, -1, -1):
		var m: Dictionary = meteors[i]
		m.t += dt; m.x += cos(m.ang) * m.spd * dt; m.y += sin(m.ang) * m.spd * dt
		if m.t > m.life: meteors.remove_at(i)

	if key == "storm":
		if lightning > 0.0: lightning -= dt * 1.6
		if randf() < dt * 0.35 and lightning <= 0.0:
			lightning = 1.0; shake = maxf(shake, 16)
			Sfx.tone(90, .3, "sawtooth", .14); Sfx.noise(.4, .12)
	elif lightning > 0.0:
		lightning = maxf(0.0, lightning - dt * 3)

# =========================================================== 루프
func _process(delta: float) -> void:
	var dt := minf(0.05, delta)
	clock += dt
	t += dt; mood_t += dt
	if shake > 0.0: shake = maxf(0.0, shake - dt * 46)
	if flash > 0.0: flash = maxf(0.0, flash - dt * 2.2)
	if mood_t > 2.2 and cat_mood != "idle" and mode != "fight" and mode != "bite": cat_mood = "idle"

	# 눈 깜빡임
	next_blink -= dt
	if next_blink <= 0.0:
		blink = 0.16; next_blink = 1.6 + randf() * 3.4
	if blink > 0.0: blink -= dt

	# 뚱냥이 지수(먹인 만큼 통통)
	var target_fat := minf(1.0, S.fed / 22.0)
	fat_show += (target_fat - fat_show) * minf(1.0, dt * 2)

	# 날씨
	weather.t += dt
	if weather.t >= weather.dur: roll_weather()
	_update_weather_fx(dt)

	match mode:
		"power":
			power += pdir * dt * 1.15
			if power >= 1.0: power = 1.0; pdir = -1.0
			if power <= 0.0: power = 0.0; pdir = 1.0
		"cast":
			var k := minf(1.0, t / 0.62)
			fx = cast_from.x + (cast_to.x - cast_from.x) * k
			fy = cast_from.y + (cast_to.y - cast_from.y) * k - sin(k * PI) * 150
			if k >= 1.0:
				splash(fx, surf, 12, 1.0); Sfx.noise(.22, .11); after_splash()
		"wait":
			fy = surf - 4
			if t >= bite_at: start_bite()
		"bite":
			if t >= bite_win:
				mode = "idle"; t = 0.0
				set_status("놓쳤다! 입질 때 바로 눌러야 해요")
				Sfx.escape(); fish = null
				cat_say(["늦었어! 물고기도 기다려주는 거 아니야.", "에이, 방금 거 맛있어 보였는데."].pick_random(), 3.0)
		"fight":
			var f: Dictionary = fight
			if f.lock > 0.0: f.lock -= dt
			if f.flashT > 0.0: f.flashT -= dt
			f.pos += f.dir * f.spd * dt
			if f.pos > 1.0: f.pos = 1.0; f.dir = -1.0
			if f.pos < 0.0: f.pos = 0.0; f.dir = 1.0
		"reelin":
			reel_t += dt
			# 찌를 고양이 쪽으로 당김
			fx += (ROD_HAND.x + 40 - fx) * minf(1.0, dt * 4.5)
			fy += (WATER - 70 - fy) * minf(1.0, dt * 4.5)
			if reel_t > 0.62:
				mode = "over"; t = 0.0
				show_result(fish)

	# 파티클
	for i in range(parts.size() - 1, -1, -1):
		var p: Dictionary = parts[i]
		p.t += dt; p.vy += p.g * dt; p.x += p.vx * dt; p.y += p.vy * dt
		if p.vr: p.rot += p.vr * dt
		p.a = maxf(0.0, 1.0 - p.t / p.life)
		if p.t > p.life: parts.remove_at(i)
	for i in range(ripples.size() - 1, -1, -1):
		var w: Dictionary = ripples[i]
		w.r += dt * 46; w.a -= dt * 0.75
		if w.a <= 0.0: ripples.remove_at(i)
