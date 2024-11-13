local M = {}
local im = ui_imgui

local showUI = im.BoolPtr(false)
local urlText = im.ArrayChar(256)
local skyIndex = im.IntPtr(-1)
local exposure = im.FloatPtr(1.0)
local removeSkyAfterFinish = im.BoolPtr(false)

local callbackFunc = nil
local looseSkies = {}

local function listLooseSkies()
    looseSkies = {}
    local files = FS:findFiles("settings/gfxSuite/skies", "*.*", 0, true, false)
    for _, filepath in ipairs(files) do
        local dir, filename, ext = path.split(filepath)
        if ext == "jpg" or ext == "png" then
            table.insert(looseSkies, filename)
        end
    end
end

local function rotate90CounterClockwise(img)
    local width = img:getWidth()
    local height = img:getHeight()

    local rotatedImage = GBitmap()
    rotatedImage:init(height, width)

    local tempCol = ColorI(0, 0, 0, 255)

    for y = 1, height do
        for x = 1, width do
            img:getColor(x - 1, y - 1, tempCol)
            rotatedImage:setColor(height - y, x, tempCol)
        end
    end

    return rotatedImage
end

local function rotate180(img)
    local width = img:getWidth()
    local height = img:getHeight()

    local rotatedImage = GBitmap()
    rotatedImage:init(width, height)

    local tempCol = ColorI(0, 0, 0, 255)

    for y = 1, height do
        for x = 1, width do
            img:getColor(x - 1, y - 1, tempCol)
            rotatedImage:setColor(width - x, height - y, tempCol)
        end
    end

    return rotatedImage
end

local function rotate270CounterClockwise(img)
    return rotate90CounterClockwise(rotate90CounterClockwise(rotate90CounterClockwise(img)))
end

local function rotateImage(img, angle)
    if angle == 90 then
        return rotate90CounterClockwise(img)
    elseif angle == 180 then
        return rotate180(img)
    elseif angle == 270 then
        return rotate270CounterClockwise(img)
    else
        return img
    end
end

local function getSubImage(img, xStart, yStart, faceSize)
    local subImage = GBitmap()
    subImage:init(faceSize, faceSize)

    local tempCol = ColorI(0, 0, 0, 255)

    for y = 1, faceSize do
        for x = 1, faceSize do
            img:getColor(xStart + x - 1, yStart + y - 1, tempCol)
            subImage:setColor(x - 1, y - 1, tempCol)
        end
    end

    return subImage
end

local function growBorder(img)
    local width = img:getWidth()
    local height = img:getHeight()

    local tempCol = ColorI(0, 0, 0, 255)
    -- Fill the outer border with the inner edge color
    -- Top and bottom rows
    for x = 0, width - 1 do
        -- top
        img:getColor(x, 1, tempCol)
        img:setColor(x, 0, tempCol)
        -- bottom
        img:getColor(x, height - 2, tempCol)
        img:setColor(x, height - 1, tempCol)
    end

    -- Left and right columns
    for y = 0, height - 1 do
        -- left
        img:getColor(1, y, tempCol)
        img:setColor(0, y, tempCol)
        -- right
        img:getColor(width - 2, y, tempCol)
        img:setColor(width - 1, y, tempCol)
    end
end

