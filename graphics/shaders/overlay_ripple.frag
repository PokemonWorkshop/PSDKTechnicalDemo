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

//uniform keeping track of a sample color
uniform vec4 sample_color = vec4(0.9,0.9,1.0,1.0);

//uniform keeping track of base texture
uniform sampler2D texture;

//uniform keeping track of a position
uniform vec2 position = vec2(0.5, 0.5);

//uniform keeping track of the time variable
uniform float time;
//uniform keeping track of the opacity variable
uniform float opacity = 1.0;

//constant keeping track of a small number for comparison purposes
const float SMALL_NUMBER = 0.0001;

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

vec4 ripple(vec2 pixPos)
{
	//progress of the ripple
	float spread = mod(time, 1.0);
	//width of the ripple
	float width = 0.098;
	//strength of distorsion
	float amount = 0.008;

	//map out the ripple, this makes a donut shape
	float outer_map = 1.0 - smoothstep(spread - width, spread, compute_distance(pixPos,position));
	float inner_map = smoothstep(spread - width * 2.0,spread - width, compute_distance(pixPos,position) );
	float map = outer_map * inner_map;

	//fading factor with distance
	float fade = clamp(1.2 - spread,0.0,1.0);

	//normalize the result
	vec2 displacement = normalize(gl_TexCoord[0].xy - position) * amount * map * fade;

	return texture2D(texture, clamp(gl_TexCoord[0].xy - displacement,vec2(0.0),vec2(1.0))) + map * sample_color * fade;
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
	vec4 overlay = ripple(gl_TexCoord[1].xy);

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
