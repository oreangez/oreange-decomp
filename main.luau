--Usage of AI is prohibited using this script. 
--If you fork/update this script, please make sure to credit me!
--Found bugs? contact @oreangez on discord



local cmd, a, b = ...

local USSI = "https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau"
local genv = (type(getgenv) == "function" and getgenv()) or getfenv(0)
local DECOMP = genv.__OREANGE_DECOMPILER_URL or "http://127.0.0.1:4128/luau/decompile"
local BATCH_URL = DECOMP .. "/batch"
local BATCH_SCRIPTS = 200
local BATCH_BYTES = 4 * 1024 * 1024
local BATCHES_IN_FLIGHT = 4
local WORKERS = 8

local function pick(...)
    for _, v in {...} do if type(v) == "function" then return v end end
end

local requestFn = pick(genv.request, genv.http_request, type(syn) == "table" and syn.request, type(http) == "table" and http.request)
local getbc = pick(genv.getscriptbytecode)
local getnil = pick(genv.getnilinstances)
local setclip = pick(genv.setrbxclipboard, genv.setclipboard, genv.toclipboard)
local delfileFn = pick(genv.delfile)

local OPTIONS = {
    FilePath = "string", IgnoreArchivable = "boolean", SavePlayerCharacters = "boolean",
    SavePlayers = "boolean", DisableCompression = "boolean", DecompileScripts = "boolean",
    SaveNonCreatable = "boolean", SaveNilInstances = "boolean", CopyToClipboard = "boolean",
    IgnoreList = "table", DecompilerOptions = "table", ShowStatus = "boolean",
    SafeMode = "boolean", SaveMeshes = "boolean", SaveImages = "boolean",
}

local optValues = setmetatable({}, { __mode = "k" })
local SaveInstanceOptions = {}

