#ifdef GL_ES
precision mediump float;

uniform mat4 sf_texture;
uniform vec2 factor_npot;

varying vec2 v_texCoord;
#else
const vec2 factor_npot = vec2(1.0, 1.0);
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

#ifdef GL_ES
  vec2 tc = (sf_texture * vec4(v_texCoord / factor_npot, 0.0, 1.0)).xy;
#else
  vec2 tc = gl_TexCoord[0].xy;
#endif

  float circleX = mod((tc.x - t) * 6.0, 1.0);
  float colorIndex = mod((tc.x - t) * 6.0, 6.0);
  vec4 frag = mix(
    COLORS[int(floor(colorIndex))],
    COLORS[int(floor(colorIndex)) + 1],
    fract(colorIndex)
  );
  float circleRadius = pow(sin(tc.x * PI), 3.0);
  frag.a = 1.0 - (sqrt(pow((tc.y * 2.0 - 1.0) / circleRadius, 2.0) + pow(circleX * 2.0 - 1.0, 2.0)));
  gl_FragColor = frag;
}