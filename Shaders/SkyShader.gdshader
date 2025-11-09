shader_type sky;

uniform vec3 skyColor : source_color;
uniform vec3 horizonColor : source_color;

void sky() {
	// Called for every visible pixel in the sky background, as well as all pixels
	// in the radiance cubemap.
	float col = clamp(EYEDIR.y / 0.05, 0.0, 1.0);
	vec3 finalColor = mix(horizonColor, skyColor, col);
	// we have access to time
	COLOR = finalColor;
	
	//ALPHA=SD
	//FOG=
}
