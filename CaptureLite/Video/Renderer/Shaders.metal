#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct VertexIn {
    float2 position;
    float2 texCoord;
};

vertex VertexOut vertex_main(uint vid [[vertex_id]],
                             constant VertexIn* vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(vertices[vid].position, 0.0, 1.0);
    out.texCoord = vertices[vid].texCoord;
    return out;
}

fragment float4 fragment_nv12(VertexOut in [[stage_in]],
                              texture2d<float> yTexture [[texture(0)]],
                              texture2d<float> cbcrTexture [[texture(1)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float y = yTexture.sample(s, in.texCoord).r;
    float2 cbcr = cbcrTexture.sample(s, in.texCoord).rg;
    float cb = cbcr.r - 0.5;
    float cr = cbcr.g - 0.5;
    float r = y + 1.402 * cr;
    float g = y - 0.344136 * cb - 0.714136 * cr;
    float b = y + 1.772 * cb;
    return float4(clamp(float3(r, g, b), 0.0, 1.0), 1.0);
}

fragment float4 fragment_bgra(VertexOut in [[stage_in]],
                              texture2d<float> texture [[texture(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    return texture.sample(s, in.texCoord);
}
