shader_type spatial;
render_mode cull_back, specular_disabled;

// Look PS1: vertex snapping, texture affine, niente filtro, colori a 5 bit con dithering.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform float snap = 200.0;      // 0 = niente vertex snapping
uniform float affine = 1.0;      // 1 = texture affine stile PS1, 0 = prospettiva corretta
uniform float dither_strength = 0.7;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

varying vec2 uv_aff;
varying vec2 uv_persp;
varying float w_var;

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	// snapping solo per vertici davanti alla camera: dietro (w <= 0) la divisione esplode
	if (snap > 0.0 && clip.w > 0.05) {
		vec2 ndc = clip.xy / clip.w;
		ndc = floor(ndc * snap + 0.5) / snap;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
	uv_persp = UV * uv_scale;
	// trucco: UV*w interpolato con correzione prospettica, diviso per w interpolato = UV affine
	uv_aff = UV * uv_scale * clip.w;
	w_var = clip.w;
}

void fragment() {
	vec2 uv = mix(uv_persp, uv_aff / w_var, affine);
	vec3 c = texture(tex, uv).rgb * albedo.rgb;
	ivec2 p = ivec2(mod(FRAGCOORD.xy, 4.0));
	float b = float(BAYER[p.x + p.y * 4]) / 16.0;
	float levels = 31.0;
	c = clamp(floor(c * levels + b * dither_strength) / levels, 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = emission_color * emission_energy;
}
