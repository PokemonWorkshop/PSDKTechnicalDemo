#ifdef GL_ES
precision mediump float;

uniform mat4 sf_texture;
uniform vec2 factor_npot;

varying vec2 v_texCoord;
varying vec4 v_color;
#endif
uniform sampler2D texture;
const vec4 gray = vec4(0.4, 0.4, 0.4, 0.3);
const vec4 blank = vec4(0, 0, 0, 0);
void main()
{
#ifdef GL_ES
  vec2 tc = (sf_texture * vec4(v_texCoord, 0.0, 1.0)).xy;
  vec4 glColor = v_color;
#else
  vec4 glColor = gl_Color;
  vec2 tc = gl_TexCoord[0].xy;
#endif
  vec4 frag = texture2D(texture, tc);
  gl_FragColor = mix(blank, gray, frag.a) * glColor;
}