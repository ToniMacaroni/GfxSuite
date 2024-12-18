if not scenetree.findObject("Custom_FXAA_PostEffect") then
    rerequire("client/postFx/fxaaCustom")
end


-- ========== Foliage SSS ==========

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

local foliageSSSFx = scenetree.findObject("FoliageSSSFx")
if not foliageSSSFx then
    foliageSSSFx = createObject("PostEffect")
    foliageSSSFx.isEnabled = false
    foliageSSSFx:setField("renderTime", 0, "PFXBeforeBin")
    foliageSSSFx:setField("renderBin", 0, "RenderBinFoliage")
    foliageSSSFx:setField("shader", 0, "foliageSSSShader")
    foliageSSSFx:setField("stateBlock", 0, "PFX_DefaultStateBlock")
    foliageSSSFx:setField("texture", 0, "$backBuffer")
    foliageSSSFx:setField("texture", 1, "#prepass[RT0]")
    foliageSSSFx:setField("texture", 2, "#prepass[Depth]")
    foliageSSSFx:setField("texture", 3, "#prepass[RT1]")
    foliageSSSFx:setField("texture", 4, "#lightinfo")
    foliageSSSFx.renderPriority = 4
    foliageSSSFx:registerObject("FoliageSSSFx")
end


-- ========== Chromatic aberration ==========

local caShader = scenetree.findObject("CAShader")
if not caShader then
    caShader = createObject("ShaderData")
    caShader.DXVertexShaderFile    = "shaders/common/postFx/miscEffects.hlsl"
    caShader.DXPixelShaderFile     = "shaders/common/postFx/miscEffects.hlsl"
    caShader.pixVersion = 5.0
    caShader.defines = "CA_PASS"
    caShader:registerObject("CAShader")
end

local caPostFx = scenetree.findObject("CAPostFx")
if not caPostFx then
    caPostFx = createObject("PostEffect")
    caPostFx.isEnabled = true
    caPostFx:setField("renderTime", 0, "PFXBeforeBin")
    caPostFx:setField("renderBin", 0, "RenderBinFoliage")
    caPostFx:setField("shader", 0, "CAShader")
    caPostFx:setField("stateBlock", 0, "PFX_DefaultStateBlock")
    caPostFx:setField("texture", 0, "$backBuffer")
    -- caPostFx.renderPriority = 100
    caPostFx:registerObject("CAPostFx")
end


-- ========== Highpass ==========

local highpassShader = scenetree.findObject("HighpassShader")
if not highpassShader then
    highpassShader = createObject("ShaderData")
    highpassShader.DXVertexShaderFile    = "shaders/common/postFx/miscEffects.hlsl"
    highpassShader.DXPixelShaderFile     = "shaders/common/postFx/miscEffects.hlsl"
    highpassShader.pixVersion = 5.0
    highpassShader.defines = "HIGHPASS_PASS"
    highpassShader:registerObject("HighpassShader")
end

local highpassPostFx = scenetree.findObject("HighpassPostFx")
if not highpassPostFx then
    highpassPostFx = createObject("PostEffect")
    highpassPostFx.isEnabled = true
    highpassPostFx:setField("renderTime", 0, "PFXBeforeBin")
    highpassPostFx:setField("renderBin", 0, "RenderBinFoliage")
    highpassPostFx:setField("shader", 0, "HighpassShader")
    highpassPostFx:setField("stateBlock", 0, "PFX_DefaultStateBlock")
    highpassPostFx:setField("texture", 0, "$backBuffer")
    highpassPostFx.renderPriority = 100
    highpassPostFx:registerObject("HighpassPostFx")
end

-- ========== Adaptive sharpening ==========

local pfxAdaptiveSharpenShader1 = scenetree.findObject("PFX_AdaptiveSharpenShader1")
if not pfxAdaptiveSharpenShader1 then
    pfxAdaptiveSharpenShader1 = createObject("ShaderData")
    pfxAdaptiveSharpenShader1.DXVertexShaderFile    = "shaders/common/postFx/adaptiveSharpen.hlsl"
    pfxAdaptiveSharpenShader1.DXPixelShaderFile     = "shaders/common/postFx/adaptiveSharpen.hlsl"
    pfxAdaptiveSharpenShader1.pixVersion = 5.0
    pfxAdaptiveSharpenShader1:registerObject("PFX_AdaptiveSharpenShader1")
end

