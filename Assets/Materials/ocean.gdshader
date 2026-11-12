// Cheap animated ocean for mobile: 3 summed sine waves, analytic normals,
// distance-based depth colour, fresnel sheen and crest foam. No depth texture.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.60, 0.64, 0.72);
uniform vec4 deep_color : source_color = vec4(0.02, 0.20, 0.40, 0.95);
uniform float wave_height = 0.22;
uniform float wave_speed = 0.8;

varying float crest;

void add_wave(inout float h, inout vec2 g, vec2 p, vec2 dir, float k, float spd, float amp, float t) {
	float phase = dot(dir, p) * k + t * spd;
	h += sin(phase) * amp;
	g += dir * (cos(phase) * k * amp);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = 0.0;
	vec2 g = vec2(0.0);
	add_wave(h, g, wp.xz, normalize(vec2(1.0, 0.4)), 0.21, 1.0, 1.0, t);
	add_wave(h, g, wp.xz, normalize(vec2(-0.5, 1.0)), 0.37, 1.3, 0.5, t);
	add_wave(h, g, wp.xz, normalize(vec2(0.2, -1.0)), 0.71, 1.7, 0.25, t);
	VERTEX.y += h * wave_height;
	NORMAL = normalize(vec3(-g.x * wave_height, 1.0, -g.y * wave_height));
	crest = h;
}

void fragment() {
	float dist = length(VERTEX);
	float depth_mix = smoothstep(8.0, 140.0, dist);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, depth_mix);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, vec3(0.70, 0.86, 0.95), fres * 0.55);
	float foam = smoothstep(1.25, 1.75, crest);
	col = mix(col, vec3(0.95, 0.98, 1.0), foam * 0.35);
	ALBEDO = col;
	ALPHA = clamp(mix(shallow_color.a, deep_color.a, depth_mix) + foam * 0.2, 0.0, 1.0);
	ROUGHNESS = 0.10;
	SPECULAR = 0.6;
	METALLIC = 0.15;
}
