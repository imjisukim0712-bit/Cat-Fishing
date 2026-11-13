extends Node
## 까미와 밤낚시 — 정적 게임 데이터 (원본 index.html 의 데이터 블록을 그대로 옮김)

const RARITY := {
	"junk":   {"key": "junk",   "name": "잡동사니", "col": Color("#8d93a3"), "w": 16.0,  "need": 2, "spd": 0.50, "zone": 1.35},
	"common": {"key": "common", "name": "일반",     "col": Color("#cfd9ef"), "w": 48.0,  "need": 3, "spd": 0.72, "zone": 1.15},
	"rare":   {"key": "rare",   "name": "희귀",     "col": Color("#49a6ff"), "w": 23.0,  "need": 3, "spd": 0.95, "zone": 1.00},
	"epic":   {"key": "epic",   "name": "영웅",     "col": Color("#b06bff"), "w": 9.5,   "need": 4, "spd": 1.18, "zone": 0.84},
	"legend": {"key": "legend", "name": "전설",     "col": Color("#ffb020"), "w": 2.2,   "need": 5, "spd": 1.45, "zone": 0.66},
	"myth":   {"key": "myth",   "name": "신화",     "col": Color("#ff2d3a"), "w": 0.35,  "need": 6, "spd": 1.70, "zone": 0.52},
	"trans":  {"key": "trans",  "name": "초월",     "col": Color("#fff4d6"), "w": 0.0,   "need": 7, "spd": 2.00, "zone": 0.40},
}
const RORDER := ["junk", "common", "rare", "epic", "legend", "myth", "trans"]

