uniform sampler2D texture;
uniform float textureHeight;
uniform float textureWidth;
uniform int lineOffset;

void main() {
    vec2 tc = gl_TexCoord[0].xy;
    vec4 frag = texture2D(texture, tc);

    if(int(floor(tc.y * textureHeight)) % 2 == lineOffset) {
        frag.a = 0.0;
    }

    gl_FragColor = frag;
}