#ifndef CA_H_HLSL
#define CA_H_HLSL

#include "shaders/common/bng.hlsl"
#include "shaders/common/lighting.h.hlsl"
#include "postFx.h.hlsl"

uniform_sampler2D(backBuffer, 0);
uniform_sampler2D(prepassDepthTex, 1);
uniform_sampler2D(prepass1Tex, 2);

cbuffer perDraw
{
    float4x4 worldToCamera;
    float4x4 worldToScreenPos0;
    uniform float3 eyePosWorld;
    uniform float exitDepth;
    
    PURE_POSTFX_UNIFORMS
    BNG_LIGHTING_UNIFORMS
};

#include "shaders/common/lighting.hlsl"
#include "postFx.hlsl"

#endif // CA_H_HLSL
