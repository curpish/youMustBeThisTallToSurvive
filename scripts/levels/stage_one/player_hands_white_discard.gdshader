shader_type canvas_item;

uniform float white_cutoff = 0.96;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (color.r > white_cutoff && color.g > white_cutoff && color.b > white_cutoff) {
		discard;
	}
	COLOR = color;
}
