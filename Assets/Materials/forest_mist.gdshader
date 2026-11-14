shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, fog_disabled;

// Soft billboard mist puff. Always faces the camera, has no hard edges, and
// fades out where it touches trees/ground/player so it never looks like a plane.

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 mist_color : source_color = vec4(0.78, 0.85, 0.80, 1.0);
uniform float strength : hint_range(0.0, 0.5) = 0.10;
uniform float drift_speed : hint_range(0.0, 0.2) = 0.03;
uniform float soft_distance : hint_range(0.1, 8.0) = 3.0;   // fade near geometry
uniform float near_fade_start = 1.5;                        // fade near camera
uniform float near_fade_end = 6.0;
uniform float far_fade_start = 35.0;
uniform float far_fade_end = 55.0;
instance uniform float seed = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	// Full camera-facing billboard, keeps node scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	// Smooth round falloff - no visible quad edge at all.
	float radial = 1.0 - smoothstep(0.0, 1.0, r);
	radial *= radial;

	// Cloudy, slowly drifting density so each puff looks like wispy mist.
	vec2 q = UV * 3.0 + vec2(seed * 17.0, seed * 5.0) + vec2(TIME * drift_speed, TIME * drift_speed * 0.4);
	float n = noise21(q) * 0.6 + noise21(q * 2.3 + 4.0) * 0.4;
	float density = radial * mix(0.35, 1.0, n);

	// Soft particle: fade where mist intersects solid geometry.
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_dist = -view.z;
	float my_dist = -VERTEX.z;
	float soft = clamp((scene_dist - my_dist) / soft_distance, 0.0, 1.0);

	float near_f = smoothstep(near_fade_start, near_fade_end, my_dist);
	float far_f = 1.0 - smoothstep(far_fade_start, far_fade_end, my_dist);

	ALBEDO = mist_color.rgb;
	ALPHA = clamp(strength * density * soft * near_f * far_f, 0.0, 1.0);
}
