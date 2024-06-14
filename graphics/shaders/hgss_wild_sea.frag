uniform sampler2D texture;
uniform float time;

void main() {
    vec2 tc = gl_TexCoord[0].xy;

    float offsetX = 0.01 * sin(tc.y * 50.0 + time * 10.0);
    vec2 newTC = vec2(tc.x + offsetX, tc.y);

    vec4 frag = texture2D(texture, newTC);
    gl_FragColor = frag;
}
