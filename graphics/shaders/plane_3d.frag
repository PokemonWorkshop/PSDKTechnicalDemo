uniform sampler2D texture;
uniform sampler2D planeTexture;
uniform vec2 zoom;
uniform vec2 origin;
uniform vec2 textureSize;
uniform vec2 screenSize;

void main() {
  vec2 screenCoord = gl_TexCoord[0].xy * screenSize;
  vec2 bmpCoord = mod(origin + screenCoord / zoom, textureSize) / textureSize;
  vec4 frag = texture2D(planeTexture, bmpCoord);
  frag.a *= gl_Color.a; 
  frag.a *= texture2D(texture, gl_TexCoord[0].xy).a;
  gl_FragColor = frag;
}