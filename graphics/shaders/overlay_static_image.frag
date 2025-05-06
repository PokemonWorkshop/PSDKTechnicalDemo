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

//uniform keeping track of addtional texture 1
uniform sampler2D extra_texture;

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

// static_image preset
vec4 static_image(vec2 pixPos){
	//calculate distance of current pixel to center, multiplied by a factor
  float dist = clamp(compute_distance(pixPos,CENTER) * dist_factor,0.0,1.0);

	//final result
  return vec4(texture2D(extra_texture, pixPos).rgb,dist);
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
	vec4 overlay = static_image(gl_TexCoord[1].xy);

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
