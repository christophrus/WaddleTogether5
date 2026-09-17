shader_type spatial;
// Vertical gradient (darker below, lighter above) is a texture-free ambient-occlusion
// stand-in; the wind sway is weighted by t² so only the crown moves and the trunk
// stays rooted. The phase is taken from the world position, otherwise every plant in
// the park nods in lockstep.

uniform vec3 color_bottom : source_color = vec3(0.18, 0.38, 0.16);
uniform vec3 color_top : source_color = vec3(0.45, 0.72, 0.30);
uniform float half_height = 1.0;   // primitives span -h/2..+h/2 (8.A.3), never 0..h
uniform float sway_strength = 0.06;
uniform float sway_speed = 1.2;

varying float t_up;

void vertex() {
	// Symmetric remap: primitive meshes are centred on their origin.
	t_up = clamp((VERTEX.y + half_height) / (2.0 * half_height), 0.0, 1.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = wp.x * 0.7 + wp.z * 1.3;
	float w = t_up * t_up * sway_strength;
	VERTEX.x += sin(TIME * sway_speed + phase) * w;
	VERTEX.z += cos(TIME * sway_speed * 0.8 + phase * 1.7) * w * 0.6;
}

void fragment() {
	ALBEDO = mix(color_bottom, color_top, t_up);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
