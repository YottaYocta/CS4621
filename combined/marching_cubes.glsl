#[compute]
#version 450

// Workgroup size - process cubes in parallel
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

// Input voxel data
layout(set = 0, binding = 0, std430) restrict readonly buffer VoxelData {
    int voxels[];
} voxel_data;

// Output vertex positions
layout(set = 0, binding = 1, std430) restrict buffer VertexData {
    vec4 vertices[];  // vec4 for alignment, w component unused
} vertex_data;

// Output normals
layout(set = 0, binding = 2, std430) restrict buffer NormalData {
    vec4 normals[];
} normal_data;

// Atomic counter for vertex output
layout(set = 0, binding = 3, std430) restrict buffer Counter {
    uint vertex_count;
} counter;

// Uniforms
layout(set = 0, binding = 4, std140) uniform Params {
    ivec3 chunk_size;     // Size of the chunk
    float voxel_size;     // Size of each voxel
    ivec3 chunk_offset;   // World offset for this chunk
    int padding;
} params;

// Edge table - which edges are intersected for each cube configuration
const int EDGE_TABLE[256] = int[256](
    0x0, 0x109, 0x203, 0x30a, 0x406, 0x50f, 0x605, 0x70c,
    0x80c, 0x905, 0xa0f, 0xb06, 0xc0a, 0xd03, 0xe09, 0xf00,
    0x190, 0x99, 0x393, 0x29a, 0x596, 0x49f, 0x795, 0x69c,
    0x99c, 0x895, 0xb9f, 0xa96, 0xd9a, 0xc93, 0xf99, 0xe90,
    0x230, 0x339, 0x33, 0x13a, 0x636, 0x73f, 0x435, 0x53c,
    0xa3c, 0xb35, 0x83f, 0x936, 0xe3a, 0xf33, 0xc39, 0xd30,
    0x3a0, 0x2a9, 0x1a3, 0xaa, 0x7a6, 0x6af, 0x5a5, 0x4ac,
    0xbac, 0xaa5, 0x9af, 0x8a6, 0xfaa, 0xea3, 0xda9, 0xca0,
    0x460, 0x569, 0x663, 0x76a, 0x66, 0x16f, 0x265, 0x36c,
    0xc6c, 0xd65, 0xe6f, 0xf66, 0x86a, 0x963, 0xa69, 0xb60,
    0x5f0, 0x4f9, 0x7f3, 0x6fa, 0x1f6, 0xff, 0x3f5, 0x2fc,
    0xdfc, 0xcf5, 0xfff, 0xef6, 0x9fa, 0x8f3, 0xbf9, 0xaf0,
    0x650, 0x759, 0x453, 0x55a, 0x256, 0x35f, 0x55, 0x15c,
    0xe5c, 0xf55, 0xc5f, 0xd56, 0xa5a, 0xb53, 0x859, 0x950,
    0x7c0, 0x6c9, 0x5c3, 0x4ca, 0x3c6, 0x2cf, 0x1c5, 0xcc,
    0xfcc, 0xec5, 0xdcf, 0xcc6, 0xbca, 0xac3, 0x9c9, 0x8c0,
    0x8c0, 0x9c9, 0xac3, 0xbca, 0xcc6, 0xdcf, 0xec5, 0xfcc,
    0xcc, 0x1c5, 0x2cf, 0x3c6, 0x4ca, 0x5c3, 0x6c9, 0x7c0,
    0x950, 0x859, 0xb53, 0xa5a, 0xd56, 0xc5f, 0xf55, 0xe5c,
    0x15c, 0x55, 0x35f, 0x256, 0x55a, 0x453, 0x759, 0x650,
    0xaf0, 0xbf9, 0x8f3, 0x9fa, 0xef6, 0xfff, 0xcf5, 0xdfc,
    0x2fc, 0x3f5, 0xff, 0x1f6, 0x6fa, 0x7f3, 0x4f9, 0x5f0,
    0xb60, 0xa69, 0x963, 0x86a, 0xf66, 0xe6f, 0xd65, 0xc6c,
    0x36c, 0x265, 0x16f, 0x66, 0x76a, 0x663, 0x569, 0x460,
    0xca0, 0xda9, 0xea3, 0xfaa, 0x8a6, 0x9af, 0xaa5, 0xbac,
    0x4ac, 0x5a5, 0x6af, 0x7a6, 0xaa, 0x1a3, 0x2a9, 0x3a0,
    0xd30, 0xc39, 0xf33, 0xe3a, 0x936, 0x83f, 0xb35, 0xa3c,
    0x53c, 0x435, 0x73f, 0x636, 0x13a, 0x33, 0x339, 0x230,
    0xe90, 0xf99, 0xc93, 0xd9a, 0xa96, 0xb9f, 0x895, 0x99c,
    0x69c, 0x795, 0x49f, 0x596, 0x29a, 0x393, 0x99, 0x190,
    0xf00, 0xe09, 0xd03, 0xc0a, 0xb06, 0xa0f, 0x905, 0x80c,
    0x70c, 0x605, 0x50f, 0x406, 0x30a, 0x203, 0x109, 0x0
);

