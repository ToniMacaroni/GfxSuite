#include "contactShadows.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else 
	#define mainP main 
#endif

float sampleDepth(float2 uv)
{
    return decodeGBuffer(prepassDepthTex, prepass1Tex, uv, projParams).w * 1000;
}

float raycast(float2 uv, float3 wsEyeRay)
{
    //if (uv.y > 0.5) return 0.0;
    //return 1;
    // prepass x y z are normal, w is depth

    float origDepth = sampleDepth(uv);
    // return origDepth;
    float3 worldPos = eyePosWorld + wsEyeRay * origDepth;

    if (origDepth > 1.0) return 1.0;

    //const float4x4 objToCamera = worldToCamera;
    //const float4x4 objToScreen = mul(cameraToScreen, worldToCamera);

    // convert to clip space
    //float4 clip0 = mul(InWorldToScreenPos, float4(worldPos, 1));
    //if (clip0.x < 0.0) return 0;
    //return 1;
    // float4 cola = prePassBuffer1._texture.SampleLevel(prepassDepthTex._filter, uv, 0, 0);
    // return float4(1-tex2D(prepass1, uv).aaa, 1.0);
    // return float4(prepass.www, 1.0);

    //float sceneDepth = distance(eyePosWorld, worldPos);

    float3 _LightVector = float3(0, -0.005, 0);

    for (uint i = 0; i < 16; i++)
    {
        float2 uv2 = abs(uv + _LightVector.xy * (i + 2));
        float newDepth = sampleDepth(uv2);

        // View space position of the ray sample
        //float3 vp_ray = (wsEyeRay * sampleDepth(uv)) + _LightVector * (i + 2);

        // View space position of the depth sample
        // float3 vp_depth = InverseProjectUV(ProjectVP(vp_ray));
        // float3 vp_depth = eyePosWorld + wsEyeRay * prepass.w;
        //float2 uv_depth = mul(worldToScreenPos0, vp_ray);
        //float depth = sampleDepth(uv_depth);

        float diff = origDepth - newDepth;

        // Occlusion test
        if (diff > 0 && diff < (exitDepth * 0.001)) return 0;
    }

    return 1;
}

float4 mainP(PFXVertToPix IN) : SV_Target
{

    float3 sceneColor = tex2D(backBuffer, IN.uv0).rgb;
    //return float4(sceneColor, 1.0);

    // return float4(raycast(IN.uv0, IN.wsEyeRay), 0.0, 0.0, 1.0);
    return float4(sceneColor * max(0.2, raycast(IN.uv0, IN.wsEyeRay)), 1.0);
    // return float4(lerp(float3(0.0, 0.0, 1.0), sceneColor.rgb, max(raycast(IN.uv0, IN.wsEyeRay), 0.0)), 1.0);
}

PFXVertToPix mainV(PFXVert IN)
{
    return processPostFxVert(IN);
}