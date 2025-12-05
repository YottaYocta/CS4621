shader_type spatial;
render_mode cull_disabled;
//render everything first, use depth buffer to do one pass with all geometry. then bind depth buffer as a texture and reference as value in shader.
//then do another pass and do shader for all pixels. when you march and dist from camera is greater than depth stored in buffer then quit. if pixels are way above clouds you could not do anything
//look into full screen pass/quad for shader. look at color correction for an example, want for every pixel not rly geometry
//do the inverse of the projection urself

//look into disabling backface culling - kinda works, order of rendering objects inside gets kinda weird though
// try flipping normals to only drop back - also kinda works same as above
// for both the occlusion makes the most sense if cull_disabled totally

#define MAX_STEPS 40
#define MARCH_SIZE 0.16
#define PI 3.14159265359
#define RADIUS 1.5

const vec3 SUN_POSITION = vec3(5.0,6.0,0.0);

uniform sampler2D noise_texture : repeat_enable;
uniform sampler2D blue_noise : repeat_enable;

uniform vec3 boundsMin = -(vec3(2.5,2.5,1));
uniform vec3 boundsMax = vec3(2.5,2.5,1);

uniform vec3 light_pos = vec3(5.0,6.0,0.0);
uniform vec4 light_color : source_color;

uniform vec3 cloudPos = vec3(0,0,0);


// Signed distance function for a sphere
float sd_sphere(vec3 p, float radius) {
    return length(p) - radius;
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
	vec3 ab = b-a;
	vec3 ap = p-a;
	float t = dot(ab,ap) / dot(ab,ab);
	t = clamp(t, 0.0, 1.0);
	vec3 c = a + t*ab;
	float d = length(p-c) - r;
	return d;
}

float sdTorus(vec3 p, vec2 r) {
	float x = length(p.xz) - r.x;
	return length(vec2(x, p.y)) - r.y;
}

// Takes in input of position in cloud
// Don't know where the numbers came from but apparently this function is used in a lot of demos
float noise(vec3 x) {
	vec3 p = floor(x);
	vec3 f = fract(x);
	f = f * f * (3. - 2. * f);

	// sampling 2D slice from 3D position. z coord lets us move through "time" in the noise?
	vec2 uv = (p.xy + vec2(37.0, 239.0) * p.z) + f.xy;
	vec2 tex = texture(noise_texture, (uv + 0.5) / 256.0, 0.0).yx;
	// Smooth noise mix from texture lookup and rescale it to [-1,1]

	return mix(tex.x, tex.y, f.z*.1) * 2.0 - 1.0;
}

mat2 rotate2D(float a) {
	float s = sin(a);
	float c = cos(a);
	return mat2(vec2(c, -s), vec2(s,c));
}

float nextStep(float t, float len, float smo) {
	float tt = mod(t+=smo,len);
	float stp = floor(t / len) - 1.0;
	return smoothstep(0.0, smo, tt) + stp;
}

//Fractal Brownian Motion
float fbm(vec3 p, float time) {
	// No idea abt these numbers
	// Getting new vector of position with also time?
	// Vector determines speed of inner cloud movement directions
	vec3 q = p + TIME*0.5 *vec3(1.0,-0.2,-1.0);

	float f = 0.0;
	float scale = 0.45;
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

	//vec3 p1 = p;
	//p1.xz *= rotate2D(-PI * 0.1);
	//p1.yz *= rotate2D(PI * 0.3);
//
	//float s1 = sdTorus(p1, vec2(1.3,0.9));
	//float s2 = sd_sphere(p, RADIUS);
	//float s3 = sdCapsule(p, vec3(-1.0, 2.0, 0.0), vec3(1.0, 2.0,0.0), 1.5);
//
	//float t = mod(nextStep(TIME, 3.0, 1.2), 4.0);
//
	//float dist = mix(s1,s2, clamp(t, 0.0, 1.0));
	//dist = mix(dist, s3, clamp(t-1.0,0.0,1.0));
	//dist = mix(dist, s1, clamp(t-3.0, 0.0, 1.0));

	////NO CHANGING SHAPES
	float dist = sdCapsule(p, vec3(-0.8, 1.0, 0.0), vec3(0.8, 1.0,0.0), 1.5);

	float f = fbm(p, time);
	return -dist + f; //adding a noise term to the inside of distance
}

// Raymarch function
vec4 raymarch(vec3 ro, vec3 rd, float time, float offset) {
	float depth = 0.0; //analogous to d0
	vec3 p = ro + rd * depth;
	depth += MARCH_SIZE * offset;
	vec3 sunDirection = normalize(light_pos);
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

bool insideBox(vec3 point) {
	// Check if the point's x-coordinate is within the box's x-range
    bool x_in_bounds = point.x >= boundsMin.x && point.x <= boundsMax.x;

    // Check if the point's y-coordinate is within the box's y-range
    bool y_in_bounds = point.y >= boundsMin.y && point.y <= boundsMax.y;

    // Check if the point's z-coordinate is within the box's z-range
    bool z_in_bounds = point.z >= boundsMin.z && point.z <= boundsMax.z;
	return x_in_bounds && y_in_bounds && z_in_bounds;
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

	//if (insideBox(ro)) {
		//rd = normalize(ro-vert);
	//}



	//Sun and sky?
	vec3 sunDirection = normalize(light_pos);
	float sun = clamp(dot(sunDirection, rd), 0.0, 1.0);

	//base sky color
	vec3 color = vec3(0.7,0.7,0.90);
	//Add gradient vertically
	color -= 0.8*vec3(0.90,0.75,0.90)*rd.y;
	// Add sun color to sky
	color += 0.5 * vec3(1.0,0.5,0.3) * pow(sun, 10.0);

	float blueNoise = texture(blue_noise, UV.xy / 1024.0).r;
  	float offset = fract(blueNoise + float(int(floor(TIME))%32) / sqrt(0.5));


    // Perform raymarch
    vec4 d = raymarch(ro, rd, TIME, offset);
    //vec3 p = ro + rd * d;
	color = color * (1.0 - d.a) + d.rgb;

    ALBEDO = color;
	ALPHA = d.a;
    //EMISSION = color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}