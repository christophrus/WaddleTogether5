shader_type spatial;
// The ground is the largest surface on screen; a flat colour there did more for the
// "grey boxes with paint" look than any single prop. Two-tone value noise from the
// world position breaks it up without a single texture.

uniform vec3 color_a : source_color = vec3(0.36, 0.58, 0.24);
uniform vec3 color_b : source_color = vec3(0.47, 0.68, 0.28);
uniform vec3 color_sand : source_color = vec3(0.72, 0.66, 0.46);
uniform float noise_scale = 0.35;
uniform float sand_height = -0.15;

varying vec3 world_pos;

// Integer hash: the classic fract(sin(...)*43758) loses precision at park-sized
// world coordinates and breaks into axis-aligned tiles.
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + ivec2(4096)) * uvec2(1597334677u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334677u;
	n ^= n >> 16u;
	n *= 2246822519u;
	n ^= n >> 13u;
	return float(n & 0x00FFFFFFu) / 16777215.0;
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Three octaves, blended linearly: a hard smoothstep on one octave read as tiles.
	float n = value_noise(world_pos.xz * noise_scale) * 0.5
	        + value_noise(world_pos.xz * noise_scale * 2.7 + 13.0) * 0.3
	        + value_noise(world_pos.xz * noise_scale * 7.3 + 41.0) * 0.2;
	vec3 grass = mix(color_a, color_b, clamp((n - 0.3) / 0.4, 0.0, 1.0));
	// Sandy shore where the bowl dips below the waterline.
	float sand = smoothstep(sand_height + 0.15, sand_height - 0.25, world_pos.y);
	ALBEDO = mix(grass, color_sand, sand);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
