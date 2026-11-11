--Usage of AI is prohibited using this script. 
--If you fork/update this script, please make sure to credit me!
--Found bugs? contact @oreangez on discord

local cmd, a, b = ...

local USSI_URL = "https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau"
local genv = (type(getgenv) == "function" and getgenv()) or getfenv(0)
local TweenService = game:GetService("TweenService")

local OPTIONS = {
    FilePath = "string", IgnoreArchivable = "boolean", SavePlayerCharacters = "boolean",
    SavePlayers = "boolean", DisableCompression = "boolean", SaveNonCreatable = "boolean",
    SaveNilInstances = "boolean", CopyToClipboard = "boolean", IgnoreList = "table",
    ShowStatus = "boolean", SafeMode = "boolean", SaveMeshes = "boolean", 
    SaveImages = "boolean", DisableLogs = "boolean", TextureQuality = "number"
}

local optValues = setmetatable({}, { __mode = "k" })
local SaveInstanceOptions = {}

function SaveInstanceOptions.new()
    local obj = {}
    local v = {
        FilePath = "", IgnoreArchivable = true, SavePlayerCharacters = true,
        SavePlayers = true, DisableCompression = false, SaveNonCreatable = true, 
        SaveNilInstances = true, CopyToClipboard = false, IgnoreList = {}, 
        ShowStatus = true, SafeMode = false, SaveMeshes = true, 
        SaveImages = true, DisableLogs = false, TextureQuality = 1
    }
    optValues[obj] = v
    setmetatable(obj, {
        __tostring = function() return "SaveInstanceOptions" end,
        __index = function(_, k)
            if OPTIONS[k] == nil then error(tostring(k) .. " is not a valid member", 2) end
            if k == "IgnoreList" then return table.freeze(table.clone(v.IgnoreList)) end
            return v[k]
        end,
        __newindex = function(_, k, val)
            local want = OPTIONS[k]
            if want == nil then error(tostring(k) .. " is not a valid member", 2) end
            if type(val) ~= want then error(string.format("%s expected, got %s", want, typeof(val)), 2) end
            if k == "IgnoreList" then
                local list = {}
                for _, item in val do
                    if typeof(item) ~= "Instance" then error("IgnoreList must only contain Instances", 2) end
                    table.insert(list, item)
                end
                val = list
            end
            v[k] = val
        end
    })
    return obj
end

local ALIASES = {
    filepath="FilePath", filename="FilePath", ignorearchivable="IgnoreArchivable",
    saveplayercharacters="SavePlayerCharacters", savecharacters="SavePlayerCharacters", saveplayers="SavePlayers",
    isolateplayers="SavePlayers", disablecompression="DisableCompression", savenoncreatable="SaveNonCreatable", 
    savenotcreatable="SaveNonCreatable", savenilinstances="SaveNilInstances", nilinstances="SaveNilInstances", 
    copytoclipboard="CopyToClipboard", clipboard="CopyToClipboard", ignorelist="IgnoreList", 
    instancesblacklist="IgnoreList", showstatus="ShowStatus", showprogress="ShowStatus", safemode="SafeMode", 
    savemeshes="SaveMeshes", meshes="SaveMeshes", exportmeshes="SaveMeshes", saveimages="SaveImages", 
    images="SaveImages", exportimages="SaveImages", disablelogs="DisableLogs", silent="DisableLogs", 
    nologs="DisableLogs", disableconsole="DisableLogs", texturequality="TextureQuality", quality="TextureQuality"
}

local function fromTable(src)
    local obj = SaveInstanceOptions.new()
    for k, val in src do
        if type(k) == "string" then
            local low = string.lower(k)
            local name = ALIASES[low]
            if name and type(val) == OPTIONS[name] then
                if name == "IgnoreList" then
                    local list = {}
                    for _, item in val do if typeof(item) == "Instance" then table.insert(list, item) end end
                    val = list
                end
                obj[name] = val
            end
        end
    end
    return obj
end

local function isInstArray(v)
    if type(v) ~= "table" or #v == 0 then return false end
    for _, item in v do if typeof(item) ~= "Instance" then return false end end
    return true
end

local function mkParents(path)
    local parent = ""
    for seg in string.gmatch(path, "([^/\\]+)[/\\]") do
        parent = parent == "" and seg or (parent .. "/" .. seg)
        if not isfolder(parent) then makefolder(parent) end
    end
end

local function mkFolder(f)
    if f and f ~= "" then mkParents(f .. "/_") end
end

local function sanitize(name)
    if not name or name == "" then return "unknown" end
    local clean = string.gsub(name, "[^%w%-_ ]", "")
    clean = string.match(clean, "^%s*(.-)%s*$")
    if clean == "" then return "unknown" end
    return clean
