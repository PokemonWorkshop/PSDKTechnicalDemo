#ifdef GL_ES
varying vec2 v_factor_npot;
#else
const vec2 v_factor_npot = vec2(1.0, 1.0);
#endif
uniform float t;

const float PI = 3.14159265359;

void main() {
  vec4 COLORS[7];
  COLORS[0] = vec4(1.0000, 0.1490, 0.2196, 1.0);
  COLORS[1] = vec4(1.0000, 0.4196, 0.1882, 1.0);
  COLORS[2] = vec4(1.0000, 0.6353, 0.0078, 1.0);
  COLORS[3] = vec4(0.0078, 0.8157, 0.5686, 1.0);
  COLORS[4] = vec4(0.0039, 0.5020, 0.9843, 1.0);
  COLORS[5] = vec4(0.4824, 0.2118, 0.8549, 1.0);
  COLORS[6] = vec4(1.0000, 0.1490, 0.2196, 1.0);

  vec2 adjusted_coordinates = gl_TexCoord[0].xy / v_factor_npot;

  float circleX = mod((adjusted_coordinates.x - t) * 6.0, 1.0);
  float colorIndex = mod((adjusted_coordinates.x - t) * 6.0, 6.0);
  vec4 frag = mix(
    COLORS[int(floor(colorIndex))],
    COLORS[int(floor(colorIndex)) + 1],
    fract(colorIndex)
  );
  float circleRadius = pow(sin(adjusted_coordinates.x * PI), 3.0);
  frag.a = 1.0 - (sqrt(pow((adjusted_coordinates.y * 2.0 - 1.0) / circleRadius, 2.0) + pow(circleX * 2.0 - 1.0, 2.0)));
  gl_FragColor = frag;
}