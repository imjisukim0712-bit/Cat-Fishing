shader_type canvas_item;
// 광원 조명: 달(오른쪽 위, 차가운 빛), 랜턴(점광원, 따뜻한 빛, 거리 감쇠), 번개(전체 섬광).
// 그림 스프라이트의 외곽 중 광원을 향한 쪽에 테두리 빛, 랜턴 가까이는 면 전체가 따뜻해진다.

uniform vec2 lantern_pos = vec2(0.0);       // 랜턴 위치 (캔버스 좌표)
uniform float lantern = 1.0;                // 랜턴 밝기 (깜빡임)
uniform float lantern_radius = 190.0;
uniform vec2 moon_dir = vec2(0.85, -0.53);  // 달 방향 (화면 기준, y 아래가 +)
uniform float moon_light = 1.0;
uniform float lightning = 0.0;
uniform vec3 ambient = vec3(0.86, 0.88, 1.0);
uniform float rim_px = 7.0;                 // 테두리 빛 두께 (텍스처 픽셀)
uniform float submerge = 0.0;               // 부두용: 물에 잠기는 높이(UV). 0 이면 사용 안 함

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float lum = dot(c.rgb, vec3(0.3, 0.5, 0.2));
	float dark = 1.0 - smoothstep(0.3, 0.7, lum);     // 눈·장식 같은 밝은 부분엔 테두리 빛을 줄임
	vec2 px = TEXTURE_PIXEL_SIZE * rim_px;

	float rim_m = clamp(c.a - texture(TEXTURE, UV + moon_dir * px).a, 0.0, 1.0);
	vec2 to_l = lantern_pos - world;
	float dist = length(to_l);
	vec2 ld = to_l / max(dist, 0.001);
	float rim_l = clamp(c.a - texture(TEXTURE, UV + ld * px).a, 0.0, 1.0);
	float fall = lantern * pow(1.0 - smoothstep(0.0, lantern_radius, dist), 1.6);

	vec3 col = c.rgb * ambient;
	col += c.rgb * vec3(1.0, 0.6, 0.28) * fall * 0.75;               // 랜턴 확산광
	col += vec3(1.0, 0.64, 0.32) * rim_l * fall * 1.1 * dark;          // 랜턴 쪽 테두리
	col += vec3(0.62, 0.74, 1.0) * rim_m * moon_light * 0.55 * dark;   // 달 쪽 테두리
	col += c.rgb * lightning * 0.9 + vec3(0.75, 0.85, 1.0) * rim_m * lightning;

	if (submerge > 0.0) {   // 부두 기둥이 물에 잠기는 부분
		float sub = smoothstep(submerge, 1.0, UV.y);
		col = mix(col, vec3(0.035, 0.17, 0.27), sub * 0.68);
		c.a *= 1.0 - smoothstep(0.75, 1.0, UV.y) * 0.8;
	}
	COLOR = vec4(col, c.a);
}
