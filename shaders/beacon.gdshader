shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// Fascio luminoso su un CylinderMesh: colonna glitch sopra i ricordi rotti, o fascio del faro.
// invert = false: luminoso in cima (faro, la cima è verso la lanterna)
// invert = true:  luminoso in basso (colonna che sale dal terreno)
uniform vec3 color : source_color = vec3(0.85, 0.2, 0.9);
uniform vec3 color2 : source_color = vec3(0.2, 0.9, 1.0);
uniform float strength = 1.0;
uniform float flicker = 1.0;
uniform float height = 40.0;
uniform bool invert = false;

varying float vh;

void vertex() {
	vh = VERTEX.y / height + 0.5;
}

void fragment() {
	float v = invert ? vh : 1.0 - vh;
	float fade = (1.0 - smoothstep(0.35, 1.0, v)) * smoothstep(0.0, 0.03, v);
	float rnd = fract(sin(floor(TIME * 14.0) * 12.9898) * 43758.5453);
	float fl = mix(1.0, 0.35 + 0.65 * step(0.3, rnd), flicker);
	float bands = mix(1.0, 0.55 + 0.45 * step(0.5, fract(v * 30.0 - TIME * 2.0)), flicker);
	vec3 c = mix(color, color2, flicker * step(0.5, fract(TIME * 3.0 + v * 4.0)));
	ALBEDO = c * strength * fade * fl * bands * 0.5;
}
