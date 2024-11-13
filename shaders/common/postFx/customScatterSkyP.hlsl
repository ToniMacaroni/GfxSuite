#include "customScatterSky.h.hlsl"

struct Conn
{
    float4 position : SV_Position;
    float4 rayleighColor : TEXCOORD0;
    float4 mieColor : TEXCOORD1;
    float3 v3Direction : TEXCOORD2;
    float3 pos : TEXCOORD3;
};

float4 main(Conn In) : SV_Target
{
#ifdef BNG_RENDER_ANNOTATION_BUILD
   if (debugColor.a > 0.1f) {
       return float4(debugColor.rgb, 1);
   }
#endif

   float fCos = dot(lightDir, In.v3Direction) / length(In.v3Direction);
   float fCos2 = fCos * fCos;

   float g = -0.991;
   float g2 = -0.991 * -0.991;

   float fMiePhase = renderSun * 1.5 * ((1.0 - g2) / (2.0 + g2)) * (1.0 + fCos2) / pow(abs(1.0 + g2 - 2.0 * g * fCos), 1.5);

   float4 color = In.rayleighColor + fMiePhase * In.mieColor;
   color.a = color.b;

   float4 Out;

   float4 nightSkyColor = texCUBE(nightSky, -In.v3Direction);
   float3 skyboxTexColor = nightSkyColor.rgb;
   nightSkyColor = lerp(nightColor, nightSkyColor, useCubemap);

   float fac = dot(normalize(In.pos), sunDir);
   fac = max(nightInterpAndExposure.y, pow(saturate(fac), 2));
   Out = lerp(color, nightSkyColor, nightInterpAndExposure.y);

   Out.a = 1;
   Out.rgb = lerp(skyboxTexColor * colorize.rgb * 2.0, Out.rgb, saturate(colorize.a));

   return hdrEncode(Out);
}