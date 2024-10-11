local M = {}
local events = require('timeEvents').create()
local procPrimitives = require('util/trackBuilder/proceduralPrimitives')
local ffi = require('ffi')

local version = "1.1.0"
local configVersion = "0.0.0"
local pendingQuit = false

local im = ui_imgui
local showUI = im.BoolPtr(false)

-- post processing settings

local ppOptions = {header = "Post Processing"}
ppOptions["sharpAmount"] = {
  name = "Sharpness", type = "float", min = 0.0, max = 3.0, value = im.FloatPtr(0.0), -- 0.6
  setter = function(value, ctx)
    ctx.highpassFx:setShaderConst("$highPassSharpStrength", value)
  end
}
ppOptions["caAmount"] = {
  name = "Chromatic Abberation", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.4),
  setter = function(value, ctx)
    ctx.caPostFx:setShaderConst("$caAmount", value)
  end
}

-- tonemapping settings

local tonemappingOptions = {header = "Tonemapping"}
tonemappingOptions["contrast"] = {
  name = "Contrast", type = "float", min = 0.5, max = 3.0, value = im.FloatPtr(1.7),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$contrast", value)
  end
}
tonemappingOptions["maxDisplayBrightness"] = {
  name = "Max Display Brightness", type = "float", min = 0.5, max = 2.0, value = im.FloatPtr(0.92),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$maxDisplayBrightness", value)
  end
}
tonemappingOptions["linearSectionStart"] = {
  name = "Linear Section Start", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.22),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$linearSectionStart", value)
  end
}
tonemappingOptions["linearSectionLength"] = {
  name = "Linear Section Length", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.1),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$linearSectionLength", value)
  end
}
tonemappingOptions["black"] = {
  name = "Black", type = "float", min = 0.0, max = 3.0, value = im.FloatPtr(1.45),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$black", value)
  end
}
tonemappingOptions["pedestal"] = {
  name = "Pedestal", type = "float", min = 0.0, max = 0.1, value = im.FloatPtr(0.0),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$pedestal", value)
  end
}

-- tonemapping extras

local tonemappingExtrasOptions = {header = "Tonemapping Extras"}
tonemappingExtrasOptions["lutStrength"] = {
  name = "LUT Strength", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.211),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$lutStrength", value)
  end
}
tonemappingExtrasOptions["hue"] = {
  name = "Hue", type = "float", min = -1.0, max = 1.0, value = im.FloatPtr(1.0),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$hue", value)
  end
}
tonemappingExtrasOptions["saturation"] = {
  name = "Saturation", type = "float", min = 0.0, max = 2.0, value = im.FloatPtr(1.15),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$saturation", value)
  end
}
tonemappingExtrasOptions["exposure"] = {
  name = "Exposure", type = "float", min = 0.0, max = 2.0, value = im.FloatPtr(1.15),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$exposure", value)
  end
}
tonemappingExtrasOptions["tint"] = {
  name = "Tint", type = "color", value = im.ArrayFloat(4),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$tint", string.format("%f %f %f %f", value[0], value[1], value[2], value[3]))
  end
}

-- misc stuff

local miscOptions = {header = "Misc"}
miscOptions["ssaoSamples"] = {
  name = "High SSAO Samples", type = "bool", value = im.BoolPtr(false),
  setter = function(value, ctx)
    scenetree.SSAOPostFx:setSamples(value and 64 or 16)
  end
}
miscOptions["ssaoRadius"] = {
  name = "SSAO Radius", type = "float", min = 0, max = 10, value = im.FloatPtr(1.5),
  setter = function(value, ctx)
    scenetree.SSAOPostFx:setRadius(value)
  end
}
miscOptions["ssaoContrast"] = {
  name = "SSAO Contrast", type = "float", min = 0, max = 10, value = im.FloatPtr(2.0),
  setter = function(value, ctx)
    scenetree.SSAOPostFx:setContrast(value)
  end
}
miscOptions["shadowQuality"] = {
  name = "Shadow Quality", type = "int", min = 1, max = 4, value = im.IntPtr(4),
  setter = function(value, ctx)
    TorqueScriptLua.setVar("$pref::Shadows::textureScalar", value)
  end
}
miscOptions["shadowSoftness"] = {
  name = "Shadow Softness", type = "float", min = 0.0, max = 4.0, value = im.FloatPtr(0.2),
  setter = function(value, ctx)
    ctx.sky.shadowSoftness = value
    ctx.sky:postApply()
  end
}
miscOptions["shadowLogWeight"] = {
  name = "Log Weight", type = "float", min = 0.0, max = 100.0, value = im.FloatPtr(66.8),
  setter = function(value, ctx)
    ctx.sky.logWeight = value * 0.0003 + 0.97
    ctx.sky:postApply()
  end
}
miscOptions["terrainDetail"] = {
  name = "Terrain Detail", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.4),
  setter = function(value, ctx)
    TorqueScriptLua.setVar("$pref::Terrain::lodScale", value)
  end
}
miscOptions["lodDetail"] = { -- 1.5 default
  name = "LOD Detail", type = "float", min = 0.0, max = 10.0, value = im.FloatPtr(6.8),
  setter = function(value, ctx)
    TorqueScriptLua.setVar("$pref::TS::detailAdjust", value)
  end
}
miscOptions["foliageDensity"] = {
  name = "Foliage Density", type = "float", min = 0.0, max = 3.0, value = im.FloatPtr(1.881),
  setter = function(value, ctx)
    TorqueScriptLua.setVar("$pref::GroundCover::densityScale", value)
  end
}

