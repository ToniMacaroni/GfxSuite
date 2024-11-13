#ifndef CustomTonemap_H_HLSL
#define CustomTonemap_H_HLSL

#include "shaders/common/bng.hlsl"
#include "shaders/common/lighting.h.hlsl"
#include "postFx.h.hlsl"

uniform_sampler2D(backBuffer, 0);
uniform_sampler2D(lutTex, 1);

cbuffer perDraw
{
    uniform float contrast;
    uniform float maxDisplayBrightness;
    uniform float linearSectionStart;
    uniform float linearSectionLength;
    uniform float black;
    uniform float pedestal;
    uniform float lutStrength;

    // --
    uniform float gain;
    uniform float agx_mix;
    uniform float agx_mix_exp;
    uniform float agx_slope;
    uniform float agx_power;
    uniform float agx_sat;
    uniform float agx_sat_dependency;
    // --

    uniform float hue;
    uniform float saturation;
    uniform float exposure;

    uniform float3 tint;
    
    PURE_POSTFX_UNIFORMS
    BNG_LIGHTING_UNIFORMS
};

#include "shaders/common/lighting.hlsl"
#include "postFx.hlsl"

#endif // CA_H_HLSL