const FISH := [
	{"id": "boot",    "n": "낡은 장화",       "e": "👢", "r": "junk",   "p": 3,    "cm": [20, 32]},
	{"id": "can",     "n": "찌그러진 깡통",   "e": "🥫", "r": "junk",   "p": 4,    "cm": [10, 16]},
	{"id": "news",    "n": "젖은 신문지",     "e": "📰", "r": "junk",   "p": 2,    "cm": [25, 40]},
	{"id": "weed",    "n": "해초 뭉치",       "e": "🌿", "r": "junk",   "p": 3,    "cm": [15, 55]},

	{"id": "bung",    "n": "붕어",            "e": "🐟", "r": "common", "p": 9,    "cm": [12, 26]},
	{"id": "pira",    "n": "피라미",          "e": "🐠", "r": "common", "p": 7,    "cm": [7, 15]},
	{"id": "song",    "n": "송사리",          "e": "🐟", "r": "common", "p": 6,    "cm": [3, 8]},
	{"id": "loach",   "n": "미꾸라지",        "e": "🪱", "r": "common", "p": 12,   "cm": [10, 22]},
	{"id": "crab",    "n": "참게",            "e": "🦀", "r": "common", "p": 15,   "cm": [8, 17]},

	{"id": "trout",   "n": "무지개송어",      "e": "🐡", "r": "rare",   "p": 34,   "cm": [28, 52]},
	{"id": "carp",    "n": "잉어",            "e": "🐠", "r": "rare",   "p": 42,   "cm": [35, 70]},
	{"id": "turtle",  "n": "자라",            "e": "🐢", "r": "rare",   "p": 48,   "cm": [20, 38]},
	{"id": "ssogari", "n": "쏘가리",          "e": "🐟", "r": "rare",   "p": 38,   "cm": [25, 45]},
	{"id": "squid",   "n": "한치",            "e": "🦑", "r": "rare",   "p": 40,   "cm": [18, 34]},
	{"id": "salmon",  "n": "연어",            "e": "🐟", "r": "rare",   "p": 45,   "cm": [45, 85]},
	{"id": "bass",    "n": "농어",            "e": "🐟", "r": "rare",   "p": 52,   "cm": [35, 90]},
	{"id": "snakeh",  "n": "가물치",          "e": "🐍", "r": "rare",   "p": 55,   "cm": [40, 100]},
	{"id": "puffer",  "n": "복어",            "e": "🐡", "r": "rare",   "p": 58,   "cm": [20, 50]},
	{"id": "eel",     "n": "민물장어",        "e": "〰️", "r": "rare",   "p": 62,   "cm": [45, 120]},

	{"id": "gold",    "n": "황금잉어",        "e": "🪙", "r": "epic",   "p": 150,  "cm": [40, 80]},
	{"id": "angler",  "n": "심해아귀",        "e": "🎣", "r": "epic",   "p": 180,  "cm": [45, 95]},
	{"id": "octo",    "n": "대왕문어",        "e": "🐙", "r": "epic",   "p": 165,  "cm": [60, 140]},
	{"id": "sturg",   "n": "철갑상어",        "e": "🦈", "r": "epic",   "p": 200,  "cm": [90, 180]},
	{"id": "tuna",    "n": "참다랑어",        "e": "🐟", "r": "epic",   "p": 210,  "cm": [120, 280]},
	{"id": "marlin",  "n": "청새치",          "e": "🗡️", "r": "epic",   "p": 225,  "cm": [180, 400]},
	{"id": "sail",    "n": "돛새치",          "e": "⛵", "r": "epic",   "p": 235,  "cm": [170, 340]},
	{"id": "manta",   "n": "대왕쥐가오리",    "e": "🪽", "r": "epic",   "p": 250,  "cm": [300, 700]},
	{"id": "white",   "n": "백상아리",        "e": "🦈", "r": "epic",   "p": 280,  "cm": [350, 650]},
	{"id": "oarfish", "n": "산갈치",          "e": "🐲", "r": "epic",   "p": 265,  "cm": [300, 900]},

	{"id": "moonw",   "n": "달빛고래",        "e": "🐋", "r": "legend", "p": 820,  "cm": [200, 420]},
	{"id": "starray", "n": "별자리 가오리",   "e": "✨", "r": "legend", "p": 900,  "cm": [150, 300]},
	{"id": "dragon",  "n": "용왕의 비단잉어", "e": "🐉", "r": "legend", "p": 1100, "cm": [120, 260]},
	{"id": "catfish", "n": "냥어(猫魚)",      "e": "🐱", "r": "legend", "p": 1300, "cm": [30, 66]},
	{"id": "aurorad", "n": "오로라 해룡",     "e": "🌌", "r": "legend", "p": 1050, "cm": [160, 360]},
	{"id": "mosa",    "n": "모사사우르스",    "e": "🐊", "r": "legend", "p": 1450, "cm": [350, 700]},

	{"id": "nessie",  "n": "네시",            "e": "🦕", "r": "myth",   "p": 4200, "cm": [900, 1800]},
	{"id": "leviath", "n": "레비아탄",        "e": "🐉", "r": "myth",   "p": 6800, "cm": [1800, 4200]},
	{"id": "kraken",  "n": "크라켄",          "e": "🦑", "r": "myth",   "p": 5500, "cm": [1400, 3200]},
	{"id": "jormung", "n": "요르문간드",      "e": "🐍", "r": "myth",   "p": 7200, "cm": [2400, 5200]},
	{"id": "makara",  "n": "마카라",          "e": "🐊", "r": "myth",   "p": 4600, "cm": [800, 1700]},
	{"id": "aspido",  "n": "아스피도켈론",    "e": "🐢", "r": "myth",   "p": 6000, "cm": [1600, 3600]},
	{"id": "umibozu", "n": "우미보즈",        "e": "🌊", "r": "myth",   "p": 4800, "cm": [1000, 2500]},
	{"id": "bahamut", "n": "바하무트",        "e": "🐋", "r": "myth",   "p": 7500, "cm": [2600, 6000]},
	{"id": "kun",     "n": "곤(鯤)",          "e": "☁️", "r": "myth",   "p": 8000, "cm": [3000, 7000]},
	{"id": "charyb",  "n": "카리브디스",      "e": "🌀", "r": "myth",   "p": 6500, "cm": [2000, 4800]},
	{"id": "godzilla","n": "고질라",          "e": "🦖", "r": "myth",   "p": 15000,"cm": [8000, 20000]},

	# 초월급 — 날씨 전용, 해당 날씨가 아니면 절대 낚이지 않음
	{"id": "yongwang","n": "용왕",            "e": "🐲", "r": "trans",  "p": 22000,"cm": [3000, 8000],   "wk": "rain"},
	{"id": "mermaid", "n": "인어공주",        "e": "🧜‍♀️", "r": "trans",  "p": 22000,"cm": [150, 220],    "wk": "fog"},
	{"id": "goldaxe", "n": "금도끼",          "e": "🪓", "r": "trans",  "p": 34000,"cm": [45, 90],      "wk": "meteor"},
	{"id": "poseidon","n": "포세이돈",        "e": "🔱", "r": "trans",  "p": 30000,"cm": [400, 900],    "wk": "hightide"},
	{"id": "titanic", "n": "타이타닉호",      "e": "🚢", "r": "trans",  "p": 42000,"cm": [18000, 32000],"wk": "storm"},
]

