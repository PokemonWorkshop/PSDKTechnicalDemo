uniform sampler2D texture;
uniform float time;
uniform float textureWidth;
uniform float textureHeight;

void main() {
    vec2 resolution = vec2(textureWidth, textureHeight);
    vec2 uv = vec2(gl_FragCoord.x / resolution.x, (resolution.y - gl_FragCoord.y) / resolution.y);

    vec2 center = vec2(0.5, 0.5);
    vec2 toCenter = uv - center;
    float dist = length(toCenter);

    float wave = 0.01 * sin(dist * 30.0 - time * 5.0);

    vec2 newUV = uv + normalize(toCenter) * wave;

    vec4 frag = texture2D(texture, newUV);
    gl_FragColor = frag;
}
