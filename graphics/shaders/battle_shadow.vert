#ifdef GL_ES
precision mediump float;

attribute vec2 position;
attribute vec2 texCoord;
attribute vec4 color;

uniform mat4 sf_texture;
uniform mat4 sf_modelview;
uniform mat4 sf_projection;
uniform vec2 factor_npot;

varying vec4 sf_color;

varying vec2 v_texture_coordinates;
#endif
const vec4 shadowVect = vec4(0.2, -0.2, 0, 0);

void main()
{
#ifdef GL_ES
  vec2 tc = (sf_texture * vec4(texCoord, 0.0, 1.0)).xy;
  float invY = 1.0 - (tc / factor_npot).y;
  sf_color = color;
  v_texture_coordinates = tc;
  gl_Position = sf_projection * sf_modelview * vec4(position.xy, 0.0, 1.0) + shadowVect * invY;
#else
  gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
  gl_FrontColor = gl_Color;
  float invY = 1.0 - gl_TexCoord[0].y;
  gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex + shadowVect * invY;
#endif
}