uniform mat4 camera;
uniform float z;
const vec4 shadowVect = vec4(0.5, -0.5, 0, 0.8);

void main()
{
  gl_TexCoord[0].xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
  float invY = 1 - gl_TexCoord[0].y;
  vec4 vert = gl_Vertex;
  vert.z = z;
  gl_Position = camera * vert + shadowVect * invY;
  vert.z = gl_Vertex.z;
  gl_FrontColor = gl_Color;
}