// Triangle table - simplified version that stores triangle count per config
const int TRI_COUNT[256] = int[256](
    0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 2,
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 3,
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 3,
    2, 3, 3, 2, 3, 4, 4, 3, 3, 4, 4, 3, 4, 5, 5, 2,
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 3,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 4,
    2, 3, 3, 4, 3, 4, 2, 3, 3, 4, 4, 5, 4, 5, 3, 2,
    3, 4, 4, 3, 4, 5, 3, 2, 4, 5, 5, 4, 5, 2, 4, 1,
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 3,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 2, 4, 3, 4, 3, 5, 2,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 4,
    3, 4, 4, 3, 4, 5, 5, 4, 4, 3, 5, 2, 5, 4, 2, 1,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 2, 3, 3, 2,
    3, 4, 4, 5, 4, 5, 5, 2, 4, 3, 5, 4, 3, 2, 4, 1,
    3, 4, 4, 5, 4, 5, 3, 4, 4, 5, 5, 2, 3, 4, 2, 1,
    2, 3, 3, 2, 3, 4, 2, 1, 3, 2, 4, 1, 2, 1, 1, 0
);

int get_voxel(ivec3 pos) {
    ivec3 size = params.chunk_size + ivec3(1);  // +1 for boundary voxels
    if (pos.x < 0 || pos.y < 0 || pos.z < 0 ||
        pos.x >= size.x || pos.y >= size.y || pos.z >= size.z) {
        return -1;
    }
    int index = pos.x + size.x * pos.y + size.x * size.y * pos.z;
    return voxel_data.voxels[index];
}

vec3 interpolate_vertex(ivec3 p1, ivec3 p2, int val1, int val2) {
    vec3 v1 = vec3(p1) * params.voxel_size;
    vec3 v2 = vec3(p2) * params.voxel_size;

    if (abs(val1 - val2) < 0.00001) {
        return (v1 + v2) * 0.5;
    }

    float threshold = 0.5;
    float t = (threshold - float(val1)) / float(val2 - val1);
    t = clamp(t, 0.0, 1.0);

    return mix(v1, v2, t);
}

vec3 calculate_normal(vec3 pos) {
    // Calculate gradient using central differences
    float delta = 0.1;
    ivec3 ipos = ivec3(round(pos / params.voxel_size));

    float dx = float(get_voxel(ipos + ivec3(1,0,0)) - get_voxel(ipos - ivec3(1,0,0)));
    float dy = float(get_voxel(ipos + ivec3(0,1,0)) - get_voxel(ipos - ivec3(0,1,0)));
    float dz = float(get_voxel(ipos + ivec3(0,0,1)) - get_voxel(ipos - ivec3(0,0,1)));

    vec3 gradient = vec3(dx, dy, dz);
    if (length(gradient) > 0.0001) {
        return -normalize(gradient);
    }
    return vec3(0, 1, 0);
}