local function generateMappingData(imageWidth)
    local outTexWidth = imageWidth
    local outTexHeight = math.floor(imageWidth * 3 / 4)
    local faceEdgeSize = outTexWidth / 4

    local outMapping = {}
    for i = 1, outTexHeight do
        outMapping[i] = {}
        for j = 1, outTexWidth do
            outMapping[i][j] = { 0, 0 }
        end
    end

    local xyz = {}
    local vals = {}

    local start, _end = 1, 1
    local pixColumnRange1 = {}
    for i = 0, faceEdgeSize * 3 - 1 do
        pixColumnRange1[i] = i
    end
    local pixColumnRange2 = {}
    for i = faceEdgeSize, faceEdgeSize * 2 - 1 do
        pixColumnRange2[i - faceEdgeSize] = i
    end

    for colIdx = 1, outTexWidth do
        local face = math.floor((colIdx - 1) / faceEdgeSize)
        local colPixRange = (face == 1) and pixColumnRange1 or pixColumnRange2

        for _, colPix in ipairs(colPixRange) do
            vals[start] = { colPix, colIdx - 1, face }
            start = start + 1
        end
    end

    local colPixRange, colIdx, face = {}, {}, {}
    for i = 1, #vals do
        colPixRange[i], colIdx[i], face[i] = vals[i][1], vals[i][2], vals[i][3]
    end

    for i = 1, #colPixRange do
        if colPixRange[i] < faceEdgeSize then
            face[i] = 4 -- top
        elseif colPixRange[i] >= 2 * faceEdgeSize then
            face[i] = 5 -- bottom
        end
    end

    local a, b = {}, {}
    for i = 1, #colIdx do
        a[i] = 2.0 * colIdx[i] / faceEdgeSize
        b[i] = 2.0 * colPixRange[i] / faceEdgeSize
    end

    local oneArr = {}
    for i = 1, #a do
        oneArr[i] = 1.0
    end

    for k = 0, 5 do
        for i = 1, #face do
            if face[i] == k then
                local valsToUse = {}
                if k == 0 then
                    valsToUse = { oneArr[i], a[i] - 1.0, 3.0 - b[i] }  -- X-positive face mapping
                elseif k == 1 then
                    valsToUse = { 3.0 - a[i], oneArr[i], 3.0 - b[i] }  -- Y-positive face mapping
                elseif k == 2 then
                    valsToUse = { -oneArr[i], 5.0 - a[i], 3.0 - b[i] } -- X-negative face mapping
                elseif k == 3 then
                    valsToUse = { a[i] - 7.0, -oneArr[i], 3.0 - b[i] } -- Y-negative face mapping
                elseif k == 4 then
                    valsToUse = { 3.0 - a[i], b[i] - 1.0, oneArr[i] }  -- Z-positive face mapping
                elseif k == 5 then
                    valsToUse = { 3.0 - a[i], 5.0 - b[i], -oneArr[i] } -- bottom face mapping
                end
                xyz[i] = valsToUse
            end
        end
    end

    local x, y, z = {}, {}, {}
    for i = 1, #xyz do
        x[i], y[i], z[i] = xyz[i][1], xyz[i][2], xyz[i][3]
    end

    local phi, rProjXY, theta = {}, {}, {}
    for i = 1, #x do
        phi[i] = math.atan2(y[i], x[i])
        rProjXY[i] = math.sqrt(x[i] * x[i] + y[i] * y[i])
        theta[i] = math.pi / 2 - math.atan2(z[i], rProjXY[i])
    end

    local uf, vf = {}, {}
    for i = 1, #phi do
        uf[i] = 4.0 * faceEdgeSize * phi[i] / (2.0 * math.pi) % outTexWidth
        vf[i] = 2.0 * faceEdgeSize * theta[i] / math.pi
    end

    for i = 1, #colPixRange do
        outMapping[colPixRange[i] + 1][colIdx[i]] = { uf[i], vf[i] }
    end

    local mapX, mapY = {}, {}
    for i = 1, outTexHeight do
        mapX[i] = {}
        mapY[i] = {}
        for j = 1, outTexWidth do
            mapX[i][j] = outMapping[i][j][1]
            mapY[i][j] = outMapping[i][j][2]
        end
    end

    return mapX, mapY
end

local function modExposure(col, exposure)
    local r = clamp(col.r * exposure, 0, 255)
    local g = clamp(col.g * exposure, 0, 255)
    local b = clamp(col.b * exposure, 0, 255)
    return ColorI(r, g, b, col.a)
end

