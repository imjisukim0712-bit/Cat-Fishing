# 까미와 밤낚시 — Godot 버전

루트의 `index.html`(웹 버전)을 **Godot 4.7** 로 옮긴 프로젝트입니다. 게임 규칙·데이터·대사·연출은 웹 버전과 동일합니다.

## 실행

1. [Godot 4.7.x](https://godotengine.org/download) (Standard, GDScript) 설치
2. Godot 프로젝트 매니저 → **가져오기** → 이 폴더의 `project.godot` 선택
3. ▶ 실행 (F5)

조작: **스페이스 / 클릭** = 던지기 · 챔질 · 릴 감기, **S** 상점, **C** 어망, **D** 도감, **Esc** 창 닫기

## 구조

| 파일 | 역할 |
|---|---|
| `scripts/data.gd` (오토로드 `Data`) | 물고기 51종, 등급, 업그레이드, 옷, 날씨, 까미 대사, 폰트, 물고기 그림 |
| `scripts/game.gd` (오토로드 `Game`) | 게임 상태·규칙 (낚시 단계, 물고기 뽑기, 먹이, 상점, 날씨, 저장) |
| `scripts/sfx.gd` (오토로드 `Sfx`) | 웹 버전의 합성 효과음을 같은 파형으로 렌더링해 재생 |
| `scripts/stage.gd` | 무대 그리기 (하늘·달·물·부두·까미·옷·낚싯대·파티클·날씨·게이지) |
| `scripts/main.gd` | 화면 구성 (상단바, 말풍선, 상태줄, 축하 연출, 어망/상점/도감/결과 창, 입력) |
| `assets/fish/*.svg` | 웹 버전에 내장돼 있던 물고기 그림을 파일로 분리한 것 |
| `assets/fonts/` | Pretendard(본문) + Twemoji(이모지) — 웹 익스포트엔 시스템 폰트가 없어서 번들 |

화면 좌표는 웹 버전 캔버스와 같은 960×540 을 그대로 씁니다.

## 개발용 도구

```bash
# 규칙 자동 점검 (실제 입력으로 한 판을 끝까지 + 상점·먹이·옷·저장·초기화)
godot --path godot -- --selftest

# 주요 화면 스크린샷 14장 저장
godot --path godot -- --shots=/저장할/폴더
```

화면이 없는 서버에서는 `xvfb-run -a godot --rendering-driver opengl3 ...` 로 실행하면 됩니다.

## 웹 버전과 다른 점

- 저장 데이터는 웹 버전(브라우저 localStorage)과 따로 저장됩니다 (`user://kkami-fishing-v1.json`).
- 화면은 1000×660 가로 비율로 고정되고, 창 크기에 맞춰 늘어납니다. 세로 모바일 전용 배치는 아직 없습니다.

## 라이선스 / 출처

- Pretendard — SIL Open Font License 1.1 (`assets/fonts/LICENSE-Pretendard.txt`)
- Twemoji Mozilla — 그래픽 © Twitter, Inc. 외, [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/), [mozilla/twemoji-colr](https://github.com/mozilla/twemoji-colr)