local pfxAdaptiveSharpenShader0 = scenetree.findObject("PFX_AdaptiveSharpenShader0")
if not pfxAdaptiveSharpenShader0 then
  pfxAdaptiveSharpenShader0 = createObject("ShaderData")
  pfxAdaptiveSharpenShader0:inheritParentFields(pfxAdaptiveSharpenShader1)
  pfxAdaptiveSharpenShader0.defines = "PASS0"
  pfxAdaptiveSharpenShader0:registerObject("PFX_AdaptiveSharpenShader0")
end

local pfxAdaptiveSharpen = scenetree.findObject("AdaptiveSharpenPostFx")
if not pfxAdaptiveSharpen then
    pfxAdaptiveSharpen = createObject("PostEffect")
    pfxAdaptiveSharpen.isEnabled = true
    pfxAdaptiveSharpen.allowReflectPass = false
    pfxAdaptiveSharpen:setField("renderTime", 0, "PFXBeforeBin")
    pfxAdaptiveSharpen:setField("renderBin", 0, "ObjTranslucentBin")
    pfxAdaptiveSharpen:setField("shader", 0, "PFX_AdaptiveSharpenShader0")
    pfxAdaptiveSharpen:setField("stateBlock", 0, "PFX_DefaultStateBlock")
    pfxAdaptiveSharpen:setField("texture", 0, "$backBuffer")
    pfxAdaptiveSharpen:setField("target", 0, "$outTex")
    pfxAdaptiveSharpen:setField("targetFormat", 0, "GFXFormatR16G16F")
    pfxAdaptiveSharpen:registerObject("AdaptiveSharpenPostFx")

    local pfxAdaptiveSharpen1 = createObject("PostEffect")
    pfxAdaptiveSharpen1:setField("shader", 0, "PFX_AdaptiveSharpenShader1")
    pfxAdaptiveSharpen1:setField("stateBlock", 0, "PFX_DefaultStateBlock")
    pfxAdaptiveSharpen1:setField("texture", 0, "$backBuffer")
    pfxAdaptiveSharpen1:setField("texture", 1, "$inTex")
    pfxAdaptiveSharpen1:setField("target", 0, "$backBuffer")
    pfxAdaptiveSharpen1:registerObject("AdaptiveSharpenPostFx1")
    pfxAdaptiveSharpen:add(pfxAdaptiveSharpen1)
end


-- ========== Contact shadows ========== (NOT USED)

