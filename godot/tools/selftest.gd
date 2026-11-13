extends Node
## 개발용 자동 점검: `godot --headless -- --selftest`
## 실제 입력 경로로 한 판을 끝까지 돌리고, 상점·먹이·옷·저장·초기화 규칙을 확인한다.

var main: Control
var fails := 0
var checks := 0

func _ready() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	checks += 1
	if cond: print("  PASS  ", what)
	else:
		fails += 1
		print("  FAIL  ", what)

func frames(n := 1) -> void:
	for i in n: await get_tree().process_frame

func until(cond: Callable, timeout := 12.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > timeout * 1000.0: return false
		await get_tree().process_frame
	return true

func press_space() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE; e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var u := InputEventKey.new()
	u.keycode = KEY_SPACE; u.pressed = false
	Input.parse_input_event(u)
	await frames(1)

func click_stage() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true
	e.position = main.STAGE_POS + Vector2(480, 200); e.global_position = e.position
	Input.parse_input_event(e)
	await frames(2)
	var u := e.duplicate(); u.pressed = false
	Input.parse_input_event(u)
	await frames(1)

func _run() -> void:
	await frames(3)
	Game.S = Game.default_state(); Game.hud_changed.emit()
	Game.set_weather("clear", false)

	print("[1] 한 판: 스페이스로 던지고, 입질에 챔질하고, 초록 구간에서 감기")
	await press_space()
	ok(Game.mode == "power", "스페이스 → 세기 게이지")
	await frames(20)
	await click_stage()
	ok(Game.mode == "cast", "스테이지 클릭 → 던지기")
	ok(await until(func(): return Game.mode == "wait"), "착수 → 대기")
	ok(Game.fish != null, "물고기가 정해짐: %s" % (Game.fish.n if Game.fish else "-"))
	ok(await until(func(): return Game.mode == "bite"), "입질 발생")
	await press_space()
	ok(Game.mode == "fight", "챔질 → 싸움")
	var guard := 0
	while Game.mode == "fight" and guard < 4000:
		guard += 1
		var f = Game.fight
		if f and f.lock <= 0.0 and absf(f.pos - f.zc) <= f.zw / 2.0 * 0.6:
			await press_space()
		else:
			await frames(1)
	ok(Game.mode in ["reelin", "over"], "초록 구간 맞추기 → 성공 (%s)" % Game.mode)
	var caught = Game.fish
	ok(await until(func(): return main.modal_id == "result", 8.0), "결과 창 열림")
	ok(Game.S.totalCatch == 1 and Game.S.dex.has(caught.id), "도감·총 마릿수 기록")
	var coins0: int = Game.S.coins
	main._result_action("sell")
	ok(Game.S.coins == coins0 + caught.price and Game.mode == "idle", "바로 팔기 → 코인 +%d" % caught.price)

	print("[2] 조급한 챔질 / 입질 놓침 / 싸움 실패")
	await press_space(); await press_space()
	await until(func(): return Game.mode == "wait")
	await press_space()
	ok(Game.mode == "idle" and Game.fish == null, "대기 중 누르면 조급한 챔질로 실패")
	Game.start_power(); Game.do_cast()
	await until(func(): return Game.mode == "bite")
	ok(await until(func(): return Game.mode == "idle", 3.0), "입질 때 안 누르면 놓침")
	Game.start_power(); Game.do_cast()
	await until(func(): return Game.mode == "bite")
	Game.hook_it()
	guard = 0
	while Game.mode == "fight" and guard < 4000:
		guard += 1
		var f = Game.fight
		if f and f.lock <= 0.0 and absf(f.pos - f.zc) > f.zw / 2.0 + 0.05:
			Game.fight_tap()
		await frames(1)
	ok(Game.mode == "idle" and Game.cat_mood == "sad", "빗나감 누적 → 도망")

	print("[3] 결과 창을 그냥 닫으면 어망에 자동 보관")
	Game.fish = Game.build_fish(Data.FISH_BY_ID["bung"], 0.3)
	Game.succeed()
	await until(func(): return main.modal_id == "result", 5.0)
	var n0: int = Game.S.creel.size()
	await press_space()
	ok(Game.S.creel.size() == n0 + 1 and main.modal_id == "" and Game.mode == "idle", "스페이스로 닫기 → 자동 보관")

	print("[4] 어망 팔기 / 먹이 / 전부 팔기")
	for id in ["boot", "bung", "trout", "gold", "moonw", "kraken", "yongwang", "catfish", "godzilla"]:
		Game.S.creel.append(Game.build_fish(Data.FISH_BY_ID[id], 0.5))
	var uid0: String = Game.S.creel[0].uid
	var price0: int = Game.S.creel[0].price
	coins0 = Game.S.coins
	Game.sell_fish(uid0)
	ok(Game.S.coins == coins0 + price0, "한 마리 팔기")
	var aff0: int = Game.S.aff
	while Game.S.creel.size() > 2:
		Game.feed_fish(Game.S.creel[0].uid)
	ok(Game.S.aff > aff0 and Game.S.fed >= 7, "등급별 먹이 주기 (호감도 %d, 먹인 수 %d)" % [Game.S.aff, Game.S.fed])
	coins0 = Game.S.coins
	var total := Game.creel_total()
	Game.sell_all()
	ok(Game.S.creel.is_empty() and Game.S.coins == coins0 + total, "전부 팔기")

	print("[5] 상점 업그레이드 / 옷")
	Game.S.coins = 5000000
	for u in Data.UPG:
		for i in 12: Game.buy_upgrade(u.k)
		ok(Game.S.upg[u.k] == u.max, "%s 최대 레벨 %d" % [u.n, u.max])
	Game.S.aff = 0
	Game.buy_or_equip_outfit("hoodie")
	ok(not Game.S.ownedOutfits.has("hoodie"), "호감도 100% 전엔 옷 구매 불가")
	Game.S.aff = Data.AFF_MAX
	Game.buy_or_equip_outfit("wizard")
	ok(not Game.S.ownedOutfits.has("wizard"), "앞 단계 옷 없이 건너뛰기 불가")
	for o in Data.OUTFITS: Game.buy_or_equip_outfit(o.id)
	ok(Game.S.ownedOutfits.size() == 6 and Game.S.outfit == "pirate", "옷 6벌 순서대로 구매·착용")
	Game.buy_or_equip_outfit("none")
	ok(Game.S.outfit == "none", "기본 까미로 갈아입기")

	print("[6] 저장 / 불러오기 / 초기화")
	Game.save()
	var loaded := Game._load()
	ok(loaded.coins == Game.S.coins and loaded.upg.rod == 8 and loaded.ownedOutfits.size() == 6, "저장 파일 왕복")
	Game.reset_all()
	ok(Game.S.coins == 0 and Game.S.upg.rod == 1 and Game.S.creel.is_empty(), "기록 초기화")

	print("[7] 날씨 전용 초월 물고기")
	Game.set_weather("storm", false)
	var got_trans := false
	Game.S.upg.bait = 8
	for i in 3000:
		if Game.roll_fish(1.0).id == "titanic": got_trans = true; break
	ok(got_trans, "폭풍에서 타이타닉호가 낚일 수 있음")
	Game.set_weather("clear", false)
	var leak := false
	for i in 3000:
		if Game.roll_fish(1.0).r == "trans": leak = true; break
	ok(not leak, "맑은 날엔 초월 물고기가 안 나옴")
	Game.reset_all()

	print("\nSELFTEST: %d/%d passed" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)