-- environment stuff

local environmentOptions = {header = "Environment"}
environmentOptions["time"] = {
  name = "Time", type = "float", min = 0.0, max = 100.0, value = im.FloatPtr(83.0),
  setter = function(value, ctx)
    local tempSunScale = ctx.sky.sunScale

    local time = core_environment.getTimeOfDay()
    time.time = value/100.0
    core_environment.setTimeOfDay(time)

    ctx.sky.sunScale = tempSunScale
    ctx.sky:postApply()

    ctx["fogNeedsUpdating"] = true
  end
}
environmentOptions["azimuth"] = {
  name = "Sun Direction", type = "float", min = 0.0, max = 360.0, value = im.FloatPtr(0.0),
  setter = function(value, ctx)
    local tempSunScale = ctx.sky.sunScale

    local time = core_environment.getTimeOfDay()
    time.azimuthOverride = value/180.0*math.pi
    core_environment.setTimeOfDay(time)

    ctx.sky.sunScale = tempSunScale
    ctx.sky:postApply()

    ctx["fogNeedsUpdating"] = true
  end
}
environmentOptions["light"] = {
  name = "Light", type = "float", min = 0.0, max = 5.0, value = im.FloatPtr(0.544),
  setter = function(value, ctx)
    ctx.sky.brightness = value
    ctx.sky:postApply()

    ctx["fogNeedsUpdating"] = true
  end
}
environmentOptions["skyBrightness"] = {
  name = "Sky Brightness", type = "float", min = 0.0, max = 200.0, value = im.FloatPtr(120.0),
  setter = function(value, ctx)
    ctx.sky.skyBrightness = value
    ctx.sky:postApply()

    ctx["fogNeedsUpdating"] = true
  end
}
environmentOptions["sunScale"] = {
  name = "Sun Scale", type = "color", value = im.ArrayFloat(4),
  setter = function(value, ctx)
    ctx.sky.sunScale = Point4F(value[0], value[1], value[2], value[3])
    ctx.sky:postApply()

    ctx["fogNeedsUpdating"] = true
  end
}
environmentOptions["fogAmount"] = {
  name = "Fog Amount", type = "float", min = 0.0, max = 10.0, value = im.FloatPtr(0.0),
  setter = function(value, ctx)
    core_environment.setFogDensity(value * 0.0001)
  end
}
environmentOptions["fogColor"] = {
  name = "Fog Color", type = "color", value = im.ArrayFloat(4),
  setter = function(value, ctx)
    scenetree.theLevelInfo.fogColor = Point4F(value[0], value[1], value[2], value[3])
    scenetree.theLevelInfo:postApply()
  end
}
environmentOptions["fov"] = {
  name = "Camera FOV", type = "float", min = 10, max = 90, value = im.FloatPtr(60),
  setter = function(value, ctx)
    core_camera.setFOV(0, value)
  end
}
environmentOptions["rayleighScattering"] = {
  name = "Rayleigh Scattering", type = "float", min = 0.0, max = 100.0, value = im.FloatPtr(14),
  setter = function(value, ctx)
    ctx.sky.rayleighScattering = value * 0.0001
    ctx.sky:postApply()

    ctx["fogNeedsUpdating"] = true
  end
}

-- lightray stuff

