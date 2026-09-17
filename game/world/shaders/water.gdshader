shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
// Gentle vertex ripple plus a Fresnel brightening at grazing angles: without it the
// pond reads as tinted glass over a hole in the lawn.

uniform vec3 color_deep : source_color = vec3(0.10, 0.36, 0.52);
uniform vec3 color_shallow : source_color = vec3(0.35, 0.68, 0.78);
uniform float alpha_base = 0.72;
uniform float ripple_height = 0.035;
uniform float ripple_speed = 1.1;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wp.x * 1.7 + TIME * ripple_speed) * ripple_height
	          + cos(wp.z * 2.3 - TIME * ripple_speed * 0.7) * ripple_height;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(color_deep, color_shallow, fresnel * 0.9);
	ALPHA = clamp(alpha_base + fresnel * 0.25, 0.0, 0.95);
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
