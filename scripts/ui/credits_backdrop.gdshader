shader_type canvas_item;
// Cheap darken + slight blur for the credits backdrop. Single-pass 9-tap box
// blur on the screen texture, then mixed toward a dark tint. Web-safe: one
// back-buffer read + 9 texture taps, no extra passes or render targets.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float blur_radius : hint_range(0.0, 6.0) = 2.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.6);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 col = vec3(0.0);
	col += texture(screen_tex, SCREEN_UV + vec2(-px.x, -px.y)).rgb;
	col += texture(screen_tex, SCREEN_UV + vec2( 0.0,  -px.y)).rgb;
	col += texture(screen_tex, SCREEN_UV + vec2( px.x, -px.y)).rgb;
	col += texture(screen_tex, SCREEN_UV + vec2(-px.x,  0.0)).rgb;
	col += texture(screen_tex, SCREEN_UV).rgb;
	col += texture(screen_tex, SCREEN_UV + vec2( px.x,  0.0)).rgb;
	col += texture(screen_tex, SCREEN_UV + vec2(-px.x,  px.y)).rgb;
	col += texture(screen_tex, SCREEN_UV + vec2( 0.0,   px.y)).rgb;
	col += texture(screen_tex, SCREEN_UV + vec2( px.x,  px.y)).rgb;
	col /= 9.0;
	col = mix(col, tint.rgb, tint.a);
	COLOR = vec4(col, 1.0);
}
