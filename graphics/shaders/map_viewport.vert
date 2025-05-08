uniform bool in_snapshot = false;

// Entry point function
void main()
{
  vec2 position = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
  if (in_snapshot) {
    gl_TexCoord[1].xy = vec2(position.x, 1 - position.y);
  } else {
    gl_TexCoord[1].xy = position;
  }
  gl_TexCoord[0].xy = position;
  gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
  gl_FrontColor = gl_Color;
}
