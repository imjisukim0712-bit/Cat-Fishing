shader_type canvas_item;
// 파스텔 두들용 조명: 그림의 단색 면을 해치지 않도록 그라데이션 광택 없이 '색조'만 살짝 바꾼다.
//  - 랜턴 가까이는 따뜻한 빛이 은은하게 물든다 (깜빡임 따라)
//  - 구름이 달을 가리거나 궂은 날씨엔 조금 어두워진다
//  - 번개가 치면 전체가 하얗게 번쩍
//  - 부두 기둥은 물에 잠긴 부분이 바다색으로 덮이고 수면선이 또렷하게 그려진다

uniform vec2 lantern_pos = vec2(0.0);       // 랜턴 위치 (캔버스 좌표)
uniform float lantern = 1.0;                // 랜턴 밝기 (깜빡임)
uniform float lantern_radius = 170.0;
uniform vec2 moon_dir = vec2(0.85, -0.53);  // (호환용)
uniform float moon_light = 1.0;
uniform float lightning = 0.0;
uniform vec3 ambient = vec3(1.0);
uniform float rim_px = 0.0;                 // (호환용)
uniform float submerge = 0.0;               // 부두용: 물에 잠기는 높이(UV). 0 이면 사용 안 함
uniform vec3 sea_col = vec3(0.10, 0.36, 0.52);
uniform vec3 line_col = vec3(0.24, 0.14, 0.27);
uniform vec3 fur_shift = vec3(0.0);        // 어두운 털을 이만큼 밝힘 (선·명암 차이는 유지)
uniform float outline_px = 0.0;            // 0 보다 크면 그림 바깥에 두들 테두리 (화면 픽셀 두께)

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;   // Godot 4: COLOR 는 이미 텍스처 색 × 모듈레이트
	if (outline_px > 0.0 && c.a < 0.95) {
		// 화면 픽셀 기준 두께 (꼬리·앞발처럼 작게 그린 부품도 몸과 같은 굵기),
		// 24방향 × 2겹으로 매끈하게, 흰 수염처럼 밝은 가는 선 둘레엔 테두리를 만들지 않음
		vec2 px = fwidth(UV) * outline_px;
		float n = 0.0;
		for (int r = 0; r < 2; r++) {
			float k = r == 0 ? 1.0 : 0.55;
			for (int i = 0; i < 24; i++) {
				float a = float(i) * 0.261799;
				vec4 sm = texture(TEXTURE, UV + vec2(cos(a), sin(a)) * px * k);
				float sl = dot(sm.rgb, vec3(0.3, 0.5, 0.2));
				n = max(n, sm.a * (1.0 - smoothstep(0.5, 0.75, sl)));
			}
		}
		n = smoothstep(0.2, 0.65, n);
		vec4 edge = vec4(line_col, n);
		c = mix(edge, vec4(c.rgb, 1.0), c.a);
		c.a = max(c.a, edge.a);
	}
	float lum = dot(c.rgb, vec3(0.3, 0.5, 0.2));
	// 털(어둡고 채도 낮은 면)만 밝히고, 자주색 선은 그대로 두어 선이 또렷하게
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c.rgb += fur_shift * (1.0 - smoothstep(0.2, 0.4, lum)) * (1.0 - smoothstep(0.05, 0.12, sat)) * step(0.001, c.a);
	float dist = length(lantern_pos - world);
	float fall = lantern * (1.0 - smoothstep(lantern_radius * 0.25, lantern_radius, dist));

	vec3 col = c.rgb * ambient;
	col = mix(col, col * vec3(1.12, 1.0, 0.82) + vec3(0.05, 0.03, 0.0), fall * 0.15);   // 따뜻하게 물듦
	col = mix(col, vec3(1.0), lightning * 0.55);

	if (submerge > 0.0) {   // 부두 기둥이 물에 잠기는 부분
		float wl = submerge + 0.004 * sin(TIME * 2.0 + world.x * 0.05);
		float sub = step(wl, UV.y);
		col = mix(col, mix(c.rgb, sea_col, 0.72), sub);
		float edge = 1.0 - smoothstep(0.0, 0.006, abs(UV.y - wl));
		col = mix(col, line_col, edge * c.a);
		c.a *= 1.0 - smoothstep(0.8, 1.0, UV.y);
	}
	COLOR = vec4(col, c.a);
}
