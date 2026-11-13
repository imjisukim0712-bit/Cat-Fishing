shader_type canvas_item;
render_mode blend_premul_alpha;
// Viewport output is premultiplied; filtering it directly avoids dark fringes.
float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec2 d = TEXTURE_PIXEL_SIZE * 1.15;
	vec4 center = texture(TEXTURE, UV);
	vec4 left = texture(TEXTURE, UV - vec2(d.x, 0.0));
	vec4 right = texture(TEXTURE, UV + vec2(d.x, 0.0));
	vec4 up = texture(TEXTURE, UV - vec2(0.0, d.y));
	vec4 down = texture(TEXTURE, UV + vec2(0.0, d.y));
	vec4 paint = center * 0.52 + (left + right + up + down) * 0.12;
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	// Stable, fine grain: no temporal noise or sparkling eyes.
	paint.rgb *= 1.0 + (grain(floor(pixel * 0.7)) - 0.5) * 0.045;
	float moon_edge = max(0.0, left.a - right.a);
	float lamp_edge = max(0.0, right.a - left.a);
	// Keep environmental rim treatment on the cat, not the floating rod.
	float cat_mask = smoothstep(135.0, 175.0, pixel.y) * (1.0 - smoothstep(260.0, 285.0, pixel.x));
	paint.rgb += (vec3(0.60, 0.49, 0.86) * moon_edge * 0.20
		+ vec3(0.85, 0.43, 0.18) * lamp_edge * 0.10) * paint.a * cat_mask;
	COLOR = paint;
}
