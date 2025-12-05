shader_type sky;
render_mode use_half_res_pass;

uniform vec3 skyColor : source_color;
uniform vec3 horizonColor : source_color;

void sky() {
	// Called for every visible pixel in the sky background, as well as all pixels
	// in the radiance cubemap.
	float col = clamp(EYEDIR.y / 0.05, 0.0, 1.0);
	vec3 skyColorFinal = (3.0-EYEDIR.y)*skyColor + exp(-2.0*EYEDIR.y)*vec3(1.0,1.0,1.0) ; 
	vec3 white = vec3(1.0,1.0,1.0);
	//vec3 skyColorFinal = EYEDIR.y*skyColor + (1.0-EYEDIR.y)*white;
	vec3 finalColor = mix(horizonColor, skyColorFinal, col);
	
	// we have access to time
	COLOR = finalColor;
	
	//ALPHA=SD
	//FOG=
}
