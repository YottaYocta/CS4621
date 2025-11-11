shader_type spatial;
render_mode unshaded;

#define MAX_STEPS 100
#define MARCH_SIZE 0.08

const vec3 SUN_POSITION = vec3(5.0,6.0,0.0);

uniform sampler2D noise_texture;

// Signed distance function for a sphere
float sd_sphere(vec3 p, float radius) {
    return length(p) - radius;
}

// Takes in input of position in cloud
// Don't know where the numbers came from but apparently this function is used in a lot of demos
float noise(vec3 x) {
	vec3 p = floor(x);
	vec3 f = fract(x);
	vec3 u = f * f * (3. - 2. * f);
	
	// sampling 2D slice from 3D position. z coord lets us move through "time" in the noise?
	vec2 uv = (p.xy + vec2(37.0, 239.0) * p.z) + u.xy; 
	vec2 tex = textureLod(noise_texture, (uv + 0.5) / 256.0, 0.0).yx;
	// Smooth noise mix from texture lookup and rescale it to [-1,1]
	return mix(tex.x, tex.y, u.z) * 2.0 - 1.0;
	
	  // Simplified lookup for single-channel noise
    //vec2 uv = (p.xy + vec2(37.0,239.0)*p.z) / 256.0;
    //float tex = textureLod(noise_texture, uv + f.xy / 256.0, 0.0).r;
    //return tex * 2.0 - 1.0;
}
//Fracal Brownian Motion
float fbm(vec3 p, float time) {
	// No idea abt these numbers
	// Getting new vector of position with also time?
	vec3 q = p + (TIME*0.5 *vec3(1.0,-0.2,-1.0));
	
	float f = 0.0;
	float scale = 0.5;
	float factor = 2.02;
	// 6 iterations of adjusting noise?
	for(int i =0; i < 6; i++) {
		f += scale * noise(q);
		q *= factor;
		factor += 0.21;
		scale *= 0.5;
	}
	
	return f;
}

// Scene function
float scene(vec3 p, float time) {
    float dist = sd_sphere(p, 1.0);
	float f = fbm(p, time);
	return -dist + f; //adding a noise term to the inside of distance
}

// Raymarch function
vec4 raymarch(vec3 ro, vec3 rd, float time) {
	float depth = 0.0; //analogous to d0
	vec3 p = ro + rd * depth;
	vec3 sunDirection = normalize(SUN_POSITION);
	vec4 res = vec4(0.0);
    for (int i = 0; i < MAX_STEPS; i++) {
        float density = scene(p, time); //analogous to dS
        // Only draw if density is greater than 0 (inside cloud)
      	if (density > 0.0) {
			//Directional derivative lighting
			float diffuse = clamp((scene(p, time) - scene(p + 0.3*sunDirection, time)) / 0.3, 0.0, 1.0);
			vec3 lin = vec3(0.60,0.60,0.75)*1.1 + 0.8*vec3(1.0,0.6,0.3)*diffuse;
			vec4 color = vec4(mix(vec3(1.0), vec3(0.0), density), density);
			color.rgb *= lin;
			
			color.rgb *= color.a;
			res += color * (1.0 - res.a);
		}
		depth += MARCH_SIZE;
		p = ro + depth * rd;
    }
    return res;
}

varying vec3 vert;
varying float time;

void vertex() {
	// Called for every vertex the material is visible on.
	vert = VERTEX; // vertex in local space
	time = TIME;
	
}

void fragment() {
	// Called for every pixel the material is visible on.
	// Normalized screen-space UV
    vec2 uv =fract(UV * vec2(3,2)) - 0.5;
   

    // Camera origin and direction
    vec3 ro = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD,1)).xyz;
    vec3 rd = normalize(vert - ro);
	//attempt 2--------
	//vec3 ro = vec3(0.0,0.0,5.0);
	//vec3 rd = normalize(vec3(uv, -1.0));
	
	
	//Sun and sky?
	vec3 sunDirection = normalize(SUN_POSITION);
	float sun = clamp(dot(sunDirection, rd), 0.0, 1.0);
	
	//base sky color
	vec3 color = vec3(0.7,0.7,0.90);
	color -= 0.8*vec3(0.90,0.75,0.90)*rd.y;
	color += 0.5 * vec3(1.0,0.5,0.3) * pow(sun, 10.0);
	
	
    // Perform raymarch
    vec4 d = raymarch(ro, rd, TIME);
    //vec3 p = ro + rd * d;
	color = color * (1.0 - d.a) + d.rgb;
	//if (length(d) > 0.0) {
		//color = d.xyz;
	//} else {
		//discard;
	//}

    ALBEDO = color;
    //EMISSION = color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}