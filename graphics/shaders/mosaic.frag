uniform sampler2D texture;
uniform vec2 textureSize;
uniform float mosaic;

void main() {
  vec2 uv = gl_TexCoord[0].xy;
  if (mosaic > 1.0) {
    vec2 size = textureSize / mosaic;
    uv = (floor(uv * size) + 0.5) / size;
  }
  vec4 frag = texture2D(texture, uv);
  gl_FragColor = frag * gl_Color;
}