## 까미의 농담 (이스터에그)
const JOKES := [
	"물고기가 화나면 뭐라고 하게? “어이가 없네!” … 어이. 물고기. 어? 알겠어?",
	"낚시꾼이 제일 좋아하는 대답이 뭔지 알아? “물론이지.”",
	"물고기는 왜 학교에 안 가? 이미 스쿨(school)에 있으니까. 영어 개그야. 웃어.",
	"제일 비싼 물고기가 뭐게? 금붕어. 금이잖아. 경제 공부 좀 해.",
	"물고기 두 마리가 수조에 있었대. 한 마리가 그랬대. “야, 이거 어떻게 운전해?”",
	"물고기가 다이어트에 실패하는 이유? 하루 종일 물만 먹었는데도 그대로래.",
	"고양이가 생선가게를 열면 어떻게 될까? … 3일 만에 폐업. 재고가 사라져.",
	"얘 이름 물어봤는데 대답을 안 해. 하긴, 입만 뻐끔거리더라.",
	"나랑 물고기랑 싸우면 누가 이겨? 당연히 나지. 나는 앞발이 두 개나 있어.",
	"어제 나도 물에 들어가 봤어. … 농담이야. 미쳤니?",
	"참치가 왜 참치게? 참을성이 많아서. 나는 못 참아. 그거 이리 줘.",
	"밤낚시가 좋은 이유? 물고기도 야근하는 줄 알고 갑자기 동질감이 들거든.",
	"생선을 세 글자로 줄이면? “내 거야.”",
	"낚싯대를 영어로 로드(rod)라고 하잖아. 그래서 잃어버리면 로드 실패야.",
	"물고기가 제일 무서워하는 게 뭔지 알아? 튀김옷.",
	"내가 오늘 아침에 잡혔어. 낮잠한테.",
	"물고기는 절대 비밀을 못 지켜. 다 비늘이 새거든. … 미안, 이건 좀 억지다.",
	"우리 집 규칙 알아? 네가 잡으면 내가 먹는다. 완벽한 분업이지.",
	"물고기가 헬스장에 가면 뭘 할까? 물살 키우기.",
	"왜 물고기는 항상 쿨할까? 늘 찬물에 있으니까. 나는 이불 속이 좋아.",
]
const LEGEND_JOKES := [
	"…잠깐. 이거 진짜야? 나 이런 거 처음 봐. 만져도 돼? 아니 먹어도 돼?",
	"전설의 물고기를 나한테 준다고? 너… 좋은 집사구나. 오늘부터 내 무릎 사용권 줄게.",
	"이건 못 먹겠어. 액자에 넣자. 아니다, 반만 먹고 반은 액자에 넣자.",
	"이 정도면 나 SNS 해야 돼. 냥스타그램 아이디 뭐로 하지?",
]
const MYTH_JOKES := [
	"집사야… 이건 물고기가 아니라 신화책에서 탈출한 것 같은데? 그래도 한입만.",
	"내가 고양이라 목숨이 아홉 개라지만, 이걸 먹는 데 전부 쓰고 싶진 않아.",
	"이걸 낚았다고? 이제부터 집사가 아니라 용사라고 불러줄게. 가끔만.",
	"잠깐, 얘 눈 떴어. 우리 둘 다 못 본 척하자. 코인은 챙기고.",
]
const CATFISH_LINE := "야. 잠깐만. 이거… 나랑 닮았는데? 혹시 내 먼 친척이야? 어… 이건 좀 못 먹겠다. 놔줄까? …아니다, 일단 코인은 챙기자."
const GODZILLA_LINE := "…집사야. 이거 도쿄 몇 번 부순 그 몸집인데? 일단 조용히 어망에 넣자. 아무도 못 본 걸로 하자."
const TRANS_JOKES := [
	"이건 그냥 물고기가 아니야. 전설이 나한테 낚였다고 자랑하러 온 거야.",
	"…나 지금 수염 떨려. 이거 실화냥? 사진 찍어둬, 아무도 안 믿을 거야.",
]
const TRANS_LINES := {
	"yongwang": "용왕님… 이라고요? 저기, 저 그냥 고양이인데요. 아, 코인은 감사히 받을게요.",
	"mermaid":  "인어공주라니. 노래 한 소절만 불러줘… 라고 하고 싶은데 목소리 들으면 나 홀릴까 봐 무서워.",
	"goldaxe":  "이건 물고기가 아니라 도끼잖아! …잠깐, 이거 금도끼 은도끼 설화 그거 아니야? 나 정직한 고양이거든? 은도끼도 내 거 할래.",
	"poseidon": "포, 포세이돈?! 삼지창 든 그분?! 집사야 우리 오늘부로 바다 쪽은 조용히 다니자.",
	"titanic":  "…배가 왜 낚여. 이거 심지어 가라앉은 그 배 아니야? 낚싯대로 배를 낚다니, 너 사기캐릭터였구나.",
}

