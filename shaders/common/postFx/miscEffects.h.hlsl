#ifndef MISCEFFECTS_H_HLSL
#define MISCEFFECTS_H_HLSL

#include "shaders/common/bng.hlsl"
#include "shaders/common/lighting.h.hlsl"
#include "postFx.h.hlsl"

uniform_sampler2D(backBuffer, 0);

cbuffer perDraw
{
    uniform float highPassSharpStrength;
    uniform float caAmount;

    uniform float2 oneOverTargetSize;

    PURE_POSTFX_UNIFORMS
    BNG_LIGHTING_UNIFORMS
};

#include "shaders/common/lighting.hlsl"
#include "postFx.hlsl"

#endif // MISCEFFECTS_H_HLSL
