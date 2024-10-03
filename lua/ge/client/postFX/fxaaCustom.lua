-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

 -- An implementation of "NVIDIA FXAA 3.11" by TIMOTHY LOTTES
 --
 -- http://timothylottes.blogspot.com/
 --
 -- The shader is tuned for the defaul quality and good performance.
 -- See shaders\common\postFx\fxaa\fxaaP.hlsl to tweak the internal
 -- quality and performance settings.

local customFxaaPostEffect = scenetree.findObject("Custom_FXAA_PostEffect")
if not customFxaaPostEffect then
  local customFxaaPostEffect = createObject("PostEffect")
  customFxaaPostEffect.isEnabled = false
  customFxaaPostEffect.allowReflectPass = false
  customFxaaPostEffect:setField("renderTime", 0, "PFXAfterDiffuse")
  customFxaaPostEffect:setField("shader", 0, "FXAA_ShaderData")
  customFxaaPostEffect:setField("stateBlock", 0, "FXAA_StateBlock")
  customFxaaPostEffect:setField("texture", 0, "$backBuffer")
  customFxaaPostEffect:setField("target", 0, "$backBuffer")
  customFxaaPostEffect:registerObject("Custom_FXAA_PostEffect")
end

-- log("I", "", "FXAA Custom PostFX loaded")