## 업그레이드
const UPG := [
	{"k": "rod",   "e": "🎣", "n": "낚싯대",    "max": 8, "tip": "타이밍 존이 넓어져요"},
	{"k": "reel",  "e": "⚙️", "n": "릴",        "max": 8, "tip": "표시기가 느려져 맞추기 쉬워요"},
	{"k": "float", "e": "🟠", "n": "찌",        "max": 8, "tip": "입질이 빨라지고 반응 시간이 늘어요"},
	{"k": "bait",  "e": "🦐", "n": "미끼",      "max": 8, "tip": "전설·신화급 조우 확률이 올라가요"},
	{"k": "charm", "e": "🧿", "n": "냥냥 부적", "max": 5, "tip": "까미의 축복으로 값을 더 받아요"},
]

const AFF_MAX := 60
const OUTFITS := [
	{"id": "hoodie",  "e": "🧥", "n": "빨간 후드",   "price": 50000,  "bonus": 5,  "d": "포근하고 장난기 넘치는 스트리트 룩"},
	{"id": "captain", "e": "⚓", "n": "선장 제복",   "price": 125000, "bonus": 8,  "d": "밤바다를 지휘하는 금장 제복"},
	{"id": "wizard",  "e": "🧙", "n": "별빛 마법사", "price": 185000, "bonus": 12, "d": "별가루가 반짝이는 마법 망토"},
	{"id": "space",   "e": "🚀", "n": "우주 탐사복", "price": 260000, "bonus": 16, "d": "달까지 낚싯줄을 던질 탐사 장비"},
	{"id": "royal",   "e": "👑", "n": "왕실 예복",   "price": 380000, "bonus": 20, "d": "까미 폐하를 위한 최고급 예복"},
	{"id": "pirate",  "e": "🏴‍☠️", "n": "해적왕 의상", "price": 500000, "bonus": 25, "d": "전설의 보물을 노리는 바다의 지배자"},
]

