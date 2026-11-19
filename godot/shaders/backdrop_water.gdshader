shader_type canvas_item;
// 파스텔 두들 배경 셰이더 — 단색 면 그림이라 빛 번짐·그라데이션은 더하지 않고, 그려진 모양만 움직인다.
//  하늘: 그림 속 크림색 별·반짝이 모양이 제각각 깜빡이고, 작은 반짝이가 군데군데 켜졌다 꺼진다.
//  바다: 단색 바다 위로 밝은 마루·어두운 골 줄무늬가 보는 쪽으로 밀려오고, 작은 반짝이가 깜빡인다.
//        (물결 낙서선·달빛 점선은 stage.gd 가 코드로 그려 함께 흘러간다)

uniform float horizon = 0.5919;          // 그림에서 바다가 시작되는 높이 (비율, 수평선 아래)
uniform float moon_x = 0.782;            // 달 가로 위치 (비율)
uniform vec2 moon_px = vec2(1308.0, 193.0);   // 그림 속 달 중심 (픽셀)
uniform float moon_r = 104.0;            // 그림 속 달 반지름 (픽셀, 후광 고리 포함)
uniform float strength = 1.0;            // 날씨(폭풍·만조)에 따라 크고 빠르게
uniform float moon_light = 1.0;          // (호환용) 궂은 날씨엔 달빛 점선이 덜 반짝임
uniform float lantern = 1.0;             // (호환용)
uniform float lantern_x = 0.04;          // (호환용)
uniform sampler2D wave_normal : repeat_enable, filter_linear_mipmap;
uniform sampler2D blob_noise : repeat_enable, filter_linear_mipmap;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// 원근 수면 좌표: z 는 깊이(멀수록 큼)
vec2 plane(vec2 uv) {
	float d = clamp((uv.y - horizon) / (1.0 - horizon), 0.0, 1.0);
	float z = 1.0 / (d + 0.10);
	return vec2((uv.x - 0.5) * z * 1.6, z);
}

// 너울 높이: 모두 보는 사람 쪽으로 진행
float swell(vec2 P, float t) {
	return 0.6 * sin(dot(P, normalize(vec2(0.10, 1.0))) * 2.6 + t * 1.2)
		+ 0.4 * sin(dot(P, normalize(vec2(-0.30, 1.0))) * 4.4 + t * 1.6 + 1.7);
}

// 작은 4각 반짝이 (선명한 단색 모양)
float sparkle(vec2 f, float s) {
	vec2 a = abs(f) / s;
	return step(a.x * a.y * 9.0 + (a.x + a.y) * 0.55, 0.35);
}

void fragment() {
	vec2 uv = UV;
	vec2 tex = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = uv * tex;
	vec3 cream = vec3(1.0, 0.96, 0.84);
	if (uv.y <= horizon) {
		// ================= 하늘 =================
		vec4 col = texture(TEXTURE, uv);
		float dm = length(p - moon_px);
		float away = step(moon_r * 1.25, dm);
		float lum = dot(col.rgb, vec3(0.3, 0.5, 0.2));
		float sat = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
		// 크림색(밝고 채도 낮은) 별·반짝이 모양만 골라 깜빡이게
		float star = smoothstep(0.62, 0.8, lum) * (1.0 - smoothstep(0.25, 0.45, sat)) * away;
		vec2 o = TEXTURE_PIXEL_SIZE * 16.0;
		vec3 sky = (texture(TEXTURE, uv + vec2(o.x, 0.0)).rgb + texture(TEXTURE, uv - vec2(o.x, 0.0)).rgb
			+ texture(TEXTURE, uv + vec2(0.0, o.y)).rgb + texture(TEXTURE, uv - vec2(0.0, o.y)).rgb) * 0.25;
		float hs = hash(floor(p / 36.0));
		float tw = 0.5 + 0.5 * sin(TIME * (1.0 + hs * 2.2) + hs * 50.0);
		col.rgb = mix(col.rgb, sky, star * (1.0 - tw) * 0.75);

		// 그림에 없는 작은 반짝이가 군데군데 켜졌다 꺼짐 (윗하늘)
		float sky_mask = 1.0 - step(tex.y * horizon * 0.62, p.y);
		vec2 g = p / 46.0;
		vec2 gc = floor(g);
		float hr = hash(gc);
		vec2 off = (vec2(hash(gc + 7.1), hash(gc + 3.7)) - 0.5) * 0.5;
		float on = step(0.82, hr) * step(0.55, 0.5 + 0.5 * sin(TIME * (0.7 + hr * 1.8) + hr * 70.0));
		float s2 = sparkle((fract(g) - 0.5 - off) * 46.0, 3.0 + hr * 2.5) * on * sky_mask * away;
		col.rgb = mix(col.rgb, cream, s2);
		COLOR = col;
	} else {
		// ================= 바다 =================
		// 바다 그림은 단색 면. 그 위에 너울 줄무늬(밝은 마루·어두운 골)가 보는 쪽으로 밀려온다.
		float t = TIME * (0.8 + 0.25 * strength);
		float d = clamp((uv.y - horizon) / (1.0 - horizon), 0.0, 1.0);
		vec2 P = plane(uv);
		vec4 col = texture(TEXTURE, uv);
		float h = swell(P, t) + 0.3 * sin(P.x * 1.1 + P.y * 0.4 + t * 0.5);
		float aa = max(fwidth(h), 0.002);
		float mask = smoothstep(0.02, 0.22, d);
		float crest = smoothstep(0.95 - aa, 0.95 + aa, h) * mask;
		float trough = (1.0 - smoothstep(-1.05 - aa, -1.05 + aa, h)) * mask;
		col.rgb = mix(col.rgb, col.rgb * 1.12 + vec3(0.02, 0.04, 0.05), crest * 0.45);
		col.rgb = mix(col.rgb, col.rgb * 0.9, trough * 0.4);
		// 수평선 바로 아래 얇은 밝은 띠가 살랑임
		float rim = 1.0 - smoothstep(0.0, 0.018 + 0.006 * sin(uv.x * 40.0 + t * 1.5), d);
		col.rgb = mix(col.rgb, col.rgb * 1.22 + vec3(0.03, 0.05, 0.06), rim * 0.6);

		// 수면 위 작은 반짝이 (달빛 길 근처에 더 많이, 너울 마루에서)
		vec2 cell = floor(P * vec2(10.0, 6.0));
		vec2 f = fract(P * vec2(10.0, 6.0)) - 0.5;
		float rnd = hash(cell);
		float blink = step(0.7, 0.5 + 0.5 * sin(TIME * (1.6 + rnd * 2.4) + rnd * 40.0));
		float near_moon = 1.0 - smoothstep(0.08, 0.25, abs(uv.x - moon_x));
		float chance = mix(0.93, 0.72, near_moon);
		float near = smoothstep(0.0, 1.0, d);
		float sp = sparkle(f * mix(26.0, 60.0, 1.0 - near), mix(2.0, 6.0, near) * 0.06 + 0.06) * step(chance, rnd) * blink * step(0.2, h);
		col.rgb = mix(col.rgb, mix(cream, vec3(1.0, 0.9, 0.5), near_moon), sp * mix(0.6, 1.0, moon_light));
		COLOR = col;
	}
}