local lightrayOptions = {header = "Light Rays"}
-- lightrayOptions["brightness"] = {
--   name = "Lightray Brightness", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.75),
--   setter = function(value, ctx)
--     TorqueScriptLua.setVar("$LightRayPostFX::brightScalar", value)
--   end
-- }
lightrayOptions["numSamples"] = {
  name = "Lightray Samples", type = "int", min = 0, max = 100, value = im.IntPtr(40),
  setter = function(value, ctx)
    TorqueScriptLua.setVar("$LightRayPostFX::numSamples", value)
  end
}
-- lightrayOptions["density"] = {
--   name = "Lightray Density", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.94),
--   setter = function(value, ctx)
--     TorqueScriptLua.setVar("$LightRayPostFX::density", value)
--   end
-- }
lightrayOptions["weight"] = {
  name = "Lightray Weight", type = "float", min = 0.0, max = 100.0, value = im.FloatPtr(10.0),
  setter = function(value, ctx)
    TorqueScriptLua.setVar("$LightRayPostFX::weight", value)
  end
}
-- lightrayOptions["decay"] = {
--   name = "Lightray Decay", type = "float", min = 0.0, max = 10.0, value = im.FloatPtr(1.0),
--   setter = function(value, ctx)
--     TorqueScriptLua.setVar("$LightRayPostFX::decay", value)
--   end
-- }
lightrayOptions["exposure"] = {
  name = "Lightray Exposure", type = "float", min = 0.0, max = 100, value = im.FloatPtr(5),
  setter = function(value, ctx)
    TorqueScriptLua.setVar("$LightRayPostFX::exposure", value * 0.0001)
  end
}
lightrayOptions["resolutionScale"] = {
  name = "Lightray Resolution Scale", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.20),
  setter = function(value, ctx)
    TorqueScriptLua.setVar("$LightRayPostFX::resolutionScale", value)
  end
}

-- sky stuff

local skyboxOptions = {header = "Skybox"}
skyboxOptions["enable"] = {
  name = "Enable", type = "bool", value = im.BoolPtr(true),
  setter = function (value, ctx)
    if value then
      ctx.skyboxManager:createSky()
    else
      ctx.skyboxManager:removeSky()
    end
  end
}

-- bloom stuff

local bloomOptions = {header = "Bloom"}
bloomOptions["bloomThreshold"] = {
  name = "Threshold", type = "float", min = 0.001, max = 5.0, value = im.FloatPtr(3.5),
  setter = function(value, ctx)
    scenetree.PostEffectBloomObject.threshHold = value
  end
}
bloomOptions["knee"] = {
  name = "Knee", type = "float", min = 0.001, max = 5.0, value = im.FloatPtr(0.1),
  setter = function(value, ctx)
    scenetree.PostEffectBloomObject.knee = value
  end
}

-- extra stuff

local extraOptions = {header = "Extras"}
extraOptions["enableFXAA"] = {
  name = "Enable FXAA", type = "bool", value = im.BoolPtr(false),
  setter = function(value, ctx)
    scenetree.findObject("FXAA_PostEffect"):disable()

    if value then
      scenetree.findObject("Custom_FXAA_PostEffect"):enable()
    else
      scenetree.findObject("Custom_FXAA_PostEffect"):disable()
    end
  end
}
extraOptions["enableSMAA"] = {
  name = "Enable SMAA", type = "bool", value = im.BoolPtr(false),
  setter = function(value, ctx)
    scenetree.findObject("FXAA_PostEffect"):disable()
    
    if value then
      scenetree.findObject("SMAA_PostEffect"):enable()
    else
      scenetree.findObject("SMAA_PostEffect"):disable()
    end
  end
}


local options = {
  ppOptions = ppOptions,
  tonemappingOptions = tonemappingOptions,
  tonemappingExtrasOptions = tonemappingExtrasOptions,
  miscOptions = miscOptions,
  environmentOptions = environmentOptions,
  lightrayOptions = lightrayOptions,
  skyboxOptions = skyboxOptions,
  bloomOptions = bloomOptions,
  extraOptions = extraOptions
}

local function setImArray(imArray, ...)
  local values = {...}
  for i, v in ipairs(values) do
    imArray[i - 1] = im.Float(v)
  end
end

miscOptions["shadowSoftness"].value[0] = 2.5
setImArray(environmentOptions["sunScale"].value, 0.776, 0.582, 0.448, 1.0)
setImArray(tonemappingExtrasOptions["tint"].value, 1.0, 1.0, 1.0, 1.0)
setImArray(environmentOptions["fogColor"].value, 0.402, 0.374, 0.322, 1.0)

