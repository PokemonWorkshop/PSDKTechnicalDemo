//uniform keeping track of the blend mode
// 0: normal (mix)
// 1: add
// 2: subtract
// 3: multiply
// 4: overlay
// 5: screen
uniform int blend_mode = 0;

//// compatibility with other SpritesetMap shaders

const vec3 lumaF = vec3(.299, .587, .114);

uniform vec4 color = vec4(0.0,0.0,0.0,0.0);
uniform vec4 tone = vec4(0.0,0.0,0.0,0.0);

////

//uniform keeping track of base texture
uniform sampler2D texture;

//uniform keeping track of additional texture 2
uniform sampler2D noise;

//uniform keeping track of a color gradient
uniform sampler2D color_gradient;

//uniform keeping track of a first scroll
uniform vec2 direction1 = vec2(0.1, 0.1);
//uniform keeping track of a second scroll
uniform vec2 direction2 = vec2(-0.1, -0.1);

//uniform keeping track of the time variable
uniform float time;
//uniform keeping track of the opacity variable
uniform float opacity = 1.0;
//uniform keeping track of the factor by which the distance should be multiplied
uniform float dist_factor = 1.5;

//constant keeping track of a small number for comparison purposes
const float SMALL_NUMBER = 0.0001;
//constant keeping track of the UV coordinates of the center of the screen
const vec2 CENTER = vec2(0.5, 0.5);

//function to compute the overlay blend mode effect
vec4 overlay_blend_mode(vec4 base, vec4 blend1){
	vec4 limit = step(0.5, base);
	return mix(2.0 * base * blend1, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend1), limit);
}

// function to compute the screen blend mode effect
vec4 screen(vec4 base, vec4 blend){
	return 1.0 - (1.0 - base) * (1.0 - blend);
}

//function to computer the distance to center to leave the middle of the screen free
float compute_distance(vec2 pixPos, vec2 to){
	vec2 result = pixPos - to;
  return length(result);
}

// Water overlay preset
vec4 water(vec2 pixPos){
	//calculate distance of current pixel to center, multiplied by a factor
  float dist = compute_distance(pixPos,CENTER) * dist_factor;
	//wobble according to time
	vec2 wobble = vec2(cos(time)*0.03,sin(time)*0.05);

	//load the noise texture's pixels with a wobble
	vec4 noise1 = texture2D(noise, mod(pixPos + direction1 * time + wobble,vec2(1.0)));
	vec4 noise2 = texture2D(noise, mod(pixPos + direction2 * time,vec2(1.0)));

	//calculate energy based on noise
	float energy =  noise1.r * noise2.r;

	//load color corresponding to energy on a horizontal color gradient
	vec4 newColor = texture2D(color_gradient,vec2(energy,0.5));

	//compute color intensity based on energy
	vec4 color_intensity = overlay_blend_mode(newColor,vec4(energy));

	//final result
	return vec4(color_intensity.rgb,dist+energy);
}

// account for opacity in blend modes
vec3 blend(vec3 frag, vec3 overlay, float overlay_opacity)
{
	float base_opacity = 1.0 - overlay_opacity;
	return step(SMALL_NUMBER, float(blend_mode==0)) * mix(frag,overlay,overlay_opacity)
			+	 step(SMALL_NUMBER, float(blend_mode==1)) * (frag * base_opacity + (overlay + frag) * overlay_opacity)
			+	 step(SMALL_NUMBER, float(blend_mode==2)) * (frag * base_opacity + (overlay - frag) * overlay_opacity)
			+	 step(SMALL_NUMBER, float(blend_mode==3)) * (frag * base_opacity + (overlay * frag) * overlay_opacity)
			+	 step(SMALL_NUMBER, float(blend_mode==4)) * overlay_blend_mode(vec4(frag,1.0),vec4(overlay.rgb,overlay_opacity)).rgb
			+	 step(SMALL_NUMBER, float(blend_mode==5)) * screen(vec4(frag,1.0),vec4(overlay.rgb,overlay_opacity)).rgb;
}

// account for blend mode
// 0: normal (mix)
// 1: add
// 2: subtract
// 3: multiply
// 4: overlay
vec4 account_for_blend_mode(vec4 frag, vec4 overlay)
{
	float overlay_opacity = opacity * overlay.a;
	return vec4(blend(frag.rgb,overlay.rgb,overlay_opacity),frag.a);
}

//main function where everything happens
void main() {
	//load the base texture pixel
  vec4 frag = texture2D(texture, gl_TexCoord[0].xy);

	//overlay presets
	vec4 overlay = water(gl_TexCoord[1].xy);

	//set the final color of this pixel
	frag = account_for_blend_mode(frag,overlay);

	////compability with color_process
	frag.rgb = mix(frag.rgb, color.rgb, color.a);

	////compability with tone_process
	float luma = dot(frag.rgb, lumaF);
	frag.rgb = mix(frag.rgb, vec3(luma), tone.a);
	frag.rgb += tone.rgb;
	////

	gl_FragColor = frag;
}