void main() {
    ivec3 cube_pos = ivec3(gl_GlobalInvocationID.xyz);

    // Check if within bounds
    if (cube_pos.x >= params.chunk_size.x ||
        cube_pos.y >= params.chunk_size.y ||
        cube_pos.z >= params.chunk_size.z) {
        return;
    }

    // Get 8 corner values
    int corners[8];
    corners[0] = get_voxel(cube_pos + ivec3(0,0,0));
    corners[1] = get_voxel(cube_pos + ivec3(1,0,0));
    corners[2] = get_voxel(cube_pos + ivec3(1,0,1));
    corners[3] = get_voxel(cube_pos + ivec3(0,0,1));
    corners[4] = get_voxel(cube_pos + ivec3(0,1,0));
    corners[5] = get_voxel(cube_pos + ivec3(1,1,0));
    corners[6] = get_voxel(cube_pos + ivec3(1,1,1));
    corners[7] = get_voxel(cube_pos + ivec3(0,1,1));

    // Calculate cube index
    int cube_index = 0;
    for (int i = 0; i < 8; i++) {
        if (corners[i] > 0) {
            cube_index |= (1 << i);
        }
    }

    // Skip empty/full cubes
    if (cube_index == 0 || cube_index == 255) {
        return;
    }

    // Get edge configuration
    int edge_flags = EDGE_TABLE[cube_index];

    // Calculate edge vertices
    vec3 edge_verts[12];

    if ((edge_flags & 1) != 0)
        edge_verts[0] = interpolate_vertex(cube_pos + ivec3(0,0,0), cube_pos + ivec3(1,0,0), corners[0], corners[1]);
    if ((edge_flags & 2) != 0)
        edge_verts[1] = interpolate_vertex(cube_pos + ivec3(1,0,0), cube_pos + ivec3(1,0,1), corners[1], corners[2]);
    if ((edge_flags & 4) != 0)
        edge_verts[2] = interpolate_vertex(cube_pos + ivec3(1,0,1), cube_pos + ivec3(0,0,1), corners[2], corners[3]);
    if ((edge_flags & 8) != 0)
        edge_verts[3] = interpolate_vertex(cube_pos + ivec3(0,0,0), cube_pos + ivec3(0,0,1), corners[0], corners[3]);
    if ((edge_flags & 16) != 0)
        edge_verts[4] = interpolate_vertex(cube_pos + ivec3(0,1,0), cube_pos + ivec3(1,1,0), corners[4], corners[5]);
    if ((edge_flags & 32) != 0)
        edge_verts[5] = interpolate_vertex(cube_pos + ivec3(1,1,0), cube_pos + ivec3(1,1,1), corners[5], corners[6]);
    if ((edge_flags & 64) != 0)
        edge_verts[6] = interpolate_vertex(cube_pos + ivec3(1,1,1), cube_pos + ivec3(0,1,1), corners[6], corners[7]);
    if ((edge_flags & 128) != 0)
        edge_verts[7] = interpolate_vertex(cube_pos + ivec3(0,1,0), cube_pos + ivec3(0,1,1), corners[4], corners[7]);
    if ((edge_flags & 256) != 0)
        edge_verts[8] = interpolate_vertex(cube_pos + ivec3(0,0,0), cube_pos + ivec3(0,1,0), corners[0], corners[4]);
    if ((edge_flags & 512) != 0)
        edge_verts[9] = interpolate_vertex(cube_pos + ivec3(1,0,0), cube_pos + ivec3(1,1,0), corners[1], corners[5]);
    if ((edge_flags & 1024) != 0)
        edge_verts[10] = interpolate_vertex(cube_pos + ivec3(1,0,1), cube_pos + ivec3(1,1,1), corners[2], corners[6]);
    if ((edge_flags & 2048) != 0)
        edge_verts[11] = interpolate_vertex(cube_pos + ivec3(0,0,1), cube_pos + ivec3(0,1,1), corners[3], corners[7]);

    // Generate triangles
    int tri_count = TRI_COUNT[cube_index];
    if (tri_count > 0) {
        // Reserve space for vertices
        uint base_idx = atomicAdd(counter.vertex_count, uint(tri_count * 3));

        // For simplicity, we'll generate approximate triangles based on edge_flags
        // A full implementation would need the complete tri_table
        // This generates triangles from active edges (simplified)
        uint vert_idx = base_idx;
        for (int i = 0; i < 12 && vert_idx < base_idx + uint(tri_count * 3); i += 3) {
            if ((edge_flags & (1 << i)) != 0 &&
                (edge_flags & (1 << (i+1))) != 0 &&
                (edge_flags & (1 << (i+2))) != 0) {

                vertex_data.vertices[vert_idx] = vec4(edge_verts[i], 1.0);
                normal_data.normals[vert_idx] = vec4(calculate_normal(edge_verts[i]), 0.0);
                vert_idx++;

                if ((i + 1) < 12) {
                    vertex_data.vertices[vert_idx] = vec4(edge_verts[i+1], 1.0);
                    normal_data.normals[vert_idx] = vec4(calculate_normal(edge_verts[i+1]), 0.0);
                    vert_idx++;
                }

                if ((i + 2) < 12) {
                    vertex_data.vertices[vert_idx] = vec4(edge_verts[i+2], 1.0);
                    normal_data.normals[vert_idx] = vec4(calculate_normal(edge_verts[i+2]), 0.0);
                    vert_idx++;
                }
            }
        }
    }
}
