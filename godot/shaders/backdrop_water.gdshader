shader_type canvas_item;
// 배경 그림의 바다 부분을 실제로 일렁이게 하는 셰이더.
// 수평선 아래만 UV 를 흔들고(원근: 멀수록 잘고 약하게, 가까울수록 크고 강하게),
// 밝은 물결 부분에 흐르는 반짝임과 달빛 기둥 일렁임을 더한다. 하늘·산은 건드리지 않는다.

uniform float horizon = 0.5823;     // 그림에서 수평선 높이 (548 / 941)
uniform float moon_x = 0.794;       // 달빛 기둥 가로 위치 (1327 / 1672)
uniform float strength = 1.0;       // 날씨(폭풍·만조)에 따라 키움

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float d = clamp((uv.y - horizon) / (1.0 - horizon), 0.0, 1.0);   // 0 = 수평선, 1 = 화면 맨 아래
	vec4 col;
	if (uv.y <= horizon) {
		col = texture(TEXTURE, uv);
	} else {
		float freq = mix(170.0, 30.0, d);                // 원근: 먼 물결은 촘촘하게
		float amp = mix(0.0004, 0.0062, d * d) * strength;
		vec2 w = uv;
		w.x += sin(uv.y * freq + t * 1.3) * amp * 0.6
			+ sin(uv.y * freq * 0.53 - t * 0.9 + uv.x * 18.0) * amp * 0.4;
		w.y += sin(uv.x * 34.0 + t * 1.1 + uv.y * freq * 0.3) * amp * 0.45;
		w.y = max(w.y, horizon + 0.002);                 // 하늘을 끌어오지 않게
		col = texture(TEXTURE, w);

		// 밝은 물결 위로 흐르는 반짝임 (원래 그림이 밝은 곳일수록 강하게)
		float lum = dot(col.rgb, vec3(0.3, 0.5, 0.2));
		float a = sin(uv.x * 85.0 + t * 1.9 + sin(uv.y * 130.0 - t * 1.6) * 2.2);
		float b = sin(uv.y * mix(320.0, 120.0, d) - t * 2.4 + uv.x * 9.0);
		float sparkle = smoothstep(0.62, 1.0, a * b);
		col.rgb += sparkle * lum * (0.18 + 0.45 * d) * strength;

		// 달빛 기둥: 가로로 살짝 흔들리며 반짝임
		float mx = moon_x + sin(uv.y * 210.0 + t * 2.2) * 0.004 * (0.4 + d);
		float column = exp(-pow((uv.x - mx) / 0.028, 2.0)) * (1.0 - d * 0.6);
		float glint = smoothstep(0.35, 1.0, sin(uv.y * 380.0 - t * 3.1) * sin(uv.x * 140.0 + t * 1.7));
		col.rgb += column * glint * vec3(1.0, 0.88, 0.66) * 0.32;
	}
	COLOR = col;
}
