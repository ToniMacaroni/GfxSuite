local M = {}
local events = require('timeEvents').create()
local procPrimitives = require('util/trackBuilder/proceduralPrimitives')
local ffi = require('ffi')
local imStyle = require('gfxSuite/imStyle')
local skyboxCreator = require('gfxSuite/skyboxCreator')

local version = "1.3.0"
local configVersion = "0.0.0"
local pendingQuit = false

local im = ui_imgui
local showUI = im.BoolPtr(false)

-- post processing settings

local ppOptions = {header = "Post Processing"}

ppOptions["sharpAmount"] = {
  name = "Highpass Sharpen", type = "float", min = 0.0, max = 3.0, value = im.FloatPtr(0.0), -- 0.6
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
ppOptions["adaptiveSharpen"] = {
  name = "Adaptive Sharpen", type = "float", min = 0.0, max = 5.0, value = im.FloatPtr(0.0),
  setter = function(value, ctx)
    if value < 0.01 then
      if ctx.adaptiveSharpenPostFx.isEnabled then ctx.adaptiveSharpenPostFx:disable() end
    else
      ctx.adaptiveSharpenPostFx:enable()
      ctx.adaptiveSharpenPostFx1:setShaderConst("$curveHeight", value)
    end
  end
}
ppOptions["sharpenOpacityMask"] = {
  name = "Opacity mask for sharpen", type = "bool", value = im.BoolPtr(false),
  setter = function(value, ctx)
    ctx.adaptiveSharpenPostFx1:setShaderConst("$useOpacityMask", value and 1.0 or 0.0)
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

tonemappingOptions["gain"] = {
  name = "Gain", type = "float", min = 0.0, max = 10.0, value = im.FloatPtr(1.0),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$gain", value)
  end
}
tonemappingOptions["agxMix"] = {
  name = "AGX Mix", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.85),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$agx_mix", value)
  end
}
tonemappingOptions["agxMixExp"] = {
  name = "AGX Mix Exp", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.40),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$agx_mix_exp", value)
  end
}
tonemappingOptions["agxSlope"] = {
  name = "AGX Slope", type = "float", min = 0.0, max = 2.0, value = im.FloatPtr(1.18),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$agx_slope", value)
  end
}
tonemappingOptions["agxPower"] = {
  name = "AGX Power", type = "float", min = 0.0, max = 10.0, value = im.FloatPtr(2.40),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$agx_power", value)
  end
}
tonemappingOptions["agxSat"] = {
  name = "AGX Sat", type = "float", min = 0.0, max = 2.0, value = im.FloatPtr(0.99),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$agx_sat", value)
  end
}
tonemappingOptions["agxSatDependency"] = {
  name = "AGX Sat Dependency", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(1.0),
  setter = function(value, ctx)
    ctx.tonemappingFx:setShaderConst("$agx_sat_dependency", value)
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

    ctx["fogNeedsUpdating"] = true
  end
}
miscOptions["shadowLogWeight"] = {
  name = "Log Weight", type = "float", min = 0.0, max = 100.0, value = im.FloatPtr(66.8),
  setter = function(value, ctx)
    ctx.sky.logWeight = value * 0.0003 + 0.97
    ctx.sky:postApply()

    ctx["fogNeedsUpdating"] = true
  end
}
miscOptions["terrainDetail"] = {
  name = "Terrain Detail", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.4),
  setter = function(value, ctx)
    TorqueScriptLua.setVar("$pref::Terrain::lodScale", value)
  end
}
miscOptions["lodDetail"] = { -- 1.5 default
  name = "LOD Detail", type = "float", min = 0.0, max = 50.0, value = im.FloatPtr(6.8),
  setter = function(value, ctx)
    TorqueScriptLua.setVar("$pref::TS::detailAdjust", value)
  end
}
miscOptions["foliageDensity"] = {
  name = "Foliage Density", type = "float", min = 0.0, max = 10.0, value = im.FloatPtr(1.881),
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
  name = "Fog Amount", type = "float", min = 0.0, max = 30.0, value = im.FloatPtr(0.0),
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
environmentOptions["cloudCover1"] = {
  name = "Cloud Cover 1", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.1),
  setter = function (value, ctx)
    if ctx.clouds[1] ~= nil then
      ctx.clouds[1].coverage = value
    end
  end
}
environmentOptions["cloudCover2"] = {
  name = "Cloud Cover 2", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.2),
  setter = function (value, ctx)
    if ctx.clouds[2] ~= nil then
      ctx.clouds[2].coverage = value
    end
  end
}
environmentOptions["skyColorAmt"] = {
  name = "Sky Color Amount", type = "float", min = 0.0, max = 10.0, value = im.FloatPtr(1.75),
  setter = function (value, ctx)
    if not ctx.options.skyboxOptions.enable.value[0] then
      ctx.sky.colorizeAmount = value
      ctx.sky:postApply()
    end
  end
}
environmentOptions["skyColor"] = {
  name = "Sky Color", type = "color", value = im.ArrayFloat(4),
  setter = function (value, ctx)
    if not ctx.options.skyboxOptions.enable.value[0] then
      ctx.sky.colorize = Point4F(value[0], value[1], value[2], ctx.sky.colorize.w)
    end
  end
}
environmentOptions["oceanFullReflection"] = {
  name = "Full Ocean Reflection", type = "bool", value = im.BoolPtr(false),
  setter = function (value, ctx)
    if ctx["ocean"] then
      ctx["ocean"].fullReflect = value
    end
  end
}
environmentOptions["oceanReflectivity"] = {
  name = "Ocean Reflectivity", type = "float", min = 0.0, max = 1.0, value = im.FloatPtr(0.3),
  setter = function (value, ctx)
    if ctx["ocean"] then
      ctx["ocean"].reflectivity = value
    end
  end
}
environmentOptions["oceanColor"] = {
  name = "Ocean Color", type = "color", value = im.ArrayFloat(4),
  setter = function (value, ctx)
    if ctx["ocean"] then
      ctx["ocean"].baseColor = ColorI(value[0]*255, value[1]*255, value[2]*255, value[3]*255)
    end
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
skyboxOptions["skyColor"] = {
  name = "Sky Color", type = "color", value = im.ArrayFloat(4),
  setter = function (value, ctx)
    if ctx.options.skyboxOptions.enable.value[0] then
      ctx.sky.colorize = Point4F(value[0], value[1], value[2], ctx.sky.colorize.w)
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
setImArray(environmentOptions["skyColor"].value, 0.216, 0.349, 0.604, 1.0)
setImArray(environmentOptions["oceanColor"].value, 0.992, 0.996, 0.996, 1.0)
setImArray(skyboxOptions["skyColor"].value, 0.5, 0.5, 0.5, 1.0)

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
local activeProfile = "Photorealism2"
local newProfileName = im.ArrayChar(64)
local profileIndex = im.IntPtr(-1)

local isTablesRefreshed = false

local screenShotSuperSamplingPtr = im.IntPtr(1)
local globalEnablePtr = im.BoolPtr(true)

local function refreshTable(table)
  for k,v in pairs(table) do
    if k ~= "header" then
      if v.type == "color" then v.setter(v.value, ctx)
      else v.setter(v.value[0], ctx) end
    end
  end
end

local function revertTable(table, refreshTable)
  for k,v in pairs(table) do
    if k ~= "header" then
      if v.type == "color" then
        setImArray(v.value, v.defaultValue[0], v.defaultValue[1], v.defaultValue[2], v.defaultValue[3])
      else
        v.value[0] = v.defaultValue
      end

      if refreshTable then
        v.setter(v.defaultValue, ctx)
      end
    end
  end
end

local function refreshOptionsAll()
  for k,v in pairs(options) do
    refreshTable(v)
  end
end

local function revertOptionsAll(refreshTables)
  for k,v in pairs(options) do
    revertTable(v, refreshTables)
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

  revertOptionsAll(false)

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

local function loadProfileAndUpdateUI(profileName, refreshTables)
  loadProfile(profileName, refreshTables)
  ffi.copy(newProfileName, profileName)
  for i, profile in ipairs(profiles) do
    if profile == profileName then
      profileIndex[0] = i
      break
    end
  end
end

local function toggleTonemapping(useGameTonemapping)
  scenetree.findObject("PostEffectCombinePassObject").enabled = useGameTonemapping and 1.0 or 0.0
  local tonemappingFx = scenetree.findObject("CustomTonemapPostFx")
  if tonemappingFx then
    if useGameTonemapping then tonemappingFx:disable() else tonemappingFx:enable() end
  end
end

local function toggleAllEffects(shouldEnable)
  if shouldEnable then
    loadProfile(activeProfile, true)
  else
    revertOptionsAll(true)
  end

  toggleTonemapping(not shouldEnable)

  -- specific values for differences between the mods default (to make things look "better") and game's default
  skyboxOptions["enable"].setter(shouldEnable and skyboxOptions["enable"].value[0] or false, ctx)
  environmentOptions["light"].setter(shouldEnable and environmentOptions["light"].value[0] or 1.0, ctx)
  ctx["sky"].texSize = shouldEnable and 4096 or 1024
  ctx["sky"].exposure = shouldEnable and 2.0 or 1.0
  local time = core_environment.getTimeOfDay()
  time.time = shouldEnable and environmentOptions["time"].value[0]/100.0 or 0.92586
  time.azimuthOverride = shouldEnable and environmentOptions["azimuth"].value[0]/180.0*math.pi or 0.0
  core_environment.setTimeOfDay(time)
end

local function loadSettings()
  if not FS:fileExists("settings/gfxSuite.json") then
    log('I', '', "GfxSuite settings file not found!")
    loadProfileAndUpdateUI(activeProfile, false)
    return
  end

  local data = jsonReadFile("settings/gfxSuite.json")
  if not data then
    log('I', '', "GfxSuite settings file is empty!")
    loadProfileAndUpdateUI(activeProfile, false)
    return
  end

  if data["activeProfile"] then
    activeProfile = data["activeProfile"]
    loadProfileAndUpdateUI(activeProfile, false)
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

local function placeObject(name, mesh, pos, rot)
  pos = vec3(pos)
  rot = quat(rot):toTorqueQuat()

  local proc = createObject('ProceduralMesh')
  if proc == nil then return nil end
  proc:registerObject(name)
  proc.canSave = false
  scenetree.MissionGroup:add(proc.obj)
  proc:createMesh({{mesh}})
  proc:setPosition(pos)
  proc:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)
  proc.scale = vec3(1, 1, 1)

  be:reloadCollision()

  return proc
end

local function onExtensionLoaded()
  listProfiles()
  loadSettings()

  if configVersion ~= version then
    saveSettings()
    local result = messageBox("GfxSuite", "New version of GFX Suite installed. It is recommended to clear the '%localappdata%/BeamNG.drive/latest/temp/shaders' folder in order to recompile the shaders and start the game again. If it's your first time installing this mod you can ignore this message.\n\nDo you want to open the folder?", 4, 2)
    if result == 1 then
      Engine.Platform.exploreFolder('/temp/shaders')
    end
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

  -- local skybox = scenetree.findObject("MySky")
  -- if not skybox then
  --   skybox = worldEditorCppApi.createObject("SkyBox")
  --   skybox:setName("MySky")
  --   scenetree.MissionGroup:add(skybox.obj)
  --   skybox:registerObject("MySky")
  -- end

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

  -- skybox:setField("material", 0, "MySkyMat")
  -- skybox:postApply()

  skyboxManager.setSunskyOptions(true)

  log('I', '', "Skybox created/updated")
end

skyboxManager.removeSky = function()
  -- local skybox = scenetree.findObject("MySky")
  -- if skybox then
  --   skybox:delete()
  -- end

  skyboxManager.setSunskyOptions(false)

  local cubemap = scenetree.findObject("MyCubemap")
  -- if cubemap then
  --   cubemap:delete()
  -- end

  local skyMat = scenetree.findObject("MySkyMat")
  if skyMat then
    skyMat:delete()
  end

  log('I', '', "Skybox removed")
end

skyboxManager.setSunskyOptions = function(useCustomSkybox)
  ctx.sky:setField("nightCubemap", 0, useCustomSkybox and "MyCubemap" or "NightCubemap")
  local skyColor = useCustomSkybox and skyboxOptions["skyColor"].value or environmentOptions["skyColor"].value;
  ctx.sky.colorizeAmount = useCustomSkybox and 1.0 or environmentOptions["skyColorAmt"].value[0]
  ctx.sky.colorize = Point4F(skyColor[0], skyColor[1], skyColor[2], useCustomSkybox and 0.0 or 1.0)
  ctx.sky:postApply()
end

local function renderTableEntry(tableEntry)
  if tableEntry.type == "int" then
    if im.SliderInt(tableEntry.name, tableEntry.value, tableEntry.min, tableEntry.max) then
      tableEntry.setter(tableEntry.value[0], ctx)
    end
  elseif tableEntry.type == "float" then
    if im.SliderFloat(tableEntry.name, tableEntry.value, tableEntry.min, tableEntry.max) then
      tableEntry.setter(tableEntry.value[0], ctx)
    end
  elseif tableEntry.type == "bool" then
    if im.Checkbox(tableEntry.name, tableEntry.value) then
      tableEntry.setter(tableEntry.value[0], ctx)
    end
  elseif tableEntry.type == "color" then
    if im.ColorEdit4(tableEntry.name, tableEntry.value) then
      tableEntry.setter(tableEntry.value, ctx)
    end
  end
end

local function renderTable(table, inTreeNode)
  if not inTreeNode or im.TreeNodeEx1(table.header, im.TreeNodeFlags_FramePadding + im.TreeNodeFlags_DefaultOpen) then
    for k,v in pairs(table) do
      if not v.hidden then
        renderTableEntry(v)
      end
    end
    if inTreeNode then im.TreePop() end
  end
end

local function afterMissionRefresh()
  
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
  ctx.options = options

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

  toggleTonemapping(false)

  scenetree.findObject("FXAA_PostEffect"):disable()

  ctx["fogNeedsUpdating"] = true

  -- events:addEvent( 3, afterMissionRefresh)
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
        if skyboxOptions["enable"].value[0] then
          skyboxManager:createSky()
        end
      end
    end
    im.EndCombo()
  end

  if im.ColorEdit4(skyboxOptions["skyColor"].name, skyboxOptions["skyColor"].value) then
    skyboxOptions["skyColor"].setter(skyboxOptions["skyColor"].value, ctx)
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
      if imButton("Explore Folder") then
        if not FS:fileExists('/screenshots/GFXSuite/') then
          FS:directoryCreate('/screenshots/GFXSuite/', true)
        end
         Engine.Platform.exploreFolder('/screenshots/GFXSuite/')
      end
      im.EndTabItem()
    end

    if im.BeginTabItem("Skybox") then
      renderSkyboxOptions()
      if imButton("Open Skybox Converter (Experimental)", 40) then
        skyboxCreator.openUI(true)
      end
      im.EndTabItem()
    end

    if im.BeginTabItem("Profiles") then

      if im.ListBox1("Profiles", profileIndex, im.ArrayCharPtrByTbl(profiles), #profiles, 6) then
        if profileIndex[0] ~= -1 then
          loadProfile(profiles[profileIndex[0] + 1], true)
          ctx["fogNeedsUpdating"] = true
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

      if im.Checkbox("Enable all effects", globalEnablePtr) then
        toggleAllEffects(globalEnablePtr[0])
        log('I', '', "All effects are now " .. (globalEnablePtr[0] and "enabled" or "disabled"))
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

  imStyle.pushImStyle()

  im.SetNextWindowSizeConstraints(im.ImVec2(500, 800), im.ImVec2(500, 800))
  if im.Begin("GFX Suite v" .. version, showUI, im.WindowFlags_AlwaysAutoResize+im.WindowFlags_NoResize) then
    drawWindowContent()
    im.End()
  end

  skyboxCreator:onUpdate()

  imStyle.imPopStyle()
end

local function toggleWindow()
  showUI[0] = not showUI[0]
  log('I', '', "GFX Suite is now " .. (showUI[0] and "visible" or "hidden"))
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
    return
  end

  if ctx["contactShadowsFx"] == nil then
    ctx["contactShadowsFx"] = scenetree.findObject("ContactShadowsPostFx")
    return
  end

  if ctx["adaptiveSharpenPostFx"] == nil then
    ctx["adaptiveSharpenPostFx"] = scenetree.findObject("AdaptiveSharpenPostFx")
    ctx["adaptiveSharpenPostFx1"] = scenetree.findObject("AdaptiveSharpenPostFx1")
    return
  end

  if ctx["sky"] == nil then
    ctx["sky"] = scenetree.findObject("sunsky")
    return
  end

  if ctx["clouds"] == nil then
    ctx["clouds"] = {}
    for _, objName in ipairs(scenetree.findClassObjects("CloudLayer")) do
      local cloud = scenetree.findObject(objName)
      if cloud then
        table.insert(ctx["clouds"], cloud)
      end
    end
  end

  if ctx["ocean"] == nil then
    for _, objName in ipairs(scenetree.findClassObjects("WaterPlane")) do
      if string.find(objName, "Ocean") then
        local ocean = scenetree.findObject(objName)
        if ocean then
          ctx["ocean"] = ocean
          break
        end
      end
    end
  end

  if not isTablesRefreshed then
    refreshOptionsAll()

    -- those need to be applied afterwards too for some reason
    environmentOptions["time"].setter(environmentOptions["time"].value[0], ctx)
    environmentOptions["azimuth"].setter(environmentOptions["azimuth"].value[0], ctx)

    log('I', '', "Setting tables refreshed")
    isTablesRefreshed = true
  end

  if ctx["fogNeedsUpdating"] then
    scenetree.theLevelInfo:postApply()
    skyboxManager.setSunskyOptions(skyboxOptions["enable"].value[0])
    ctx["fogNeedsUpdating"] = false
  end

  imRender()

  -- print(getPlayerVehicle(0):getPosition())
end

local function onCameraToggled(parms)
  if parms.cameraType == "FreeCam" then
    environmentOptions["fov"].setter(environmentOptions["fov"].value[0], ctx)    
  end
end

local function onExit()
  saveSettings()
end

-- local function onTeleportedFromBigmap()
  
--   print("Teleported from bigmap")
-- end

local function onDeactivateBigMapCallback()
  refreshOptionsAll()
  skyboxManager.setSunskyOptions(skyboxOptions["enable"].value[0])
end

M.onExtensionLoaded = onExtensionLoaded
M.onClientPostStartMission = onClientPostStartMission
M.onDeactivateBigMapCallback = onDeactivateBigMapCallback
M.onUpdate = onUpdate
M.onExit = onExit
M.toggleWindow = toggleWindow
M.onCameraToggled = onCameraToggled
return M