local function remapImage(inImg, mapX, mapY, exposureVal)
    -- log('I' , '', "Sizes x:" .. #map_x .. " y:" .. #map_y)
    local outTexHeight = inImg:getWidth() / 4 * 3
    local outTexWidth = inImg:getWidth()

    local outputImage = GBitmap()
    outputImage:init(outTexWidth, outTexHeight)
    outputImage:fillColor(ColorI(255, 255, 255, 255))

    local tempCol = ColorI(0, 0, 0, 255)

    for i = 1, outTexHeight do
        for j = 1, outTexWidth do
            local uf = mapX[i][j]
            local vf = mapY[i][j]

            local xSrc = math.floor(uf + 1)
            local ySrc = math.floor(vf + 1)

            if xSrc >= 1 and xSrc <= outTexWidth and ySrc >= 1 and ySrc <= outTexHeight then
                inImg:getColor(xSrc-1, ySrc-1, tempCol)
                outputImage:setColor(j-1, i-1, modExposure(tempCol, exposureVal))
            end
        end
    end

    return outputImage
end

local function extractCubemapFaces(cubemapTexture, faceSize)
    local cubemapFaces = {}

    local facePositions = {
        pz = { faceSize, 0, 0 },
        px = { faceSize, faceSize, 270 },
        nz = { faceSize, faceSize * 2, 180 },
        nx = { faceSize, faceSize * 3, 90 },
        py = { 0, faceSize, 270 },
        ny = { faceSize * 2, faceSize, 0 }
    }

    for face, params in pairs(facePositions) do
        local yStart = params[1]
        local xStart = params[2]
        local rot = params[3]

        local faceImage = getSubImage(cubemapTexture, xStart, yStart, faceSize)
        faceImage = rotateImage(faceImage, rot)
        -- if faceSize <= 512 then growBorder(faceImage) end
        growBorder(faceImage)
        cubemapFaces[face] = faceImage
    end

    return cubemapFaces
end

local function createSkybox(filename)
    local name = filename:sub(1, -5)
    log('I', 'SkyboxConverter', "Converting skybox " .. name)

    local hp = hptimer()

    local bm = GBitmap()
    bm:loadFile("settings/gfxSuite/skies/" .. filename)
    local mapX32, mapY32 = generateMappingData(bm:getWidth())
    log('I', 'SkyboxConverter', "Generated mapping data")
    local outImage = remapImage(bm, mapX32, mapY32, exposure[0])
    -- outImage:saveFile("settings/gfxSuite/skies/" .. name .. "/skybox.png")
    local faces = extractCubemapFaces(outImage, bm:getWidth() / 4)
    for face, img in pairs(faces) do
        img:saveFile("settings/gfxSuite/skies/" .. name .. "/" .. face .. ".png")
        log('I', 'SkyboxConverter', "Saved face " .. face .. " to art/skybox_" .. face .. ".png")
    end

    local t = hp:stopAndReset()
    log('I', 'SkyboxConverter', "Skybox created in " .. string.format('%0.3f', t) .. "s")

    messageBox("Skybox Converter", "Finished creating skybox. Don't forget to press 'Refresh Skyboxes' to see the new skybox!", 0, 2)

    if removeSkyAfterFinish[0] then
        FS:removeFile("settings/gfxSuite/skies/" .. filename)
        listLooseSkies()
    end

    -- local client, code, headers = https.request(url)
    -- if code ~= 200 then
    --     log('I', '', "Failed to download skybox")
    --     log('E', '', dumps(code) .. " " .. dumps(headers))
    --     return
    -- else
    --     log('I', '', "Downloaded skybox")
    -- end

    if callbackFunc then
        callbackFunc()
    end
end

local function onRenderUI()
    im.SetNextWindowSizeConstraints(im.ImVec2(400, 600), im.ImVec2(1000, 600))
    if im.Begin("Skybox Converter (Experimental)", showUI) then
        im.Text([[
The skybox converter allows you to convert a (equirectangular) skybox image into a cubemap to be usable in the game as a skybox.
One place to find good skyboxes is https://polyhaven.com/hdris
Once you have downloaded a skybox, place it in settings/gfxSuite/skies (click on 'Explore Folder') and select it from the list below.
        ]])
        im.Spacing()
        im.TextColored(im.ImVec4(1, 0, 0, 1), "I recommend only using skyboxes with a resolution of 4096x2048 or lower.")
        im.Spacing()

        im.Separator()

        im.ListBox1("Select Sky", skyIndex, im.ArrayCharPtrByTbl(looseSkies), #looseSkies, 6)
        -- im.InputText("URL", urlText)
        im.Checkbox("Remove sky afterwards", removeSkyAfterFinish)
        im.SliderFloat("Exposure", exposure, 0.1, 5.0)
        im.Spacing()
        if im.Button("Convert", im.ImVec2(im.GetContentRegionAvailWidth(), 50)) then
            local result = messageBox("Skybox Converter", "Converting big skyboxes can potentially take a very long time (up to a minute).\n\nDo you want to continue?", 4, 2)
            if result == 1 then
                createSkybox(looseSkies[skyIndex[0] + 1])
            end
        end
        if im.Button("Explore Folder", im.ImVec2(im.GetContentRegionAvailWidth(), 30)) then
            if not FS:fileExists('/screenshots/gfxSuite/skies') then
                FS:directoryCreate('/screenshots/gfxSuite/skies', true)
            end
            Engine.Platform.exploreFolder('/screenshots/gfxSuite/skies')
        end
        if im.Button("Refresh Skies", im.ImVec2(im.GetContentRegionAvailWidth(), 30)) then
            listLooseSkies()
        end
    end
end

local function onUpdate()
    if showUI[0] then
        onRenderUI()
    end
end

local function openUI(shouldOpen)
    listLooseSkies()
    showUI[0] = shouldOpen
end

local function registerCallback(callback)
    callbackFunc = callback
end

M.onUpdate = onUpdate
M.openUI = openUI
M.registerCallback = registerCallback
return M
