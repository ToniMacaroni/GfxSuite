#ifndef SCATTER_SKY_H_HLSL
#define SCATTER_SKY_H_HLSL

#include "shaders/common/bng.hlsl"

uniform_samplerCUBE(nightSky, 0);

cbuffer perDraw
{
    uniform float4 colorize;

    uniform float4x4 modelView;
    uniform float4 misc;
    uniform float4 sphereRadii;
    uniform float4 scatteringCoeffs;
    uniform float3 camPos;
    uniform float3 lightDir;
    uniform float renderSun;
    uniform float4 invWaveLength;
    uniform float2 targetSize;

    uniform float4 nightColor;
    uniform float2 nightInterpAndExposure;
    uniform float useCubemap;
    uniform float3 sunDir;
    uniform float4 debugColor;
};

#endif //SCATTER_SKY_H_HLSL
