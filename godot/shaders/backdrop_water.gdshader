shader_type canvas_item;
// 배경 그림의 바다를 살아 움직이게 하는 셰이더.
// 이음매 없는 물결 노멀맵(노이즈)을 '원근이 적용된 수면 좌표'에 깔고, 한 방향(수평선 → 보는 사람,
// 살짝 오른쪽)으로 흘린다. 그 노멀로 그림을 굴절시키고(물결이 일렁임), 노멀이 달 쪽을 향할 때
// 반짝임을 더한다(움직이는 물결 하이라이트). 두 장면을 섞지 않으므로 겹쳐 보이는 현상이 없다.
// 하늘·산(수평선 위)은 그대로 둔다.

uniform float horizon = 0.5823;          // 그림에서 수평선 높이 (548 / 941)
uniform float moon_x = 0.794;            // 달빛 기둥 가로 위치 (1327 / 1672)
uniform float strength = 1.0;            // 날씨(폭풍·만조)에 따라 크고 빠르게
uniform sampler2D wave_normal : repeat_enable, filter_linear_mipmap;   // 이음매 없는 물결 노멀맵
uniform float speed = 0.22;              // 물결이 밀려오는 속도 (수면 좌표/초)
uniform float side = 0.05;               // 오른쪽으로 흐르는 정도

vec2 wave(vec2 p, float t) {
	// 같은 방향으로 흐르는 두 겹(큰 물결 + 잔물결). 속도만 다르고 방향은 같다.
	vec2 n1 = texture(wave_normal, p * 0.55 + vec2(side, 1.0) * t * speed).rg * 2.0 - 1.0;
	vec2 n2 = texture(wave_normal, p * 1.7 + vec2(side, 1.0) * t * speed * 1.6 + vec2(0.37, 0.11)).rg * 2.0 - 1.0;
	return n1 * 0.65 + n2 * 0.35;
}

void fragment() {
	vec2 uv = UV;
	if (uv.y <= horizon) {
		COLOR = texture(TEXTURE, uv);
	} else {
		float t = TIME * (0.6 + 0.4 * strength);
		float d = clamp((uv.y - horizon) / (1.0 - horizon), 0.0, 1.0);   // 0 = 수평선, 1 = 맨 아래
		float z = 1.0 / (d + 0.10);                                     // 원근 깊이 (멀수록 큼)
		// 원근 수면 좌표: 멀수록 가로로 넓게(작게 보임), 깊이 방향은 z. 흐름은 z 가 줄어드는 쪽(보는 사람 쪽).
		vec2 p = vec2((uv.x - 0.5) * z * 1.6, z * 0.9);
		vec2 n = wave(p, t);

		// 굴절: 가까울수록 크게 일렁임 (수평선 근처는 거의 0)
		float amp = mix(0.0008, 0.010, smoothstep(0.0, 1.0, d)) * strength;
		vec2 s = uv + n * amp * vec2(0.6, 1.0);
		s.y = max(s.y, horizon + 0.002);
		vec4 col = texture(TEXTURE, s);

		// 물결 하이라이트: 노멀이 달 쪽(오른쪽 위)을 향할 때. 그림이 밝은 곳(달빛 기둥, 아래쪽 발광)일수록 강하게.
		vec2 to_moon = normalize(vec2((moon_x - uv.x) * 1.4, -1.0));
		float facing = max(dot(normalize(n + vec2(0.0001)), to_moon), 0.0);
		float spec = pow(facing, 10.0) * smoothstep(0.15, 0.9, length(n));
		float lum = dot(col.rgb, vec3(0.3, 0.5, 0.2));
		float column = exp(-pow((uv.x - moon_x) / 0.035, 2.0));
		vec3 moon_tint = vec3(1.0, 0.9, 0.7);
		vec3 sea_tint = vec3(0.55, 1.0, 1.0);
		col.rgb += spec * (column * moon_tint * 0.55 + sea_tint * lum * (0.25 + 0.6 * d)) * (0.5 + 0.5 * strength);
		COLOR = col;
	}
}
