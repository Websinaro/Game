// Cheap animated ocean for mobile: 3 summed sine waves with analytic normals, water colour from
// an ANALYTIC shore-depth estimate (matches TerrainGenerator.height_at's beach profile, so no
// depth texture is needed), shoreline foam with wash lines, fresnel sheen and crest foam.
// If you change the beach profile in TerrainGenerator, update the shore_* uniforms below.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.12, 0.66, 0.66, 0.55);
uniform vec4 deep_color : source_color = vec4(0.02, 0.20, 0.40, 0.95);
uniform vec3 sky_reflect_color : source_color = vec3(0.70, 0.86, 0.95);
uniform float quality : hint_range(0.0, 1.0) = 1.0;
uniform float wave_height = 0.22;
uniform float wave_speed = 0.8;
uniform float shore_z_start = 80.0;     // z where the sea floor bottoms out
uniform float shore_z_end = 40.0;       // z where the beach reaches its top
uniform float sea_floor_y = -5.0;
uniform float beach_top_y = 2.0;
uniform float depth_color_range = 5.0;  // metres of depth for shallow -> deep colour
uniform float foam_width = 0.9;
uniform sampler2D water_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float water_tex_scale = 0.045;  // tiles per metre
uniform float water_tex_strength = 0.6;

varying float crest;
varying vec3 wpos;

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
	wpos = wp;
}

void fragment() {
	float s = clamp((shore_z_start - wpos.z) / (shore_z_start - shore_z_end), 0.0, 1.0);
	float ease_s = s * s * (3.0 - 2.0 * s);
	float floor_y = mix(sea_floor_y, beach_top_y, ease_s);
	// wobble so the shoreline is not a perfectly straight line
	floor_y += sin(wpos.x * 0.21 + TIME * 0.2) * 0.12 + sin(wpos.x * 0.57) * 0.05;
	float depth = max(-floor_y, 0.0);

	float dmix = smoothstep(0.0, depth_color_range, depth);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, dmix);
	float haze = smoothstep(8.0, 160.0, length(VERTEX));
	col = mix(col, deep_color.rgb, haze * 0.35);
	// real water surface texture (from ocean_wave.glb): two drifting layers, tints the depth colour
	vec2 wuv = wpos.xz * water_tex_scale;
	vec3 wt = texture(water_tex, wuv + vec2(TIME * 0.010, TIME * 0.006)).rgb;
	if (quality > 0.5) {
		vec3 wt2 = texture(water_tex, wuv * 2.3 * vec2(-1.0, 1.0) + vec2(-TIME * 0.008, TIME * 0.011)).rgb;
		wt = (wt + wt2) * 0.5;
	}
	float wl = dot(wt, vec3(0.333));
	col = mix(col, col * (wt / max(wl, 0.05)) * (0.55 + wl * 1.1), water_tex_strength);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky_reflect_color, fres * 0.55);

	float alpha = mix(shallow_color.a, deep_color.a, dmix);
	float foam = smoothstep(1.25, 1.75, crest) * 0.35;
	if (quality > 0.5) {
		float edge = 1.0 - smoothstep(0.0, foam_width, depth);
		float wash = 0.5 + 0.5 * sin(depth * 14.0 - TIME * 1.8 + crest * 2.0);
		foam += edge * mix(0.55, 1.0, wash);
		alpha *= smoothstep(-0.02, 0.35, depth);
	} else {
		foam += (1.0 - smoothstep(0.0, foam_width, depth)) * 0.6;
	}
	foam = clamp(foam, 0.0, 1.0);
	col = mix(col, vec3(0.96, 0.98, 1.0), foam);
	ALBEDO = col;
	ALPHA = clamp(alpha + foam * 0.25, 0.0, 1.0);
	ROUGHNESS = mix(0.10, 0.9, foam);
	SPECULAR = mix(0.6, 0.2, foam);
	METALLIC = 0.12;
}