## 날씨
const WEATHERS := [
	{"key": "clear",    "name": "맑음",   "e": "🌙", "w": 44.0, "min": 80.0, "max": 150.0},
	{"key": "rain",     "name": "비",     "e": "🌧️", "w": 22.0, "min": 60.0, "max": 110.0, "fish": "yongwang"},
	{"key": "fog",      "name": "물안개", "e": "🌫️", "w": 18.0, "min": 60.0, "max": 110.0, "fish": "mermaid"},
	{"key": "hightide", "name": "만조",   "e": "🌊", "w": 12.0, "min": 70.0, "max": 120.0, "fish": "poseidon"},
	{"key": "meteor",   "name": "유성우", "e": "☄️", "w": 7.0,  "min": 45.0, "max": 80.0,  "fish": "goldaxe"},
	{"key": "storm",    "name": "폭풍",   "e": "⚡", "w": 4.0,  "min": 40.0, "max": 70.0,  "fish": "titanic"},
]
const WEATHER_FX := {
	"clear":    {"waitMul": 1.0,  "zoneMul": 1.0,  "rareMul": 1.0,  "sizeMul": 0.0,  "priceMul": 1.0,  "missBonus": 0},
	"rain":     {"waitMul": 0.55, "zoneMul": 1.0,  "rareMul": 1.15, "sizeMul": 0.0,  "priceMul": 1.0,  "missBonus": 0},
	"fog":      {"waitMul": 1.0,  "zoneMul": 0.8,  "rareMul": 1.0,  "sizeMul": 0.0,  "priceMul": 1.20, "missBonus": 0},
	"hightide": {"waitMul": 1.0,  "zoneMul": 1.0,  "rareMul": 1.0,  "sizeMul": 0.35, "priceMul": 1.0,  "missBonus": 0},
	"meteor":   {"waitMul": 1.0,  "zoneMul": 1.0,  "rareMul": 1.9,  "sizeMul": 0.0,  "priceMul": 1.0,  "missBonus": 0},
	"storm":    {"waitMul": 0.8,  "zoneMul": 0.75, "rareMul": 1.1,  "sizeMul": 0.0,  "priceMul": 1.35, "missBonus": -1},
}
const WEATHER_LINES := {
	"clear":    ["다시 맑아졌다. 별 보기 딱 좋네.", "평범한 밤. 이런 날도 나쁘지 않아."],
	"rain":     ["비 온다. 물고기들 신났나 봐, 입질이 빨라지겠어.", "비 맞는 거 딱 질색인데… 너는 즐거워 보이네."],
	"fog":      ["안개가 꼈어. 잘 안 보이지만 뭔가 특별한 게 지나간 느낌이야.", "물안개 속엔 원래 이상한 애들이 숨어 있어. 조심해."],
	"hightide": ["물이 차올랐어. 오늘은 커다란 녀석들이 나올 것 같은데?", "만조야. 부두 아래까지 찰랑찰랑하네."],
	"meteor":   ["어? 별똥별이다!! 소원 빌 시간 없어, 얼른 던져!!", "유성우 뜬 날은 심상치 않은 게 걸린다던데…"],
	"storm":    ["천둥소리… 하나도 안 무서운데 조금만 옆에 있어줄래.", "폭풍이야! 위험하지만… 오늘 뭔가 크게 걸릴 것 같아."],
}

var FISH_BY_ID := {}
var OUTFIT_BY_ID := {}
var WEATHER_BY_KEY := {}
var FISH_TEX := {}

## 폰트: 원본과 같은 Pretendard + 이모지용 Twemoji 폴백 (웹 익스포트엔 시스템 폰트가 없으므로 번들)
var font_regular: FontFile
var font_bold: FontFile
var font_heavy: FontFile

func _ready() -> void:
	for f in FISH: FISH_BY_ID[f.id] = f
	for o in OUTFITS: OUTFIT_BY_ID[o.id] = o
	for w in WEATHERS: WEATHER_BY_KEY[w.key] = w
	var emoji: FontFile = load("res://assets/fonts/TwemojiMozilla.ttf")
	font_regular = load("res://assets/fonts/Pretendard-Regular.otf")
	font_bold = load("res://assets/fonts/Pretendard-Bold.otf")
	font_heavy = load("res://assets/fonts/Pretendard-ExtraBold.otf")
	for f in [font_regular, font_bold, font_heavy]:
		f.fallbacks = [emoji]

