shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 shaft_color : source_color = vec4(1.0, 0.82, 0.53, 1.0);
uniform float opacity : hint_range(0.0, 0.2) = 0.095;
uniform float sun_factor : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float x = (UV.x - 0.5) * 2.0;
	float beam = exp(-x * x * 5.5);
	float top_fade = smoothstep(0.0, 0.18, UV.y);
	float bottom_fade = 1.0 - smoothstep(0.72, 1.0, UV.y);
	float soft_breakup = 0.82 + 0.18 * sin(UV.y * 19.0 + TIME * 0.22);
	ALBEDO = shaft_color.rgb;
	ALPHA = opacity * sun_factor * beam * top_fade * bottom_fade * soft_breakup;
}
