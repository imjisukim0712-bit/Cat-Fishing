shader_type canvas_item;
// 배경 그림의 바다 자체를 '한 방향으로 흘러가게' 하는 셰이더 (플로우맵 방식).
// 같은 바다 그림을 흐름 방향(수평선 → 보는 사람, 살짝 오른쪽)으로 시간차를 두고 두 번 읽어
// 서로 교차시키며 섞는다. 그러면 그려진 물결 모양이 끊김 없이 계속 밀려오는 것처럼 보인다.
// 이동량은 원근에 맞춘다: 먼 물은 느리게, 가까운 물은 빠르게. 하늘·산(수평선 위)은 그대로.

uniform float horizon = 0.5823;     // 그림에서 수평선 높이 (548 / 941)
uniform float strength = 1.0;       // 날씨(폭풍·만조)에 따라 흐름을 빠르게
uniform float cycle = 3.2;          // 한 번 흘러가는 주기(초)
uniform float travel = 0.11;        // 한 주기 동안 깊이 방향으로 흘러오는 양
uniform float drift = 0.010;        // 한 주기 동안 오른쪽으로 흐르는 양

float z_of(float d) { return 1.0 / (d + 0.12); }          // 원근 깊이 (수평선 쪽이 큼)
float d_of(float z) { return 1.0 / z - 0.12; }

vec4 sample_flow(sampler2D tex, vec2 uv, float d, float k) {
	// k(0~1) 만큼 흘러온 상태: 지금 이 자리에는 '조금 더 먼 곳'에 있던 물이 와 있다
	float z = z_of(d) + travel * k * strength;
	float ds = max(d_of(z), 0.004);
	vec2 s = vec2(uv.x - drift * k * strength * (0.3 + d), horizon + ds * (1.0 - horizon));
	return texture(tex, s);
}

void fragment() {
	vec2 uv = UV;
	if (uv.y <= horizon) {
		COLOR = texture(TEXTURE, uv);
	} else {
		float d = clamp((uv.y - horizon) / (1.0 - horizon), 0.0, 1.0);   // 0 = 수평선, 1 = 맨 아래
		float t = TIME * strength / cycle;
		float p0 = fract(t);
		float p1 = fract(t + 0.5);
		vec4 a = sample_flow(TEXTURE, uv, d, p0);
		vec4 b = sample_flow(TEXTURE, uv, d, p1);
		float mixk = abs(0.5 - p0) * 2.0;          // a 가 처음으로 돌아가는 순간엔 b 만 보이게
		COLOR = mix(a, b, mixk);
	}
}
