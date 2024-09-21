#include "customSkyShader.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else 
	#define mainP main 
#endif

float4 mainP(vertexVS IN) : SV_Target0
{
    float3 eyeToVert = normalize(IN.wsPos - eyePosWorld);
    float3 col = texCUBE(skyTex, eyeToVert).rgb;
    return float4(IN.wsPos, 1.0);
}

vertexVS mainV(VertData inVtx, svInstanceData instanceData) {
    vertexVS outVtx;
    uint instanceId = getInstanceId(instanceData);
    const float4x4 instanceTransform = getInstanceTransform(instanceId);
    // const float4x4 localToScreenM = mul(worldToScreenPos0, subMatrixPosition(instanceTransform, eyePosWorld));
    //  const float4x4 objectTrans = getInstanceData(svInstanceID + instanceBase).uObjectTrans;
    //  const float4x4 vtxToCameraPos0 = calculateVtxToCameraPos0(worldToCameraPos0, eyePosWorld, cameraRemainder, objectTrans, localTrans);
    //   const float4x4 localToScreenM = mul(worldToScreenPos0, subMatrixPosition(uObjectTrans, eyePosWorld));
    //   float4 outPos = mul(localToScreenM, mul(localTrans, float4(inVtx.pos, 1)));
    outVtx.pos = float4(inVtx.pos, 1);
    outVtx.uv = inVtx.uv;
    // outVtx.wsPos = mul(instanceTransform, mul(localTrans, float4(inVtx.pos, 1))).xyz;
    outVtx.wsPos = outVtx.pos.xyz;
    return outVtx;
}