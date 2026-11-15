shader_type spatial;
render_mode specular_disabled;

// Mare: onde lente, vertex snapping PS1.
uniform vec3 deep : source_color = vec3(0.07, 0.1, 0.13);
uniform vec3 crest : source_color = vec3(0.22, 0.27, 0.3);
uniform float snap = 160.0;
varying float h;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = sin(w.x * 0.15 + TIME * 0.8) * 0.5 + sin(w.z * 0.22 - TIME * 1.1) * 0.5;
	VERTEX.y += h * 0.25;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (clip.w > 0.05) {
		vec2 ndc = clip.xy / clip.w;
		ndc = floor(ndc * snap + 0.5) / snap;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = mix(deep, crest, h * 0.5 + 0.5);
	ROUGHNESS = 0.7;
}
