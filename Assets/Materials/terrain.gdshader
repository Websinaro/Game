// Terrain splat shader. Vertex COLOR holds blend weights: R grass, G sand, B soil, A rock.
// Textures are plain uniforms: replace them in terrain_material.tres with your own at any time.
// `quality` (1 = High, 0 = Low) is set by GameMaterials.apply_quality() from the pause menu.
//   High: macro colour variation, detail texture, height-based layer blending (ragged grass
//         fringe along paths), triplanar rock + strata on steep slopes, derivative bump shading.
//   Low:  plain splat blend, one rock sample, no bump.
shader_type spatial;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D beach_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_tex : filter_linear_mipmap, repeat_enable;

uniform float quality : hint_range(0.0, 1.0) = 1.0;
uniform float tile_scale = 0.12;
uniform float rock_scale = 0.10;
uniform float detail_scale = 0.9;
uniform float macro_scale = 0.011;
uniform float shore_wet_height = 1.1;
uniform float tide_range = 0.18;
uniform float blend_height = 0.35;
uniform float blend_depth = 0.28;
uniform float bump_strength = 0.25;
uniform float strata_strength = 0.35;
uniform float strata_freq = 2.4;
uniform vec3 macro_tint_dark : source_color = vec3(0.84, 0.90, 0.78);
uniform vec3 macro_tint_light : source_color = vec3(1.10, 1.06, 0.92);
uniform vec3 wet_sand_tint : source_color = vec3(0.70, 0.62, 0.52);
uniform vec3 under_water_tint : source_color = vec3(0.45, 0.62, 0.62);

varying vec4 splat;
varying vec3 world_pos;
varying vec3 world_nrm;

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void vertex() {
	splat = COLOR;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = world_pos.xz * tile_scale;
	vec3 grass = texture(grass_tex, uv).rgb;
	vec3 sand = texture(sand_tex, uv).rgb;
	vec3 soil = texture(soil_tex, uv).rgb;
	vec3 wet_tex = texture(beach_tex, uv).rgb;
	float macro_v = 0.5;
	float detail_v = 0.5;
	if (quality > 0.5) {
		macro_v = texture(macro_tex, world_pos.xz * macro_scale).r;
		detail_v = texture(detail_tex, world_pos.xz * detail_scale).r;
		grass *= mix(macro_tint_dark, macro_tint_light, macro_v);
		soil *= mix(vec3(0.88), vec3(1.10), macro_v);
		sand *= mix(vec3(0.94), vec3(1.06), macro_v);
	}

	// wet sand shoreline (band moves slowly like a tide)
	float tide = sin(TIME * 0.35 + world_pos.x * 0.04) * tide_range;
	float wet = 1.0 - smoothstep(0.05, shore_wet_height + tide, world_pos.y);
	sand = mix(sand, wet_tex * wet_sand_tint, wet);

	vec3 rock;
	if (quality > 0.5) {
		vec3 tw = pow(abs(world_nrm), vec3(4.0));
		tw = tw / (tw.x + tw.y + tw.z + 0.0001);
		vec3 rx = texture(rock_tex, world_pos.zy * rock_scale).rgb;
		vec3 ry = texture(rock_tex, world_pos.xz * rock_scale).rgb;
		vec3 rz = texture(rock_tex, world_pos.xy * rock_scale).rgb;
		rock = rx * tw.x + ry * tw.y + rz * tw.z;
		float strata = sin(world_pos.y * strata_freq + (detail_v - 0.5) * 6.0);
		rock *= 1.0 - strata_strength * 0.5 * (strata * 0.5 + 0.5);
	} else {
		rock = texture(rock_tex, world_pos.xz * rock_scale).rgb;
	}

	vec4 w = max(splat, vec4(0.0));
	if (quality > 0.5) {
		// height blend: bright texels win near layer borders, giving ragged edges
		vec4 hv = vec4(lum(grass), lum(sand), lum(soil), lum(rock));
		vec4 t = w + hv * blend_height;
		float mx = max(max(t.x, t.y), max(t.z, t.w)) - blend_depth;
		vec4 bw = max(t - vec4(mx), vec4(0.0));
		bw *= smoothstep(vec4(0.0), vec4(0.06), w);
		float s = bw.x + bw.y + bw.z + bw.w;
		if (s > 0.0001) {
			w = bw / s;
		}
	} else {
		float s2 = max(w.x + w.y + w.z + w.w, 0.0001);
		w = w / s2;
	}

	vec3 col = grass * w.x + sand * w.y + soil * w.z + rock * w.w;
	float below = 1.0 - smoothstep(-1.5, 0.0, world_pos.y);
	col = mix(col, col * under_water_tint * 1.25, below * 0.7);
	ALBEDO = col;

	float wet_amount = wet * w.y;
	ROUGHNESS = mix(0.95, 0.38, wet_amount);
	SPECULAR = mix(0.12, 0.55, wet_amount);

	if (quality > 0.5) {
		// cheap bump from a height value (screen-space derivatives, no tangents needed)
		float hgt = detail_v + lum(col) * 0.6;
		vec3 dpx = dFdx(VERTEX);
		vec3 dpy = dFdy(VERTEX);
		vec3 r1 = cross(dpy, NORMAL);
		vec3 r2 = cross(NORMAL, dpx);
		float det = dot(dpx, r1);
		float k = bump_strength * (0.5 + 0.8 * w.w + 0.3 * w.y);
		vec3 grad = sign(det) * (dFdx(hgt) * r1 + dFdy(hgt) * r2);
		NORMAL = normalize(abs(det) * NORMAL - k * grad);
	}
}
