#version 120

uniform mat4 camera;
uniform float z;

void main() {
  vec4 vert = gl_Vertex;
  vert.z = z;
  gl_Position = camera * vert;
  vert.z = gl_Vertex.z;
  gl_TexCoord[0].xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
  gl_FrontColor = gl_Color;
}
