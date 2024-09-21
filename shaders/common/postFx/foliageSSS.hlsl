#include "foliageSSS.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else 
	#define mainP main 
#endif

VertToPix2 mainV(PFXVert IN)
{
    VertToPix2 OUT;

    OUT.hpos = float4(IN.pos, 1);

    IN.uv = viewportCoordToRenderTarget(IN.uv, rtParams0);

    float2 processingSize = float2(0.001, 0.001);

    OUT.uv0 = IN.uv + ((BLUR_DIR * 3.5f) * processingSize);
    OUT.uv1 = IN.uv + ((BLUR_DIR * 2.5f) * processingSize);
    OUT.uv2 = IN.uv + ((BLUR_DIR * 1.5f) * processingSize);
    OUT.uv3 = IN.uv + ((BLUR_DIR * 0.5f) * processingSize);

    OUT.uv4 = IN.uv - ((BLUR_DIR * 3.5f) * processingSize);
    OUT.uv5 = IN.uv - ((BLUR_DIR * 2.5f) * processingSize);
    OUT.uv6 = IN.uv - ((BLUR_DIR * 1.5f) * processingSize);
    OUT.uv7 = IN.uv - ((BLUR_DIR * 0.5f) * processingSize);

    OUT.uv = IN.uv;

    return OUT;
}

float4 mainP(VertToPix2 IN) : SV_TARGET0
{
    float4 prepass1Sample = prepass1._texture.SampleLevel(prepassDepthTex._filter, IN.uv, 0, 0);

    if (prepass1Sample.a != 0.2)
    {
        return tex2D(backBuffer, IN.uv);
    }

    float4 kernel = float4(0.175, 0.275, 0.375, 0.475) * 0.5 / 1.3;

    float4 OUT = 0;
    OUT += tex2D(backBuffer, IN.uv0) * kernel.x;
    OUT += tex2D(backBuffer, IN.uv1) * kernel.y;
    OUT += tex2D(backBuffer, IN.uv2) * kernel.z;
    OUT += tex2D(backBuffer, IN.uv3) * kernel.w;

    OUT += tex2D(backBuffer, IN.uv4) * kernel.x;
    OUT += tex2D(backBuffer, IN.uv5) * kernel.y;
    OUT += tex2D(backBuffer, IN.uv6) * kernel.z;
    OUT += tex2D(backBuffer, IN.uv7) * kernel.w;

    return OUT;
}