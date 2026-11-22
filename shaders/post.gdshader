shader_type canvas_item;
// Screen-space neon finish: soft-knee bloom (quality tiers), chromatic aberration,
// colour grade, vignette, film grain, flash.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int quality = 2;               // 0 low, 1 medium, 2 high
uniform float aberration = 0.0015;
uniform float bloom = 0.75;
uniform float bloom_threshold = 0.38;
uniform float vignette = 0.55;
uniform float grain = 0.035;
uniform float flash = 0.0;
uniform vec3 flash_col : source_color = vec3(1.0);
uniform vec3 shadow_tint : source_color = vec3(0.03, 0.0, 0.06);
uniform float time_s = 0.0;

vec3 tap(vec2 uv, float lod) {
	return textureLod(screen_tex, uv, lod).rgb;
}

vec3 knee(vec3 c) {
	// soft threshold so highlights bloom smoothly instead of popping
	float br = max(c.r, max(c.g, c.b));
	float soft = clamp(br - bloom_threshold + 0.25, 0.0, 0.5);
	soft = soft * soft / (4.0 * 0.25 + 0.0001);
	float contrib = max(soft, br - bloom_threshold) / max(br, 0.0001);
	return c * contrib;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - 0.5;
	vec3 col;
	if (quality > 0) {
		float ab = aberration * (0.15 + length(dir) * 1.6);
		col.r = tap(uv - dir * ab * 2.0, 0.0).r;
		col.g = tap(uv, 0.0).g;
		col.b = tap(uv + dir * ab * 2.0, 0.0).b;
	} else {
		col = tap(uv, 0.0);
	}

	if (quality > 0) {
		vec2 px = SCREEN_PIXEL_SIZE;
		vec3 b = vec3(0.0);
		float wsum = 0.0;
		int taps = quality == 1 ? 6 : 10;
		for (int i = 0; i < 10; i++) {
			if (i >= taps) {
				break;
			}
			float a = float(i) * 6.2831853 / float(taps) + 0.3;
			vec2 o = vec2(cos(a), sin(a));
			b += knee(tap(uv + o * px * 7.0, 2.0)) * 0.55;
			b += knee(tap(uv + o * px * 18.0, 3.5)) * 0.45;
			if (quality == 2) {
				b += knee(tap(uv + o * px * 40.0, 5.0)) * 0.35;
			}
			wsum += 1.0;
		}
		b /= wsum;
		col += b * bloom;
	}

	// colour grade: lift shadows toward violet, gentle filmic shoulder
	col += shadow_tint * (1.0 - clamp(dot(col, vec3(0.333)), 0.0, 1.0));
	col = col / (1.0 + col * 0.12) * 1.04;

	// vignette
	float v = 1.0 - vignette * pow(length(dir * vec2(1.15, 1.0)) * 1.25, 2.6);
	col *= clamp(v, 0.0, 1.0);
	if (quality > 0) {
		float n = fract(sin(dot(FRAGCOORD.xy + fract(time_s * 7.0) * 100.0, vec2(12.9898, 78.233))) * 43758.5453);
		col += (n - 0.5) * grain;
	}
	col = mix(col, flash_col, flash);
	COLOR = vec4(col, 1.0);
}
