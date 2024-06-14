uniform sampler2D texture;
uniform float textureHeight;
uniform int lineOffset;

void main() {
    vec2 tc = gl_TexCoord[0].xy;
    vec4 frag = texture2D(texture, tc);

    int lineIndex = int(floor(tc.y * textureHeight));
    if ((lineIndex / 6) % 2 == 1) {
        frag.a = 0.0;
    }

    gl_FragColor = frag;
}
