shader_type canvas_item;
// World-space backdrop: layered nebula, parallax stars + dust, a lit planet, and a neon grid
// that ripples with shockwaves, carries energy pulses and is lit by dynamic lights.

uniform vec2 cam_pos = vec2(0.0);
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform vec3 col_a : source_color = vec3(0.01, 0.02, 0.08);
uniform vec3 col_b : source_color = vec3(0.05, 0.08, 0.3);
uniform vec3 col_c : source_color = vec3(0.0, 0.35, 0.6);
uniform vec3 grid_col : source_color = vec3(0.2, 0.55, 1.0);
uniform float time_s = 0.0;
uniform float grid_strength = 1.0;
uniform int detail = 2;                 // 0 low, 1 medium, 2 high
uniform vec4 arena = vec4(-1400.0, -1400.0, 2800.0, 2800.0);
uniform vec4 waves[8];
uniform vec4 lights[4];                 // xy world pos, z radius, w intensity
uniform vec4 light_cols[4];
// planet in parallax space: xy offset from origin, z radius (0 = none)
uniform vec3 planet = vec3(0.0);
uniform vec3 planet_col : source_color = vec3(0.3, 0.4, 0.9);
uniform vec3 planet_rim : source_color = vec3(0.4, 0.9, 1.0);
uniform float planet_rings = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p, int oct) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= oct) {
			break;
		}
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

float stars(vec2 p, float density, float size) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash(cell);
	if (h > density) {
		return 0.0;
	}
	vec2 c = vec2(hash(cell + 1.7), hash(cell + 3.1)) * 0.8 + 0.1;
	float d = length(f - c);
	float tw = 0.55 + 0.45 * sin(time_s * (1.0 + h * 6.0) + h * 40.0);
	// tiny diffraction cross on the brightest stars
	vec2 q = abs(f - c);
	float cross = h < density * 0.15 ? (smoothstep(size * 0.35, 0.0, q.x) + smoothstep(size * 0.35, 0.0, q.y)) * smoothstep(size * 6.0, 0.0, d) * 0.6 : 0.0;
	return (smoothstep(size, 0.0, d) + smoothstep(size * 4.0, 0.0, d) * 0.25 + cross) * tw;
}

vec3 planet_layer(vec2 pp, vec3 col) {
	if (planet.z <= 0.0) {
		return col;
	}
	vec2 d = (pp - planet.xy) / planet.z;
	float r = length(d);
	vec3 light_dir = normalize(vec3(-0.6, -0.5, 0.55));
	// atmosphere halo
	col += planet_rim * exp(-pow((r - 1.0) / 0.05, 2.0)) * 0.35;
	col += planet_rim * smoothstep(1.5, 1.0, r) * 0.04;
	// rings (behind + in front approximated by an ellipse band)
	if (planet_rings > 0.0) {
		vec2 rd = vec2(d.x, d.y * 3.2);
		float rr = length(rd);
		float band = smoothstep(1.45, 1.5, rr) * smoothstep(2.3, 2.2, rr) * (0.55 + 0.45 * sin(rr * 40.0));
		bool behind = d.y < 0.0 && r < 1.0;
		if (!behind) {
			col = mix(col, planet_rim * 0.5 + planet_col * 0.3, band * 0.3 * planet_rings);
		}
	}
	if (r < 1.0) {
		vec3 n = vec3(d, sqrt(1.0 - r * r));
		float lam = clamp(dot(n, light_dir), 0.0, 1.0);
		float bands = fbm(vec2(d.x * 2.0 + time_s * 0.01, d.y * 9.0), 4);
		vec3 surf = planet_col * (0.3 + bands * 0.7);
		vec3 lit = surf * (0.04 + lam * 0.55);
		float rim = pow(1.0 - n.z, 4.0);
		lit += planet_rim * rim * (0.15 + lam * 0.45);
		float edge = smoothstep(1.0, 0.985, r);
		col = mix(col, lit, edge);
	}
	return col;
}

