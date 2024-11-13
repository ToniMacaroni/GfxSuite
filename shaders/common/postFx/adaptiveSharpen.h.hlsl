#ifndef ADAPTIVESHARPEN_H_HLSL
#define ADAPTIVESHARPEN_H_HLSL

#include "shaders/common/bng.hlsl"
#include "shaders/common/lighting.h.hlsl"
#include "postFx.h.hlsl"

uniform_sampler2D(backBuffer, 0);
uniform_sampler2D(inTex, 1);

cbuffer perDraw
{
    uniform float2 oneOverTargetSize;

    uniform float curveHeight;
    uniform float useOpacityMask;

    PURE_POSTFX_UNIFORMS
    BNG_LIGHTING_UNIFORMS
};

#include "shaders/common/lighting.hlsl"
#include "postFx.hlsl"

#endif // ADAPTIVESHARPEN_H_HLSL
