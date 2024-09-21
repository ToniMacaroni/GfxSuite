#include "miscEffects.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else 
	#define mainP main 
#endif

float3 sharpBlur(float2 texcoord)
{
    float HighPassDarkIntensity = 1.0;
    float HighPassLightIntensity = 1.0;

    float highPassSharpOffset = 2.0;

    float2 pixelSize = 1.0 / screenResolution;

    float3 color = tex2D(backBuffer, texcoord).rgb;
    float3 orig = color;
    float luma = dot(color.rgb, float3(0.32786885, 0.655737705, 0.0163934436));
    float3 chroma = orig.rgb / luma;

    int sampleOffsetsX[25] = { 0.0, 1, 0, 1, 1, 2, 0, 2, 2, 1, 1, 2, 2, 3, 0, 3, 3, 1, -1, 3, 3, 2, 2, 3, 3 };
    int sampleOffsetsY[25] = { 0.0, 0, 1, 1, -1, 0, 2, 1, -1, 2, -2, 2, -2, 0, 3, 1, -1, 3, 3, 2, -2, 3, -3, 3, -3 };
    float sampleWeights[5] = { 0.225806, 0.150538, 0.150538, 0.0430108, 0.0430108 };

    color *= sampleWeights[0];

    [loop]
    for (int i = 1; i < 5; ++i) {
        color += tex2D(backBuffer, texcoord + float2(sampleOffsetsX[i] * pixelSize.x, sampleOffsetsY[i] * pixelSize.y) * highPassSharpOffset).rgb * sampleWeights[i];
        color += tex2D(backBuffer, texcoord - float2(sampleOffsetsX[i] * pixelSize.x, sampleOffsetsY[i] * pixelSize.y) * highPassSharpOffset).rgb * sampleWeights[i];
    }

    float sharp = dot(color.rgb, float3(0.32786885, 0.655737705, 0.0163934436));
    sharp = 1.0 - sharp;
    sharp = (luma + sharp) * 0.5;

    float sharpMin = lerp(0, 1, smoothstep(0, 1, sharp));
    float sharpMax = sharpMin;
    sharpMin = lerp(sharp, sharpMin, HighPassDarkIntensity);
    sharpMax = lerp(sharp, sharpMax, HighPassLightIntensity);
    sharp = lerp(sharpMin, sharpMax, step(0.5, sharp));

    sharp = lerp(2 * luma * sharp, 1.0 - 2 * (1.0 - luma) * (1.0 - sharp), step(0.50, luma));

    luma = lerp(luma, sharp, highPassSharpStrength);
    orig.rgb = luma * chroma;

    return saturate(orig);
}

float3 caPass(float2 uv, float2 shift, float strength) : SV_Target
{
    float2 pixelSize = 1.0 / screenResolution;

    float3 color, ogColor = tex2D(backBuffer, uv).rgb;
    color.r = tex2D(backBuffer, uv + (pixelSize * shift)).r;
    color.g = ogColor.g;
    color.b = tex2D(backBuffer, uv - (pixelSize * shift)).b;

    return lerp(ogColor, color, strength);
}

float4 mainP(PFXVertToPix IN) : SV_Target
{
    float2 uv = IN.uv0;

#if defined( HIGHPASS_PASS )
    return float4(sharpBlur(uv), 1.0);
#elif defined( CA_PASS )
    return float4(caPass(uv, float2(2, -0.3), caAmount), 1.0);
#else
    return float4(tex2D(backBuffer, uv).rgb, 1);
#endif
}

PFXVertToPix mainV(PFXVert IN)
{
   return processPostFxVert(IN);
}