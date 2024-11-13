#include "contactShadows.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else 
	#define mainP main 
#endif

#ifdef PASS0
float4 mainP(in PFXVertToPix IN) : SV_Target0
{
    return tex2D(backBuffer, IN.uv0);
}
#endif

PFXVertToPix mainV(PFXVert IN)
{
    return processPostFxVert(IN);
}