void fragment() {
	vec2 local = (UV - 0.5) * view_size;
	vec2 world = cam_pos + local;
	int oct = detail == 0 ? 3 : (detail == 1 ? 4 : 5);

	// shockwave displacement
	vec2 disp = vec2(0.0);
	float wave_glow = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) {
			continue;
		}
		vec2 d = world - w.xy;
		float r = length(d);
		float front = w.z * 1000.0;
		float band = exp(-pow((r - front) / 80.0, 2.0));
		float fade = clamp(1.0 - w.z / 1.1, 0.0, 1.0);
		float k = band * fade * w.w;
		disp += d / (r + 0.001) * k * 28.0;
		wave_glow += k;
	}
	vec2 gp = world + disp;

	// deep nebula (parallax 0.15) + near nebula (parallax 0.3)
	vec2 np = (cam_pos * 0.15 + local) * 0.0010;
	float n = fbm(np + vec2(time_s * 0.010, 0.0), oct);
	float n2 = fbm(np * 2.3 - vec2(0.0, time_s * 0.015) + n * 1.7, oct);
	vec3 col = mix(col_a, col_b, smoothstep(0.25, 0.95, n));
	col += col_c * pow(n2, 3.0) * 1.7;
	col += col_b * pow(max(n - 0.55, 0.0) * 2.0, 2.0) * 0.9;
	if (detail > 0) {
		vec2 np2 = (cam_pos * 0.3 + local) * 0.0016;
		float n3 = fbm(np2 + vec2(-time_s * 0.02, time_s * 0.008) + 13.0, oct - 1);
		// dark dust lanes + bright filaments
		col *= 0.75 + 0.25 * smoothstep(0.3, 0.6, n3);
		col += mix(col_c, grid_col, 0.5) * pow(smoothstep(0.55, 0.85, n3), 2.0) * 0.35;
	}

	// stars, three parallax layers
	col += vec3(0.6, 0.75, 1.0) * stars((cam_pos * 0.05 + local) / 30.0, 0.10, 0.07) * 0.45;
	col += vec3(1.0, 0.95, 0.9) * stars((cam_pos * 0.2 + local) / 70.0, 0.07, 0.05);
	if (detail > 1) {
		col += mix(vec3(1.0, 0.7, 0.9), col_c, 0.5) * stars((cam_pos * 0.45 + local) / 140.0, 0.05, 0.035) * 1.2;
	}

	// planet (very slow parallax)
	col = planet_layer(cam_pos * 0.04 + local, col);

	// dynamic lights
	vec3 lightc = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		vec4 L = lights[i];
		if (L.w <= 0.0) {
			continue;
		}
		float d2 = dot(world - L.xy, world - L.xy);
		lightc += light_cols[i].rgb * L.w * exp(-d2 / (L.z * L.z));
	}

	// grid inside the arena
	vec2 rel = world - arena.xy;
	float inside = step(0.0, rel.x) * step(0.0, rel.y) * step(rel.x, arena.z) * step(rel.y, arena.w);
	float gs = 96.0;
	vec2 gl = (0.5 - abs(fract(gp / gs) - 0.5)) * gs;
	float line = min(gl.x, gl.y);
	vec2 gl4 = (0.5 - abs(fract(gp / (gs * 4.0)) - 0.5)) * gs * 4.0;
	float major = min(gl4.x, gl4.y);
	float g = smoothstep(1.4, 0.0, line) * 0.30 + smoothstep(9.0, 0.0, line) * 0.05;
	float gm = smoothstep(2.0, 0.0, major) * 0.38 + smoothstep(16.0, 0.0, major) * 0.08;
	float dots = smoothstep(4.0, 0.0, length(gl)) * 0.5;
	// energy pulses racing along the major lines
	float pulse_x = pow(fract(gp.x / 1400.0 - time_s * 0.35 + floor(gp.y / (gs * 4.0)) * 0.37), 14.0);
	float pulse_y = pow(fract(gp.y / 1400.0 - time_s * 0.28 + floor(gp.x / (gs * 4.0)) * 0.61), 14.0);
	float on_h = smoothstep(2.5, 0.0, gl4.y);
	float on_v = smoothstep(2.5, 0.0, gl4.x);
	float pulses = (pulse_x * on_h + pulse_y * on_v) * 1.6;
	float breathe = 0.75 + 0.25 * sin(time_s * 0.7 + (gp.x + gp.y) * 0.002);
	vec3 grid_light = grid_col * (0.45 + wave_glow * 2.5) * breathe + lightc * 1.2;
	col += (grid_light * (g + gm + dots) + grid_col * pulses) * inside * grid_strength;
	col += grid_col * wave_glow * 0.12;
	col += lightc * 0.10 * inside;

	// outside arena: dark hazard stripes
	float stripes = step(0.5, fract((world.x + world.y) / 60.0));
	col = mix(col * 0.3 + vec3(0.06, 0.0, 0.02) * stripes, col, inside);

	COLOR = vec4(col, 1.0);
}