local contactShadowsPostFx = scenetree.findObject("ContactShadowsPostFx")
if not contactShadowsPostFx then
    -- local contactShadowsPostFxCallbacks = {}
    -- contactShadowsPostFxCallbacks.setShaderConsts = function ()
    --     local fx = scenetree.findObject("ContactShadowsPostFx")
    --     fx:setShaderConst("$radius", 1.0)
    --     fx:setShaderConst("$power", 1.0)
    --     log('I', '', "Contact shadows setShaderConsts")
    -- end
    -- rawset(_G, "contactShadowsPostFxCallbacks", contactShadowsPostFxCallbacks)

    local contactShadowsShader = createObject("ShaderData")
    contactShadowsShader.DXVertexShaderFile    = "shaders/common/postFx/ContactShadows.hlsl"
    contactShadowsShader.DXPixelShaderFile     = "shaders/common/postFx/ContactShadows.hlsl"
    contactShadowsShader.pixVersion = 5.0
    contactShadowsShader.defines = "PASS0"
    contactShadowsShader:registerObject("ContactShadowsShader0")

    contactShadowsPostFx = createObject("PostEffect")
    contactShadowsPostFx.isEnabled = true
    contactShadowsPostFx.allowReflectPass = false
    contactShadowsPostFx:setField("renderTime", 0, "PFXBeforeBin")
    contactShadowsPostFx:setField("renderBin", 0, "ObjTranslucentBin")
    contactShadowsPostFx:setField("shader", 0, "ContactShadowsShader0")
    contactShadowsPostFx:setField("stateBlock", 0, "PFX_DefaultStateBlock")
    contactShadowsPostFx:setField("texture", 0, "$backBuffer")
    contactShadowsPostFx:setField("texture", 1, "#prepass[Depth]")
    contactShadowsPostFx:setField("texture", 2, "#prepass[RT0]")
    contactShadowsPostFx:setShaderConst("$radius", 1.0)
    contactShadowsPostFx:setShaderConst("$power", 1.0)
    -- contactShadowsPostFx:setField("target", 0, "#commonTexx1")
    contactShadowsPostFx:setField("target", 0, "$backBuffer")
    contactShadowsPostFx:registerObject("contactShadowsPostFx")

    -- local contactShadowsPostFx1 = createObject("PostEffect")
    -- -- contactShadowsPostFx1:setField("renderTime", 0, "PFXAfterDiffuse")
    -- contactShadowsPostFx1:setField("shader", 0, "ContactShadowsShader1")
    -- contactShadowsPostFx1:setField("stateBlock", 0, "PFX_DefaultStateBlock")
    -- contactShadowsPostFx1:setField("texture", 0, "$backBuffer")
    -- contactShadowsPostFx1:setField("texture", 1, "#prepass[Depth]")
    -- contactShadowsPostFx1:setField("texture", 2, "#prepass[RT0]")
    -- contactShadowsPostFx1:setField("texture", 3, "#commonTexx1")
    -- contactShadowsPostFx1:setField("texture", 4, "$backBuffer")
    -- contactShadowsPostFx1:setField("texture", 5, "$backBuffer")
    -- contactShadowsPostFx1:setField("target", 0, "#SSR_ColorTex")
    -- -- contactShadowsPostFx1:setField("target", 0, "$backBuffer")
    -- contactShadowsPostFx1:registerObject("contactShadowsPostFx1")
    -- contactShadowsPostFx:add(contactShadowsPostFx1)

    -- local contactShadowsPostFx2 = createObject("PostEffect")
    -- -- contactShadowsPostFx1:setField("renderTime", 0, "PFXAfterDiffuse")
    -- contactShadowsPostFx2:setField("shader", 0, "ContactShadowsShader2")
    -- contactShadowsPostFx2:setField("stateBlock", 0, "PFX_DefaultStateBlock")
    -- contactShadowsPostFx2:setField("texture", 0, "$backBuffer")
    -- contactShadowsPostFx2:setField("texture", 1, "#prepass[Depth]")
    -- contactShadowsPostFx2:setField("texture", 2, "#prepass[RT0]")
    -- contactShadowsPostFx2:setField("texture", 3, "#commonTexx1")
    -- contactShadowsPostFx2:setField("texture", 4, "$backBuffer")
    -- contactShadowsPostFx2:setField("texture", 5, "#SSR_ColorTex")
    -- contactShadowsPostFx2:setField("target", 0, "$backBuffer")
    -- contactShadowsPostFx2:registerObject("contactShadowsPostFx2")
    -- contactShadowsPostFx:add(contactShadowsPostFx2)
end


-- ========== Custom Tonemap ==========

local customTonemapShader = scenetree.findObject("CustomTonemapShader")
if not customTonemapShader then
    customTonemapShader = createObject("ShaderData")
    customTonemapShader.DXVertexShaderFile    = "shaders/common/postFx/customTonemap.hlsl"
    customTonemapShader.DXPixelShaderFile     = "shaders/common/postFx/customTonemap.hlsl"
    customTonemapShader.pixVersion = 5.0
    customTonemapShader:registerObject("CustomTonemapShader")
end

local customTonemapPostFx = scenetree.findObject("CustomTonemapPostFx")
if not customTonemapPostFx then
    customTonemapPostFx = createObject("PostEffect")
    customTonemapPostFx.isEnabled = true
    customTonemapPostFx:setField("shader", 0, "CustomTonemapShader")
    customTonemapPostFx:setField("stateBlock", 0, "PFX_DefaultStateBlock")
    customTonemapPostFx:setField("texture", 0, "$backBuffer")
    customTonemapPostFx:setField("texture", 1, "art/luts/correction.png")
    customTonemapPostFx.renderPriority = 9999
    customTonemapPostFx:registerObject("CustomTonemapPostFx")
end


-- ========== Custom ScatterSky ==========

local existingScatterSky = scenetree.findObject("ScatterSkyShaderData")
if existingScatterSky then
    existingScatterSky:delete()
end

local scatterSkyShaderData = createObject("ShaderData")
scatterSkyShaderData.DXVertexShaderFile = "shaders/common/postFx/customScatterSkyV.hlsl"
scatterSkyShaderData.DXPixelShaderFile  = "shaders/common/postFx/customScatterSkyP.hlsl"
scatterSkyShaderData.pixVersion = 5.0;
scatterSkyShaderData:registerObject("ScatterSkyShaderData")