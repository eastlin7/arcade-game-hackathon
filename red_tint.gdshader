shader_type canvas_item;
// Recolors the player sprite toward red while keeping shading (luminance).

uniform float mix_amount : hint_range(0.0, 1.0) = 0.8;
// Hit flash: 1.0 turns the sprite solid white.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 red = vec3(min(lum * 1.5, 1.0), lum * 0.22, lum * 0.2);
	vec3 tinted = mix(c.rgb, red, mix_amount);
	COLOR = vec4(mix(tinted, vec3(1.0), flash), c.a);
}
