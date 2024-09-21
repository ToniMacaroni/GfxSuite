local function createState(stateName)
    local stateBlock = scenetree.findObject(stateName)
    if stateBlock then
        return stateBlock
    end

    stateBlock = createObject("GFXStateBlockData")
    stateBlock.zDefined = true;
    stateBlock.zEnable = false;
    stateBlock.zWriteEnable = false;
    stateBlock.samplersDefined = false;
    stateBlock:setField("samplerStates", 0, "SamplerClampPoint")
    stateBlock:registerObject(stateName)
end

local foliageSSSShader = scenetree.findObject("FoliageSSSShader")
if not foliageSSSShader then
    foliageSSSShader = createObject("ShaderData")
    foliageSSSShader.DXVertexShaderFile    = "shaders/common/postFx/foliageSSS.hlsl"
    foliageSSSShader.DXPixelShaderFile     = "shaders/common/postFx/foliageSSS.hlsl"
    foliageSSSShader:setField("samplerNames", 0, "$prepassTex")
    foliageSSSShader.pixVersion = 5.0
    foliageSSSShader.defines = "BLUR_DIR=float2(0.0,1.0)"
    foliageSSSShader:registerObject("FoliageSSSShader")
end

local caShader = scenetree.findObject("CAShader")
if not caShader then
    caShader = createObject("ShaderData")
    caShader.DXVertexShaderFile    = "shaders/common/postFx/miscEffects.hlsl"
    caShader.DXPixelShaderFile     = "shaders/common/postFx/miscEffects.hlsl"
    caShader.pixVersion = 5.0
    caShader.defines = "CA_PASS"
    caShader:registerObject("CAShader")
end

local highpassShader = scenetree.findObject("HighpassShader")
if not highpassShader then
    highpassShader = createObject("ShaderData")
    highpassShader.DXVertexShaderFile    = "shaders/common/postFx/miscEffects.hlsl"
    highpassShader.DXPixelShaderFile     = "shaders/common/postFx/miscEffects.hlsl"
    highpassShader.pixVersion = 5.0
    highpassShader.defines = "HIGHPASS_PASS"
    highpassShader:registerObject("HighpassShader")
end

local contactShadowsShader = scenetree.findObject("ContactShadowsShader")
if not contactShadowsShader then
    contactShadowsShader = createObject("ShaderData")
    contactShadowsShader.DXVertexShaderFile    = "shaders/common/postFx/ContactShadows.hlsl"
    contactShadowsShader.DXPixelShaderFile     = "shaders/common/postFx/ContactShadows.hlsl"
    contactShadowsShader.pixVersion = 5.0
    contactShadowsShader:registerObject("ContactShadowsShader")
end

local customTonemapShader = scenetree.findObject("CustomTonemapShader")
if not customTonemapShader then
    customTonemapShader = createObject("ShaderData")
    customTonemapShader.DXVertexShaderFile    = "shaders/common/postFx/customTonemap.hlsl"
    customTonemapShader.DXPixelShaderFile     = "shaders/common/postFx/customTonemap.hlsl"
    customTonemapShader.pixVersion = 5.0
    customTonemapShader:registerObject("CustomTonemapShader")
end

createState("FoliageSSSStateBlock")
createState("CAPassStateBlock")
createState("HighpassStateBlock")
createState("ContactShadowsStateBlock")

local customTonemapStateBlock = scenetree.findObject("CustomTonemapStateBlock")
if not customTonemapStateBlock then
    customTonemapStateBlock = createObject("GFXStateBlockData")
    customTonemapStateBlock.zDefined = true
    customTonemapStateBlock.zEnable = false
    customTonemapStateBlock.zWriteEnable = false
    --customTonemapStateBlock.samplersDefined = true
    customTonemapStateBlock.blendDefined = true;
    customTonemapStateBlock.blendEnable = true;
    customTonemapStateBlock:setField("blendSrc", 0, "GFXBlendSrcAlpha")
    customTonemapStateBlock:setField("blendDest", 0, "GFXBlendInvSrcAlpha")
    customTonemapStateBlock:setField("blendOp", 0, "GFXBlendOpAdd")
    --customTonemapStateBlock:setField("samplerStates", 0, "SamplerClampLinear")
    customTonemapStateBlock:registerObject("CustomTonemapStateBlock")
