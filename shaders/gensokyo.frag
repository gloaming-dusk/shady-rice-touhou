// Gensokyo at dusk: the sky over the Hakurei Shrine going from indigo to
// sunset orange, a pale moon, a slow boss pattern of bullets turning in the
// sky with a magic circle at its heart, hills, the shrine and its torii in
// silhouette, and cherry petals drifting down.
//
// A surface shader for the wallpaper; it replaces the drawing it is given.
//
// Uniforms: panel (px taken by the side panel on the right, so the scene
// centres in what is left), beat (0..1: the pattern spins faster while
// music plays).

uniform float u_time;
uniform vec2 u_size;
uniform float u_panel;
uniform float u_beat;

varying vec2 v_local;

const float TAU = 6.2831853;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.03 + 11.7;
        a *= 0.5;
    }
    return v;
}

// Signed distance to an axis-aligned box.
float box(vec2 p, vec2 c, vec2 h) {
    vec2 d = abs(p - c) - h;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// The sky from the zenith (y = 0) to the horizon (y = 1).
vec3 sky(float y) {
    vec3 c0 = vec3(0.071, 0.055, 0.165);  // #120E2A
    vec3 c1 = vec3(0.165, 0.090, 0.271);  // #2A1745
    vec3 c2 = vec3(0.420, 0.145, 0.275);  // #6B2546
    vec3 c3 = vec3(0.784, 0.341, 0.243);  // #C8573E
    vec3 c4 = vec3(0.910, 0.604, 0.333);  // #E89A55
    if (y < 0.40) return mix(c0, c1, y / 0.40);
    if (y < 0.70) return mix(c1, c2, (y - 0.40) / 0.30);
    if (y < 0.88) return mix(c2, c3, (y - 0.70) / 0.18);
    return mix(c3, c4, clamp((y - 0.88) / 0.12, 0.0, 1.0));
}

// The torii, in its own units: base centre at the origin, y up, about one
// unit tall. Returns a signed distance.
float torii(vec2 q) {
    float taper = 0.035 + 0.008 * (1.0 - q.y);
    float d = box(vec2(abs(q.x), q.y), vec2(0.30 - 0.02 * q.y, 0.42), vec2(taper, 0.42));
    // Nuki, the lower beam, running through the pillars.
    d = min(d, box(q, vec2(0.0, 0.66), vec2(0.43, 0.026)));
    // Gakuzuka, the strut holding the name plaque.
    d = min(d, box(q, vec2(0.0, 0.74), vec2(0.03, 0.06)));
    // Shimaki and kasagi: the top beams, the kasagi sweeping up at its ends.
    d = min(d, box(q, vec2(0.0, 0.82), vec2(0.48, 0.022)));
    float lift = 0.07 * pow(clamp(abs(q.x) / 0.58, 0.0, 1.0), 3.0);
    d = min(d, box(vec2(q.x, q.y - lift), vec2(0.0, 0.89), vec2(0.58, 0.032)));
    return d;
}

// The shrine's hall seen from the front: a heavy irimoya roof whose eaves
// sweep up at the corners, a small gable over the steps, and the hall
// beneath on its posts. In its own units, y up, about one unit wide.
float shrine(vec2 q) {
    float x = abs(q.x);
    // The roof: narrow at the ridge, flaring to the eaves, which lift at
    // their tips.
    float ridge = 0.62, eave = 0.36;
    float k = clamp((ridge - q.y) / (ridge - eave), 0.0, 1.0);
    // Concave: steep under the ridge, spreading out towards the eaves.
    float half_w = mix(0.16, 0.66, pow(k, 1.9));
    float lift = 0.09 * pow(clamp(x / 0.66, 0.0, 1.0), 6.0);
    float roof = max(x - half_w, max(q.y - ridge, (eave + lift) - q.y));
    float ridge_cap = box(q, vec2(0.0, ridge + 0.012), vec2(0.20, 0.016));
    // The chidori gable in front, a low triangle over the middle.
    float gable = max(abs(q.x) * 0.9 + (q.y - 0.50), eave - 0.02 - q.y);
    float hall = box(q, vec2(0.0, 0.18), vec2(0.46, 0.18));
    float steps = box(q, vec2(0.0, 0.04), vec2(0.16, 0.04));
    return min(min(min(roof, ridge_cap), min(gable, hall)), steps);
}

// The bullet of a ring nearest to p: n of them at radius r, turned by a.
// Returns p in that bullet's frame: x along its flight (outward), y across.
vec2 ring(vec2 p, float r, float n, float a) {
    float ang = atan(p.y, p.x) - a;
    float k = floor(ang / TAU * n + 0.5);
    float ba = a + k / n * TAU;
    vec2 dir = vec2(cos(ba), sin(ba));
    vec2 d = p - dir * r;
    return vec2(dot(d, dir), dot(d, vec2(-dir.y, dir.x)));
}

void main() {
    vec2 uv = v_local;                  // 0..1, y down
    vec2 px = uv * u_size;
    float H = u_size.y;
    float scene_w = max(u_size.x - u_panel, H * 0.5);
    float cx = scene_w * 0.5;
    float t = u_time;

    float horizon = 0.74;
    vec3 col = sky(clamp(uv.y / horizon, 0.0, 1.0));

    // Stars in the upper sky.
    vec2 sg = px / 3.0;
    float star = step(0.9975, hash(floor(sg)));
    float twinkle = 0.5 + 0.5 * sin(t * 2.0 + hash(floor(sg) + 3.0) * 30.0);
    col += vec3(1.0, 0.95, 0.9) * star * twinkle * (1.0 - smoothstep(0.0, 0.45, uv.y)) * 0.8;

    // The moon, low on the right of the scene, with a halo.
    vec2 moon = vec2(cx + 0.42 * H, 0.17 * H);
    float md = length(px - moon) / H;
    col += vec3(1.0, 0.85, 0.65) * exp(-md * 9.0) * 0.18;
    float disc = 1.0 - smoothstep(0.052, 0.055, md);
    float maria = fbm((px - moon) / H * 30.0);
    col = mix(col, mix(vec3(1.0, 0.96, 0.86), vec3(0.93, 0.84, 0.70), maria), disc);

    // Clouds lit from below by the sunset.
    float cl = fbm(vec2(px.x / H * 2.2 + t * 0.008, uv.y * 7.0));
    float band = smoothstep(0.45, 0.75, cl) * smoothstep(0.30, 0.55, uv.y) * (1.0 - smoothstep(0.62, 0.74, uv.y));
    col = mix(col, mix(vec3(0.95, 0.55, 0.50), vec3(0.45, 0.20, 0.38), smoothstep(0.62, 0.40, uv.y)), band * 0.45);

    // The boss pattern: rings of bullets leaving a point in the sky and a
    // magic circle turning there.
    vec2 boss = vec2(cx - 0.18 * H, 0.30 * H);
    vec2 bp = px - boss;
    float spin = t * (0.10 + 0.12 * u_beat);
    float bl = length(bp);
    float sky_mask = 1.0 - smoothstep(horizon - 0.06, horizon, uv.y);

    float circle = 0.0;
    float r0 = 0.15 * H;
    circle += exp(-abs(bl - r0) * 0.9);
    circle += 0.6 * exp(-abs(bl - r0 * 0.86) * 1.4) * step(0.5, fract(atan(bp.y, bp.x) / TAU * 48.0 + spin * 2.0));
    // A five-pointed star inscribed in the circle.
    for (int i = 0; i < 5; i++) {
        float a0 = spin + float(i) * TAU / 5.0 - TAU / 4.0;
        float a1 = a0 + 2.0 * TAU / 5.0;
        vec2 p0 = vec2(cos(a0), sin(a0)) * r0 * 0.82;
        vec2 p1 = vec2(cos(a1), sin(a1)) * r0 * 0.82;
        vec2 e = p1 - p0;
        float h = clamp(dot(bp - p0, e) / dot(e, e), 0.0, 1.0);
        circle += 0.8 * exp(-length(bp - p0 - e * h) * 1.1);
    }
    col += vec3(0.95, 0.30, 0.38) * clamp(circle, 0.0, 1.0) * 0.32 * sky_mask;

    // Four rings in flight at a time, alternately red rice bullets and
    // blue round ones, turning opposite ways.
    float period = 9.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float age = fract(t / period + fi / 4.0);
        float r = r0 * 0.5 + age * 1.1 * H;
        bool rice = mod(fi, 2.0) < 0.5;
        float n = rice ? 28.0 : 20.0;
        float a = spin * (rice ? 1.0 : -1.3) + fi * 0.37;
        vec2 q = ring(bp, r, n, a);
        vec2 shape = rice ? vec2(9.0, 4.5) : vec2(6.5, 6.5);
        float e = length(q / shape);
        float core = 1.0 - smoothstep(0.55, 0.75, e);
        float body = 1.0 - smoothstep(0.85, 1.05, e);
        float halo = exp(-max(e - 1.0, 0.0) * 2.5) * (1.0 - body);
        vec3 tint = rice ? vec3(1.0, 0.30, 0.42) : vec3(0.45, 0.62, 1.0);
        float fade = (1.0 - smoothstep(0.6, 1.0, age)) * smoothstep(0.0, 0.06, age) * sky_mask;
        col = mix(col, tint, body * 0.75 * fade);
        col = mix(col, vec3(1.0), core * 0.85 * fade);
        col += tint * halo * 0.35 * fade;
    }

    // Glow of the set sun along the horizon.
    col += vec3(1.0, 0.55, 0.30) * exp(-abs(uv.y - horizon) * 14.0) * 0.25;

    // Far hills.
    float xh = px.x / H;
    float far = horizon - 0.05 - 0.035 * sin(xh * 2.3 + 1.2) - 0.03 * fbm(vec2(xh * 3.0, 2.0));
    if (uv.y > far) {
        col = mix(vec3(0.29, 0.12, 0.22), vec3(0.20, 0.08, 0.17), smoothstep(far, 1.0, uv.y));
        col += vec3(1.0, 0.5, 0.35) * exp(-(uv.y - far) * H * 0.08) * 0.10;
    }

    // The shrine on the near hill, its torii in front of it.
    vec2 shrine_at = vec2(cx + 0.34 * H, 0.775 * H);
    vec2 torii_at = vec2(cx + 0.02 * H, 0.86 * H);
    float near = 0.82 - 0.05 * exp(-pow((px.x - shrine_at.x) / (0.6 * H), 2.0))
                - 0.02 * sin(xh * 1.7) - 0.015 * fbm(vec2(xh * 5.0, 7.0));
    float tree_line = near - 0.03 * smoothstep(0.35, 0.8, fbm(vec2(xh * 18.0, 3.0)));
    vec3 ink = vec3(0.09, 0.043, 0.12);
    if (uv.y > tree_line) col = mix(vec3(0.13, 0.06, 0.16), ink, smoothstep(tree_line, 1.0, uv.y));

    float ss = 0.22 * H;
    float sd = shrine((vec2(px.x, -px.y) - vec2(shrine_at.x, -shrine_at.y)) / ss);
    col = mix(col, vec3(0.14, 0.06, 0.15), 1.0 - smoothstep(-1.0 / ss, 1.0 / ss, sd));
    // Warm light from inside, between the posts.
    vec2 sq = (vec2(px.x, -px.y) - vec2(shrine_at.x, -shrine_at.y)) / ss;
    float window_light = (1.0 - step(0.0, box(sq, vec2(0.0, 0.17), vec2(0.36, 0.09)))) *
        step(0.5, fract(sq.x * 7.0 + 0.5));
    col = mix(col, vec3(1.0, 0.62, 0.30), window_light * 0.55);

    float S = 0.24 * H;
    float td = torii((vec2(px.x, -px.y) - vec2(torii_at.x, -torii_at.y)) / S);
    float aa = 1.5 / S;
    vec3 vermilion = vec3(0.50, 0.08, 0.12);
    // Lit a little on the side facing the sunset.
    float lit = smoothstep(0.02, -0.03, td) * (1.0 - smoothstep(-0.03, 0.0, td));
    vec3 torii_col = mix(vermilion * 0.55, vec3(0.85, 0.30, 0.25), lit * 0.5);
    col = mix(col, torii_col, 1.0 - smoothstep(-aa, aa, td));
    // A soft glow of lantern light at its foot.
    col += vec3(1.0, 0.55, 0.25) * exp(-length(px - torii_at) / H * 14.0) * 0.12;

    // Cherry petals drifting down and to the left.
    for (int layer = 0; layer < 3; layer++) {
        float fl = float(layer);
        float cell = H * (0.10 + 0.05 * fl);
        float speed = 0.035 + 0.02 * fl;
        vec2 drift = vec2(-0.6, 1.0) * t * speed * H;
        vec2 g = (px - drift) / cell;
        vec2 id = floor(g);
        float h = hash(id + fl * 17.0);
        if (h > 0.72) {
            vec2 f = fract(g) - 0.5;
            f += vec2(sin(t * 0.8 + h * 20.0), cos(t * 0.6 + h * 13.0)) * 0.22;
            float ang = t * (0.8 + h) + h * TAU;
            f = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * f;
            float s = (0.022 + 0.014 * fl) * (0.7 + 0.6 * hash(id + 4.0));
            float petal = length(f / vec2(s, s * 0.55));
            float m = 1.0 - smoothstep(0.85, 1.0, petal);
            vec3 pink = mix(vec3(0.97, 0.72, 0.80), vec3(1.0, 0.88, 0.92), hash(id + 9.0));
            col = mix(col, pink, m * (0.35 + 0.2 * fl));
        }
    }

    // A faint vignette towards the corners.
    float vig = length((uv - 0.5) * vec2(1.0, 1.2));
    col *= 1.0 - 0.25 * smoothstep(0.5, 0.95, vig);

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