-- set default values
for k,v in pairs(options) do
  for k2,v2 in pairs(v) do
    if k2 ~= "header" then
      if v2.type == "color" then v2["defaultValue"] = v2.value
      else v2["defaultValue"] = v2.value[0] end
    end
  end
end

local ctx = {}
local skyboxManager = { activeSky = {name = "partially_cloudy", dir = "art/custom_skies"} }
local skyDirs = {}
local profiles = {}
local activeProfile = "default"
local newProfileName = im.ArrayChar(64)
local profileIndex = im.IntPtr(-1)

local isTablesRefreshed = false

local screenWidth = 2560
local screenHeight = 1440

local screenShotSuperSamplingPtr = im.IntPtr(1)

local function refreshTable(table)
  for k,v in pairs(table) do
    if k ~= "header" then
      if v.type == "color" then v.setter(v.value, ctx)
      else v.setter(v.value[0], ctx) end
    end
  end
end

local function revertTable(table)
  for k,v in pairs(table) do
    if k ~= "header" then
      if v.type == "color" then
        setImArray(v.value, v.defaultValue[0], v.defaultValue[1], v.defaultValue[2], v.defaultValue[3])
      else
        v.value[0] = v.defaultValue
      end
      v.setter(v.defaultValue, ctx)
    end
  end
end

local function refreshOptionsAll()
  for k,v in pairs(options) do
    refreshTable(v)
  end
end

local function revertOptionsAll()
  for k,v in pairs(options) do
    revertTable(v)
  end
end