## 물고기 그림 (그림 화풍 PNG 우선, 없으면 원본에서 분리한 SVG)
func fish_texture(id: String) -> Texture2D:
	if FISH_TEX.has(id): return FISH_TEX[id]
	var tex: Texture2D = null
	for path in ["res://assets/art/fish/%s.png" % id, "res://assets/fish/%s.svg" % id]:
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	FISH_TEX[id] = tex
	return tex

## UI 아이콘: 이모지 대신 쓰는 그림 아이콘 (assets/art/icons)
const EMOJI_ICON := {
	"🐈‍⬛": "kkami_head", "🪙": "coin", "💗": "heart",
	"🌙": "w_clear", "🌧️": "w_rain", "🌧": "w_rain", "🌫️": "w_fog", "🌫": "w_fog", "🌊": "w_hightide",
	"☄️": "w_meteor", "☄": "w_meteor", "⚡": "w_storm",
	"🧺": "creel", "🛒": "shop", "📖": "dex", "🔊": "sound_on", "🔇": "sound_off",
	"🎣": "rod", "⚙️": "reel", "⚙": "reel", "🟠": "float", "🦐": "bait", "🧿": "charm",
	"🐾": "paw", "🔒": "lock", "🔓": "lock", "✨": "sparkle",
}
var ICON_TEX := {}

func icon(name: String) -> Texture2D:
	if not ICON_TEX.has(name):
		var path := "res://assets/art/icons/%s.png" % name
		ICON_TEX[name] = load(path) if ResourceLoader.exists(path) else null
	return ICON_TEX[name]

## 문장 속 이모지를 그림 아이콘 [img] 로 바꾼 BBCode (RichTextLabel 용)
func emoji_bb(text: String, px := 16) -> String:
	for e in EMOJI_ICON:
		if text.contains(e) and icon(EMOJI_ICON[e]):
			text = text.replace(e, "[img=%dx%d]res://assets/art/icons/%s.png[/img]" % [px, px, EMOJI_ICON[e]])
	return text

## 맨 앞 이모지를 아이콘 이름과 나머지 글자로 분리 ("🪙 55" → ["coin", "55"])
func split_icon(text: String) -> Array:
	for e in EMOJI_ICON:
		if text.begins_with(e) and icon(EMOJI_ICON[e]):
			return [EMOJI_ICON[e], text.substr(e.length()).strip_edges()]
	return ["", text]

## 업그레이드 비용·설명 (원본의 cost/d 람다)
static func js_round(x: float) -> int:
	return int(floor(x + 0.5))

static func upg_cost(k: String, l: int) -> int:
	match k:
		"rod":   return js_round(55.0 * pow(1.85, l - 1))
		"reel":  return js_round(70.0 * pow(1.9, l - 1))
		"float": return js_round(45.0 * pow(1.8, l - 1))
		"bait":  return js_round(90.0 * pow(2.0, l - 1))
		"charm": return js_round(260.0 * pow(2.2, l - 1))
	return 0

static func upg_desc(k: String, l: int) -> String:
	match k:
		"rod":   return "챔질 판정 범위 +%d%%" % js_round(((0.20 + 0.019 * (l - 1)) / 0.20 - 1.0) * 100.0)
		"reel":  return "바늘 이동 속도 -%d%%" % js_round((1.0 - maxf(0.5, 1.0 - 0.065 * (l - 1))) * 100.0)
		"float": return "입질 대기 -%.2f초 · 챔질 여유 +%.2f초" % [0.26 * (l - 1), 0.09 * (l - 1)]
		"bait":  return "희귀 이상 확률 ×%.2f" % (1.0 + 0.30 * (l - 1))
		"charm": return "판매가 +%d%%" % (13 * (l - 1))
	return ""

## 숫자 표시 헬퍼
static func comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

static func fmt_cm(cm: float) -> String:
	if is_equal_approx(cm, roundf(cm)): return str(int(roundf(cm)))
	return "%.1f" % cm
