#include "customTonemap.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else 
	#define mainP main 
#endif

// Uchimura 2017, "HDR theory and practice"
// Math: https://www.desmos.com/calculator/gslcdxvipg
// Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
float3 uchimura(float3 x, float P, float a, float m, float l, float c, float b) {
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;

    float3 w0 = float3(1.0 - smoothstep(0.0, m, x));
    float3 w2 = float3(step(m + l0, x));
    float3 w1 = float3(1.0 - w0 - w2);

    float3 T = float3(m * pow(x / m, (c)) + b);
    float3 S = float3(P - (P - S1) * exp(CP * (x - S0)));
    float3 L = float3(m + a * (x - m));

    return T * w0 + L * w1 + S * w2;
}

float3 uchimura(float3 x) {
    const float P = maxDisplayBrightness;
    const float a = contrast;
    const float m = linearSectionStart;
    const float l = linearSectionLength;
    const float c = black;
    const float b = pedestal;

    return uchimura(x, P, a, m, l, c, b);
}

float3 applyLut(float3 color)
{
    float amountChroma = 1.0;
    float amountLuma = 1.0;

    float3 colorOrig = color;

    float tileSize = 32.0;
    float2 texelsize = 1.0 / tileSize;
    texelsize.x /= tileSize;

    float3 lutcoord = float3((color.xy * tileSize - color.xy + 0.5) * texelsize.xy, color.z * tileSize - color.z);
    float lerpfact = frac(lutcoord.z);
    lutcoord.x += (lutcoord.z - lerpfact) * texelsize.y;

    float3 lutcolor = lerp(tex2D(lutTex, lutcoord.xy).xyz, tex2D(lutTex, float2(lutcoord.x + texelsize.y, lutcoord.y)).xyz, lerpfact);

    color = lerp(normalize(color.xyz), normalize(lutcolor.xyz), amountChroma) *
                lerp(length(color.xyz), length(lutcolor.xyz), amountLuma);

    // return pow(abs(color.rgb), 1.0 / 2.2);
    return color;
}

float3 adjustExposure(float3 col, float exposure) {
    float3 b = exposure * col;
    return b / (b - col + 1.);
}

float4 mainP(PFXVertToPix IN) : SV_Target
{
    float2 uv = IN.uv0;

    float3 sceneColor = tex2D(backBuffer, uv).rgb;
    sceneColor = uchimura(sceneColor);
    sceneColor = linearToGammaColor(sceneColor);
    sceneColor = lerp(sceneColor, applyLut(sceneColor), lutStrength);

    sceneColor = rgb2hsv(sceneColor) * float3(hue, saturation, 1.0);
    sceneColor = hsv2rgb(sceneColor);
    sceneColor = adjustExposure(sceneColor, exposure);

    return float4(sceneColor, 1.0);
}

PFXVertToPix mainV(PFXVert IN)
{
   return processPostFxVert(IN);
}