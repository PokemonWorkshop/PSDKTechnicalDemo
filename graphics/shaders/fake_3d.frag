#version 120

uniform sampler2D texture;

void main() {
  vec4 frag = texture2D(texture, gl_TexCoord[0].xy) * gl_Color;
  gl_FragColor = frag;
}