end

local foliageSSSFx = scenetree.findObject("FoliageSSSFx")
if not foliageSSSFx then
    foliageSSSFx = createObject("PostEffect")
    foliageSSSFx.isEnabled = false
    foliageSSSFx.allowReflectPass = false
    foliageSSSFx:setField("renderTime", 0, "PFXBeforeBin")
    foliageSSSFx:setField("renderBin", 0, "RenderBinFoliage")
    foliageSSSFx:setField("shader", 0, "foliageSSSShader")
    foliageSSSFx:setField("stateBlock", 0, "FoliageSSSStateBlock")
    foliageSSSFx:setField("texture", 0, "$backBuffer")
    foliageSSSFx:setField("texture", 1, "#prepass[RT0]")
    foliageSSSFx:setField("texture", 2, "#prepass[Depth]")
    foliageSSSFx:setField("texture", 3, "#prepass[RT1]")
    foliageSSSFx:setField("texture", 4, "#lightinfo")
    foliageSSSFx.renderPriority = 4
    foliageSSSFx:registerObject("FoliageSSSFx")
end

local caPostFx = scenetree.findObject("CAPostFx")
if not caPostFx then
    caPostFx = createObject("PostEffect")
    caPostFx.isEnabled = true
    caPostFx.allowReflectPass = false
    caPostFx:setField("renderTime", 0, "PFXBeforeBin")
    caPostFx:setField("renderBin", 0, "RenderBinFoliage")
    caPostFx:setField("shader", 0, "CAShader")
    caPostFx:setField("stateBlock", 0, "CAPassStateBlock")
    caPostFx:setField("texture", 0, "$backBuffer")
    caPostFx.renderPriority = 100
    caPostFx:registerObject("CAPostFx")
end

local highpassPostFx = scenetree.findObject("HighpassPostFx")
if not highpassPostFx then
    highpassPostFx = createObject("PostEffect")
    highpassPostFx.isEnabled = true
    highpassPostFx.allowReflectPass = false
    highpassPostFx:setField("renderTime", 0, "PFXBeforeBin")
    highpassPostFx:setField("renderBin", 0, "RenderBinFoliage")
    highpassPostFx:setField("shader", 0, "HighpassShader")
    highpassPostFx:setField("stateBlock", 0, "HighpassStateBlock")
    highpassPostFx:setField("texture", 0, "$backBuffer")
    highpassPostFx.renderPriority = 100
    highpassPostFx:registerObject("HighpassPostFx")
end

local contactShadowsPostFx = scenetree.findObject("ContactShadowsPostFx")
if not contactShadowsPostFx then
    contactShadowsPostFx = createObject("PostEffect")
    contactShadowsPostFx.isEnabled = false
    contactShadowsPostFx:setField("renderTime", 0, "PFXAfterDiffuse")
    contactShadowsPostFx:setField("shader", 0, "ContactShadowsShader")
    contactShadowsPostFx:setField("stateBlock", 0, "PFX_DefaultStateBlock")
    contactShadowsPostFx:setField("texture", 0, "$backBuffer")
    contactShadowsPostFx:setField("texture", 1, "#prepass[Depth]")
    contactShadowsPostFx:setField("texture", 2, "#prepass[RT0]")
    contactShadowsPostFx:registerObject("ContactShadowsPostFx")
end

local customTonemapPostFx = scenetree.findObject("CustomTonemapPostFx")
if not customTonemapPostFx then
    customTonemapPostFx = createObject("PostEffect")
    customTonemapPostFx.isEnabled = true
    customTonemapPostFx.allowReflectPass = true
    customTonemapPostFx:setField("shader", 0, "CustomTonemapShader")
    customTonemapPostFx:setField("stateBlock", 0, "CustomTonemapStateBlock")
    customTonemapPostFx:setField("texture", 0, "$backBuffer")
    customTonemapPostFx:setField("texture", 1, "art/luts/correction.png")
    customTonemapPostFx.renderPriority = 9999
    customTonemapPostFx:registerObject("CustomTonemapPostFx")
end