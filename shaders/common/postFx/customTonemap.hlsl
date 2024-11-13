#include "customTonemap.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else 
	#define mainP main 
#endif

#define luminosityFactor float3(0.2126, 0.7152, 0.0722)

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

// =================== NEW TONEMAPPING ===================

// Mean error^2: 3.6705141e-06
float3 agxDefaultContrastApprox(float3 x) {
    float3 x2 = x * x;
    float3 x4 = x2 * x2;

    return +15.5 * x4 * x2
                - 40.14 * x4 * x
                + 31.96 * x4
                - 6.868 * x2 * x
                + 0.4298 * x2
                + 0.1191 * x
                - 0.00232;
}

float3 agx(float3 val) {

    float3x3 agx_mat = float3x3(
        0.842479062253094, 0.0423282422610123, 0.0423756549057051,
        0.0784335999999992, 0.878468636469772, 0.0784336,
        0.0792237451477643, 0.0791661274605434, 0.879142973793104);

    float min_ev = -12.47393f;
    float max_ev = 4.026069f;

    // Input transform
    val = mul(agx_mat, val);

    // Log2 space encoding
    val = clamp(log2(val), min_ev, max_ev);
    val = (val - min_ev) / (max_ev - min_ev);

    // Apply sigmoid function approximation
    val = agxDefaultContrastApprox(val);

    return val;
}

float3 agxEotf(float3 val) {
    float3x3 agx_mat_inv = float3x3(
        1.19687900512017, -0.0528968517574562, -0.0529716355144438,
        -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
        -0.0990297440797205, -0.0989611768448433, 1.15107367264116);

    // Undo input transform
    return mul(agx_mat_inv, val);
}

float3 agxLook(float3 val, float luma) {

    // Default
    float3 offset = float3(0.0, 0.0, 0.0);
    float3 slope = float3(agx_slope, agx_slope, agx_slope);
    float3 power = float3(agx_power, agx_power, agx_power);
    float sat = agx_sat;

    // ASC CDL
    val = pow(max(0, val * slope + offset), power);
    return luma + sat * (val - luma);
}

float3 RGB_Uchimura_AgX(float3 x) {

    x = pow(max(0, x * 1.075), 1.025);

    float3 hsv = rgb2hsv(x);

    float luma = saturate(dot(x, luminosityFactor));

    float3 col = agx(x);
    col = agxLook(col, luma);
    col = agxEotf(col);

    x = lerp(x, col, agx_mix * pow(luma, agx_mix_exp) * sqrt(1 - agx_sat_dependency * saturate(hsv.y)));

    x *= gain;
    x = uchimura(x);

    return x;
}

// =================== NEW TONEMAPPING ===================

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
    sceneColor = RGB_Uchimura_AgX(sceneColor);
    sceneColor = linearToGammaColor(sceneColor);
    sceneColor = lerp(sceneColor, applyLut(sceneColor), lutStrength);

    sceneColor = rgb2hsv(sceneColor) * float3(hue, saturation, 1.0);
    sceneColor = hsv2rgb(sceneColor);
    sceneColor = adjustExposure(sceneColor, exposure);
    sceneColor = sceneColor * tint;

    return float4(sceneColor, 1.0);
}

PFXVertToPix mainV(PFXVert IN)
{
   return processPostFxVert(IN);
}