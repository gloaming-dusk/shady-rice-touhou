// point-items: the window mesh. At rest it is Shady's own window quad.
// While the window closes, each pass (client, title bar) stretches upward
// and a little sideways, so the items its tiles turn into have room to
// rise above the window; the fragment shader decides what is drawn where.

#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

attribute vec3 a_pos;
attribute vec2 a_uv;

uniform mat4 u_mvp;
uniform vec4 u_frame_rect;   // this pass inside the frame: x, y, w, h (y up)
uniform float u_close_progress;

// Where the fragment is, in frame units (0..1 over the whole frame, y up;
// beyond that range while closing).
varying vec2 v_frame;

// How far up, in frame heights, the items travel.
const float RISE = 1.6;
const float MARGIN = 0.12;

void main() {
    vec2 local = a_pos.xy;
    float closing = step(0.0001, u_close_progress);
    vec2 lo = vec2(mix(u_frame_rect.x, -MARGIN, closing), u_frame_rect.y);
    vec2 hi = vec2(mix(u_frame_rect.x + u_frame_rect.z, 1.0 + MARGIN, closing),
                   u_frame_rect.y + u_frame_rect.w + RISE * closing);
    vec2 frame = lo + local * (hi - lo);
    v_frame = frame;
    gl_Position = u_mvp * vec4(frame, a_pos.z, 1.0);
    gl_Position.y = -gl_Position.y;
}
