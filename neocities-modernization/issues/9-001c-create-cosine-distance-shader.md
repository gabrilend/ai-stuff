# Issue 9-001c: Create Cosine Distance Compute Shader

## Parent Issue
9-001: Implement Vulkan Compute Infrastructure

## Current Behavior
Cosine distance calculated in Lua:
```lua
local function cosine_distance(emb1, emb2)
    local dot_product, norm1, norm2 = 0, 0, 0
    for i = 1, #emb1 do
        dot_product = dot_product + (emb1[i] * emb2[i])
        norm1 = norm1 + (emb1[i] * emb1[i])
        norm2 = norm2 + (emb2[i] * emb2[i])
    end
    return 1.0 - (dot_product / (sqrt(norm1) * sqrt(norm2)))
end
```

## Intended Behavior
GPU compute shader calculates cosine distance for thousands of embeddings in parallel.

## Implementation Steps

### Step 1: Basic Cosine Distance Shader
```glsl
#version 450

layout(local_size_x = 256) in;

layout(set = 0, binding = 0) readonly buffer Embeddings {
    float embeddings[];  // 6641 * 768 floats
};

layout(set = 0, binding = 1) readonly buffer Centroid {
    float centroid[768];
};

layout(set = 0, binding = 2) writeonly buffer Distances {
    float distances[];  // 6641 floats
};

layout(push_constant) uniform Constants {
    uint num_embeddings;
    uint embedding_dim;
};

void main() {
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= num_embeddings) return;

    uint base = idx * embedding_dim;
    float dot_product = 0.0;
    float norm1 = 0.0;
    float norm2 = 0.0;

    for (uint i = 0; i < embedding_dim; i++) {
        float a = embeddings[base + i];
        float b = centroid[i];
        dot_product += a * b;
        norm1 += a * a;
        norm2 += b * b;
    }

    float similarity = dot_product / (sqrt(norm1) * sqrt(norm2));
    distances[idx] = 1.0 - similarity;
}
```

### Step 2: Optimize for GTX 1080 Ti
- [ ] Tune workgroup size (try 64, 128, 256, 512)
- [ ] Consider shared memory for centroid
- [ ] Profile with different dispatch sizes

### Step 3: Validate Results
- [ ] Compare GPU output to CPU reference implementation
- [ ] Test edge cases (zero vectors, identical vectors)
- [ ] Verify numerical precision is acceptable

## Quality Assurance Criteria

- [ ] Shader compiles to valid SPIR-V
- [ ] Results match CPU implementation within floating-point tolerance
- [ ] No validation layer errors
- [ ] Performance improvement over CPU baseline

## Dependencies

- 9-001b (Vulkan wrapper)

---

**ISSUE STATUS: OPEN**

**Created**: 2025-12-14

**Phase**: 9 (GPU Acceleration)

**Priority**: High (blocking 9-001d)
