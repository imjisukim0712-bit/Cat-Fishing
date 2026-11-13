shader_type canvas_item;
uniform float water_uv = 0.45;
void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	float submerged = smoothstep(water_uv, 1.0, UV.y);
	paint.rgb = mix(paint.rgb, vec3(0.035, 0.17, 0.27), submerged * 0.68);
	paint.a *= 1.0 - smoothstep(0.75, 1.0, UV.y) * 0.8;
	COLOR = paint;
}
