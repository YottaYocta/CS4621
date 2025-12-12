shader_type sky;
render_mode use_debanding;

uniform vec3 skyColor : source_color;
uniform vec3 horizonColor : source_color;

uniform sampler2D noise_texture;


void sky() {
	// Called for every visible pixel in the sky background, as well as all pixels
	// in the radiance cubemap.
	float col = clamp(EYEDIR.y / 0.05, 0.0, 1.0);
	vec3 skyColorFinal = (3.0-EYEDIR.y)*skyColor + exp(-2.0*EYEDIR.y)*vec3(1.0,1.0,1.0) ; 
	//vec3 skyColorFinal = vec3(0.,0.,0.);
	vec3 white = vec3(1.0,1.0,1.0);
	//vec3 skyColorFinal = EYEDIR.y*skyColor + (1.0-EYEDIR.y)*white;
	vec3 finalColor = mix(horizonColor, skyColorFinal, col);
	
	// we have access to time
	
	//Cloud shader:
	vec2 skyCoords = vec2(EYEDIR.x/EYEDIR.y,EYEDIR.z/EYEDIR.y);
	
	vec4 n = texture(noise_texture,vec2(skyCoords.x/10.,skyCoords.y/10.)); 
	float nClamp = clamp(n.x/4., 0.0, 1.0);
	
	vec3 finalFinalColor = (finalColor * (1.0-nClamp)) + (white*nClamp);

	COLOR = finalFinalColor;
}
