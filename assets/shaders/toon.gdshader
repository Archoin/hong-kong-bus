shader_type spatial;
render_mode specular_disabled;
uniform vec4 paint : source_color = vec4(1.0);
void fragment() {
	ALBEDO = paint.rgb;
	ROUGHNESS = 1.0;
}
void light() {
	float facing = dot(NORMAL, LIGHT);
	float band = facing > 0.65 ? 0.88 : (facing > 0.0 ? 0.68 : 0.38);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band * ATTENUATION / 3.14159265;
}