function SaveInstanceOptions.new()
    local obj = {}
    local v = {
        FilePath = "", IgnoreArchivable = true, SavePlayerCharacters = true,
        SavePlayers = true, DisableCompression = false, DecompileScripts = true,
        SaveNonCreatable = true, SaveNilInstances = true, CopyToClipboard = false,
        IgnoreList = {}, DecompilerOptions = false, ShowStatus = true,
        SafeMode = false, SaveMeshes = true, SaveImages = true,
    }
    optValues[obj] = v
    setmetatable(obj, {
        __type = "SaveInstanceOptions",
        __metatable = "locked",
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

local saver, current

local function getSaver()
    if saver then return saver end
    local ok, src = pcall(game.HttpGet, game, USSI)
    if not ok or type(src) ~= "string" or #src == 0 then error("could not download ussi", 0) end
    local chunk, err = loadstring(src, "saveinstance")
    if not chunk then error("could not compile ussi: " .. tostring(err), 0) end
    local env = setmetatable({
        warn = function(...)
            if current then
                local p = table.pack(...)
                for i = 1, p.n do p[i] = tostring(p[i]) end
                table.insert(current.warnings, table.concat(p, " "))
            end
            return print(...)
        end,
        decompile = function(scr)
            if current and current.decompiled and getbc then
                local ok2, bc = pcall(getbc, scr, true)
                if ok2 and type(bc) == "string" and current.decompiled[bc] then return current.decompiled[bc] end
            end
            return "-- decompile failed"
        end,
        getscriptbytecode = getbc or function() return "" end,
        getcustomasset = function(p) return p end,
        getnilinstances = getnil or function() return {} end,
        getgc = function() return {} end,
        cloneref = function(o) return o end,
        gethui = function() return game:GetService("CoreGui") end,
        isreadonly = function() return false end,
        setreadonly = function() end,
        hookfunction = function() end,
        getrawmetatable = function(o) return getmetatable(o) end,
        request = requestFn,
        writefile = writefile,
        readfile = readfile,
        isfile = isfile,
        isfolder = isfolder,
        makefolder = makefolder,
        setrbxclipboard = setclip or function() end,
    }, { __index = genv })
    setfenv(chunk, env)
    local r = chunk()
    if type(r) ~= "function" then error("ussi did not return a function", 0) end
    saver = r
    return r
end

local ALIASES = {
    filepath="FilePath", filename="FilePath", ignorearchivable="IgnoreArchivable", ignorenotarchivable="IgnoreArchivable",
    saveplayercharacters="SavePlayerCharacters", savecharacters="SavePlayerCharacters", saveplayers="SavePlayers",
    isolateplayers="SavePlayers", disablecompression="DisableCompression", decompilescripts="DecompileScripts",
    decompile="DecompileScripts", savenoncreatable="SaveNonCreatable", savenotcreatable="SaveNonCreatable",
    savenilinstances="SaveNilInstances", nilinstances="SaveNilInstances", copytoclipboard="CopyToClipboard",
    clipboard="CopyToClipboard", ignorelist="IgnoreList", instancesblacklist="IgnoreList", decompileroptions="DecompilerOptions",
    showstatus="ShowStatus", showprogress="ShowStatus", safemode="SafeMode", savemeshes="SaveMeshes",
    meshes="SaveMeshes", exportmeshes="SaveMeshes", saveimages="SaveImages", images="SaveImages", exportimages="SaveImages",
}

local function fromTable(src)
    local obj = SaveInstanceOptions.new()
    for k, val in src do
        if type(k) == "string" then
            local low = string.lower(k)
            if low == "noscripts" and type(val) == "boolean" then
                obj.DecompileScripts = not val
            else
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
    if clean == "" then return "unknown" end
    return clean
end

local function genPath(root, isModel)
    local baseName = ""
    if isModel and root then
        baseName = root.Name
    else
        baseName = game.Name ~= "" and game.Name or "game"
    end
    baseName = sanitize(baseName)
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
    local idx, running = 0, math.min(WORKERS, #entries)
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

local function exportImages(entries, dir)
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
    local idx, running = 0, math.min(WORKERS, #entries)
    local function one(entry)
        local img, reason = loadImg(svc, entry.url)
        if not img then rep.failed += 1; rep.reason = rep.reason or reason or "unknown"; return end
        local okSz, sz = pcall(function() return img.Size end)
        if not okSz or not sz then
            pcall(img.Destroy, img)
            rep.failed += 1; rep.reason = rep.reason or tostring(sz); return
        end
        local w, h = math.floor(sz.X), math.floor(sz.Y)
        local okPx, pixels = pcall(function() return img:ReadPixelsBuffer(Vector2.zero, Vector2.new(w, h)) end)
        pcall(img.Destroy, img)
        if not okPx or not pixels then rep.failed += 1; rep.reason = rep.reason or tostring(pixels); return end
        local okE, png = pcall(pngEncode, w, h, pixels)
        if not okE then rep.failed += 1; rep.reason = rep.reason or tostring(png); return end
        local name = imgName(entry.url)
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

local function isClient(inst, cls)
    if cls == "ModuleScript" then return true end
    local ok, r = pcall(function()
        if cls == "LocalScript" then return inst.RunContext ~= Enum.RunContext.Server end
        if cls == "Script" then return inst.RunContext == Enum.RunContext.Client end
        return false
    end)
    return ok and r
end

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
    local scripts = {}
    local meshes, meshKey = {}, {}
    local images, imgKey = {}, {}
    local wantScripts = vals.DecompileScripts and getbc ~= nil
    local wantMeshes = vals.SaveMeshes
    local wantImages = vals.SaveImages

    local function consider(inst)
        if skip[inst] then return end
        local cls = inst.ClassName
        if wantScripts then
            local okC, isC = pcall(isClient, inst, cls)
            if okC and isC then
                local ok, bc = pcall(getbc, inst, true)
                if ok and type(bc) == "string" and #bc > 0 and not meshKey["bc:" .. bc] then
                    meshKey["bc:" .. bc] = true
                    scripts[#scripts+1] = { name = string.sub((string.gsub(inst.Name, "[^%w_]", "")), 1, 64), bytecode = bc }
                end
            end
        end
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
    if vals.SaveNilInstances and getnil then
        local ok, list = pcall(getnil)
        if ok and type(list) == "table" then
            for _, inst in list do if typeof(inst) == "Instance" then walk(inst) end end
        end
    end
    return scripts, meshes, images
end

local function makeUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "oreangeDecompUI_" .. tostring(math.random(100000, 999999))
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not ok or not gui.Parent then
        local pl = game:GetService("Players").LocalPlayer
        if pl then gui.Parent = pl:WaitForChild("PlayerGui") end
    end

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Status"
    lbl.AnchorPoint = Vector2.new(1, 1)
    lbl.Position = UDim2.new(1, -12, 1, -12)
    lbl.Size = UDim2.new(0, 800, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel = 0
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Right
    lbl.TextYAlignment = Enum.TextYAlignment.Bottom
    lbl.Font = Enum.Font.SourceSansSemibold
    lbl.TextSize = 16
    lbl.TextStrokeTransparency = 1
    lbl.TextTransparency = 0
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Text = "[oreange decomp] starting"
    lbl.Parent = gui

    return {
        set = function(t) if lbl and lbl.Parent then lbl.Text = "[oreange decomp] " .. tostring(t) end end,
        kill = function() pcall(function() gui:Destroy() end) end,
    }
end

local function sendBatch(batch, query, dec, fail, onCur)
    if onCur and batch[1] then
        local n = batch[1].name
        if #batch > 1 then n = n .. " (+" .. (#batch - 1) .. ")" end
        pcall(onCur, n)
    end
    if not requestFn then return end
    local parts = table.create(#batch + 2)
    parts[1] = "SQB1"
    parts[2] = string.pack("<I4", #batch)
    for i, e in batch do parts[i + 2] = string.pack("<s4s4", e.name, e.bytecode) end
    local ok, res = pcall(requestFn, {
        Url = BATCH_URL .. query, Method = "POST",
        Headers = { ["content-type"] = "application/octet-stream" }, Body = table.concat(parts),
    })
    if not ok or not res or res.StatusCode ~= 200 then return end
    local body = res.Body or ""
    if #body < 8 or string.sub(body, 1, 4) ~= "SQR1" then return end
    local parsed, results = pcall(function()
        local count, at = string.unpack("<I4", body, 5)
        if count ~= #batch then return nil end
        local list = table.create(count)
        for i = 1, count do
            local flag, text
            flag, text, at = string.unpack("<Bs4", body, at)
            list[i] = { flag == 1, text }
        end
        return list
    end)
    if not parsed or not results then return end
    for i, r in results do
        local bc = batch[i].bytecode
        if r[1] then
            dec[bc] = r[2]
        else
            fail[bc] = "decompile: " .. (string.match(r[2], "^%-%-%s*([^\n]*)") or r[2])
        end
    end
end

local function decompAll(scripts, opts, onProgress)
    local dec, fail = {}, {}
    if #scripts == 0 then return dec, fail end
    local width = 0
    if opts then
        local fmt = opts.Formatter
        width = math.clamp(math.floor(fmt and fmt.IndentWidth or 0), 0, 255)
    end
    local query = "?indent_width=" .. width
    local batches, batch, size = {}, {}, 0
    for _, e in scripts do
        if #batch > 0 and (#batch >= BATCH_SCRIPTS or size + #e.bytecode > BATCH_BYTES) then
            batches[#batches+1] = batch
            batch, size = {}, 0
        end
        batch[#batch+1] = e
        size += #e.bytecode
    end
    batches[#batches+1] = batch
    local nextB, running = 0, math.min(BATCHES_IN_FLIGHT, #batches)
    local done = 0
    for _ = 1, running do
        task.spawn(function()
            while true do
                nextB += 1
                local b = batches[nextB]
                if not b then break end
                local batchIdx = nextB
                pcall(sendBatch, b, query, dec, fail, function(n)
                    if onProgress then onProgress(batchIdx, #batches, n) end
                end)
                done += 1
                if onProgress then onProgress(done, #batches, nil) end
            end
            running -= 1
        end)
    end
    while running > 0 do task.wait() end
    return dec, fail
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

    while current do task.wait() end
    local state = { warnings = {}, decompilerOptions = vals.DecompileScripts and vals.DecompilerOptions or nil }
    current = state

    local ui
    pcall(function() ui = makeUI() end)

    local function upd(msg)
        if ui then ui.set(msg) end
        print(msg)
    end

    upd("preparing")

    local ok, err = pcall(function()
        upd("downloading ussi")
        local ussi = getSaver()
        local path = targetPath(vals, root, isPlace)
        local base = path and (string.gsub(path, "%.[^/\\%.]+$", "")) or ("oreange decomp/game " .. tostring(game.PlaceId))
        local meshDir = base .. "/meshes"
        local texDir = base .. "/textures"

        local scripts, meshes, images = {}, {}, {}
        if vals.DecompileScripts or vals.SaveMeshes or vals.SaveImages then
            upd("scanning datamodel")
            scripts, meshes, images = collect(isPlace, root, vals, function(i, n, name)
                upd(string.format("scanning %s (%d/%d)", name, i, n))
            end)
            upd(string.format("found %d scripts, %d meshes, %d textures", #scripts, #meshes, #images))
        end

        if vals.SaveMeshes and #meshes > 0 then
            upd("extracting meshes")
            local rep = exportMeshes(meshes, meshDir)
            local lastDone = -1
            while not rep.done do
                local cur = rep.saved + rep.failed
                if cur ~= lastDone then
                    lastDone = cur
                    upd(string.format("meshes %d/%d", cur, #meshes))
                end
                task.wait(0.1)
            end
            upd(string.format("meshes done: %d ok, %d failed", rep.saved, rep.failed))
        end

        if vals.SaveImages and #images > 0 then
            upd("extracting textures")
            local rep = exportImages(images, texDir)
            local lastDone = -1
            while not rep.done do
                local cur = rep.saved + rep.failed
                if cur ~= lastDone then
                    lastDone = cur
                    upd(string.format("textures %d/%d", cur, #images))
                end
                task.wait(0.1)
            end
            upd(string.format("textures done: %d ok, %d failed", rep.saved, rep.failed))
        end

        if vals.DecompileScripts and #scripts > 0 then
            upd(string.format("decompiling %d scripts", #scripts))
            state.decompiled, state.failed = decompAll(scripts, state.decompilerOptions,
                function(done, total, name)
                    if name then
                        upd(string.format("[%d/%d] %s", done, total, name))
                    else
                        upd(string.format("batch %d/%d done", done, total))
                    end
                end)
            upd(string.format("decompiled %d scripts", #scripts))
        end

        upd("serializing")

        local okU, errU = pcall(function()
            local ignore = { "CoreGui", "CorePackages", Packages = false }
            for _, item in vals.IgnoreList do table.insert(ignore, item) end
            saveCount += 1
            local internal = "oreange-save-" .. saveCount .. (isPlace and ".rbxl" or ".rbxm")
            local ussiOpts = {
                Binary = true,
                CompressionMode = (not vals.DisableCompression) and "zstd" or false,
                Decompile = vals.DecompileScripts,
                IgnoreNotArchivable = vals.IgnoreArchivable,
                SavePlayerCharacters = vals.SavePlayerCharacters,
                IsolatePlayers = vals.SavePlayers,
                SaveNotCreatable = vals.SaveNonCreatable,
                NilInstances = vals.SaveNilInstances,
                IgnoreList = ignore,
                FilePath = internal,
                ShowStatus = false,
                ReadMe = false,
                SafeMode = false,
                SaveMeshes = false,
                DecompileTimeout = -1, BytecodeTimeout = -1,
                scriptcache = false, CompressionLevel = 3,
                Callback = function(ser) state.serialized = ser end,
            }
            if isPlace then
                ussi(ussiOpts)
            else
                ussiOpts.mode = "full"
                ussi(root, ussiOpts)
            end
        end)

        if not okU then error(errU, 0) end

        local data = state.serialized
        local internal = "oreange-save-" .. saveCount .. (isPlace and ".rbxl" or ".rbxm")
        if path ~= internal and delfileFn then pcall(function() delfileFn(internal) end) end

        if type(data) ~= "string" then
            local reason
            for i, msg in state.warnings do
                if string.find(msg, "Error found while saving", 1, true) then
                    reason = state.warnings[i + 1]
                    break
                end
            end
            if not reason and #state.warnings > 0 then
                reason = table.concat(state.warnings, " | ", math.max(1, #state.warnings - 2))
            end
            error(reason or "nothing was serialized", 0)
        end

        upd("writing file")
        if vals.CopyToClipboard and setclip then pcall(setclip, data) end
        if path then
            mkParents(path)
            local okW, werr = pcall(writefile, path, data)
            if not okW then error("writefile failed: " .. tostring(werr), 0) end
        end

        upd("saved -> " .. (path or "(clipboard)"))
    end)

    current = nil
    if not ok then
        if ui then
            ui.set("failed: " .. tostring(err))
            task.delay(4, function() if ui then ui.kill() end end)
        end
        error(fname .. " failed: " .. tostring(err), 3)
    else
        task.delay(3, function() if ui then ui.kill() end end)
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
    print("oreange decomp ready")
end
    print("oreange decomp ready")
end