end

local function getGameName(placeId)
    local ok, name = pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(placeId, Enum.InfoType.Asset)
        return info.Name
    end)
    if ok and name and name ~= "" and name ~= "Place" then
        return name
    end
    local http = game:GetService("HttpService")
    local url = "https://games.roblox.com/v1/games/multiget-place-details?placeIds=" .. tostring(placeId)
    local ok2, response = pcall(function() return http:GetAsync(url) end)
    if ok2 and response then
        local ok3, data = pcall(function() return http:JSONDecode(response) end)
        if ok3 and data and data[1] and data[1].name then
            return data[1].name
        end
    end
    return nil
end

local function genPath(root, isModel)
    local baseName = ""
    if isModel and root and root.Name then
        baseName = root.Name
    else
        local gameName = getGameName(game.PlaceId)
        baseName = gameName or game.Name
    end
    baseName = sanitize(baseName)
    
    if baseName == "unknown" or baseName == "Place" or baseName == "Game" then
        baseName = isModel and "Model" or "Game"
    end
    
    local folder = "oreange decomp"
    if not isfolder(folder) then makefolder(folder) end
    
    local ext = isModel and ".rbxm" or ".rbxl"
    local p = folder .. "/" .. baseName .. ext
    local n = 0
    while isfile(p) do n += 1; p = folder .. "/" .. baseName .. " (" .. n .. ")" .. ext end
    return p
end

local function targetPath(v, root, isPlace)
    local p = v.FilePath
    if p == "" then
        if v.CopyToClipboard then return nil end
        return genPath(root, not isPlace)
    elseif not string.match(p, "%.[^/\\]+$") then
        return p .. (isPlace and ".rbxl" or ".rbxm")
    end
    return p
end

local function hasMethod(inst, name)
    local ok, m = pcall(function() return inst[name] end)
    return ok and type(m) == "function"
end

local function meshIdOf(inst, cls)
    local ok, id
    if cls == "MeshPart" then
        ok, id = pcall(function() return inst.MeshId end)
    elseif cls == "SpecialMesh" then
        ok, id = pcall(function() return inst.MeshType == Enum.MeshType.FileMesh and inst.MeshId or "" end)
    end
    if ok and type(id) == "string" and id ~= "" then return id end
end

local function meshName(id)
    local d = string.match(id, "[?&/]id=(%d+)") or string.match(id, "(%d+)%s*$")
    if d then return d .. ".mesh" end
    return (string.gsub(id, "[^%w%-_]", "_")) .. ".mesh"
end

