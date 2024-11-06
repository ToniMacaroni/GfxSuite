local M = {}
local im = ui_imgui

local showUI = im.BoolPtr(false)
local urlText = im.ArrayChar(256)
local skyIndex = im.IntPtr(-1)

local callbackFunc = nil
local loose_skies = {}

local function rotate90CounterClockwise(img)
    local width = img:getWidth()
    local height = img:getHeight()

    local rotated_img = GBitmap()
    rotated_img:init(height, width)

    local temp_col = ColorI(0, 0, 0, 255)

    for y = 1, height do
        for x = 1, width do
            img:getColor(x, y, temp_col)
            rotated_img:setColor(height - y + 1, x, temp_col)
        end
    end

    return rotated_img
end

local function rotate180(img)
    local width = img:getWidth()
    local height = img:getHeight()

    local rotated_img = GBitmap()
    rotated_img:init(width, height)

    local temp_col = ColorI(0, 0, 0, 255)

    for y = 1, height do
        for x = 1, width do
            img:getColor(x, y, temp_col)
            rotated_img:setColor(width - x + 1, height - y + 1, temp_col)
        end
    end

    return rotated_img
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

local function getSubImage(img, x_start, y_start, face_size, face_size)
    local sub_image = GBitmap()
    sub_image:init(face_size, face_size)

    local temp_col = ColorI(0, 0, 0, 255)

    for y = 1, face_size do
        for x = 1, face_size do
            img:getColor(x_start + x - 1, y_start + y - 1, temp_col)
            sub_image:setColor(x, y, temp_col)
        end
    end

    return sub_image
end

local function generate_mapping_data(image_width)
    local out_tex_width = image_width
    local out_tex_height = math.floor(image_width * 3 / 4)
    local face_edge_size = out_tex_width / 4

    local out_mapping = {}
    for i = 1, out_tex_height do
        out_mapping[i] = {}
        for j = 1, out_tex_width do
            out_mapping[i][j] = { 0, 0 }
        end
    end

    local xyz = {}
    local vals = {}

    local start, _end = 1, 1
    local pix_column_range_1 = {}
    for i = 0, face_edge_size * 3 - 1 do
        pix_column_range_1[i] = i
    end
    local pix_column_range_2 = {}
    for i = face_edge_size, face_edge_size * 2 - 1 do
        pix_column_range_2[i - face_edge_size] = i
    end

    for col_idx = 1, out_tex_width do
        local face = math.floor((col_idx - 1) / face_edge_size)
        local col_pix_range = (face == 1) and pix_column_range_1 or pix_column_range_2

        for _, col_pix in ipairs(col_pix_range) do
            vals[start] = { col_pix, col_idx - 1, face }
            start = start + 1
        end
    end

    local col_pix_range, col_idx, face = {}, {}, {}
    for i = 1, #vals do
        col_pix_range[i], col_idx[i], face[i] = vals[i][1], vals[i][2], vals[i][3]
    end

    for i = 1, #col_pix_range do
        if col_pix_range[i] < face_edge_size then
            face[i] = 4 -- top
        elseif col_pix_range[i] >= 2 * face_edge_size then
            face[i] = 5 -- bottom
        end
    end

    local a, b = {}, {}
    for i = 1, #col_idx do
        a[i] = 2.0 * col_idx[i] / face_edge_size
        b[i] = 2.0 * col_pix_range[i] / face_edge_size
    end

    local one_arr = {}
    for i = 1, #a do
        one_arr[i] = 1.0
    end

    for k = 0, 5 do
        for i = 1, #face do
            if face[i] == k then
                local vals_to_use = {}
                if k == 0 then
                    vals_to_use = { one_arr[i], a[i] - 1.0, 3.0 - b[i] }  -- X-positive face mapping
                elseif k == 1 then
                    vals_to_use = { 3.0 - a[i], one_arr[i], 3.0 - b[i] }  -- Y-positive face mapping
                elseif k == 2 then
                    vals_to_use = { -one_arr[i], 5.0 - a[i], 3.0 - b[i] } -- X-negative face mapping
                elseif k == 3 then
                    vals_to_use = { a[i] - 7.0, -one_arr[i], 3.0 - b[i] } -- Y-negative face mapping
                elseif k == 4 then
                    vals_to_use = { 3.0 - a[i], b[i] - 1.0, one_arr[i] }  -- Z-positive face mapping
                elseif k == 5 then
                    vals_to_use = { 3.0 - a[i], 5.0 - b[i], -one_arr[i] } -- bottom face mapping
                end
                xyz[i] = vals_to_use
            end
        end
    end

    local x, y, z = {}, {}, {}
    for i = 1, #xyz do
        x[i], y[i], z[i] = xyz[i][1], xyz[i][2], xyz[i][3]
    end

    local phi, r_proj_xy, theta = {}, {}, {}
    for i = 1, #x do
        phi[i] = math.atan2(y[i], x[i])
        r_proj_xy[i] = math.sqrt(x[i] * x[i] + y[i] * y[i])
        theta[i] = math.pi / 2 - math.atan2(z[i], r_proj_xy[i])
    end

    local uf, vf = {}, {}
    for i = 1, #phi do
        uf[i] = 4.0 * face_edge_size * phi[i] / (2.0 * math.pi) % out_tex_width
        vf[i] = 2.0 * face_edge_size * theta[i] / math.pi
    end

    for i = 1, #col_pix_range do
        out_mapping[col_pix_range[i] + 1][col_idx[i]] = { uf[i], vf[i] }
    end

    local map_x, map_y = {}, {}
    for i = 1, out_tex_height do
        map_x[i] = {}
        map_y[i] = {}
        for j = 1, out_tex_width do
            map_x[i][j] = out_mapping[i][j][1]
            map_y[i][j] = out_mapping[i][j][2]
        end
    end

    return map_x, map_y
