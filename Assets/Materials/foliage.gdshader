// Wind-swaying vertex-colour foliage (palms, trees, grass). Double sided.
// Sway grows with local height so trunks bend and fronds flutter.
shader_type spatial;
render_mode cull_disabled;

uniform float wind_strength = 0.28;
uniform float wind_speed = 1.3;
uniform float sway_ref_height = 8.0;
uniform float roughness_value = 0.85;

void vertex() {
	float h = max(VERTEX.y, 0.0);
	float k = clamp(h / sway_ref_height, 0.0, 1.5);
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.35 + origin.z * 0.27;
	float t = TIME * wind_speed + phase;
	VERTEX.x += (sin(t) + 0.35 * sin(t * 2.3 + VERTEX.z)) * wind_strength * k * k;
	VERTEX.z += cos(t * 0.8) * wind_strength * 0.6 * k * k;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness_value;
}