local function listSkies()
  skyDirs = {}
  local folders = FS:directoryList("art/custom_skies", false, true)
  local folders2 = FS:directoryList("settings/gfxSuite/skies", false, true)

  table.move(folders2, 1, #folders2, #folders + 1, folders)

  for _, folder in ipairs(folders) do
    local dir, filename, ext = path.split(folder)
    table.insert(skyDirs, {name = filename, dir = dir})
  end
end

local function listProfiles()
  profiles = {}
  local files = FS:findFiles("settings/gfxSuite/profiles", "*.json", -1, true, false)
  for _, filepath in ipairs(files) do
    local dir, filename, ext = path.split(filepath)
    table.insert(profiles, filename:sub(1, -6))
  end
end

local function loadProfile(profileName, refreshTables)
  if not FS:fileExists("settings/gfxSuite/profiles/" .. profileName .. ".json") then
    log('I', '', "GfxSuite profile " .. profileName .. " not found!")
    return
  end

  local data = jsonReadFile("settings/gfxSuite/profiles/" .. profileName .. ".json")
  if not data then
    log('I', '', "GfxSuite profile " .. profileName .. " is empty!")
    return
  end

  for k,v in pairs(data) do
    if options[k] then
      for k2,v2 in pairs(v) do
        if options[k][k2] then
          if options[k][k2].type == "color" then
            local values = split(v2, " ")
            if #values == 1 then values = {1.0, 1.0, 1.0, 1.0} end
            setImArray(options[k][k2].value, tonumber(values[1]), tonumber(values[2]), tonumber(values[3]), tonumber(values[4]))
          else
            options[k][k2].value[0] = v2
          end
        end
      end
    end
  end

  if data["activeSkybox"] then
    skyboxManager.activeSky = data["activeSkybox"]
  end

  activeProfile = profileName
  ffi.copy(newProfileName, profileName)

  if refreshTables and scenetree.findObject("sunsky") then
    refreshOptionsAll()
  end

  log('I', '', "GfxSuite profile " .. profileName .. " loaded!")
end

local function loadSettings()
  if not FS:fileExists("settings/gfxSuite.json") then
    log('I', '', "GfxSuite settings file not found!")
    return
  end

  local data = jsonReadFile("settings/gfxSuite.json")
  if not data then
    log('I', '', "GfxSuite settings file is empty!")
    return
  end

  if data["activeProfile"] then
    activeProfile = data["activeProfile"]
    loadProfile(activeProfile, false)
    ffi.copy(newProfileName, activeProfile)
    for i, profile in ipairs(profiles) do
      if profile == activeProfile then
        profileIndex[0] = i
        break
      end
    end
  end

  if data["version"] then
    configVersion = data["version"]
  end

  log('I', '', "GfxSuite settings loaded!")
end

local function saveProfile(profileName)
  local data = {}
  for k,v in pairs(options) do
    data[k] = {}
    for k2,v2 in pairs(v) do
      if k2 ~= "header" then
        if v2.type == "color" then
          data[k][k2] = string.format("%f %f %f %f", v2.value[0], v2.value[1], v2.value[2], v2.value[3])
        else
          data[k][k2] = v2.value[0]
        end
      end
    end
  end

  data["activeSkybox"] = skyboxManager.activeSky

  jsonWriteFile("settings/gfxSuite/profiles/" .. profileName .. ".json", data)

  log('I', '', "GfxSuite profile " .. profileName .. " saved!")
end

local function saveSettings()
  local data = {
    activeProfile = activeProfile
  }

  data["version"] = version

  jsonWriteFile("settings/gfxSuite.json", data)

  log('I', '', "GfxSuite settings saved!")
end

local function onExtensionLoaded()
  listProfiles()
  loadSettings()

  if configVersion ~= version then
    saveSettings()
    messageBox("GfxSuite", "New version of GFX Suite installed. It is recommended to clear the '%localappdata%/BeamNG.drive/latest/temp/shaders' folder in order to recompile the shaders and start the game again. If it's your first time installing this mod you can ignore this message.", 0, 0)
  end
end

skyboxManager.createSky = function()

  if not skyboxManager.activeSky then
    log('I', '', "Skybox not selected")
    return
  end

  if not FS:fileExists(skyboxManager.activeSky.dir .. "/" .. skyboxManager.activeSky.name .. "/px.png") then
    log('I', '', "Skybox not found")
    return
  end

  local fullSkyPath = skyboxManager.activeSky.dir .. "/" .. skyboxManager.activeSky.name

  local skybox = scenetree.findObject("MySky")
  if not skybox then
    skybox = worldEditorCppApi.createObject("SkyBox")
    skybox:setName("MySky")
    scenetree.MissionGroup:add(skybox.obj)
    skybox:registerObject("MySky")
  end

  local cubemap = scenetree.findObject("MyCubemap")
  if cubemap then
    cubemap:delete()
  end

  cubemap = createObject("CubemapData")
  cubemap:setField("cubeFace", 0, fullSkyPath .. "/px.png")
  cubemap:setField("cubeFace", 1, fullSkyPath .. "/nx.png")
  cubemap:setField("cubeFace", 2, fullSkyPath .. "/nz.png")
  cubemap:setField("cubeFace", 3, fullSkyPath .. "/pz.png")
  cubemap:setField("cubeFace", 4, fullSkyPath .. "/py.png")
  cubemap:setField("cubeFace", 5, fullSkyPath .. "/ny.png")
  cubemap:registerObject("MyCubemap")

  local skyMat = scenetree.findObject("MySkyMat")
  if not skyMat then
    skyMat = createObject("Material")
    skyMat:registerObject("MySkyMat")
  end

  skyMat:setField("cubemap", 0, "MyCubemap")

  skybox:setField("material", 0, "MySkyMat")
  skybox:postApply()

  log('I', '', "Skybox created/updated")
end

skyboxManager.removeSky = function()
  local skybox = scenetree.findObject("MySky")
  if skybox then
    skybox:delete()
  end

  local cubemap = scenetree.findObject("MyCubemap")
  if cubemap then
    cubemap:delete()
  end

  local skyMat = scenetree.findObject("MySkyMat")
  if skyMat then
    skyMat:delete()
  end

  log('I', '', "Skybox removed")
end

local function renderTable(table, inTreeNode)
  if not inTreeNode or im.TreeNodeEx1(table.header, im.TreeNodeFlags_FramePadding + im.TreeNodeFlags_DefaultOpen) then
    for k,v in pairs(table) do
      if v.type == "int" then
        if im.SliderInt(v.name, v.value, v.min, v.max) then
          v.setter(v.value[0], ctx)
        end
      elseif v.type == "float" then
        if im.SliderFloat(v.name, v.value, v.min, v.max) then
          v.setter(v.value[0], ctx)
        end
      elseif v.type == "bool" then
        if im.Checkbox(v.name, v.value) then
          v.setter(v.value[0], ctx)
        end
      elseif v.type == "color" then
        if im.ColorEdit4(v.name, v.value) then
          v.setter(v.value, ctx)
        end
      end
    end
    if inTreeNode then im.TreePop() end
  end
end

local function onClientPostStartMission()
  ctx = {}
  isTablesRefreshed = false

  if not scenetree.findObject("FoliageSSSFx") then
    rerequire("client/postFx/gfxSuiteFx")
    ctx["foliageSSSFx"] = scenetree.findObject("FoliageSSSFx")
    ctx["caPostFx"] = scenetree.findObject("CAPostFx")
    ctx["tonemappingFx"] = scenetree.findObject("CustomTonemapPostFx")
    ctx["highpassFx"] = scenetree.findObject("HighpassPostFx")
    ctx["contactShadowsFx"] = scenetree.findObject("ContactShadowsPostFx")
  end

  listSkies()

  ctx.skyboxManager = skyboxManager

  local meshNames = scenetree.findClassObjects('ScatterSky')
  for k,v in pairs(meshNames) do
    local m = scenetree.findObject(v)
    if not m then log("E", "", "ScatterSky broken "..dumps(v))
    else
      m.texSize = 4096
      m.shadowDistance = 1600
      m.exposure = 2.0
    end
  end

  local postEffectCombinePass = scenetree.findObject("PostEffectCombinePassObject")
  postEffectCombinePass.enabled = 0.0

  scenetree.findObject("FXAA_PostEffect"):disable()
end

local function takeScreenshot()
  local path = "screenshots/GFXSuite"
  if not FS:directoryExists(path) then FS:directoryCreate(path) end
  local screenshotDateTimeString = getScreenShotDateTimeString()
  local subFilename = string.format("%s/screenshot_%s", path, screenshotDateTimeString)

  local fullFilename
  local screenshotNumber = 0
  repeat
    if screenshotNumber > 0 then
      fullFilename = FS:expandFilename(string.format("%s_%s", subFilename, screenshotNumber))
    else
      fullFilename = FS:expandFilename(subFilename)
    end
    screenshotNumber = screenshotNumber + 1
  until not FS:fileExists(fullFilename)
  createScreenshot(fullFilename, "png", screenShotSuperSamplingPtr[0], 1, 0, nil)
  log('I', '', "Screenshot taken")
end

local function pushImStyle()
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(15, 15))
  im.PushStyleVar1(im.StyleVar_WindowRounding, 5.0)
  im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(5, 5))
  im.PushStyleVar1(im.StyleVar_FrameRounding, 4.0)
  im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(12, 8))
  im.PushStyleVar2(im.StyleVar_ItemInnerSpacing, im.ImVec2(8, 6))
  im.PushStyleVar1(im.StyleVar_IndentSpacing, 25.0)
  im.PushStyleVar1(im.StyleVar_ScrollbarSize, 15.0)
  im.PushStyleVar1(im.StyleVar_ScrollbarRounding, 9.0)
  im.PushStyleVar1(im.StyleVar_GrabMinSize, 5.0)
  im.PushStyleVar1(im.StyleVar_GrabRounding, 3.0)

  im.PushStyleColor2(im.Col_Text, im.ImVec4(0.86, 0.93, 0.89, 0.78))
  im.PushStyleColor2(im.Col_TextDisabled, im.ImVec4(0.86, 0.93, 0.89, 0.28))
  im.PushStyleColor2(im.Col_WindowBg, im.ImVec4(0.13, 0.14, 0.17, 1.00))
  im.PushStyleColor2(im.Col_Border, im.ImVec4(0.31, 0.31, 1.00, 0.00))
  im.PushStyleColor2(im.Col_BorderShadow, im.ImVec4(0.00, 0.00, 0.00, 0.00))
  im.PushStyleColor2(im.Col_FrameBg, im.ImVec4(0.20, 0.22, 0.27, 1.00))
  im.PushStyleColor2(im.Col_FrameBgHovered, im.ImVec4(0.92, 0.18, 0.29, 0.78))
  im.PushStyleColor2(im.Col_FrameBgActive, im.ImVec4(0.92, 0.18, 0.29, 1.00))
  im.PushStyleColor2(im.Col_TitleBg, im.ImVec4(0.20, 0.22, 0.27, 1.00))
  im.PushStyleColor2(im.Col_TitleBgCollapsed, im.ImVec4(0.20, 0.22, 0.27, 0.75))
  im.PushStyleColor2(im.Col_TitleBgActive, im.ImVec4(0.20, 0.22, 0.27, 1.00))
  im.PushStyleColor2(im.Col_MenuBarBg, im.ImVec4(0.20, 0.22, 0.27, 0.47))
  im.PushStyleColor2(im.Col_ScrollbarBg, im.ImVec4(0.13, 0.14, 0.17, 1.00))
  im.PushStyleColor2(im.Col_ScrollbarGrab, im.ImVec4(0.20, 0.22, 0.27, 1.00))
  im.PushStyleColor2(im.Col_ScrollbarGrabHovered, im.ImVec4(0.92, 0.18, 0.29, 0.78))
  im.PushStyleColor2(im.Col_ScrollbarGrabActive, im.ImVec4(0.92, 0.18, 0.29, 1.00))
  im.PushStyleColor2(im.Col_CheckMark, im.ImVec4(0.71, 0.22, 0.27, 1.00))
  im.PushStyleColor2(im.Col_SliderGrab, im.ImVec4(0.47, 0.77, 0.83, 0.14))
  im.PushStyleColor2(im.Col_SliderGrabActive, im.ImVec4(0.92, 0.18, 0.29, 1.00))
  im.PushStyleColor2(im.Col_Button, im.ImVec4(0.47, 0.77, 0.83, 0.14))
  im.PushStyleColor2(im.Col_ButtonHovered, im.ImVec4(0.92, 0.18, 0.29, 0.86))
  im.PushStyleColor2(im.Col_ButtonActive, im.ImVec4(0.92, 0.18, 0.29, 1.00))
  im.PushStyleColor2(im.Col_Header, im.ImVec4(0.92, 0.18, 0.29, 0.76))
  im.PushStyleColor2(im.Col_HeaderHovered, im.ImVec4(0.92, 0.18, 0.29, 0.86))
  im.PushStyleColor2(im.Col_HeaderActive, im.ImVec4(0.92, 0.18, 0.29, 1.00))
  im.PushStyleColor2(im.Col_Separator, im.ImVec4(0.34, 0.36, 0.39, 1.00))
  im.PushStyleColor2(im.Col_SeparatorHovered, im.ImVec4(0.92, 0.18, 0.29, 0.78))
  im.PushStyleColor2(im.Col_SeparatorActive, im.ImVec4(0.92, 0.18, 0.29, 1.00))
  im.PushStyleColor2(im.Col_ResizeGrip, im.ImVec4(0.47, 0.77, 0.83, 0.04))
  im.PushStyleColor2(im.Col_ResizeGripHovered, im.ImVec4(0.92, 0.18, 0.29, 0.78))
  im.PushStyleColor2(im.Col_ResizeGripActive, im.ImVec4(0.92, 0.18, 0.29, 1.00))
  im.PushStyleColor2(im.Col_PlotLines, im.ImVec4(0.86, 0.93, 0.89, 0.63))
  im.PushStyleColor2(im.Col_PlotLinesHovered, im.ImVec4(0.92, 0.18, 0.29, 1.00))
  im.PushStyleColor2(im.Col_PlotHistogram, im.ImVec4(0.86, 0.93, 0.89, 0.63))
  im.PushStyleColor2(im.Col_PlotHistogramHovered, im.ImVec4(0.92, 0.18, 0.29, 1.00))
  im.PushStyleColor2(im.Col_TextSelectedBg, im.ImVec4(0.92, 0.18, 0.29, 0.43))
  im.PushStyleColor2(im.Col_PopupBg, im.ImVec4(0.20, 0.22, 0.27, 0.9))
  im.PushStyleColor2(im.Col_TabActive, im.ImVec4(0.92, 0.18, 0.29, 1.00))
