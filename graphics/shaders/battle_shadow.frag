uniform sampler2D texture;
const vec4 gray = vec4(0.4, 0.4, 0.4, 0.3);
const vec4 blank = vec4(0, 0, 0, 0);
void main()
{
  vec4 glColor = gl_Color;
  vec2 tc = gl_TexCoord[0].xy;
  vec4 frag = texture2D(texture, tc);
  gl_FragColor = mix(blank, gray, frag.a) * glColor;
}