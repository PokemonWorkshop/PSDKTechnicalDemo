attribute vec2 position;
attribute vec2 texCoord;
attribute vec4 color;

uniform mat4 sf_modelview;
uniform mat4 sf_projection;

varying vec2 v_texCoord;
varying vec4 v_color;
varying vec2 v_position;

void main() {
    v_texCoord = texCoord;
    v_color = color;
    v_position = position;
    gl_Position = sf_projection * sf_modelview * vec4(position.xy, 0.0, 1.0);
}
