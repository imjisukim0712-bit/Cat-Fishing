shader_type canvas_item;
// 배경 그림의 바다 부분을 '한 방향으로' 흐르게 하는 셰이더.
// 모든 움직임이 하나의 물결 위상(phase)을 공유한다:
//   물결 마루는 수평선 → 보는 사람 쪽으로 일정한 속도로 밀려오고, 살짝 오른쪽으로 비스듬히 흐른다.
//   반짝임은 그 마루 위에만 생기고 마루와 같이 이동한다. 달빛 기둥 반짝임도 같은 흐름을 탄다.
// 하늘·산(수평선 위)은 건드리지 않는다.

uniform float horizon = 0.5823;     // 그림에서 수평선 높이 (548 / 941)
uniform float moon_x = 0.794;       // 달빛 기둥 가로 위치 (1327 / 1672)
uniform float strength = 1.0;       // 날씨(폭풍·만조)에 따라 키움
uniform float speed = 0.35;         // 물결이 밀려오는 속도
uniform float drift = 0.06;         // 물결 마루의 기울기(오른쪽으로 흐르는 정도)

// 원근 깊이: 수평선 근처는 촘촘하게, 가까울수록 넓게 (1/z 형태)
float depth_coord(float d) {
	return 1.0 / (d + 0.12);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	vec4 col;
	if (uv.y <= horizon) {
		col = texture(TEXTURE, uv);
	} else {
		float d = clamp((uv.y - horizon) / (1.0 - horizon), 0.0, 1.0);   // 0 = 수평선, 1 = 맨 아래
		float z = depth_coord(d);
		// 하나의 위상: 깊이 방향으로 진행(밀려옴) + 가로로 살짝 기울어 오른쪽으로 흐름
		float phase = z * 9.0 + uv.x * drift * 40.0 * (0.4 + d) + t * speed * 6.2832;
		float amp = mix(0.0003, 0.0040, d * d) * strength;
		vec2 w = uv;
		w.y += sin(phase) * amp;                 // 마루가 지나갈 때 위아래로
		w.x += cos(phase) * amp * 0.35;          // 원운동(같은 위상) — 제멋대로 흔들리지 않음
		w.y = max(w.y, horizon + 0.002);
		col = texture(TEXTURE, w);

		// 마루 위 반짝임: 마루(sin≈1)에서만, 가로로는 일정한 간격의 결을 따라 같은 방향으로 이동
		float crest = smoothstep(0.82, 1.0, sin(phase));
		// 두 주파수(비율이 정수배가 아님)를 곱해 간격이 기계적으로 일정해 보이지 않게, 이동 방향은 같게
		float gx = (uv.x - t * 0.012) * mix(260.0, 70.0, d) + z * 3.0;
		float grain = (0.5 + 0.5 * sin(gx)) * (0.45 + 0.55 * sin(gx * 0.37 + 1.3 + z));
		float lum = dot(col.rgb, vec3(0.3, 0.5, 0.2));
		col.rgb += crest * smoothstep(0.35, 1.0, grain) * lum * (0.10 + 0.40 * d) * strength;

		// 달빛 기둥: 같은 위상으로 아래로 흘러내리는 반짝임
		float column = exp(-pow((uv.x - moon_x) / 0.026, 2.0)) * (1.0 - d * 0.5);
		float glint = smoothstep(0.55, 1.0, sin(phase * 1.0));
		col.rgb += column * glint * vec3(1.0, 0.88, 0.66) * 0.28;
	}
	COLOR = col;
}
