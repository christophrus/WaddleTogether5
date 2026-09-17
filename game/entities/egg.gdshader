shader_type spatial;
// Egg shell whose lower part warms from cream to speckled brown as it incubates.
// This is an object counter (brood progress), which rule 3.1 explicitly allows.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shell : source_color = vec3(0.96, 0.93, 0.82);
uniform vec3 warm : source_color = vec3(0.78, 0.6, 0.4);
uniform float half_height = 0.22;

varying float t_up;

void vertex() {
	// Symmetric remap: sphere meshes span -h/2..+h/2 (8.A.3).
	t_up = clamp((VERTEX.y + half_height) / (2.0 * half_height), 0.0, 1.0);
}

void fragment() {
	float fill = step(t_up, progress);
	ALBEDO = mix(shell, warm, fill * 0.85);
	ROUGHNESS = 0.7;
}
