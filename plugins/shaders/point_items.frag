// point-items: a window that closes breaks into tiles, and every tile
// becomes a score item that is collected upward, as when a stage's enemies
// are cleared: blue point items (点) and now and then a red power item (P).
//
// At rest it draws the window as Shady's own shader does, without the
// glass effects: the client's texture, tint and opacity, and the rounded
// frame with its border.
//
// Close timeline (u_close_progress 0..1):
//   0.00-0.30  the window splits into tiles that shrink apart
//   0.15-0.45  each tile turns into an item
//   0.25-1.00  the items rise, swaying, faster and faster

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D u_tex;
uniform vec4 u_tint;
uniform float u_has_alpha;
uniform float u_brightness;
uniform float u_time;
uniform vec4 u_border_color;
uniform vec2 u_border_width;
uniform float u_close_progress;
uniform vec4 u_frame_rect;
uniform vec2 u_frame_px;
uniform vec2 u_frame_shape;
uniform vec2 u_window_size;
uniform vec4 u_uv_rect;

varying vec2 v_frame;

const float TILE = 44.0;       // tile size in px, about
const float ITEM = 16.0;       // an item's size in px
const float RISE = 1.6;        // as in point_items.vert

const vec3 POINT_BLUE = vec3(0.24, 0.44, 0.92);
const vec3 POWER_RED = vec3(0.86, 0.16, 0.22);

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float frame_aa(float d) {
#ifdef GL_OES_standard_derivatives
    return max(fwidth(d), 0.0001);
#else
    return 1.0;
#endif
}

// The frame's size in px: the rounded frame when there is one, else this
// pass's size scaled up to the whole frame.
vec2 frame_px() {
    if (min(u_frame_px.x, u_frame_px.y) > 0.5) return u_frame_px;
    return u_window_size / max(u_frame_rect.zw, vec2(0.0001));
}

