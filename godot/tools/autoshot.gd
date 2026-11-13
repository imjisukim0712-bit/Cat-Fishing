extends Node
## 개발용: `godot -- --shots=DIR` 로 실행하면 주요 화면을 차례로 띄우고 스크린샷을 저장한다.
## 일반 실행에서는 main.gd 가 이 노드를 만들지 않으므로 아무 영향이 없다.

var dir := ""
var main: Control

func _ready() -> void:
	_run()

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])
	print("shot ", name)

func _run() -> void:
	Game.S = Game.default_state()
	Game.set_weather("clear", false)
	Game.hud_changed.emit()
	await _wait(1.6)
	await _shot("01-idle")
	Game.action(); await _wait(0.55)
	await _shot("02-power")
	Game.action(); await _wait(1.4)
	await _shot("03-wait")
	Game.start_bite(); await _wait(0.15)
	await _shot("04-bite")
	Game.hook_it(); await _wait(0.4)
	await _shot("05-fight")
	Game.fish = Game.build_fish(Data.FISH_BY_ID["moonw"], 0.6)
	Game.succeed(); await _wait(1.2)
	await _shot("06-legend-celebrate")
	await _wait(2.4)
	await _shot("07-result")
	main.close_modals(); await _wait(0.3)
	for id in ["bung", "trout", "gold", "kraken", "boot"]:
		Game.S.creel.append(Game.build_fish(Data.FISH_BY_ID[id], 0.5))
		Game.S.dex[id] = {"c": 2, "best": 30.5}
	Game.hud_changed.emit()
	main.open_creel(); await _wait(0.4)
	await _shot("08-creel")
	main.open_shop(); await _wait(0.4)
	await _shot("09-shop")
	Game.S.aff = Data.AFF_MAX; Game.S.coins = 300000
	main.close_modals()
	Game.buy_or_equip_outfit("hoodie"); Game.buy_or_equip_outfit("captain"); Game.buy_or_equip_outfit("wizard")
	main.open_shop(); await _wait(0.4)
	var sc := _find_scroll(main.modal_layer)
	if sc: sc.scroll_vertical = 10000
	await _wait(0.2)
	await _shot("10-shop-outfits")
	main.open_dex(); await _wait(0.4)
	await _shot("11-dex")
	main.close_modals()
	Game.set_weather("rain", true); await _wait(1.2)
	await _shot("12-rain-wizard")
	Game.set_weather("storm", false); Game.lightning = 0.8; await _wait(0.1)
	await _shot("13-storm")
	Game.set_weather("meteor", false); await _wait(1.5)
	await _shot("14-meteor")
	get_tree().quit()

func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer: return n
	for ch in n.get_children():
		var r := _find_scroll(ch)
		if r: return r
	return null
