shader_type spatial;
render_mode unshaded, cull_front;

#define MAX_STEPS 40
#define MARCH_SIZE 0.16
#define RADIUS 1.5

const vec3 SUN_POSITION = vec3(2.0,3.0,0.0);

uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform sampler2D blue_noise : repeat_enable;
uniform vec3 light_pos = vec3(5.0,6.0,0.0);

//Screen texture contains current frame for post processing.
//Mipmap helps us get smooth transition between textures depending on dist from camera.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

//Accesses depth buffer
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;

uniform vec3 cloudContainerPos;
uniform vec3 cloudCountainerScale;

float remap_density(float d) {
    d = clamp(d, 0.0, 1.0);
    // Stronger contrast curve (gamma)
    d = pow(d, 1.5);        // change exponent for more contrast
    // Hard floor to produce thicker clumps
    d = smoothstep(0.25, 0.75, d);
    return d;
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

	return mix(tex.x, tex.y, f.z) * 2.0 - 1.0;
}

//Fractal Brownian Motion
float fbm(vec3 p, float time) {
	// No idea abt these numbers
	// Getting new vector of position with also time?
	// Vector determines speed of inner cloud movement directions
	vec3 q = p + TIME*0.2 *vec3(0.7,-0.2,-0.7);

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



// This is used to sample the density of the cloud, whether through SDF or other func
float scene(vec3 p, float time) {
	//float f = fbm(p, TIME);
    //return f;

	// Good for floor clouds, gets weird if box y pos is not close to 0m
	//float n = fbm(p * 0.5, time);
    //n = (n + 1.0) * 0.5; // normalize FBM from [-1,1] → [0,1]
    //float height = clamp(1.0 - abs(p.y) * 0.2, 0.0, 1.0);
    //float d = n * height;
	 //return remap_density(d) * 5. *n;
	vec3 local_p = (p - cloudContainerPos) / cloudCountainerScale;


	float n = fbm(local_p , TIME);

    float height = clamp(1.0 - abs(local_p.y) * 0.6, 0.0, 1.0);
    return n * height;


	 //adding a noise term to the inside of distance
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

			vec3 lin = vec3(0.60,0.60,0.75)*1.1 + 2.8*vec3(1.0,0.6,0.3)*diffuse;
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



float DepthViewSpace(vec2 uv, mat4 inv_proj_mat) {
	float depth = texture(DEPTH_TEXTURE, uv).r;
	return 1. / (depth * inv_proj_mat[2].w + inv_proj_mat[3].w);

}

vec2 rayBoxDst(vec3 boundsMin, vec3 boundsMax, vec3 ro, vec3 rd) {
	vec3 t0 = (boundsMin - ro) / rd;
	vec3 t1 = (boundsMax - ro) / rd;
	vec3 tmin = min(t0,t1);
	vec3 tmax = max(t0,t1);

	float dstA = max(max(tmin.x,tmin.y), tmin.z);
	float dstB = min(tmax.x, min(tmax.y, tmax.z));

	float dstToBox = max(0, dstA);
	float dstInsideBox = max(0, dstB - dstToBox);
	return vec2(dstToBox, dstInsideBox);
}

void vertex() {
	// Called for every vertex the material is visible on.
	// Set position in clip space, which is -1 to 1. This enables quad to "cover entire screen"
	POSITION = vec4(VERTEX.xy,1.,1.);
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec3 color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 offset = texture(SCREEN_TEXTURE, SCREEN_UV-0.002).rgb;

	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1., depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;

	float d = DepthViewSpace(SCREEN_UV, INV_PROJECTION_MATRIX);
	float border_r = DepthViewSpace(SCREEN_UV + vec2(0.002,0), INV_PROJECTION_MATRIX) - depth;
	vec3 boundsMin = cloudContainerPos - cloudCountainerScale / 2.;
	vec3 boundsMax = cloudContainerPos + cloudCountainerScale / 2.;

	// Ray origin (camera view-space)
	vec3 ro = vec3(0.0); // Camera is at origin in view space

	// Ray direction (view-space)

	vec3 rd = normalize(view.xyz);
    // 2. Convert ray direction to world space
    vec3 rd_world = (INV_VIEW_MATRIX * vec4(rd, 0.0)).xyz;

    // 3. Ray origin in world space
    vec3 ro_world = CAMERA_POSITION_WORLD;

	vec3 half = cloudCountainerScale * 0.5;
	// We cannot just convert the min and max bounds from world to view space once because it changes at different angles depending on the camera.
	// We have to look at all the corners.
	vec3 corners[8] = vec3[](
	    cloudContainerPos + vec3(-half.x, -half.y, -half.z),
	    cloudContainerPos + vec3( half.x, -half.y, -half.z),
	    cloudContainerPos + vec3(-half.x,  half.y, -half.z),
	    cloudContainerPos + vec3( half.x,  half.y, -half.z),
	    cloudContainerPos + vec3(-half.x, -half.y,  half.z),
	    cloudContainerPos + vec3( half.x, -half.y,  half.z),
	    cloudContainerPos + vec3(-half.x,  half.y,  half.z),
	    cloudContainerPos + vec3( half.x,  half.y,  half.z)
	);

	vec3 bmin_view = vec3(99999.0);
	vec3 bmax_view = vec3(-99999.0);

	for (int i = 0; i < 8; i++) {
	    vec3 p = ( vec4(corners[i], 1.0)).xyz;
	    bmin_view = min(bmin_view, p);
	    bmax_view = max(bmax_view, p);
	}

	// Intersect ray (ro, rd) with view-space AABB
	vec2 rayBoxInfo = rayBoxDst(bmin_view, bmax_view, ro_world, rd_world);

	//linearize depth buffer - formula just taken from online
	float zNear = 0.5;
	float zFar = 100.0;
	float z_n = 2.0 * depth - 1.0;
	float z_e = 2.0 * zNear * zFar / (zFar + zNear - z_n * (zFar - zNear));
	float linear_depth = z_e;

	bool rayHitBox = rayBoxInfo.y > 0. && rayBoxInfo.x < (linear_depth * length(view.xyz));
	if (!rayHitBox) {
		if (length(color - offset) > 0.4) {
		ALBEDO = vec3(0);
		} else {
		ALBEDO = color;
		}
	}
	else {
		vec3 sunDirection = normalize(light_pos);
		float sun = clamp(dot(sunDirection, rd), 0.0, 1.0);
		//base sky color
		vec3 color = vec3(0.7,0.7,0.90);
		//Add gradient vertically
		color -= 0.8*vec3(0.90,0.75,0.90)*rd_world.y;
		// Add sun color to sky
		color += 0.5 * vec3(1.0,0.5,0.3) * pow(sun, 10.0);
		float blueNoise = texture(blue_noise, SCREEN_UV.xy / 512.0).r;
  		float blue_offset = fract(blueNoise + float(int(floor(TIME))%32) / sqrt(0.5));

		// Perform raymarch
	    vec4 d = raymarch(ro_world, rd_world, TIME, blue_offset);
		color = color * (1.0 - d.a) + d.rgb;

	    ALBEDO = color;
		ALPHA = d.a;
	}
}

