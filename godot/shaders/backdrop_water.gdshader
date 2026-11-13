shader_type canvas_item;
// 바다 셰이더 — 배경 그림의 바다를 실제로 출렁이게 한다.
//  1) 너울: 원근 수면 위를 보는 사람 쪽으로 밀려오는 사인파 3겹. 높이·기울기로 그림을 위아래·좌우로 밀어
//     그려진 물결이 함께 출렁인다.
//  2) 잔물결: 이음매 없는 노멀맵(노이즈)을 같은 방향으로 흘려 잔 굴절과 반사를 더한다.
//  3) 달빛: 물결 기울기가 달을 향할 때 반사, 달빛 길 위에서 깜빡이는 잔 빛.
//  4) 발광: 가까운 물결 마루를 따라 청록빛이 실리고, 천천히 움직이는 발광 무리가 지나간다.
//  5) 랜턴: 랜턴 아래로 따뜻한 빛기둥이 물결에 끊기며 일렁인다.
// 하늘·산(수평선 위)은 건드리지 않는다.

uniform float horizon = 0.5823;          // 그림에서 수평선 높이 (548 / 941)
uniform float moon_x = 0.794;            // 달빛 기둥 가로 위치
uniform float lantern_x = 0.0385;        // 랜턴 가로 위치 (무대 x / 960)
uniform float lantern = 1.0;             // 랜턴 밝기 (깜빡임)
uniform float strength = 1.0;            // 날씨(폭풍·만조)에 따라 크고 빠르게
uniform float moon_light = 1.0;          // 달빛 세기 (구름이 가리거나 궂은 날씨면 약해짐)
uniform vec2 moon_px = vec2(1327.0, 190.0);   // 그림 속 달 중심 (픽셀)
uniform float moon_r = 70.0;             // 그림 속 달 반지름 (픽셀)
uniform sampler2D wave_normal : repeat_enable, filter_linear_mipmap;
uniform sampler2D blob_noise : repeat_enable, filter_linear_mipmap;   // 발광 무리용 일반 노이즈

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// 원근 수면 좌표: z 는 깊이(멀수록 큼), x 는 멀수록 넓게
vec2 plane(vec2 uv) {
	float d = clamp((uv.y - horizon) / (1.0 - horizon), 0.0, 1.0);
	float z = 1.0 / (d + 0.10);
	return vec2((uv.x - 0.5) * z * 1.6, z);
}

// 너울 높이 (-1..1 근처). 모두 보는 사람 쪽(z 감소)으로 진행.
float swell(vec2 P, float t) {
	float h = 0.0;
	h += 0.55 * sin(dot(P, normalize(vec2(0.12, 1.0))) * 3.1 + t * 1.25);
	h += 0.30 * sin(dot(P, normalize(vec2(-0.35, 1.0))) * 5.3 + t * 1.75 + 1.7);
	h += 0.15 * sin(dot(P, normalize(vec2(0.55, 1.0))) * 8.9 + t * 2.4 + 4.1);
	return h;
}

