uniform bool in_snapshot;

// Entry point function
void main()
{
  vec2 tc = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

  vec2 invTexCoord = tc;
  if (in_snapshot) {
    invTexCoord = vec2(tc.x, 1.0 - tc.y);
  }

  gl_TexCoord[0].xy = tc;
  gl_TexCoord[1].xy = invTexCoord;
  gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
  gl_FrontColor = gl_Color;
}
