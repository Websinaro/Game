// Terrain splat shader. Vertex COLOR holds blend weights:
//   R = grass, G = sand, B = soil, A = rock
// Textures are plain uniforms: replace them in terrain_material.tres
// with your own (e.g. Prisma3D-made) textures at any time.
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D beach_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile_scale = 0.12;
uniform float macro_scale = 0.019;
uniform float shore_wet_height = 1.1;

varying vec4 splat;
varying vec3 world_pos;

void vertex() {
	splat = COLOR;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * tile_scale;
	vec2 muv = world_pos.xz * macro_scale;
	vec3 grass = mix(texture(grass_tex, uv).rgb, texture(grass_tex, muv).rgb, 0.45);
	vec3 sand = mix(texture(sand_tex, uv).rgb, texture(sand_tex, muv).rgb, 0.40);
	vec3 wet = texture(beach_tex, uv).rgb;
	float wetness = 1.0 - smoothstep(0.15, shore_wet_height, world_pos.y);
	sand = mix(sand, wet, wetness);
	vec3 soil = texture(soil_tex, uv).rgb;
	vec3 rock = texture(rock_tex, uv * 0.8).rgb;
	float total = max(splat.r + splat.g + splat.b + splat.a, 0.0001);
	vec3 col = (grass * splat.r + sand * splat.g + soil * splat.b + rock * splat.a) / total;
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
