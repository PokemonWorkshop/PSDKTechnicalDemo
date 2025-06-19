#ifdef GL_ES
uniform mat4 sf_texture;
uniform vec2 factor_npot;
#endif

attribute vec2 position;
attribute vec2 texCoord;
attribute vec4 color;

uniform mat4 sf_modelview;
uniform mat4 sf_projection;

varying vec4 sf_color;

varying vec2 v_texture_coordinates;

void main() {
    sf_color = color;
#ifdef GL_ES
    v_texture_coordinates = (sf_texture * vec4(texCoord / factor_npot, 0.0, 1.0)).xy;
#else
    v_texture_coordinates = vec2(0.0, 0.0);
#endif
    gl_Position = sf_projection * sf_modelview * vec4(position.xy, 0.0, 1.0);
}
