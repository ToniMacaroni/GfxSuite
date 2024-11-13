#ifndef CA_H_HLSL
#define CA_H_HLSL

#include "shaders/common/bng.hlsl"
#include "shaders/common/lighting.h.hlsl"
#include "postFx.h.hlsl"

uniform_sampler2D(backBuffer, 0);
uniform_sampler2D(prepassDepthTex, 1);
uniform_sampler2D(prepassTex, 2);

cbuffer perDraw  : register(b0)
{
    uniform float3 eyePosWorld;
    uniform float exitDepth;
    uniform float4x4 matWorldToScreen;
    uniform float4x4 matScreenToWorld;
    uniform float2 oneOverTargetSize;
    uniform float2 targetSize;
    uniform float radius;
    uniform float power;
    uniform float3 lightDirection;
    uniform float targetRatio;
    
    PURE_POSTFX_UNIFORMS
    BNG_LIGHTING_UNIFORMS
};

struct Ray
{
    float3 origin;
    float3 dir;
    float step;
    float3 pos;
};

struct SceneData
{
    float3 eyedir;
    float3 normal;
    float3 position;
    float depth;
};

struct TraceData
{
    int num_steps;
    int num_refines;
    float2 uv;
    float3 error;
    bool hit;
};

#include "shaders/common/lighting.hlsl"
#include "postFx.hlsl"

#endif // CA_H_HLSL
