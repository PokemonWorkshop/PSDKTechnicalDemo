uniform mat4 camera;
uniform float z;
uniform vec2 screenSize;
uniform vec2 cameraPosition;
uniform float cameraZoom;

void main() {
  vec2 localOffset = gl_Vertex.xy - screenSize * 0.5;
  vec4 vert = gl_Vertex;
  vert.xy = cameraPosition + localOffset * (z / cameraZoom);
  vert.z = z;
  gl_Position = camera * vert;
  gl_TexCoord[0].xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
  gl_FrontColor = gl_Color;
}