local function encodeMesh(mesh)
    local faces = mesh:GetFaces()
    local vmap, ovs, ofs = {}, {}, {}
    for _, face in faces do
        local corners = mesh:GetFaceVertices(face)
        local uvs = select(2, pcall(mesh.GetFaceUVs, mesh, face)) or {}
        local nms = select(2, pcall(mesh.GetFaceNormals, mesh, face)) or {}
        local idxs = {}
        for i, vv in corners do
            local p = mesh:GetPosition(vv)
            local n = nms[i] and mesh:GetNormal(nms[i]) or Vector3.new()
            local t = uvs[i] and mesh:GetUV(uvs[i]) or Vector2.new()
            local key = string.format("%f_%f_%f_%f_%f_%f_%f_%f", p.X,p.Y,p.Z,n.X,n.Y,n.Z,t.X,t.Y)
            local idx = vmap[key]
            if not idx then
                idx = #ovs + 1
                vmap[key] = idx
                ovs[idx] = {p, n, t}
            end
            table.insert(idxs, idx)
        end
        if #idxs >= 3 then
            if #idxs == 3 then
                table.insert(ofs, idxs)
            else
                table.insert(ofs, {idxs[1], idxs[2], idxs[3]})
                table.insert(ofs, {idxs[1], idxs[3], idxs[4]})
            end
        end
    end
    local parts = {}
    local function s(x) parts[#parts+1] = x end
    local function u8(n) parts[#parts+1] = string.char(n) end
    local function u16(n) parts[#parts+1] = string.pack("<I2", n) end
    local function u32(n) parts[#parts+1] = string.pack("<I4", n) end
    local function f32(n) parts[#parts+1] = string.pack("<f", n) end
    s("version 2.00\n")
    u16(12) u8(36) u8(12)
    u32(#ovs) u32(#ofs)
    for _, v in ovs do
        f32(v[1].X) f32(v[1].Y) f32(v[1].Z)
        f32(v[2].X) f32(v[2].Y) f32(v[2].Z)
        f32(v[3].X) f32(v[3].Y)
        u8(127) u8(127) u8(0) u8(254)
    end
    for _, f in ofs do
        u32(f[1]-1) u32(f[2]-1) u32(f[3]-1)
    end
    return table.concat(parts)
end

local function loadMesh(svc, part, id, hasPart, hasCreate)
    if hasPart and part then
        local ok, m = pcall(function() return svc:CreateEditableMeshFromPartAsync(part, { FixedSize = true }) end)
        if ok and m then return m end
        ok, m = pcall(function() return svc:CreateEditableMeshFromPartAsync(part) end)
        if ok and m then return m end
    end
    if not hasCreate then return nil, "CreateEditableMeshAsync unavailable" end
    local sources = {}
    if Content and Content.fromUri then
        table.insert(sources, Content.fromUri(id))
        if Content.fromAssetId then
            local num = string.match(id, "(%d+)")
            if num then
                local okA, c = pcall(Content.fromAssetId, tonumber(num))
                if okA and c then table.insert(sources, c) end
            end
        end
    end
    table.insert(sources, id)
    local lastErr
    for _, source in sources do
        local ok, m = pcall(function() return svc:CreateEditableMeshAsync(source, { FixedSize = true }) end)
        if ok and m then return m end
        lastErr = tostring(m)
        ok, m = pcall(function() return svc:CreateEditableMeshAsync(source) end)
        if ok and m then return m end
        lastErr = tostring(m)
    end
    return nil, lastErr
end

local crcTable = {}
for n = 0, 255 do
    local c = n
    for _ = 1, 8 do
        if bit32.band(c, 1) == 1 then c = bit32.bxor(0xEDB88320, bit32.rshift(c, 1))
        else c = bit32.rshift(c, 1) end
    end
    crcTable[n] = c
end

local function crcAdd(crc, byte)
    return bit32.bxor(crcTable[bit32.band(bit32.bxor(crc, byte), 0xFF)], bit32.rshift(crc, 8))
end

local function adler(buf)
    local a, b = 1, 0
    local len = buffer.len(buf)
    local i = 0
    while i < len do
        local n = math.min(5552, len - i)
        for j = 0, n - 1 do
            a = a + buffer.readu8(buf, i + j)
            b = b + a
        end
        a = a % 65521
        b = b % 65521
        i = i + n
    end
    return b * 65536 + a
end

local function zlibStored(raw)
    local len = buffer.len(raw)
    local parts = { string.char(0x78, 0x01) }
    if len == 0 then
        parts[#parts+1] = string.char(1, 0, 0, 0xFF, 0xFF)
    else
        local pos = 0
        while pos < len do
            local cl = math.min(65535, len - pos)
            local bfinal = (pos + cl >= len) and 1 or 0
            local nlen = bit32.band(bit32.bnot(cl), 0xFFFF)
            parts[#parts+1] = string.char(bfinal,
                bit32.band(cl, 0xFF), bit32.band(bit32.rshift(cl, 8), 0xFF),
                bit32.band(nlen, 0xFF), bit32.band(bit32.rshift(nlen, 8), 0xFF))
            parts[#parts+1] = buffer.readstring(raw, pos, cl)
            pos = pos + cl
        end
    end
    parts[#parts+1] = string.pack(">I4", adler(raw))
    return table.concat(parts)
end

local function pngChunk(kind, data)
    local isStr = type(data) == "string"
    local dlen = isStr and #data or buffer.len(data)
    local out = { string.pack(">I4", dlen), kind }
    out[#out+1] = isStr and data or buffer.tostring(data)
    local crc = 0xFFFFFFFF
    for i = 1, #kind do crc = crcAdd(crc, string.byte(kind, i)) end
    if isStr then
        for i = 1, dlen do crc = crcAdd(crc, string.byte(data, i)) end
    else
        for i = 0, dlen - 1 do crc = crcAdd(crc, buffer.readu8(data, i)) end
    end
    crc = bit32.bxor(crc, 0xFFFFFFFF)
    out[#out+1] = string.pack(">I4", crc)
    return table.concat(out)
end

local function pngEncode(w, h, rgba)
    local rowBytes = w * 4
    local raw = buffer.create(h * (1 + rowBytes))
    for y = 0, h - 1 do
        buffer.writeu8(raw, y * (1 + rowBytes), 0)
        buffer.copy(raw, y * (1 + rowBytes) + 1, rgba, y * rowBytes, rowBytes)
    end
    local ihdr = string.pack(">I4I4BBBBB", w, h, 8, 6, 0, 0, 0)
    return table.concat({
        "\137PNG\r\n\26\n",
        pngChunk("IHDR", ihdr),
        pngChunk("IDAT", zlibStored(raw)),
        pngChunk("IEND", ""),
    })
end

local function scaleBuffer(rgba, w, h, quality)
    if quality >= 1 then return rgba, w, h end
    local nw, nh = math.floor(w * quality), math.floor(h * quality)
    if nw < 1 or nh < 1 then return rgba, w, h end
    local newBuf = buffer.create(nw * nh * 4)
    for y = 0, nh - 1 do
        for x = 0, nw - 1 do
            local srcX = math.floor(x / quality)
            local srcY = math.floor(y / quality)
            local srcIdx = (srcY * w + srcX) * 4
            local dstIdx = (y * nw + x) * 4
            buffer.writeu32(newBuf, dstIdx, buffer.readu32(rgba, srcIdx))
        end
    end
    return newBuf, nw, nh
end

local IMG_PROPS = {
    Decal = { "Texture" },
    Texture = { "Texture" },
    SurfaceAppearance = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap", "EmissiveMask" },
    Sky = { "SkyboxUp", "SkyboxDown", "SkyboxLeft", "SkyboxRight", "SkyboxFront", "SkyboxBack" },
    ParticleEmitter = { "Texture" },
    Beam = { "Texture" },
    Trail = { "Texture" },
    MeshPart = { "TextureID" },
}

local function readContent(inst, prop)
    local ok, v = pcall(function() return inst[prop] end)
    if not ok or v == nil then return nil end
    local s = tostring(v)
    if s == "" or s == "rbxasset://textures/face.png" then return nil end
    return s
end

local function imgName(url)
    local d = string.match(url, "[?&/]id=(%d+)") or string.match(url, "rbxassetid://(%d+)") or string.match(url, "(%d+)%s*$")
    return (d or (string.gsub(url, "[^%w%-_%.]", "_"))) .. ".png"
end

local function loadImg(svc, url)
    local sources = {}
    if Content and Content.fromUri then table.insert(sources, Content.fromUri(url)) end
    local num = string.match(url, "(%d+)")
    if Content and Content.fromAssetId and num then
        local okA, c = pcall(Content.fromAssetId, tonumber(num))
        if okA and c then table.insert(sources, c) end
    end
    table.insert(sources, url)
    local lastErr
    for _, s in sources do
        local ok, img = pcall(function() return svc:CreateEditableImageAsync(s) end)
        if ok and img then return img end
        lastErr = tostring(img)
    end
    return nil, lastErr
end

local function exportMeshes(entries, dir)
    local rep = { saved = 0, failed = 0, reason = nil, patches = {}, done = false }
    if #entries == 0 then rep.done = true; return rep end
    local svc = game:GetService("AssetService")
    local hasPart = hasMethod(svc, "CreateEditableMeshFromPartAsync")
    local hasCreate = hasMethod(svc, "CreateEditableMeshAsync")
    local made = false
    local idx, running = 0, math.min(16, #entries)
    local function one(entry)
        local m, reason = loadMesh(svc, entry.part, entry.id, hasPart, hasCreate)
        if not m then rep.failed += 1; rep.reason = rep.reason or reason or "unknown"; return end
        local okE, data = pcall(encodeMesh, m)
        pcall(m.Destroy, m)
        if not okE then rep.failed += 1; rep.reason = rep.reason or tostring(data); return end
        local name = meshName(entry.id)
        if not made then made = true; mkFolder(dir) end
        local okW, werr = pcall(writefile, dir .. "/" .. name, data)
        if not okW then rep.failed += 1; rep.reason = rep.reason or tostring(werr); return end
        rep.saved += 1
        local patchUrl = "rbxasset://meshes/" .. name
        for _, inst in entry.instances do
            table.insert(rep.patches, { instance = inst, prop = "MeshId", customURL = patchUrl })
        end
    end
    for _ = 1, running do
        task.spawn(function()
            while true do
                idx += 1
                local e = entries[idx]
                if not e then break end
                local ok, err = pcall(one, e)
                if not ok then rep.failed += 1; rep.reason = rep.reason or tostring(err) end
            end
            running -= 1
            if running == 0 then rep.done = true end
        end)
    end
    return rep
end

local function exportImages(entries, dir, state, updateUI)
    local rep = { saved = 0, failed = 0, reason = nil, patches = {}, done = false }
    if #entries == 0 then rep.done = true; return rep end
    local svc = game:GetService("AssetService")
    if not hasMethod(svc, "CreateEditableImageAsync") then
        rep.done = true
        rep.failed = #entries
        rep.reason = "CreateEditableImageAsync unavailable"
        return rep
    end
    local made = false
    local idx, running = 0, 32
    local quality = state.textureQuality
    
    local function one(entry)
        local url = entry.url
        local img, reason = loadImg(svc, url)
        
        if not img then
            rep.failed += 1
            state.textureLoss += 1
            pcall(updateUI, state.textureLoss)
            rep.reason = rep.reason or reason or "unknown"
            return
        end
        
        local okSz, sz = pcall(function() return img.Size end)
        if not okSz or not sz then
            pcall(img.Destroy, img)
            rep.failed += 1; rep.reason = rep.reason or tostring(sz); return
        end
        local w, h = math.floor(sz.X), math.floor(sz.Y)
        local okPx, pixels = pcall(function() return img:ReadPixelsBuffer(Vector2.zero, Vector2.new(w, h)) end)
        pcall(img.Destroy, img)
        if not okPx or not pixels then rep.failed += 1; rep.reason = rep.reason or tostring(pixels); return end
        
        local okScale, scaledPixels, nw, nh = pcall(scaleBuffer, pixels, w, h, quality)
        if okScale and scaledPixels then
            pixels, w, h = scaledPixels, nw, nh
        end
        
        local okE, png = pcall(pngEncode, w, h, pixels)
        if not okE then rep.failed += 1; rep.reason = rep.reason or tostring(png); return end
        local name = imgName(url)
        if not made then made = true; mkFolder(dir) end
        local okW, werr = pcall(writefile, dir .. "/" .. name, png)
        if not okW then rep.failed += 1; rep.reason = rep.reason or tostring(werr); return end
        rep.saved += 1
        local patchUrl = "rbxasset://textures/" .. name
        for _, patch in entry.patches do
            table.insert(rep.patches, { instance = patch.instance, prop = patch.prop, customURL = patchUrl })
        end
    end
    for _ = 1, running do
        task.spawn(function()
            while true do
                idx += 1
                local e = entries[idx]
                if not e then break end
                local ok, err = pcall(one, e)
                if not ok then rep.failed += 1; rep.reason = rep.reason or tostring(err) end
            end
            running -= 1
            if running == 0 then rep.done = true end
        end)
    end
    return rep
end

local NEVER = { CoreGui = true, CorePackages = true }

local function collect(isPlace, root, vals, onProgress)
    local blocked = {}
    for _, item in vals.IgnoreList do blocked[item] = true end
    if not vals.SavePlayerCharacters then
        for _, pl in game:GetService("Players"):GetPlayers() do
            if pl.Character then blocked[pl.Character] = true end
        end
    end
    local skip = {}
    for item in blocked do
        skip[item] = true
        local ok, list = pcall(item.GetDescendants, item)
        if ok then for _, d in list do skip[d] = true end end
    end
    local meshes, meshKey = {}, {}
    local images, imgKey = {}, {}
    local wantMeshes = vals.SaveMeshes
    local wantImages = vals.SaveImages

    local function consider(inst)
        if skip[inst] then return end
        local cls = inst.ClassName
        if wantMeshes then
            local id = meshIdOf(inst, cls)
            if id then
                local entry = meshKey[id]
                if not entry then
                    entry = { id = id, part = nil, instances = {} }
                    meshKey[id] = entry
                    meshes[#meshes+1] = entry
                end
                table.insert(entry.instances, inst)
                if cls == "MeshPart" and not entry.part then entry.part = inst end
            end
        end
        if wantImages then
            local props = IMG_PROPS[cls]
            if props then
                for _, prop in props do
                    local url = readContent(inst, prop)
                    if url and (string.find(url, "rbxassetid://", 1, true) or string.find(url, "rbxthumb://", 1, true)) then
                        local entry = imgKey[url]
                        if not entry then
                            entry = { url = url, patches = {} }
                            imgKey[url] = entry
                            images[#images+1] = entry
                        end
                        table.insert(entry.patches, { instance = inst, prop = prop })
                    end
                end
            end
        end
    end

    local function walk(c)
        pcall(consider, c)
        local ok, list = pcall(c.GetDescendants, c)
        if ok then for _, i in list do pcall(consider, i) end end
    end

    if isPlace then
        local svcs = game:GetChildren()
        for i, svc in svcs do
            if not NEVER[svc.ClassName] and not blocked[svc] then
                walk(svc)
                if onProgress then onProgress(i, #svcs, svc.Name) end
            end
        end
    elseif type(root) == "table" then
        for i, item in root do
            walk(item)
            if onProgress then onProgress(i, #root, tostring(item)) end
        end
    else
        walk(root)
        if onProgress then onProgress(1, 1, tostring(root)) end
    end
    if vals.SaveNilInstances and getnilinstances then
        local ok, list = pcall(getnilinstances)
        if ok and type(list) == "table" then
            for _, inst in list do if typeof(inst) == "Instance" then walk(inst) end end
        end
    end
    return meshes, images
end

local function makeUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "oreangeDecompUI"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not ok or not gui.Parent then
        local pl = game:GetService("Players").LocalPlayer
        if pl then gui.Parent = pl:WaitForChild("PlayerGui") end
    end

    local container = Instance.new("Frame")
    container.Name = "Container"
    container.AnchorPoint = Vector2.new(1, 0)
    container.Position = UDim2.new(1, -15, 0, 15)
    container.Size = UDim2.new(0, 500, 0, 80)
    container.BackgroundTransparency = 1
    container.Parent = gui

    local ussiLbl = Instance.new("TextLabel")
    ussiLbl.Name = "USSI"
    ussiLbl.BackgroundTransparency = 1
    ussiLbl.Size = UDim2.new(1, 0, 0, 16)
    ussiLbl.Font = Enum.Font.Code
    ussiLbl.TextSize = 14
    ussiLbl.TextColor3 = Color3.fromRGB(255, 165, 0)
    ussiLbl.TextXAlignment = Enum.TextXAlignment.Right
    ussiLbl.Text = "[oreange decomp v1.4]"
    ussiLbl.TextTransparency = 1
    ussiLbl.Parent = container

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Name = "StatusText"
    statusLbl.BackgroundTransparency = 1
    statusLbl.Size = UDim2.new(1, 0, 0, 16)
    statusLbl.Font = Enum.Font.Code
    statusLbl.TextSize = 14
    statusLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLbl.TextXAlignment = Enum.TextXAlignment.Right
    statusLbl.Text = "loading"
    statusLbl.TextTransparency = 1
    statusLbl.Parent = container

    local lossLbl = Instance.new("TextLabel")
    lossLbl.Name = "LossText"
    lossLbl.BackgroundTransparency = 1
    lossLbl.Size = UDim2.new(1, 0, 0, 16)
    lossLbl.Font = Enum.Font.Code
    lossLbl.TextSize = 14
    lossLbl.TextColor3 = Color3.fromRGB(255, 50, 50)
    lossLbl.TextXAlignment = Enum.TextXAlignment.Right
    lossLbl.Text = "textures loss: 0"
    lossLbl.TextTransparency = 1
    lossLbl.Visible = false
    lossLbl.Parent = container

    local warnLbl = Instance.new("TextLabel")
    warnLbl.Name = "WarnText"
    warnLbl.BackgroundTransparency = 1
    warnLbl.Size = UDim2.new(1, 0, 0, 16)
    warnLbl.Font = Enum.Font.Code
    warnLbl.TextSize = 14
    warnLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
    warnLbl.TextXAlignment = Enum.TextXAlignment.Right
    warnLbl.Text = "way to many texutres, folder size will be large"
    warnLbl.TextTransparency = 1
    warnLbl.Visible = false
    warnLbl.Parent = container

    local IsLoading = false
    local LoadingText = ""
    local LoadingThread = nil
    local StatusText = statusLbl

    local function ensureSpinner()
        if LoadingThread then return end
        LoadingThread = task.spawn(function()
            local chars = { "|", "/", "-", "\\" }
            local i = 0
            while true do
                while not IsLoading do
                    task.wait()
                end
                while IsLoading do
                    i = i % #chars + 1
                    if StatusText and LoadingText then
                        StatusText.Text = LoadingText .. " " .. chars[i]
                    end
                    task.wait(0.25)
                end
            end
        end)
    end

    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    
    local function slideIn(lbl, targetY, delay)
        lbl.Position = UDim2.new(0, 500, 0, targetY)
        task.spawn(function()
            task.wait(delay)
            local tween = TweenService:Create(lbl, tweenInfo, {
                Position = UDim2.new(0, 0, 0, targetY),
                TextTransparency = 0
            })
            tween:Play()
            
            task.delay(0.6, function()
                if lbl and lbl.Parent then
                    lbl.TextTransparency = 0
                    lbl.Position = UDim2.new(0, 0, 0, targetY)
                end
            end)
        end)
    end

    slideIn(ussiLbl, 0, 0)
    slideIn(statusLbl, 18, 0.1)
    slideIn(lossLbl, 36, 0.2)
    slideIn(warnLbl, 54, 0.3)

    return {
        setUSSI = function(t)
            if ussiLbl and ussiLbl.Parent then ussiLbl.Text = tostring(t) end
        end,
        set = function(t, color) 
            IsLoading = false
            if statusLbl and statusLbl.Parent then 
                statusLbl.Text = tostring(t) 
                statusLbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
            end 
        end,
        startLoading = function(t, color)
            LoadingText = t
            if statusLbl then statusLbl.TextColor3 = color or Color3.fromRGB(255, 255, 255) end
            IsLoading = true
            ensureSpinner()
        end,
        setLoadingText = function(t)
            LoadingText = t
        end,
        setLoss = function(count)
            if lossLbl and lossLbl.Parent then
                lossLbl.Text = "textures loss: " .. tostring(count)
                if count > 0 then
                    lossLbl.Visible = true
                end
            end
        end,
        showWarning = function()
            if warnLbl and warnLbl.Parent then warnLbl.Visible = true end
        end,
        kill = function() 
            local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear)
            TweenService:Create(ussiLbl, fadeInfo, {TextTransparency = 1}):Play()
            TweenService:Create(statusLbl, fadeInfo, {TextTransparency = 1}):Play()
            TweenService:Create(lossLbl, fadeInfo, {TextTransparency = 1}):Play()
            TweenService:Create(warnLbl, fadeInfo, {TextTransparency = 1}):Play()
            task.delay(0.35, function() 
                pcall(function() gui:Destroy() end) 
            end)
        end,
    }
end

local function checkExecutor()
    local hasWrite = type(writefile) == "function"
    local hasFolder = type(makefolder) == "function"
    local hasReq = type((getgenv().request or getgenv().http_request or (syn and syn.request) or http.request)) == "function"
    
    if not hasWrite then return false, "missing writefile" end
    if not hasFolder then return false, "missing makefolder" end
    if not hasReq then return false, "missing request" end
    return true
end

local saveCount = 0

local function save(fname, root, options)
    if type(options) == "table" then
        options = fromTable(options)
    elseif options ~= nil and optValues[options] == nil then
        error(string.format("invalid arg to '%s' (%s)", fname, typeof(options)), 3)
    end
    local vals = optValues[options or SaveInstanceOptions.new()]

    local isPlace = root == game
    if not isPlace and type(root) == "table" then
        if #root == 0 then error("array is empty", 3) end
        for _, item in root do
            if typeof(item) ~= "Instance" then error("array must only contain Instances", 3) end
        end
    elseif not isPlace and typeof(root) ~= "Instance" then
        error("Instance or {Instance} expected", 3)
    end

    local state = { textureLoss = 0, textureQuality = vals.TextureQuality, disableLogs = vals.DisableLogs }
    local ui
    pcall(function() ui = makeUI() end)

    local function upd(msg, color)
        if ui then ui.set(msg, color) end
        if not vals.DisableLogs then
            print(msg)
        end
    end

    upd("loading..", Color3.fromRGB(255, 165, 0))
    task.wait(3)
    
    upd("checking executor...", Color3.fromRGB(255, 255, 255))
    
    local execOk, execErr = checkExecutor()
    if not execOk then
        upd("failed: " .. execErr, Color3.fromRGB(255, 50, 50))
        task.wait(3)
        if ui then ui.kill() end
        return
    end
    task.wait(1)

    upd("reading game...", Color3.fromRGB(255, 255, 255))

    local ok, err = pcall(function()
        local path = targetPath(vals, root, isPlace)
        local base = path and (string.gsub(path, "%.[^/\\%.]+$", "")) or ("oreange decomp/Game")
        local meshDir = base .. "/meshes"
        local texDir = base .. "/textures"

        local meshes, images = {}, {}
        if vals.SaveMeshes or vals.SaveImages then
            meshes, images = collect(isPlace, root, vals, function(i, n, name)
                upd(string.format("scanning %s (%d/%d)", name, i, n), Color3.fromRGB(255, 255, 255))
            end)
        end

        if vals.SaveMeshes and #meshes > 0 then
            if ui then ui.startLoading("decompiling meshes", Color3.fromRGB(255, 255, 255)) end
            local rep = exportMeshes(meshes, meshDir)
            local lastDone = -1
            while not rep.done do
                local cur = rep.saved + rep.failed
                if cur ~= lastDone then
                    lastDone = cur
                    if ui then ui.setLoadingText(string.format("decompiling meshes %d/%d", cur, #meshes)) end
                end
                task.wait(0.1)
            end
            upd("meshes extracted successfully", Color3.fromRGB(0, 255, 0))
            task.wait(1.5)
        end

        if vals.SaveImages and #images > 0 then
            if #images > 500 then
                if ui then ui.showWarning() end
                upd("way to many texutres, folder size will be large", Color3.fromRGB(255, 255, 255))
            end
            
            if ui then ui.startLoading("decompiling textures", Color3.fromRGB(255, 255, 255)) end
            local rep = exportImages(images, texDir, state, function(lossCount)
                if ui then ui.setLoss(lossCount) end
            end)
            local lastDone = -1
            while not rep.done do
                local cur = rep.saved + rep.failed
                if cur ~= lastDone then
                    lastDone = cur
                    if ui then ui.setLoadingText(string.format("decompiling textures %d/%d", cur, #images)) end
                end
                task.wait(0.1)
            end
            upd(string.format("textures done: %d ok, %d failed", rep.saved, rep.failed), Color3.fromRGB(255, 255, 255))
        end

        if ui then ui.startLoading("saving game...", Color3.fromRGB(255, 255, 255)) end
        if not vals.DisableLogs then print("saving game...") end

        local okSrc, src = pcall(game.HttpGet, game, USSI_URL)
        if not okSrc or type(src) ~= "string" or #src == 0 then error("could not download ussi") end
        local chunk, compileErr = loadstring(src, "saveinstance")
        if not chunk then error("could not compile ussi: " .. tostring(compileErr)) end
        
        local env = setmetatable({
            writefile = writefile, readfile = readfile, isfile = isfile, isfolder = isfolder,
            makefolder = makefolder, request = getgenv().request or getgenv().http_request or http.request,
            getcustomasset = function(p) return p end, getnilinstances = getnilinstances or function() return {} end,
            getgc = function() return {} end, cloneref = function(o) return o end,
            gethui = function() return game:GetService("CoreGui") end, isreadonly = function() return false end,
            setreadonly = function() end, hookfunction = function() end,
            getrawmetatable = function(o) return getmetatable(o) end,
            setrbxclipboard = getgenv().setrbxclipboard or function() end
        }, { __index = getgenv() })
        
        setfenv(chunk, env)
        local ussi = chunk()
        if type(ussi) ~= "function" then error("ussi did not return a function") end

        local okU, errU = pcall(function()
            local ignore = { "CoreGui", "CorePackages", Packages = false }
            for _, item in vals.IgnoreList do table.insert(ignore, item) end
            saveCount += 1
            local internal = "oreange-save-" .. saveCount .. (isPlace and ".rbxl" or ".rbxm")
            local ussiOpts = {
                Binary = true, CompressionMode = (not vals.DisableCompression) and "zstd" or false,
                Decompile = false, IgnoreNotArchivable = vals.IgnoreArchivable,
                SavePlayerCharacters = vals.SavePlayerCharacters, IsolatePlayers = vals.SavePlayers,
                SaveNotCreatable = vals.SaveNonCreatable, NilInstances = vals.SaveNilInstances,
                IgnoreList = ignore, FilePath = internal, ShowStatus = false, ReadMe = false,
                SafeMode = false, SaveMeshes = false, scriptcache = false, CompressionLevel = 3,
                Callback = function(ser) state.serialized = ser end,
            }
            if isPlace then ussi(ussiOpts) else ussiOpts.mode = "full"; ussi(root, ussiOpts) end
        end)

        if genv.USSI_statustext then
            genv.USSI_statustext:Destroy()
            genv.USSI_statustext = nil
        end

        if not okU then error(errU, 0) end

        local data = state.serialized
        local internal = "oreange-save-" .. saveCount .. (isPlace and ".rbxl" or ".rbxm")
        if path ~= internal and delfile then pcall(function() delfile(internal) end) end

        if type(data) ~= "string" then error("nothing was serialized", 0) end

        if vals.CopyToClipboard and setrbxclipboard then pcall(setrbxclipboard, data) end
        if path then
            mkParents(path)
            local okW, werr = pcall(writefile, path, data)
            if not okW then error("writefile failed: " .. tostring(werr), 0) end
        end

        upd("saved: " .. (path or "(clipboard)"), Color3.fromRGB(0, 255, 0))
    end)

    if not ok then
        if ui then
            ui.set("failed: " .. tostring(err), Color3.fromRGB(255, 50, 50))
            task.delay(4, function() if ui then ui.kill() end end)
        end
        if not vals.DisableLogs then
            error(fname .. " failed: " .. tostring(err), 3)
        end
    else
        if ui then 
            ui.setUSSI("oreange decomp finished") 
            task.delay(3, function() if ui then ui.kill() end end)
        end
    end
end

local function saveinstance(root, options)
    if root == nil then
        root = game
    elseif options == nil and (optValues[root] ~= nil or (type(root) == "table" and not isInstArray(root))) then
        root, options = game, root
    end
    save("saveinstance", root, options)
end

local function saveplace(options)
    save("saveplace", game, options)
end

genv.SaveInstanceOptions = table.freeze(SaveInstanceOptions)
genv.saveinstance = saveinstance
genv.saveplace = saveplace

if cmd == "saveplace" then
    saveplace(a)
elseif cmd == "saveinstance" then
    saveinstance(a, b)
else
    local opts = (type(a) == "table" and a) or (type(b) == "table" and b)
    if not (opts and (opts.DisableLogs or opts.disablelogs)) then
        print("oreange decomp ready")
    end
end
