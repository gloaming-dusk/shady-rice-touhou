// The spell card declaration behind the launcher: the screen dims to deep
// crimson, a white-edged red band cuts across it with SPELL CARD ATTACK
// written faintly along it, and a magic circle turns on the left.
// The launcher's own drawing (u_tex) goes on top.
//
// Uniforms: red (the band), glow (the circle's lines).

uniform sampler2D u_tex;
uniform float u_time;
uniform vec2 u_size;
uniform vec4 u_red;
uniform vec4 u_glow;

varying vec2 v_uv;
varying vec2 v_local;

const float TAU = 6.2831853;

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

void main() {
    vec2 px = v_local * u_size;
    float H = u_size.y;
    float t = u_time;

    // Dim to crimson, darker at the edges.
    vec2 c = v_local - vec2(0.3, 0.5);
    float glow = exp(-dot(c, c) * 3.0);
    vec3 col = mix(vec3(0.04, 0.02, 0.07), vec3(0.23, 0.06, 0.16), glow);
    float alpha = 0.86;

    // The band, at -12 degrees through the circle's centre.
    vec2 centre = vec2(0.24 * u_size.x, 0.52 * H);
    float ang = radians(-12.0);
    vec2 dir = vec2(cos(ang), sin(ang));
    vec2 nrm = vec2(-dir.y, dir.x);
    float across = dot(px - centre, nrm);
    float along = dot(px - centre, dir);
    float half_band = 0.065 * H;
    float band = 1.0 - smoothstep(half_band - 1.0, half_band + 1.0, abs(across));
    float edge = 1.0 - smoothstep(1.0, 2.5, abs(abs(across) - half_band - 3.0));
    float fade = smoothstep(-0.2 * u_size.x, 0.05 * u_size.x, along) *
                 (1.0 - smoothstep(0.55 * u_size.x, 0.95 * u_size.x, along));
    col = mix(col, u_red.rgb * 0.9, band * fade * 0.85);
    col = mix(col, vec3(1.0), edge * fade * 0.8);
    // Stripes running along the band.
    float stripes = step(0.5, fract((along - t * 120.0) / 28.0));
    col += vec3(1.0) * band * fade * stripes * 0.04;

    // The magic circle: rings, a ring of ticks, a pentagram, turning.
    vec2 p = px - centre;
    float r = length(p);
    float a = atan(p.y, p.x);
    float R = 0.30 * H;
    float spin = t * 0.35;
    float lines = 0.0;
    lines += 1.0 - smoothstep(1.0, 2.5, abs(r - R));
    lines += 0.7 * (1.0 - smoothstep(0.6, 1.8, abs(r - R * 0.92))) *
             step(0.55, fract((a + spin) / TAU * 72.0));
    lines += 0.8 * (1.0 - smoothstep(0.8, 2.0, abs(r - R * 0.50)));
    lines += 0.6 * (1.0 - smoothstep(0.6, 1.6, abs(r - R * 0.34)));
    for (int i = 0; i < 5; i++) {
        float a0 = -spin + float(i) * TAU / 5.0 - TAU / 4.0;
        float a1 = a0 + 2.0 * TAU / 5.0;
        float d = segment(p, vec2(cos(a0), sin(a0)) * R * 0.88, vec2(cos(a1), sin(a1)) * R * 0.88);
        lines += 0.9 * (1.0 - smoothstep(0.8, 2.2, d));
    }
    // A slower counter-turning hexagram outside.
    for (int i = 0; i < 6; i++) {
        float a0 = spin * 0.6 + float(i) * TAU / 6.0;
        float a1 = a0 + 2.0 * TAU / 6.0;
        float d = segment(p, vec2(cos(a0), sin(a0)) * R * 1.25, vec2(cos(a1), sin(a1)) * R * 1.25);
        lines += 0.35 * (1.0 - smoothstep(0.6, 1.8, d));
    }
    col += u_glow.rgb * clamp(lines, 0.0, 1.0) * 0.75;
    col += u_glow.rgb * exp(-abs(r - R) * 0.05) * 0.08;

    // A soft white heart behind where the portrait would be.
    col = mix(col, vec3(0.96, 0.93, 0.89), exp(-r * r / (R * R * 0.12)) * 0.85);

    vec4 back = vec4(col * alpha, alpha);
    vec4 ui = texture2D(u_tex, v_uv);
    gl_FragColor = ui + back * (1.0 - ui.a);
}
