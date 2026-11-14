// Wind-swaying vertex-colour foliage (palms, trees, bushes, grass). Double sided.
// Sway grows with local height so trunks bend and fronds flutter. Wind gusts roll across the
// world. Per-plant colour variation comes from the instance position (no extra data needed).
// Grass sinks into the ground between fade_start and fade_end metres (no popping, no overdraw).
shader_type spatial;
render_mode cull_disabled;

uniform float quality : hint_range(0.0, 1.0) = 1.0;
uniform float wind_strength = 0.28;
uniform float wind_speed = 1.3;
uniform float sway_ref_height = 8.0;
uniform float gust_strength = 0.6;
uniform float roughness_value = 0.85;
uniform float color_variation = 0.16;
uniform float backlight_amount = 0.12;
uniform float fade_start = 100000.0;
uniform float fade_end = 100001.0;

varying float vheight;
varying float vrand;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float dist = length(MODELVIEW_MATRIX[3].xyz);
	float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
	VERTEX.y *= fade;
	float h = max(VERTEX.y, 0.0);
	float k = clamp(h / sway_ref_height, 0.0, 1.5);
	float phase = origin.x * 0.35 + origin.z * 0.27;
	float gust = 1.0;
	if (quality > 0.5) {
		gust = 0.7 + gust_strength * (0.5 + 0.5 * sin(origin.x * 0.045 + origin.z * 0.03 + TIME * 0.35));
	}
	float t = TIME * wind_speed + phase;
	float amp = wind_strength * gust * k * k;
	VERTEX.x += (sin(t) + 0.35 * sin(t * 2.3 + VERTEX.z)) * amp;
	VERTEX.z += cos(t * 0.8) * amp * 0.6;
	vheight = clamp(h / sway_ref_height, 0.0, 1.0);
	vrand = hash21(floor(origin.xz * 2.0));
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (quality > 0.5) {
		c *= mix(1.0 - color_variation, 1.0 + color_variation, vrand);
		float yellow = smoothstep(0.75, 1.0, fract(vrand * 7.31)) * 0.5;
		c = mix(c, c * vec3(1.14, 1.06, 0.78), yellow);
		c *= mix(0.92, 1.08, vheight);
		BACKLIGHT = c * backlight_amount;
	}
	ALBEDO = c;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.2;
}
