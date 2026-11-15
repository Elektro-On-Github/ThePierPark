shader_type canvas_item;

// Mirino della videocamera VHS: jitter di riga, banda di tracking, head-switching in basso,
// aberrazione cromatica, rumore, scanlines, vignettatura e color grading freddo -> caldo.
// clean = 1 dopo EJECT: immagine pulita, nessun filtro.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float warmth : hint_range(0.0, 1.0) = 0.0;
uniform float glitch : hint_range(0.0, 2.0) = 0.0;
uniform float clean : hint_range(0.0, 1.0) = 0.0;
uniform float freeze : hint_range(0.0, 1.0) = 0.0;
uniform float vhs : hint_range(0.0, 1.0) = 1.0;        // intensità effetto VHS (impostazioni)
uniform float brightness : hint_range(0.3, 2.0) = 1.0; // luminosità (impostazioni)

void fragment() {
	vec2 suv = SCREEN_UV;
	vec2 uv = suv;
	float t = TIME;
	float g = glitch;
	float line = floor(uv.y * 240.0);
	float frame = mod(floor(t * 30.0), 512.0);
	float rh = fract(sin(line * 12.9898 + frame * 78.233) * 43758.5453);
	float jit = (rh - 0.5) * (0.0015 + 0.03 * g * g);
	float band_y = fract(t * 0.07);
	jit += (1.0 - smoothstep(0.0, 0.05, abs(uv.y - band_y))) * (0.003 + 0.03 * g);
	jit += smoothstep(0.955, 1.0, uv.y) * 0.02 * sin(t * 40.0 + uv.y * 200.0);
	if (!(abs(jit) < 0.06)) { jit = 0.0; }
	uv.x += jit * (1.0 - clean) * vhs;

	float ca = (0.0015 + 0.01 * g) * (1.0 - clean) * vhs;
	vec3 col;
	col.r = textureLod(screen_tex, uv + vec2(ca, 0.0), 0.0).r;
	col.g = textureLod(screen_tex, uv, 0.0).g;
	col.b = textureLod(screen_tex, uv - vec2(ca, 0.0), 0.0).b;
	vec3 orig = textureLod(screen_tex, suv, 0.0).rgb;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 cool = mix(vec3(lum), col, 0.3) * vec3(0.86, 0.96, 1.1);
	vec3 warm = mix(vec3(lum), col, 1.25) * vec3(1.12, 1.0, 0.84) + vec3(0.03, 0.015, 0.0);
	col = mix(cool, warm, warmth);

	vec2 px = mod(floor(suv * vec2(640.0, 360.0)), 256.0) + floor(fract(t * 0.71) * 64.0) * vec2(3.0, 7.0);
	float n = fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * (0.07 + 0.16 * g) * vhs;
	col *= 1.0 - (0.1 - 0.1 * step(0.5, fract(suv.y * 180.0))) * vhs;
	vec2 cc = suv - 0.5;
	col *= 1.0 - smoothstep(0.35, 0.9, length(cc)) * (0.25 + 0.45 * vhs);
	float fz = freeze * step(0.75, fract(sin(line * 4.898 + mod(floor(t * 12.0), 256.0) * 7.233) * 23421.631));
	col = mix(col, vec3(n), fz * 0.5);

	col = mix(col, orig, clean);
	COLOR = vec4(col * brightness, 1.0);
}