end

local function remap_img(in_img, map_x, map_y)
    -- log('I' , '', "Sizes x:" .. #map_x .. " y:" .. #map_y)
    local out_tex_height = in_img:getWidth() / 4 * 3
    local out_tex_width = in_img:getWidth()

    local output_image = GBitmap()
    output_image:init(out_tex_width, out_tex_height)
    output_image:fillColor(ColorI(255, 255, 255, 255))

    local temp_col = ColorI(0, 0, 0, 255)

    for i = 1, out_tex_height do
        for j = 1, out_tex_width do
            local uf = map_x[i][j]
            local vf = map_y[i][j]

            local x_src = math.floor(uf + 1)
            local y_src = math.floor(vf + 1)

            if x_src >= 1 and x_src <= out_tex_width and y_src >= 1 and y_src <= out_tex_height then
                in_img:getColor(x_src - 1, y_src - 1, temp_col)
                output_image:setColor(j - 1, i - 1, temp_col)
            end
        end
    end

    return output_image
end

local function extract_cubemap_faces_from_cross(cubemap_texture, face_size)
    local cubemap_faces = {}

    local face_positions = {
        pz = { face_size, 0, 0 },
        px = { face_size, face_size, 270 },
        nz = { face_size, face_size * 2, 180 },
        nx = { face_size, face_size * 3, 90 },
        py = { 0, face_size, 270 },
        ny = { face_size * 2, face_size, 0 }
    }

    for face, params in pairs(face_positions) do
        local y_start = params[1]
        local x_start = params[2]
        local rot = params[3]

        local face_image = getSubImage(cubemap_texture, x_start, y_start, face_size, face_size)
        face_image = rotateImage(face_image, rot)
        cubemap_faces[face] = face_image
    end

    return cubemap_faces
end

local function createSkybox(filename)
    local name = filename:sub(1, -5)
    log('I', '', "Creating skybox " .. name)

    local hp = hptimer()

    local bm = GBitmap()
    bm:loadFile("settings/gfxSuite/skies/" .. filename)
    local map_x_32, map_y_32 = generate_mapping_data(bm:getWidth())
    local out_image = remap_img(bm, map_x_32, map_y_32)
    out_image:saveFile("settings/gfxSuite/skies/" .. name .. "/skybox.png")
    local faces = extract_cubemap_faces_from_cross(out_image, bm:getWidth() / 4)
    for face, img in pairs(faces) do
        img:saveFile("settings/gfxSuite/skies/" .. name .. "/" .. face .. ".png")
        log('I', '', "Saved face " .. face .. " to art/skybox_" .. face .. ".png")
    end

    local t = hp:stopAndReset()
    log('I', '', "Skybox created in " .. string.format('%0.3f', t) .. "s")

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

local function listLooseSkies()
    loose_skies = {}
    local files = FS:findFiles("settings/gfxSuite/skies", "*.*", -1, true, false)
    for _, filepath in ipairs(files) do
        local dir, filename, ext = path.split(filepath)
        log('I', '', 'Found ' .. filename .. ' with ext ' .. ext)
        if ext == "jpg" or ext == "png" then
            table.insert(loose_skies, filename)
        end
    end
end

local function onRenderUI()
    im.SetNextWindowSizeConstraints(im.ImVec2(400, 600), im.ImVec2(400, 600))
    if im.Begin("Skybox Creator", showUI) then
        im.ListBox1("Loose Skies", skyIndex, im.ArrayCharPtrByTbl(loose_skies), #loose_skies, 6)
        im.InputText("URL", urlText)
        if im.Button("Create") then
            createSkybox(loose_skies[skyIndex[0] + 1])
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