void fragment() {
	vec2 uv = UV;
	if (uv.y <= horizon) {
		// ===================== 하늘: 별 반짝임, 달무리 숨쉬기, 은하수 일렁임 =====================
		vec2 tex = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 p = uv * tex;
		vec4 col = texture(TEXTURE, uv);
		float lum = dot(col.rgb, vec3(0.3, 0.5, 0.2));
		float dm = length(p - moon_px);
		float away = smoothstep(moon_r * 1.4, moon_r * 2.0, dm);   // 달 근처는 별 처리 제외

		// 그림 속 별: 주변보다 밝은 작은 점을 찾아 제각각 반짝이게
		vec2 o = TEXTURE_PIXEL_SIZE * 3.0;
		vec3 avg = (texture(TEXTURE, uv + vec2(o.x, 0.0)).rgb + texture(TEXTURE, uv - vec2(o.x, 0.0)).rgb
			+ texture(TEXTURE, uv + vec2(0.0, o.y)).rgb + texture(TEXTURE, uv - vec2(0.0, o.y)).rgb) * 0.25;
		float star = smoothstep(0.05, 0.2, lum - dot(avg, vec3(0.3, 0.5, 0.2))) * away;
		float hs = hash(floor(p / 5.0));
		float tw = 0.5 + 0.5 * sin(TIME * (1.2 + hs * 3.5) + hs * 60.0);
		col.rgb += (col.rgb - avg) * star * (tw * 1.6 - 0.6);

		// 그림에 없는 작은 별 추가 (윗하늘에만, 천천히 깜빡임)
		float sky_mask = 1.0 - smoothstep(330.0, 420.0, p.y);
		vec2 g = p / 22.0;
		vec2 gc = floor(g);
		float hr = hash(gc);
		vec2 sp = vec2(hash(gc + 7.1), hash(gc + 3.7)) - 0.5;
		float sd = length(fract(g) - 0.5 - sp * 0.7) * 22.0;
		float tw2 = pow(0.5 + 0.5 * sin(TIME * (0.8 + hr * 2.6) + hr * 80.0), 3.0);
		float s2 = step(0.72, hr) * smoothstep(1.4, 0.0, sd) * tw2 * sky_mask * away;
		col.rgb += vec3(0.9, 0.92, 1.0) * s2 * 0.75;

		// 은하수·하늘이 아주 천천히 일렁임
		float drift = texture(blob_noise, uv * vec2(2.0, 3.0) + vec2(TIME * 0.004, 0.0)).r;
		col.rgb *= 1.0 + (drift - 0.5) * 0.10 * sky_mask;

		// 달: 구름에 가리면 어두워지고, 달무리가 천천히 숨쉬듯 커졌다 작아짐
		float disc = 1.0 - smoothstep(moon_r * 0.95, moon_r * 1.05, dm);
		col.rgb *= mix(1.0, mix(0.55, 1.0, moon_light), disc);
		float breathe = 0.85 + 0.15 * sin(TIME * 0.6) + 0.05 * sin(TIME * 1.7);
		float halo = exp(-max(dm - moon_r, 0.0) / (moon_r * 0.9 * breathe)) * (1.0 - disc);
		col.rgb += vec3(1.0, 0.86, 0.62) * halo * 0.20 * moon_light * breathe;
		// 달 표면 미세한 일렁임 (대기 굴절)
		col.rgb += disc * (texture(blob_noise, (p - moon_px) / (moon_r * 3.0) + TIME * 0.02).r - 0.5) * 0.06;

		// 수평선 위 노을빛 띠가 아주 느리게 밝아졌다 어두워짐
		float band = smoothstep(380.0, 520.0, p.y);
		col.rgb += vec3(0.25, 0.10, 0.12) * band * (0.04 + 0.04 * sin(TIME * 0.25));
		COLOR = col;
	} else {
		float t = TIME * (0.75 + 0.25 * strength);
		float d = clamp((uv.y - horizon) / (1.0 - horizon), 0.0, 1.0);   // 0 = 수평선, 1 = 맨 아래
		vec2 P = plane(uv);
		float near = smoothstep(0.0, 1.0, d);

		// --- 너울: 높이와 화면상 기울기 (수치 미분)
		float e = 0.0015;
		float h = swell(P, t);
		float hx = swell(plane(uv + vec2(e, 0.0)), t) - h;
		float hy = swell(plane(uv + vec2(0.0, e)), t) - h;
		vec2 slope = vec2(hx, hy) / e;
		slope = clamp(slope * 0.004, vec2(-1.0), vec2(1.0));

		// --- 잔물결 노멀 (같은 방향으로 흐름)
		vec2 rip = texture(wave_normal, P * vec2(0.35, 0.55) + vec2(0.02, 0.18) * t).rg * 2.0 - 1.0;
		rip = rip * 0.6 + (texture(wave_normal, P * vec2(1.1, 1.6) + vec2(-0.03, 0.31) * t).rg * 2.0 - 1.0) * 0.4;

		vec2 n = slope + rip * 0.35;

		// --- 그림을 출렁이게: 마루에서는 위로 밀고, 기울기 방향으로 굴절
		float amp = mix(0.0008, 0.016, near) * strength;
		vec2 s = uv;
		s.y -= h * amp * 0.9;
		s += n * amp * vec2(0.8, 0.6);
		s.y = max(s.y, horizon + 0.002);
		vec4 col = texture(TEXTURE, s);
		float lum = dot(col.rgb, vec3(0.3, 0.5, 0.2));

		// --- 마루는 밝게, 골은 어둡게 (입체적인 너울)
		col.rgb *= 1.0 + h * mix(0.05, 0.22, near) * strength;

		// --- 달빛 반사: 기울기가 달 쪽을 향할 때
		float colw = mix(0.018, 0.075, d);
		float column = exp(-pow((uv.x + n.x * 0.03 - moon_x) / colw, 2.0));
		float facing = clamp(0.5 - n.y * 0.9 + n.x * (moon_x - uv.x) * 2.0, 0.0, 1.0);
		vec3 moonc = vec3(1.0, 0.88, 0.66);
		col.rgb += moonc * column * pow(facing, 3.0) * 0.35 * moon_light;

		// --- 달빛 길의 반짝이는 잔 빛 (원근 격자 칸마다 제각각 깜빡임)
		vec2 cell = floor(P * vec2(14.0, 9.0));
		vec2 f = fract(P * vec2(14.0, 9.0)) - 0.5;
		float rnd = hash(cell);
		float tw = pow(max(0.0, sin(TIME * (2.0 + rnd * 3.0) + rnd * 40.0)), 18.0);
		float dot_ = smoothstep(0.22, 0.0, length(f * vec2(1.0, 2.2)));
		float glints = tw * dot_ * step(0.55, rnd) * smoothstep(0.1, 0.9, h * 0.5 + 0.5);
		col.rgb += moonc * glints * exp(-pow((uv.x - moon_x) / (colw * 1.6), 2.0)) * 1.4 * moon_light;

		// --- 발광: 가까운 물결 마루를 따라 청록빛 + 천천히 지나가는 발광 무리
		float crest = smoothstep(0.35, 0.95, h);
		float patch = smoothstep(0.45, 0.9, texture(blob_noise, P * 0.12 + vec2(0.05, 0.07) * TIME).r);
		vec3 cyan = vec3(0.35, 1.0, 0.95);
		col.rgb += cyan * (crest * 0.18 + patch * 0.10) * near * near * (0.6 + 0.4 * lum) * strength;
		// 앞쪽 잔 반짝임: 마루 위 격자 칸이 청록으로 깜빡
		float sea_glint = tw * dot_ * step(0.7, rnd) * crest * near;
		col.rgb += cyan * sea_glint * 0.9;

		// --- 랜턴 빛기둥: 물결에 끊기며 일렁이는 따뜻한 반사
		float lw = mix(0.006, 0.03, d);
		float lcol = exp(-pow((uv.x + n.x * 0.05 - lantern_x) / lw, 2.0));
		float broken = smoothstep(0.1, 0.8, 0.5 + 0.5 * sin(P.y * 7.0 + t * 2.0 + n.x * 6.0));
		col.rgb += vec3(1.0, 0.68, 0.32) * lcol * broken * (1.0 - smoothstep(0.0, 0.55, d)) * 0.55 * lantern;

		COLOR = col;
	}
}
