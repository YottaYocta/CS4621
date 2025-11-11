shader_type spatial;
uniform sampler2D noise;
uniform float height_scale;
uniform sampler2D normalmap;
varying vec2 tex_position;

void vertex() {
	// Called for every vertex the material is visible on.
	tex_position = VERTEX.xz / 2.0 + 0.5;
  float height = texture(noise, tex_position).x;
  VERTEX.y += height * height_scale;
	
}

void fragment() {
	// Called for every pixel the material is visible on.
	NORMAL_MAP = texture(normalmap, tex_position).xyz;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