// Signed distance to the rounded frame, in px, for a point in frame units.
float frame_distance(vec2 f, vec2 size) {
    vec2 half_size = size * 0.5;
    float r = min(u_frame_shape.x, min(half_size.x, half_size.y));
    vec2 q = abs(f * size - half_size) - (half_size - vec2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// The window as it looks at rest, at frame position f, or nothing when f
// is outside this pass.
vec4 window_color(vec2 f, vec2 size) {
    vec2 local = (f - u_frame_rect.xy) / u_frame_rect.zw;
    if (local.x < 0.0 || local.x > 1.0 || local.y < 0.0 || local.y > 1.0)
        return vec4(0.0);
    vec2 uv = vec2(local.x, 1.0 - local.y);
    vec4 color = texture2D(u_tex, u_uv_rect.xy + uv * u_uv_rect.zw);
    if (u_has_alpha < 0.5) color.a = 1.0;
    color.rgb *= u_tint.rgb * u_brightness;
    color *= u_tint.a;

    bool rounded = min(u_frame_px.x, u_frame_px.y) > 0.5;
    float coverage = 1.0;
    float border_mask;
    if (rounded) {
        float d = frame_distance(f, size);
        float aa = frame_aa(d);
        coverage = clamp(0.5 - d / aa, 0.0, 1.0);
        float border_px = u_frame_shape.y;
        float inner = max(-d - border_px, 0.0);
        border_mask = step(0.0001, border_px) * clamp(0.5 + (d + border_px) / aa, 0.0, 1.0);
        float glow = step(0.0001, border_px) * exp(-inner / 5.0) * 0.16;
        color.rgb += u_border_color.rgb * u_border_color.a * glow * color.a;
    } else {
        float on = step(0.000001, max(u_border_width.x, u_border_width.y));
        float bx = min(uv.x, 1.0 - uv.x) / max(u_border_width.x, 0.000001);
        float by = min(uv.y, 1.0 - uv.y) / max(u_border_width.y, 0.000001);
        border_mask = (1.0 - smoothstep(0.72, 1.0, min(bx, by))) * on;
    }
    float border_alpha = clamp(border_mask * u_border_color.a, 0.0, 1.0);
    color.rgb = color.rgb * (1.0 - border_alpha) + u_border_color.rgb * border_alpha;
    color.a = color.a + border_alpha * (1.0 - color.a);
    return color * coverage;
}

// One bit of a 7x7 glyph whose rows are given top to bottom as integers.
float glyph_bit(float row_bits, float column) {
    return mod(floor(row_bits / exp2(6.0 - column)), 2.0);
}

// The item's face for a point q in -1..1 across the item (y up).
vec4 item_face(vec2 q, bool power) {
    float box = max(abs(q.x), abs(q.y));
    if (box > 1.0) return vec4(0.0);
    vec3 base = power ? POWER_RED : POINT_BLUE;
    // A lighter rim and a soft top-left highlight, like the sprites.
    vec3 c = mix(base * 1.25, base * 0.8, smoothstep(-1.0, 1.0, q.x - q.y));
    c = mix(c, vec3(1.0), smoothstep(0.78, 0.92, box) * 0.85);

    // 7x7 glyph inside the rim.
    vec2 g = (q * vec2(1.0, -1.0) + 0.78) / 1.56 * 7.0;
    if (g.x >= 0.0 && g.x < 7.0 && g.y >= 0.0 && g.y < 7.0) {
        float column = floor(g.x), row = floor(g.y);
        float bits;
        if (power) {
            // P
            bits = row < 0.5 ? 60.0 : row < 1.5 ? 34.0 : row < 2.5 ? 34.0 :
                   row < 3.5 ? 60.0 : 32.0;
        } else {
            // 点
            bits = row < 0.5 ? 8.0 : row < 1.5 ? 14.0 : row < 2.5 ? 8.0 :
                   row < 3.5 ? 62.0 : row < 4.5 ? 34.0 : row < 5.5 ? 62.0 : 85.0;
        }
        c = mix(c, vec3(1.0), glyph_bit(bits, column));
    }
    return vec4(c, 1.0);
}

void main() {
    vec2 size = frame_px();
    float p = clamp(u_close_progress, 0.0, 1.0);
    if (p <= 0.0) {
        vec4 color = window_color(v_frame, size);
        if (color.a <= 0.0) discard;
        gl_FragColor = color;
        return;
    }

    vec2 grid = max(floor(size / TILE + 0.5), vec2(1.0));
    vec2 tile_px = size / grid;
    vec2 here = v_frame * size;               // px, y up
    float column0 = floor(here.x / tile_px.x);
    float row0 = floor(here.y / tile_px.y);

    vec4 result = vec4(0.0);
    for (int dc = -1; dc <= 1; dc++) {
        float column = column0 + float(dc);
        if (column < 0.0 || column >= grid.x) continue;
        // Tiles only move up, so this point can only hold tiles from its
        // own row and the rows below it.
        for (int dr = 0; dr < 48; dr++) {
            float row = min(row0, grid.y - 1.0) - float(dr);
            if (row < 0.0) break;
            vec2 id = vec2(column, row);
            float h = hash(id + 0.37);
            float h2 = hash(id + 7.13);
            vec2 center = (id + 0.5) * tile_px;

            // Higher tiles leave first, with a little randomness.
            float delay = (1.0 - (row + 0.5) / grid.y) * 0.16 + h * 0.08;
            float split = smoothstep(0.0, 0.30, p - delay * 0.5);
            float become = smoothstep(0.15, 0.45, p - delay);
            float s = clamp((p - 0.25 - delay) / 0.75, 0.0, 1.0);
            float rise = s * s * (RISE * size.y + size.y * 0.25);
            float sway = sin(h * 6.2832 + s * 7.0) * 10.0 * s +
                         (h2 - 0.5) * 40.0 * s;
            vec2 at = center + vec2(sway, rise);

            float half_tile = mix(0.5 * min(tile_px.x, tile_px.y) * 1.02,
                                  ITEM * 0.5, split);
            vec2 d = (here - at) / half_tile;
            if (max(abs(d.x), abs(d.y)) > 1.0) continue;

            // The tile still shows the window here...
            vec2 source = (center + d * min(tile_px.x, tile_px.y) * 0.5) / size;
            vec4 window = window_color(source, size);
            // ...until it becomes an item. Items belong to the pass that
            // holds their tile's centre, so none is drawn twice.
            vec2 owner = (center / size - u_frame_rect.xy) / u_frame_rect.zw;
            bool mine = owner.x >= 0.0 && owner.x < 1.0 && owner.y >= 0.0 && owner.y < 1.0;
            vec4 item = mine ? item_face(d, h2 > 0.78) : vec4(0.0);
            vec4 c = mix(window, item, become);
            // Items flicker as they near the top and vanish.
            float fade = 1.0 - smoothstep(0.75, 1.0, s);
            fade *= mix(1.0, 0.6 + 0.4 * step(0.5, fract(u_time * 14.0 + h * 3.0)),
                        smoothstep(0.6, 0.8, s));
            c *= fade;
            if (c.a > result.a) result = c;
        }
    }
    if (result.a <= 0.002) discard;
    gl_FragColor = result;
}
