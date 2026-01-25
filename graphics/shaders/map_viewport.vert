#ifdef GL_ES
precision mediump float;

attribute vec2 position;
attribute vec2 texCoord;
attribute vec4 color;

uniform mat4 sf_texture;
uniform mat4 sf_modelview;
uniform mat4 sf_projection;
uniform vec2 factor_npot;

varying vec2 v_texture_coordinates;
varying vec2 v_inv_texture_coordinates;
varying vec4 sf_color;
#else
const vec2 factor_npot = vec2(1.0, 1.0);
#endif
uniform bool in_snapshot;

varying vec2 v_factor_npot;

// Entry point function
void main()
{
#ifdef GL_ES
  vec2 tc = (sf_texture * vec4(texCoord, 0.0, 1.0)).xy;
#else
  vec2 tc = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#endif

  vec2 invTexCoord = tc;
  if (in_snapshot) {
    invTexCoord = vec2(tc.x, 1.0 - tc.y);
  }

  v_factor_npot = factor_npot;

#ifdef GL_ES
  v_texture_coordinates = tc;
  v_inv_texture_coordinates = invTexCoord;
  gl_Position = sf_projection * sf_modelview * vec4(position.xy, 0.0, 1.0);
  sf_color = color;
#else
  gl_TexCoord[0].xy = tc;
  gl_TexCoord[1].xy = invTexCoord;
  gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
  gl_FrontColor = gl_Color;
#endif
}
