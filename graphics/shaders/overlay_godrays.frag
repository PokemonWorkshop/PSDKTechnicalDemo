// Uniform keeping track of the blend mode
// 0: normal (mix)
// 1: add
// 2: subtract
// 3: multiply
// 4: overlay
// 5: screen
uniform int blend_mode = 0;

// Compatibility with other SpritesetMap shaders

const vec3 lumaF = vec3(.299, .587, .114);

uniform vec4 color = vec4(0.0,0.0,0.0,0.0);
uniform vec4 tone = vec4(0.0,0.0,0.0,0.0);

// Uniform keeping track of a sample color
uniform vec4 sample_color = vec4(0.9,0.9,1.0,1.0);

// Uniform keeping track of base texture
uniform sampler2D texture;

// Uniform keeping track of the time variable
uniform float time;

// Uniform keeping track of the opacity variable
uniform float opacity = 1.0;

// Constant keeping track of a small number for comparison purposes
const float SMALL_NUMBER = 0.0001;

// Random and noise functions from Book of Shader's chapter on Noise.
float random(vec2 _uv) {
  return fract(sin(dot(_uv.xy,
     vec2(12.9898, 78.233))) *
    43758.5453123);
}

// Function to compute a rotation matrix
mat2 rotate(float _angle){
  return mat2(vec2(cos(_angle), -sin(_angle)),
          vec2(sin(_angle), cos(_angle)));
}

float noise_gen(in vec2 pixPos) {
  vec2 i = floor(pixPos);
  vec2 f = fract(pixPos);

  // Four corners in 2D of a tile
  float a = random(i);
  float b = random(i + vec2(1.0, 0.0));
  float c = random(i + vec2(0.0, 1.0));
  float d = random(i + vec2(1.0, 1.0));


  // Smooth Interpolation

  // Cubic Hermine Curve. Same as SmoothStep()
  vec2 u = f * f * (3.0-2.0 * f);

  // Mix 4 corners percentages
  return mix(a, b, u.x) +
      (c - a)* u.y * (1.0 - u.x) +
      (d - b) * u.x * u.y;
}


// Function to compute the overlay blend mode effect
vec4 overlay_blend_mode(vec4 base, vec4 blend1){
  vec4 limit = step(0.5, base);
  return mix(2.0 * base * blend1, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend1), limit);
}

// Function to compute the screen blend mode effect
vec4 screen(vec4 base, vec4 blend){
  return 1.0 - (1.0 - base) * (1.0 - blend);
}

vec4 godrays(vec2 pixPos)
{
  // Based off of: https:// godotshaders.com/shader/god-rays/

  float angle = 0.0;
  float position = -0.1;
  float spread = 0.5; // hint_range(0.0, 1.0)
  float cutoff = 0.1; // hint_range(-1.0, 1.0)
  float falloff = 0.2; // hint_range(0.0, 1.0)
  float edge_fade = 0.15; // hint_range(0.0, 1.0)

  float speed = 1.0;
  float ray1_density = 10.0;
  float ray2_density = 30.0;
  float ray2_intensity = 0.3; // hint_range(0.0, 1.0)

  // Rotate, skew and move the UVs
  vec2 transformed_uv = (rotate(angle) * (pixPos - position) ) / ( (1.0 - pixPos.y + spread) - ((1.0 - pixPos.y) * spread));

  // Animate the ray according the the new transformed UVs
  vec2 ray1 = vec2(transformed_uv.x * ray1_density + sin(time * 0.3 * speed) * (ray1_density * 0.2), 1.0);
  vec2 ray2 = vec2(transformed_uv.x * ray2_density + sin(time * 0.6 * speed) * (ray1_density * 0.2), 1.0);

  // Cut off the ray's edges
  float cut = step(cutoff, transformed_uv.x) * step(cutoff, 1.0 - transformed_uv.x);
  ray1 *= cut;
  ray2 *= cut;

  // Apply the noise pattern (i.e. create the rays)
  float rays = clamp(noise_gen(ray1) + (noise_gen(ray2) * ray2_intensity), 0., 1.);

  // Fade out edges
  rays *= smoothstep(0.0, falloff, (pixPos.y)); // Bottom
  rays *= smoothstep(0.0 + cutoff, edge_fade + cutoff, transformed_uv.x); // Left
  rays *= smoothstep(0.0 + cutoff, edge_fade + cutoff, 1.0 - transformed_uv.x); // Right

  // Color to the rays
  vec3 shine = vec3(rays) * (sample_color.rgb + vec3(pixPos.y) * 0.5);

  return vec4(shine, rays * sample_color.a);
}

// Account for opacity in blend modes
vec3 blend(vec3 frag, vec3 overlay, float overlay_opacity)
{
  float base_opacity = 1.0 - overlay_opacity;
  return step(SMALL_NUMBER, float(blend_mode==0)) * mix(frag, overlay, overlay_opacity)
      +   step(SMALL_NUMBER, float(blend_mode==1)) * (frag * base_opacity + (overlay + frag) * overlay_opacity)
      +   step(SMALL_NUMBER, float(blend_mode==2)) * (frag * base_opacity + (overlay - frag) * overlay_opacity)
      +   step(SMALL_NUMBER, float(blend_mode==3)) * (frag * base_opacity + (overlay * frag) * overlay_opacity)
      +   step(SMALL_NUMBER, float(blend_mode==4)) * overlay_blend_mode(vec4(frag,1.0),vec4(overlay.rgb, overlay_opacity)).rgb
      +   step(SMALL_NUMBER, float(blend_mode==5)) * screen(vec4(frag,1.0),vec4(overlay.rgb, overlay_opacity)).rgb;
}

// Account for blend mode
// 0: normal (mix)
// 1: add
// 2: subtract
// 3: multiply
// 4: overlay
// 5: screen
vec4 account_for_blend_mode(vec4 frag, vec4 overlay)
{
  float overlay_opacity = opacity * overlay.a;
  return vec4(blend(frag.rgb, overlay.rgb, overlay_opacity),frag.a);
}

// Entry point function
void main() {
  // Load the base texture
  vec4 frag = texture2D(texture, gl_TexCoord[0].xy);

  // Process overlay preset function + blend mode
  vec4 overlay = godrays(gl_TexCoord[1].xy);
  frag = account_for_blend_mode(frag, overlay);

  // Compatibility with color_process
  frag.rgb = mix(frag.rgb, color.rgb, color.a);

  // Compatibility with tone_process
  float luma = dot(frag.rgb, lumaF);
  frag.rgb = mix(frag.rgb, vec3(luma), tone.a);
  frag.rgb += tone.rgb;

  // gl_FragColor serves as our output
  gl_FragColor = frag;
}