end

local function imPopStyle()
  im.PopStyleVar(11)
  im.PopStyleColor(38)
end

local function imButton(text, height)
  return im.Button(text, im.ImVec2(im.GetContentRegionAvailWidth(), height or 30))
end

local function renderSkyboxOptions()
  if im.Checkbox(skyboxOptions["enable"].name, skyboxOptions["enable"].value) then
    skyboxOptions["enable"].setter(skyboxOptions["enable"].value[0], ctx)
  end

  if im.BeginCombo('Select Sky', skyboxManager.activeSky.name) then
    for _, sky in ipairs(skyDirs) do
      if im.Selectable1(sky.name, sky == skyboxManager.activeSky) then
        skyboxManager.activeSky = sky
        skyboxManager:createSky()
      end
    end
    im.EndCombo()
  end

  if imButton("Reload Sky") then
    skyboxManager:createSky()
  end

  if imButton("Refresh Skies") then
    listSkies()
  end
end

local function drawWindowContent()
  if im.BeginTabBar("Settings") then

    if im.BeginTabItem("Main") then
      
      renderTable(ppOptions, true)
      im.Separator()
      renderTable(tonemappingOptions, true)
      im.Separator()
      renderTable(tonemappingExtrasOptions, true)
      im.Separator()
      renderTable(miscOptions, true)
      im.Separator()
      renderTable(lightrayOptions, true)
      im.Separator()
      renderTable(bloomOptions, true)

      im.EndTabItem()
    end

    if im.BeginTabItem("Environment") then
      renderTable(environmentOptions, false)
      im.EndTabItem()
    end

    if im.BeginTabItem("Extras") then
      renderTable(extraOptions, false)
      im.Separator()
      im.Text("Screenshot")
      im.SliderInt("Super Sampling", screenShotSuperSamplingPtr, 1, 36)
      if imButton("Take Screenshot", 40) then
        takeScreenshot()
      end
      im.EndTabItem()
    end

    if im.BeginTabItem("Skybox") then
      renderSkyboxOptions()
      im.EndTabItem()
    end

    if im.BeginTabItem("Profiles") then

      if im.ListBox1("Profiles", profileIndex, im.ArrayCharPtrByTbl(profiles), #profiles, 6) then
        if profileIndex[0] ~= -1 then
          loadProfile(profiles[profileIndex[0] + 1], true)
        end
      end

      im.InputText("Profile Name", newProfileName)

      if imButton("Save Profile", 40) then
        local newProfileNameString = ffi.string(newProfileName)
        saveProfile(newProfileNameString)
        activeProfile = newProfileNameString
        listProfiles()
      end

      im.Spacing()

      if imButton("Reset all values", 40) then
        revertOptionsAll()
      end

      im.EndTabItem()
    end

    im.EndTabBar()
  end
end

local function imRender()

  if not showUI[0] then
    return
  end

  pushImStyle()

  im.SetNextWindowSizeConstraints(im.ImVec2(500, 800), im.ImVec2(500, 800))
  if im.Begin("GFX Suite v" .. version, showUI, im.WindowFlags_AlwaysAutoResize+im.WindowFlags_NoResize) then
    drawWindowContent()
    im.End()
  end

  imPopStyle()
end

local function toggleWindow()
  showUI[0] = not showUI[0]
  log('I', '', "GFX Suite is now " .. (showUI[0] and "visible" or "hidden"))
end

local function onSettingsChanged()
  local vm = GFXDevice.getVideoMode()
  screenWidth = vm.width
  screenHeight = vm.height
end

local function onUpdate(dt)
  events:process(dt)
  if pendingQuit then
    return
  end

  if ctx["foliageSSSFx"] == nil then
    ctx["foliageSSSFx"] = scenetree.findObject("FoliageSSSFx")
    return
  end

  if ctx["caPostFx"] == nil then
    ctx["caPostFx"] = scenetree.findObject("CAPostFx")
    return
  end

  if ctx["highpassFx"] == nil then
    ctx["highpassFx"] = scenetree.findObject("HighpassPostFx")
    return
  end

  if ctx["tonemappingFx"] == nil then
    ctx["tonemappingFx"] = scenetree.findObject("CustomTonemapPostFx")
    -- if ctx["tonemappingFx"] then
    --   ctx["tonemappingFx"]:setField("sampler", "lutTex", "art/luts/neutral.png")
    -- end
    return
  end

  if ctx["contactShadowsFx"] == nil then
    ctx["contactShadowsFx"] = scenetree.findObject("ContactShadowsPostFx")
    return
  end

  ctx["sky"] = scenetree.findObject("sunsky")

  if not isTablesRefreshed then
    refreshOptionsAll()
    log('I', '', "Setting tables refreshed")
    isTablesRefreshed = true
  end

  if ctx["fogNeedsUpdating"] then
    scenetree.theLevelInfo:postApply()
    ctx["fogNeedsUpdating"] = false
  end

  ctx["caPostFx"]:setShaderConst("$screenResolution", screenWidth .. " " .. screenHeight)
  ctx["highpassFx"]:setShaderConst("$screenResolution", screenWidth .. " " .. screenHeight)

  imRender()
end

local function onCameraToggled(parms)
  if parms.cameraType == "FreeCam" then
    environmentOptions["fov"].setter(environmentOptions["fov"].value[0], ctx)    
  end
end

local function onExit()
  saveSettings()
end

M.onExtensionLoaded = onExtensionLoaded
M.onClientPostStartMission = onClientPostStartMission
M.onUpdate = onUpdate
M.onSettingsChanged = onSettingsChanged
M.onExit = onExit
M.toggleWindow = toggleWindow
M.onCameraToggled = onCameraToggled
return M