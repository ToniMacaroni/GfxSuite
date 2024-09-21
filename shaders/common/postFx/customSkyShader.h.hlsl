#ifndef CUSTOMSKY_H_HLSL
#define CUSTOMSKY_H_HLSL

#define BNG_USE_SCENE_CBUFFER
#define BNG_SHADERGEN
#define MFT_MATERIAL_LAYER_COUNT 1
#include "shaders/common/bng.hlsl"
#include "shaders/common/material/shadergen/shadergen.h.hlsl"
#include "shaders/common/brdf/brdf_spec.h.hlsl"

uniform_samplerCUBE(skyTex, 0);

struct VertData
{
    float3 pos : POSITION;
    // float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

struct vertexVS {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 wsPos : TEXCOORD1;
    // float3 normal : NORMAL;
};

// struct svInstanceData {
//     uint svInstanceID : SV_InstanceID;
// #if BNG_HLSL_MODEL >= 6
//     [[vk::builtin("BaseInstance")]] uint svInstanceBaseID : A;
// #endif
// };

#endif // CUSTOMSKY_H_HLSL
