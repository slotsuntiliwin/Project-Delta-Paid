-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
   Name = "Project Delta Paid - breakneckv09",
   Icon = 0,
   LoadingTitle = "Project Delta Script...",
   LoadingSubtitle = "by - breakneckv09",
   ShowText = "Toggle Rayfield",
   Theme = "Default",
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = true,
   DisableBuildWarnings = true,
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil,
      FileName = "Big Hub"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = true,
   KeySettings = {
      Title = "Project Delta Paid - Key System",
      Subtitle = "by - breakneckv09",
      Note = "The Key Is In Our Discord .gg/faV3GCjebC",
      FileName = "ProjectDeltaKey",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = {"X7P3K9L2QM6ZBV4N1T8J", "R5Y8N3QWZT1VJ6KMB9PX", "F9L4ZRV6DM0CQW2YJTXN", "BK7HTJZXL5VMRQN9D2YC", "V2XKW9B7TF4PJHM1CLZA", "NZ8DPRMT5LVXQKFYJ0WG", "YCQZ2LJ9NXKB4VS1P7RD", "M6HTVF5YBJCNQWZ9L0RX", "XJ7SM0D6QZRLTCKHVNFY", "GWQVX8BM9CPLDRTZ5NYH"}
   }
})

local combatTab  = Window:CreateTab("Combat", 4483362458)
local visualsTab = Window:CreateTab("Visuals", 4483362458)
local miscTab    = Window:CreateTab("Misc", 4483362458)
local itemTab     = Window:CreateTab("Inv Checker", 4483362458)
local notifTab    = Window:CreateTab("Warnings", 4483362458)
local riskyTab     = Window:CreateTab("Beta/Risky", 4483362458)
local dupeTab     = Window:CreateTab("Dupe", 4483362458)
local creditsTab = Window:CreateTab("Credits", 4483362458)

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playersFolder = ReplicatedStorage:WaitForChild("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local tick = tick

-- Flags
local playerBoxEnabled, playerNameEnabled = false, false
local npcBoxEnabled = false
local containerBoxEnabled, containerTextEnabled = false, false
local droppedBoxEnabled, droppedTextEnabled = false, false
local exitEspEnabled = false
local selectedFOV = 120
local fullbrightEnabled = false
local playerNotificationEnabled = false
local playerNotificationRange = 100
local secondaryNotificationEnabled = false
local secondaryNotificationRange = 50
local autoPickupEnabled = false
local autoPickupSpeed = 1
local aimlockEnabled = false
local fovEnabled = false
local targetNpcsToo = false
local useVisibilityCheck = false
local fovSize = 100
local smoothness = 0.1
local holdingRightClick = false
local lockedTarget = nil

-- Max Range Settings
local playerESPRange = 500
local npcESPRange = 500
local containerESPRange = 500
local droppedESPRange = 500
local exitESPRange = 500
local aimlockMaxRange = 300

-- Lighting Backup
local originalLighting = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ClockTime = Lighting.ClockTime,
}

-- Colors
local Colors = {
    PlayerBox = Color3.fromRGB(0, 255, 0),
    PlayerText = Color3.fromRGB(255, 255, 255),
    NPCBox = Color3.fromRGB(249, 233, 153),
    NPCText = Color3.fromRGB(249, 233, 153),
    ContainerBox = Color3.fromRGB(255, 128, 0),
    ContainerText = Color3.fromRGB(255, 128, 0),
    DroppedBox = Color3.fromRGB(180, 210, 228),
    DroppedText = Color3.fromRGB(180, 210, 228),
    ExitText = Color3.fromRGB(232, 186, 200),
}

-- Drawing tables to hold ESP lines and text
local Drawings = {
    PlayerBoxLines = {},
    PlayerTexts = {},
    NPCBoxLines = {},
    NPCTexts = {},
    ContainerBoxLines = {},
    ContainerTexts = {},
    DroppedBoxLines = {},
    DroppedTexts = {},
    ExitTexts = {},
}

-- CONFIG
local DISCOVERY_INTERVAL = 0.5   -- how often to scan workspace for new/despawned objects
local CLEANUP_INTERVAL   = 0.35   -- fallback cleanup interval (kept as a safety net)
local MAX_RENDER_DISTANCE = 6600  -- hard cap on render distance fallback

-- ======= Precomputed constants =======
local EDGES = {
    {1,2},{2,4},{4,3},{3,1}, -- top
    {5,6},{6,8},{8,7},{7,5}, -- bottom
    {1,5},{2,6},{3,7},{4,8}  -- sides
}

-- ======= UTIL HELPERS (from your code, slightly expanded) =======
local function safeRemove(obj)
    if obj and type(obj.Remove) == "function" then
        pcall(function() obj:Remove() end)
    end
end

local function clearBoxLines(tbl)
    for key, lines in pairs(tbl) do
        for _, line in ipairs(lines) do safeRemove(line) end
        tbl[key] = nil
    end
end

local function clearDrawings(tbl)
    for key, drawing in pairs(tbl) do
        safeRemove(drawing)
        tbl[key] = nil
    end
end

local function WorldToScreenPoint(pos)
    local ok, v = pcall(function() return Camera:WorldToViewportPoint(pos) end)
    if not ok or not v then return Vector2.new(0,0), false end
    return Vector2.new(v.X, v.Y), v.Z > 0
end

local function makeBoxLines()
    local t = {}
    for i = 1, 12 do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Transparency = 1
        line.Visible = false
        t[i] = line
    end
    return t
end

local function getBoxLines(tbl, key)
    local lines = tbl[key]
    if not lines then
        lines = makeBoxLines()
        tbl[key] = lines
    end
    return lines
end

local function getDrawing(tbl, key, dtype)
    local drawingObj = tbl[key]
    if not drawingObj then
        drawingObj = Drawing.new(dtype)
        if dtype == "Text" then
            drawingObj.Size = 14
            drawingObj.Center = true
            drawingObj.Outline = true
            drawingObj.OutlineColor = Color3.new(0,0,0)
            drawingObj.Visible = false
        end
        tbl[key] = drawingObj
    end
    return drawingObj
end

local function getPrimaryPart(model)
    if not model then return nil end
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
    for _, v in ipairs(model:GetChildren()) do
        if v:IsA("BasePart") then return v end
    end
    return nil
end

local function getHealthColor(health, maxHealth)
    if not health or not maxHealth or maxHealth <= 0 then
        return Colors.PlayerBox
    end
    local ratio = math.clamp(health / maxHealth, 0, 1)
    if ratio > 0.5 then
        local interp = (ratio - 0.5) * 2
        return Color3.new((1 - interp) * 1 + interp * 0, 1, 0)
    else
        local interp = ratio * 2
        return Color3.new(1, interp * 1, 0)
    end
end

-- corners cache
local cornersCache = setmetatable({}, { __mode = "k" })
local function getCornersTable(inst)
    local t = cornersCache[inst]
    if not t then
        t = {}
        for i = 1, 8 do t[i] = Vector3.new() end
        cornersCache[inst] = t
    end
    return t
end

local function writeModelCorners(model, out, scaleMultiplier)
    local prim = getPrimaryPart(model)
    if not model or not prim then return false end
    scaleMultiplier = scaleMultiplier or 1
    local cf = prim.CFrame
    local size = prim.Size * scaleMultiplier
    local hx, hy, hz = size.X/2, size.Y/2, size.Z/2
    out[1] = (cf * Vector3.new( hx,  hy,  hz))
    out[2] = (cf * Vector3.new( hx,  hy, -hz))
    out[3] = (cf * Vector3.new( hx, -hy,  hz))
    out[4] = (cf * Vector3.new( hx, -hy, -hz))
    out[5] = (cf * Vector3.new(-hx,  hy,  hz))
    out[6] = (cf * Vector3.new(-hx,  hy, -hz))
    out[7] = (cf * Vector3.new(-hx, -hy,  hz))
    out[8] = (cf * Vector3.new(-hx, -hy, -hz))
    return true
end

-- edges reused
local EDGES = {
    {1,2},{2,4},{4,3},{3,1},
    {5,6},{6,8},{8,7},{7,5},
    {1,5},{2,6},{3,7},{4,8}
}

-- ======= TRACKED LISTS & CONNECTIONS (from your code) =======
local tracked = { players = {}, npcs = {}, containers = {}, dropped = {}, exits = {} }
local cleanupConns = setmetatable({}, { __mode = "k" })

local function disconnectConnsFor(inst)
    local conns = cleanupConns[inst]
    if conns then
        for _, c in ipairs(conns) do
            if c and type(c.Disconnect) == "function" then
                pcall(function() c:Disconnect() end)
            elseif c and type(c.disconnect) == "function" then
                pcall(function() c:disconnect() end)
            end
        end
        cleanupConns[inst] = nil
    end
end

local function trackConn(inst, conn)
    if not inst or not conn then return end
    local t = cleanupConns[inst]
    if not t then
        t = {}
        cleanupConns[inst] = t
    end
    t[#t+1] = conn
end

-- central cleanup functions (reuse yours)
local function cleanupModelEsp(model)
    if not model then return end
    if Drawings.PlayerBoxLines[model] then
        clearBoxLines({[model] = Drawings.PlayerBoxLines[model]})
        Drawings.PlayerBoxLines[model] = nil
    end
    if Drawings.PlayerTexts[model] then safeRemove(Drawings.PlayerTexts[model]); Drawings.PlayerTexts[model] = nil end
    if Drawings.NPCBoxLines[model] then clearBoxLines({[model] = Drawings.NPCBoxLines[model]}); Drawings.NPCBoxLines[model] = nil end
    if Drawings.NPCTexts[model] then safeRemove(Drawings.NPCTexts[model]); Drawings.NPCTexts[model] = nil end
    if Drawings.ContainerBoxLines[model] then clearBoxLines({[model] = Drawings.ContainerBoxLines[model]}); Drawings.ContainerBoxLines[model] = nil end
    if Drawings.ContainerTexts[model] then safeRemove(Drawings.ContainerTexts[model]); Drawings.ContainerTexts[model] = nil end
    if Drawings.DroppedBoxLines[model] then clearBoxLines({[model] = Drawings.DroppedBoxLines[model]}); Drawings.DroppedBoxLines[model] = nil end
    if Drawings.DroppedTexts[model] then safeRemove(Drawings.DroppedTexts[model]); Drawings.DroppedTexts[model] = nil end
    disconnectConnsFor(model)
end

local function cleanupPartEsp(part)
    if not part then return end
    if Drawings.ExitTexts[part] then safeRemove(Drawings.ExitTexts[part]); Drawings.ExitTexts[part] = nil end
    disconnectConnsFor(part)
end

-- Setup cleanup handlers (from your code)
local function makeOnCleanup(inst, isPart)
    return function()
        if isPart then cleanupPartEsp(inst) else cleanupModelEsp(inst) end
    end
end

local function setupCleanupForModel(model)
    if not model then return end
    if model:GetAttribute("CleanupSetup") then return end
    model:SetAttribute("CleanupSetup", true)

    local onCleanup = makeOnCleanup(model, false)

    local connA = model.AncestryChanged:Connect(function(_, parent)
        if not parent then onCleanup() end
    end)
    trackConn(model, connA)

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local connD = humanoid.Died:Connect(function() onCleanup() end)
        trackConn(model, connD)
        local ok, connH = pcall(function() return humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if humanoid.Health <= 0 then onCleanup() end
        end) end)
        if ok and connH then trackConn(model, connH) end
    end

    local success, attrConn = pcall(function() return model:GetAttributeChangedSignal("Disabled"):Connect(function()
        if model:GetAttribute("Disabled") then onCleanup() end
    end) end)
    if success and attrConn then trackConn(model, attrConn) end
    local success2, attrConn2 = pcall(function() return model:GetAttributeChangedSignal("Enabled"):Connect(function()
        if model:GetAttribute("Enabled") == false then onCleanup() end
    end) end)
    if success2 and attrConn2 then trackConn(model, attrConn2) end
end

local function setupCleanupForPart(part)
    if not part then return end
    if part:GetAttribute("CleanupSetup") then return end
    part:SetAttribute("CleanupSetup", true)

    local onCleanup = makeOnCleanup(part, true)
    local connA = part.AncestryChanged:Connect(function(_, parent) if not parent then onCleanup() end end)
    trackConn(part, connA)
    local success, attrConn = pcall(function() return part:GetAttributeChangedSignal("Disabled"):Connect(function()
        if part:GetAttribute("Disabled") then onCleanup() end
    end) end)
    if success and attrConn then trackConn(part, attrConn) end
end

-- ======= DISCOVERY LOOP (same as you provided) =======
task.spawn(function()
    while true do
        local newPlayers = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character.PrimaryPart then
                newPlayers[#newPlayers + 1] = {player = plr, char = plr.Character}
                setupCleanupForModel(plr.Character)
            end
        end
        tracked.players = newPlayers

        local newNPCs = {}
        local aiZones = Workspace:FindFirstChild("AiZones")
        if aiZones then
            for _, item in ipairs(aiZones:GetDescendants()) do
                if item:IsA("Model") and item.PrimaryPart and item:FindFirstChildOfClass("Humanoid") and not (Players:GetPlayerFromCharacter(item) ~= nil) then
                    newNPCs[#newNPCs + 1] = item
                    setupCleanupForModel(item)
                end
            end
        end
        tracked.npcs = newNPCs

        local newContainers = {}
        local containersFolder = Workspace:FindFirstChild("Containers")
        if containersFolder then
            for _, item in ipairs(containersFolder:GetChildren()) do
                if item:IsA("Model") and item.PrimaryPart then
                    newContainers[#newContainers + 1] = item
                    setupCleanupForModel(item)
                end
            end
        end
        tracked.containers = newContainers

        local newDropped = {}
        local droppedFolder = Workspace:FindFirstChild("DroppedItems")
        if droppedFolder then
            for _, item in ipairs(droppedFolder:GetChildren()) do
                if item:IsA("Model") and item.PrimaryPart then
                    newDropped[#newDropped + 1] = item
                    setupCleanupForModel(item)
                end
            end
        end
        tracked.dropped = newDropped

        local newExits = {}
        local noColl = Workspace:FindFirstChild("NoCollision")
        if noColl and noColl:FindFirstChild("ExitLocations") then
            for _, exitPart in ipairs(noColl.ExitLocations:GetChildren()) do
                if exitPart:IsA("BasePart") then
                    newExits[#newExits + 1] = exitPart
                    setupCleanupForPart(exitPart)
                end
            end
        end
        tracked.exits = newExits

        task.wait(DISCOVERY_INTERVAL)
    end
end)

-- ======= PERIODIC CLEANUP (fallback) =======
task.spawn(function()
    while true do
        for _, tbl in pairs(Drawings) do
            for key, drawingObj in pairs(tbl) do
                if typeof(key) == "Instance" and (not key.Parent or not drawingObj) then
                    if type(drawingObj) == "table" then
                        for _, line in ipairs(drawingObj) do safeRemove(line) end
                    else
                        safeRemove(drawingObj)
                    end
                    tbl[key] = nil
                end
            end
        end
        task.wait(CLEANUP_INTERVAL)
    end
end)

-- ======= Helper: immediate cleanup when out of range =======
local function cleanupIfOutOfRange(inst, kind, dist)
    -- choose the correct max range for this kind
    local maxRange = MAX_RENDER_DISTANCE
    if kind == "player" then maxRange = playerESPRange
    elseif kind == "npc" then maxRange = npcESPRange
    elseif kind == "container" then maxRange = containerESPRange
    elseif kind == "dropped" then maxRange = droppedESPRange
    elseif kind == "exit" then maxRange = exitESPRange
    end

    if dist > maxRange or dist > MAX_RENDER_DISTANCE then
        if kind == "exit" then
            cleanupPartEsp(inst)
        else
            cleanupModelEsp(inst)
        end
        return true
    end
    return false
end

-- ======= FAST CHECK: any features enabled (for early-out) =======
local function anyEnabled()
    return playerBoxEnabled or playerNameEnabled or npcBoxEnabled or containerBoxEnabled or containerTextEnabled or droppedBoxEnabled or droppedTextEnabled or exitTextEnabled
end

-- ======= RENDER (per-frame) =======
RunService.RenderStepped:Connect(function()
    if not Camera or not Camera.Parent then return end
    if not anyEnabled() then
        -- quick removal if all disabled
        clearBoxLines(Drawings.PlayerBoxLines); clearDrawings(Drawings.PlayerTexts)
        clearBoxLines(Drawings.NPCBoxLines); clearDrawings(Drawings.NPCTexts)
        clearBoxLines(Drawings.ContainerBoxLines); clearDrawings(Drawings.ContainerTexts)
        clearBoxLines(Drawings.DroppedBoxLines); clearDrawings(Drawings.DroppedTexts)
        clearDrawings(Drawings.ExitTexts)
        return
    end

    local cameraPos = Camera.CFrame.Position
    local renderList = {}

    -- build render list using tracked arrays (cheap distance checks)
    if playerBoxEnabled or playerNameEnabled then
        for _, entry in ipairs(tracked.players) do
            local plr, char = entry.player, entry.char
            if char and char.PrimaryPart and plr ~= LocalPlayer then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local hp, maxHp = humanoid.Health, humanoid.MaxHealth
                    if not (hp > 1 and hp <= maxHp) then
                        cleanupModelEsp(char)
                    else
                        local dist = (char.PrimaryPart.Position - cameraPos).Magnitude
                        -- immediate cleanup if out of range
                        if cleanupIfOutOfRange(char, "player", dist) then
                            -- nothing further for this instance
                        else
                            if dist <= playerESPRange then table.insert(renderList, {inst = char, kind = "player", player = plr, dist = dist}) end
                        end
                    end
                end
            end
        end
    end

    if npcBoxEnabled then
        for _, npc in ipairs(tracked.npcs) do
            if npc and npc.PrimaryPart then
                local humanoid = npc:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local hp, maxHp = humanoid.Health, humanoid.MaxHealth
                    if not (hp > 1 and hp <= maxHp and npc:IsDescendantOf(Workspace)) then
                        cleanupModelEsp(npc)
                    else
                        local dist = (npc.PrimaryPart.Position - cameraPos).Magnitude
                        if cleanupIfOutOfRange(npc, "npc", dist) then
                        else
                            if dist <= npcESPRange then table.insert(renderList, {inst = npc, kind = "npc", dist = dist}) end
                        end
                    end
                end
            end
        end
    end

    if containerBoxEnabled or containerTextEnabled then
        for _, cont in ipairs(tracked.containers) do
            if cont and cont.PrimaryPart then
                local dist = (cont.PrimaryPart.Position - cameraPos).Magnitude
                if cleanupIfOutOfRange(cont, "container", dist) then
                else
                    if dist <= containerESPRange then table.insert(renderList, {inst = cont, kind = "container", dist = dist}) end
                end
            end
        end
    end

    if droppedBoxEnabled or droppedTextEnabled then
        for _, item in ipairs(tracked.dropped) do
            if item and item.PrimaryPart then
                local dist = (item.PrimaryPart.Position - cameraPos).Magnitude
                if cleanupIfOutOfRange(item, "dropped", dist) then
                else
                    if dist <= droppedESPRange then table.insert(renderList, {inst = item, kind = "dropped", dist = dist}) end
                end
            end
        end
    end

    if exitTextEnabled then
        for _, exitPart in ipairs(tracked.exits) do
            if exitPart and exitPart.Position then
                local dist = (exitPart.Position - cameraPos).Magnitude
                if cleanupIfOutOfRange(exitPart, "exit", dist) then
                else
                    if dist <= exitESPRange then table.insert(renderList, {inst = exitPart, kind = "exit", dist = dist}) end
                end
            end
        end
    end

    -- sort so closest draw last (on top)
    table.sort(renderList, function(a,b) return a.dist < b.dist end)

    -- render entries
    for _, info in ipairs(renderList) do
        local kind, inst, dist = info.kind, info.inst, info.dist

        -- PLAYER
        if kind == "player" then
            local plr, char = info.player, inst
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")

            -- BOX
            if playerBoxEnabled then
                local cornersT = getCornersTable(char)
                if writeModelCorners(char, cornersT, 1.8) then
                    local lines = getBoxLines(Drawings.PlayerBoxLines, char)
                    local corners2D = {}
                    local okOn = true
                    for i = 1, 8 do
                        local sPos, ons = WorldToScreenPoint(cornersT[i])
                        if not ons then okOn = false; break end
                        corners2D[i] = sPos
                    end

                    if okOn then
                        local boxColor = Colors.PlayerBox
                        if humanoid then boxColor = getHealthColor(humanoid.Health, humanoid.MaxHealth) end
                        for ei, edge in ipairs(EDGES) do
                            local line = lines[ei]
                            line.Visible = true
                            line.From = corners2D[edge[1]]
                            line.To = corners2D[edge[2]]
                            line.Color = boxColor
                        end
                    else
                        for _, line in ipairs(lines) do line.Visible = false end
                    end
                end
            else
                if Drawings.PlayerBoxLines[char] then clearBoxLines({[char] = Drawings.PlayerBoxLines[char]}); Drawings.PlayerBoxLines[char] = nil end
            end

            -- NAME TEXT
            if playerNameEnabled then
                local text = getDrawing(Drawings.PlayerTexts, char, "Text")
                local screenPos, onScreen = WorldToScreenPoint(char.PrimaryPart.Position + Vector3.new(0,3,0))
                if onScreen then
                    text.Visible = true
                    text.Position = screenPos
                    text.Text = string.format("%s [%dm]", plr.Name, math.floor(dist))
                    text.Color = Colors.PlayerText
                    -- scaling: tune scaleFactor to taste
                    local baseSize = 18
                    local scaleFactor = 200
                    text.Size = math.clamp(baseSize * (scaleFactor / (dist + 1)), 14, 36)
                else
                    text.Visible = false
                end
            else
                if Drawings.PlayerTexts[char] then safeRemove(Drawings.PlayerTexts[char]); Drawings.PlayerTexts[char] = nil end
            end

        -- NPC
        elseif kind == "npc" then
            local npc = inst
            local humanoid = npc:FindFirstChildOfClass("Humanoid")

            if npcBoxEnabled then
                local cornersT = getCornersTable(npc)
                if writeModelCorners(npc, cornersT, 1.8) then
                    local lines = getBoxLines(Drawings.NPCBoxLines, npc)
                    local corners2D = {}
                    local okOn = true
                    for i = 1, 8 do
                        local sPos, ons = WorldToScreenPoint(cornersT[i])
                        if not ons then okOn = false; break end
                        corners2D[i] = sPos
                    end
                    if okOn then
                        local boxColor = Colors.NPCBox
                        if humanoid then boxColor = getHealthColor(humanoid.Health, humanoid.MaxHealth) end
                        for ei, edge in ipairs(EDGES) do
                            local line = lines[ei]
                            line.Visible = true
                            line.From = corners2D[edge[1]]
                            line.To = corners2D[edge[2]]
                            line.Color = boxColor
                        end
                    else
                        for _, line in ipairs(lines) do line.Visible = false end
                    end
                end
            else
                if Drawings.NPCBoxLines[npc] then clearBoxLines({[npc] = Drawings.NPCBoxLines[npc]}); Drawings.NPCBoxLines[npc] = nil end
                if Drawings.NPCTexts[npc] then safeRemove(Drawings.NPCTexts[npc]); Drawings.NPCTexts[npc] = nil end
            end

            local text = getDrawing(Drawings.NPCTexts, npc, "Text")
            local sPos, ons = WorldToScreenPoint(npc.PrimaryPart.Position + Vector3.new(0,3,0))
            if ons then
                text.Visible = true
                text.Position = sPos
                text.Text = string.format("%s [%dm]", npc.Name, math.floor(dist))
                text.Color = Colors.NPCText
                local baseSize = 16
                local scaleFactor = 200
                text.Size = math.clamp(baseSize * (scaleFactor / (dist + 1)), 12, 32)
            else
                text.Visible = false
            end

        -- Container
        elseif kind == "container" then
            local cont = inst
            if containerBoxEnabled then
                local cornersT = getCornersTable(cont)
                if writeModelCorners(cont, cornersT, 1) then
                    local lines = getBoxLines(Drawings.ContainerBoxLines, cont)
                    local corners2D = {}
                    local okOn = true
                    for i = 1, 8 do
                        local sPos, ons = WorldToScreenPoint(cornersT[i])
                        if not ons then okOn = false; break end
                        corners2D[i] = sPos
                    end
                    if okOn then
                        for ei, edge in ipairs(EDGES) do
                            local line = lines[ei]
                            line.Visible = true
                            line.From = corners2D[edge[1]]
                            line.To = corners2D[edge[2]]
                            line.Color = Colors.ContainerBox
                        end
                    else
                        for _, line in ipairs(lines) do line.Visible = false end
                    end
                end
            else
                if Drawings.ContainerBoxLines[cont] then clearBoxLines({[cont] = Drawings.ContainerBoxLines[cont]}); Drawings.ContainerBoxLines[cont] = nil end
            end

            if containerTextEnabled then
                local text = getDrawing(Drawings.ContainerTexts, cont, "Text")
                local sPos, ons = WorldToScreenPoint(cont.PrimaryPart.Position + Vector3.new(0,3,0))
                if ons then
                    text.Visible = true
                    text.Position = sPos
                    text.Text = string.format("%s [%dm]", cont.Name, math.floor(dist))
                    text.Color = Colors.ContainerText
                    local baseSize = 14
                    local scaleFactor = 200
                    text.Size = math.clamp(baseSize * (scaleFactor / (dist + 1)), 12, 28)
                else
                    text.Visible = false
                end
            else
                if Drawings.ContainerTexts[cont] then safeRemove(Drawings.ContainerTexts[cont]); Drawings.ContainerTexts[cont] = nil end
            end

        -- Dropped
        elseif kind == "dropped" then
            local item = inst
            if droppedBoxEnabled then
                local cornersT = getCornersTable(item)
                if writeModelCorners(item, cornersT, 1) then
                    local lines = getBoxLines(Drawings.DroppedBoxLines, item)
                    local corners2D = {}
                    local okOn = true
                    for i = 1, 8 do
                        local sPos, ons = WorldToScreenPoint(cornersT[i])
                        if not ons then okOn = false; break end
                        corners2D[i] = sPos
                    end
                    if okOn then
                        for ei, edge in ipairs(EDGES) do
                            local line = lines[ei]
                            line.Visible = true
                            line.From = corners2D[edge[1]]
                            line.To = corners2D[edge[2]]
                            line.Color = Colors.DroppedBox
                        end
                    else
                        for _, line in ipairs(lines) do line.Visible = false end
                    end
                end
            else
                if Drawings.DroppedBoxLines[item] then clearBoxLines({[item] = Drawings.DroppedBoxLines[item]}); Drawings.DroppedBoxLines[item] = nil end
            end

            if droppedTextEnabled then
                local text = getDrawing(Drawings.DroppedTexts, item, "Text")
                local sPos, ons = WorldToScreenPoint(item.PrimaryPart.Position + Vector3.new(0,3,0))
                if ons then
                    text.Visible = true
                    text.Position = sPos
                    text.Text = string.format("%s [%dm]", item.Name, math.floor(dist))
                    text.Color = Colors.DroppedText
                    local baseSize = 12
                    local scaleFactor = 200
                    text.Size = math.clamp(baseSize * (scaleFactor / (dist + 1)), 12, 24)
                else
                    text.Visible = false
                end
            else
                if Drawings.DroppedTexts[item] then safeRemove(Drawings.DroppedTexts[item]); Drawings.DroppedTexts[item] = nil end
            end

        -- Exit
        elseif kind == "exit" then
            local exitPart = inst
            if exitTextEnabled then
                local text = getDrawing(Drawings.ExitTexts, exitPart, "Text")
                local sPos, ons = WorldToScreenPoint(exitPart.Position + Vector3.new(0,3,0))
                if ons then
                    text.Visible = true
                    text.Position = sPos
                    text.Text = string.format("%s [%dm]", exitPart.Name, math.floor(dist))
                    text.Color = Colors.ExitText
                    local baseSize = 12
                    local scaleFactor = 200
                    text.Size = math.clamp(baseSize * (scaleFactor / (dist + 1)), 12, 24)
                else
                    text.Visible = false
                end
            else
                if Drawings.ExitTexts[exitPart] then safeRemove(Drawings.ExitTexts[exitPart]); Drawings.ExitTexts[exitPart] = nil end
            end
        end
    end

    -- Lightweight prune: remove drawings for instances not in renderList to avoid stale drawings
    local function prune(tbl)
        for inst, _ in pairs(tbl) do
            if typeof(inst) == "Instance" then
                local still = false
                for _, info in ipairs(renderList) do
                    if info.inst == inst then still = true; break end
                end
                if not still then
                    if type(tbl[inst]) == "table" then for _, v in ipairs(tbl[inst]) do safeRemove(v) end
                    else safeRemove(tbl[inst]) end
                    tbl[inst] = nil
                end
            end
        end
    end

    prune(Drawings.PlayerBoxLines); prune(Drawings.PlayerTexts)
    prune(Drawings.NPCBoxLines); prune(Drawings.NPCTexts)
    prune(Drawings.ContainerBoxLines); prune(Drawings.ContainerTexts)
    prune(Drawings.DroppedBoxLines); prune(Drawings.DroppedTexts)
    prune(Drawings.ExitTexts)
end)

local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.new(1, 0, 0)
fovCircle.Thickness = 1
fovCircle.Transparency = 1
fovCircle.NumSides = 100
fovCircle.Filled = false

RunService.RenderStepped:Connect(function()
    fovCircle.Visible = fovEnabled
    if fovEnabled then
        local center = Camera.ViewportSize / 2
        fovCircle.Position = Vector2.new(center.X, center.Y)
        fovCircle.Radius = fovSize
    end
end)

-- Cache ignore list for local player once
local cachedIgnoreList = {}
local function updateIgnoreList(targetChar)
    cachedIgnoreList = {}
    if LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(cachedIgnoreList, part) -- ignore own parts
            end
        end
    end
    if targetChar then
        for _, part in ipairs(targetChar:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(cachedIgnoreList, part)
            end
        end
    end
end

-- Visibility check that ignores own character
local visibilityCache = {}
local VISIBILITY_CACHE_TIME = 0.15

local function isVisible(targetChar)
    local now = tick()
    if visibilityCache[targetChar] and now - visibilityCache[targetChar].time < VISIBILITY_CACHE_TIME then
        return visibilityCache[targetChar].visible
    end

    local head = targetChar:FindFirstChild("Head")
    if not head then return false end

    updateIgnoreList(targetChar)
    local parts = Camera:GetPartsObscuringTarget({head.Position}, cachedIgnoreList)
    local visible = #parts == 0

    visibilityCache[targetChar] = { visible = visible, time = now }
    return visible
end

-- Distance from screen center
local function getScreenDist(pos2D)
    local center = Camera.ViewportSize / 2
    return (pos2D - center).Magnitude
end

-- Get all valid targets
local function getTargets()
    local targets = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
            table.insert(targets, plr.Character)
        end
    end
    if targetNpcsToo and Workspace:FindFirstChild("AiZones") then
        for _, npc in ipairs(Workspace.AiZones:GetDescendants()) do
            if npc:IsA("Model") and npc:FindFirstChild("Head") and not Players:GetPlayerFromCharacter(npc) then
                table.insert(targets, npc)
            end
        end
    end
    return targets
end

-- Find closest by body first, then mouse
local function getClosestTarget()
    local bestTarget = nil
    local minDist = fovSize

    local targets = getTargets()
    for _, char in ipairs(targets) do
        -- Ignore models inside LocalPlayer's model and other players' models
        if char ~= LocalPlayer.Character and not char:IsDescendantOf(LocalPlayer.Character) then
            local plr = Players:GetPlayerFromCharacter(char)
            if not plr or (plr and plr ~= LocalPlayer) then
                local targetPart = char:FindFirstChild("Head")
                if targetPart then
                    local distFromCam = (Camera.CFrame.Position - targetPart.Position).Magnitude
                    if distFromCam <= aimlockMaxRange then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local dist = getScreenDist(Vector2.new(screenPos.X, screenPos.Y))
                            if dist <= fovSize then
                                if not useVisibilityCheck or isVisible(char) then
                                    if dist < minDist then
                                        minDist = dist
                                        bestTarget = targetPart
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end



-- Lock persistence
local targetUpdateInterval = 0.1
local lastTargetUpdate = 0

RunService.RenderStepped:Connect(function()
    if aimlockEnabled and holdingRightClick then
        if not lockedTarget then
            local now = tick()
            if (now - lastTargetUpdate) > targetUpdateInterval then
                lockedTarget = getClosestTarget()
                lastTargetUpdate = now
            end
        else
            -- Check visibility only if required
            if useVisibilityCheck and not isVisible(lockedTarget.Parent) then
                lockedTarget = nil
                return
            end
        end

        if lockedTarget then
            local origin = Camera.CFrame.Position
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(origin, lockedTarget.Position), smoothness)
        end
    else
        lockedTarget = nil
    end
end)

-- Input handlers
UIS.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 and not gameProcessed then
        holdingRightClick = true
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        holdingRightClick = false
        lockedTarget = nil
    end
end)

-- Fullbright
local function setFullbright(state)
    if state then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 10
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.ClockTime = 12
    else
        for k, v in pairs(originalLighting) do Lighting[k] = v end
    end
end

-- Build list of player folder names for the dropdown
local playerNames = {}
for _, folder in ipairs(playersFolder:GetChildren()) do
    if folder:IsA("Folder") then
        table.insert(playerNames, folder.Name)
    end
end

-- Create the Player selection dropdown
itemTab:CreateParagraph({ Title = "The Callback Errors Are Normal", Content = "Thanks to @TheMentol for the idea" })

local playerDropdown = itemTab:CreateDropdown({
    Name = "Select Player",
    Options = playerNames,
    CurrentOption = {playerNames[1] or "No Players"},
    MultipleOptions = false,
    Flag = "SelectedPlayer"
})

-- Initialize inventory category dropdowns with default "No Items Found"
local gunsDropdown = itemTab:CreateDropdown({
    Name = "Guns",
    Options = {"No Items Found"},
    CurrentOption = {"No Items Found"},
    MultipleOptions = false
})
local equipmentDropdown = itemTab:CreateDropdown({
    Name = "Equipment",
    Options = {"No Items Found"},
    CurrentOption = {"No Items Found"},
    MultipleOptions = false
})
local clothingDropdown = itemTab:CreateDropdown({
    Name = "Clothing",
    Options = {"No Items Found"},
    CurrentOption = {"No Items Found"},
    MultipleOptions = false
})
local clothingInventoryDropdown = itemTab:CreateDropdown({
    Name = "Inventory",
    Options = {"No Items Found"},
    CurrentOption = {"No Items Found"},
    MultipleOptions = false
})

-- Helper function to collect string values from a given folder
local function collectStrings(folder)
    local items = {}
    if folder then
        for _, val in ipairs(folder:GetChildren()) do
            if val:IsA("StringValue") then
                table.insert(items, val.Name)
            end
        end
    end
    if #items == 0 then
        items = {"No Items Found"}
    end
    return items
end

-- Create the "Get Inv" button
itemTab:CreateButton({
    Name = "Get Players Inventory",
    Callback = function()
        -- Get selected player name
        local selectedPlayer = playerDropdown.CurrentOption[1]
        if not selectedPlayer or selectedPlayer == "" then
            Rayfield:Notify({Title = "Error", Content = "No player selected", Duration = 3})
            return
        end

        -- Find the player folder in ReplicatedStorage
        local playerFolder = playersFolder:FindFirstChild(selectedPlayer)
        if not playerFolder then
            Rayfield:Notify({Title = "Error", Content = "Player data not found", Duration = 3})
            return
        end

        -- Collect items from each category
        local gunsList = collectStrings(playerFolder:FindFirstChild("Inventory"))
        local equipmentList = collectStrings(playerFolder:FindFirstChild("Equipment"))

        local clothingList = {}
        local clothingInvList = {}
        local clothingFolder = playerFolder:FindFirstChild("Clothing")
        if clothingFolder then
            for _, cloth in ipairs(clothingFolder:GetChildren()) do
                if cloth:IsA("StringValue") then
                    table.insert(clothingList, cloth.Name)
                    -- Check for nested Inventory folder under this clothing item
                    local invFolder = cloth:FindFirstChild("Inventory")
                    if invFolder then
                        for _, innerVal in ipairs(invFolder:GetChildren()) do
                            if innerVal:IsA("StringValue") then
                                table.insert(clothingInvList, innerVal.Name)
                            end
                        end
                    end
                end
            end
        end
        if #clothingList == 0 then
            clothingList = {"No Items Found"}
        end
        if #clothingInvList == 0 then
            clothingInvList = {"No Items Found"}
        end

        -- Update the dropdowns with the new lists
        gunsDropdown:Refresh(gunsList)
        gunsDropdown:Set({gunsList[1]})

        equipmentDropdown:Refresh(equipmentList)
        equipmentDropdown:Set({equipmentList[1]})

        clothingDropdown:Refresh(clothingList)
        clothingDropdown:Set({clothingList[1]})

        clothingInventoryDropdown:Refresh(clothingInvList)
        clothingInventoryDropdown:Set({clothingInvList[1]})
    end
})

-- Track which players are inside each notification range
local playersInPrimaryRange = {}
local playersInSecondaryRange = {}

-- Helper function to notify player entry
local function notifyPlayerEntry()
    Rayfield:Notify({
        Title = "Incoming Player!",
        Content = "There's Someone In Your Area",
        Duration = 6.5,
        Image = 4483362458,
    })
end

-- Helper function to notify player exit
local function notifyPlayerExit()
    Rayfield:Notify({
        Title = "Departing Player!",
        Content = "Someone Just Left Your Area",
        Duration = 6.5,
        Image = 4483362458,
    })
end

-- Notification logic loop
task.spawn(function()
    while task.wait(0.5) do
        if playerNotificationEnabled or secondaryNotificationEnabled then
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local players = Players:GetPlayers()
                for _, plr in ipairs(players) do
                    if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        local targetRoot = plr.Character.HumanoidRootPart
                        local dist = (targetRoot.Position - root.Position).Magnitude

                        -- Primary notification range logic
                        if playerNotificationEnabled then
                            if dist <= playerNotificationRange then
                                if not playersInPrimaryRange[plr] then
                                    playersInPrimaryRange[plr] = true
                                    notifyPlayerEntry()
                                end
                            else
                                if playersInPrimaryRange[plr] then
                                    playersInPrimaryRange[plr] = nil
                                    notifyPlayerExit()
                                end
                            end
                        end

                        -- Secondary notification range logic
                        if secondaryNotificationEnabled then
                            if dist <= secondaryNotificationRange then
                                if not playersInSecondaryRange[plr] then
                                    playersInSecondaryRange[plr] = true
                                    notifyPlayerEntry()
                                end
                            else
                                if playersInSecondaryRange[plr] then
                                    playersInSecondaryRange[plr] = nil
                                    notifyPlayerExit()
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- // Auto Pickup Loop
task.spawn(function()
    while task.wait(0.1) do
        if autoPickupEnabled then
            local closestItem
            local closestDist = math.huge
            local root = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            
            if root then
                for _, item in ipairs(workspace:WaitForChild("DroppedItems"):GetChildren()) do
                    if item:IsA("Model") and item.PrimaryPart then
                        local dist = (item.PrimaryPart.Position - root.Position).Magnitude
                        if dist <= 14.5 and dist < closestDist then
                            closestItem = item
                            closestDist = dist
                        end
                    end
                end

                if closestItem then
                    local args = {
                        closestItem,
                        Vector3.new(closestItem.PrimaryPart.Position.X, closestItem.PrimaryPart.Position.Y, closestItem.PrimaryPart.Position.Z)
                    }
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Take"):FireServer(unpack(args))
                end
            end

            task.wait(autoPickupSpeed)
        end
    end
end)

-- UI Toggles
combatTab:CreateToggle({Name = "Enable Aimlock", CurrentValue = false, Callback = function(v) aimlockEnabled = v fovEnabled = v end})
combatTab:CreateToggle({Name = "Target NPCs Too", CurrentValue = false, Callback = function(v) targetNpcsToo = v end})
combatTab:CreateToggle({Name = "Visibility Check (Buggy With Some Guns/Scopes)", CurrentValue = false, Callback = function(v) useVisibilityCheck = v end})
combatTab:CreateSlider({Name = "FOV Size", Range = {30, 500}, Increment = 1, CurrentValue = 100, Suffix = "px", Callback = function(v) fovSize = v end})
combatTab:CreateSlider({Name = "Strength", Range = {0.01, 1}, Increment = 0.01, CurrentValue = 0.1, Callback = function(v) smoothness = v end})
combatTab:CreateSlider({Name = "Aimlock Max Range", Range = {50, 8000}, Increment = 50, CurrentValue = aimlockMaxRange, Callback = function(v) aimlockMaxRange = v end})

visualsTab:CreateToggle({Name="Player Box ESP", CurrentValue=false, Callback=function(v) playerBoxEnabled=v if not v then clearAdornments("PlayersBox") end end})
visualsTab:CreateToggle({Name="Player Name ESP", CurrentValue=false, Callback=function(v) playerNameEnabled=v if not v then clearAdornments("PlayersName") end end})
visualsTab:CreateToggle({Name="NPC ESP", CurrentValue=false, Callback=function(v) npcBoxEnabled=v if not v then clearAdornments("NPCsBox") clearAdornments("NPCsName") end end})
visualsTab:CreateToggle({Name="Container Box ESP", CurrentValue=false, Callback=function(v) containerBoxEnabled=v if not v then clearAdornments("ContainersBox") end end})
visualsTab:CreateToggle({Name="Container Name ESP", CurrentValue=false, Callback=function(v) containerTextEnabled=v if not v then clearAdornments("ContainersName") end end})
visualsTab:CreateToggle({Name="Dropped Item Box ESP", CurrentValue=false, Callback=function(v) droppedBoxEnabled=v if not v then clearAdornments("DroppedItemsBox") end end})
visualsTab:CreateToggle({Name="Dropped Item Name ESP", CurrentValue=false, Callback=function(v) droppedTextEnabled=v if not v then clearAdornments("DroppedItemsName") end end})
visualsTab:CreateToggle({Name="Exit Name ESP", CurrentValue=false, Callback=function(v) exitTextEnabled=v if not v then clearAdornments("ExitsName") end end})
local espDistanceSection = visualsTab:CreateSection("ESP Distance Sliders")
visualsTab:CreateSlider({
    Name = "Player ESP Range",
    Range = {50, 3000},
    Increment = 50,
    CurrentValue = playerESPRange,
    Suffix = " studs",
    Callback = function(value)
        playerESPRange = value
    end
})

visualsTab:CreateSlider({
    Name = "NPC ESP Range",
    Range = {50, 3000},
    Increment = 50,
    CurrentValue = npcESPRange,
    Suffix = " studs",
    Callback = function(value)
        npcESPRange = value
    end
})

visualsTab:CreateSlider({
    Name = "Container Max Range",
    Range = {50, 3000},
    Increment = 50,
    CurrentValue = containerESPRange,
    Suffix = " studs",
    Callback = function(value)
        containerESPRange = value
    end
})

visualsTab:CreateSlider({
    Name = "Dropped Item Max Range",
    Range = {50, 3000},
    Increment = 50,
    CurrentValue = droppedESPRange,
    Suffix = " studs",
    Callback = function(value)
        droppedESPRange = value
    end
})

visualsTab:CreateSlider({
    Name = "Exit Max Range",
    Range = {50, 3000},
    Increment = 50,
    CurrentValue = exitESPRange,
    Suffix = " studs",
    Callback = function(value)
        exitESPRange = value
    end
})

miscTab:CreateSlider({
	Name = "FOV Value",
	Range = {70, 120},
	Increment = 1,
	Suffix = "°",
	CurrentValue = selectedFOV,
	Callback = function(value)
		selectedFOV = value
	end
})

miscTab:CreateButton({
	Name = "Apply FOV (Takes A Few Seconds)",
	Callback = function()
		local args = {
			{
				GameplaySettings = {
					DefaultFOV = selectedFOV
				}
			}
		}
		game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("UpdateSettings"):FireServer(unpack(args))
	end
})

miscTab:CreateToggle({Name = "Fullbright", CurrentValue = false, Callback = function(v) fullbrightEnabled = v setFullbright(v) end})

miscTab:CreateButton({
    Name = "No Fog",
    Callback = function()
        Lighting.FogEnd = 1e10
        Lighting.FogStart = 0
        Lighting.FogColor = Color3.new(1, 1, 1)
    end
})

notifTab:CreateParagraph({Title = "This Tab Is For Warnings When Players Get Too Close", Content = "Use the sliders to choose how close they can get before warning you"})

notifTab:CreateToggle({
    Name = "Player Warning",
    CurrentValue = false,
    Flag = "PlayerNotificationToggle",
    Callback = function(value)
        playerNotificationEnabled = value
        if not value then
            playersInPrimaryRange = {} -- Clear tracking on disable
        end
    end
})

notifTab:CreateSlider({
    Name = "Player Range",
    Range = {50, 2000},
    Increment = 50,
    CurrentValue = playerNotificationRange,
    Suffix = " studs",
    Callback = function(value)
        playerNotificationRange = value
    end
})

notifTab:CreateToggle({
    Name = "Secondary Player Warning",
    CurrentValue = false,
    Flag = "SecondaryPlayerNotificationToggle",
    Callback = function(value)
        secondaryNotificationEnabled = value
        if not value then
            playersInSecondaryRange = {} -- Clear tracking on disable
        end
    end
})

notifTab:CreateSlider({
    Name = "Secondary Range",
    Range = {50, 2000},
    Increment = 50,
    CurrentValue = secondaryNotificationRange,
    Suffix = " studs",
    Callback = function(value)
        secondaryNotificationRange = value
    end
})

riskyTab:CreateParagraph({Title = "This Tab Is For Risky/In Beta Features", Content = "Please proceed with caution!"})

riskyTab:CreateButton({
    Name = "Remove Trees/Plants (May Rubberband And Get Kicked If You Walk Where A Tree Was)",
    Callback = function()
        local player = game:GetService("Players").LocalPlayer
        local workspace = game:GetService("Workspace")

        -- Remove from SpawnerZones.Foliage
        local spawnerFoliage = workspace:FindFirstChild("SpawnerZones")
        if spawnerFoliage and spawnerFoliage:FindFirstChild("Foliage") then
            for _, folder in ipairs(spawnerFoliage.Foliage:GetChildren()) do
                if folder:IsA("Folder") then
                    folder:Destroy()
                end
            end
        end

        -- Remove parts from NoCollision.FoliageZones
        local noCollisionFoliage = workspace:FindFirstChild("NoCollision")
        if noCollisionFoliage and noCollisionFoliage:FindFirstChild("FoliageZones") then
            for _, obj in ipairs(noCollisionFoliage.FoliageZones:GetChildren()) do
                if obj:IsA("BasePart") then
                    obj:Destroy()
                end
            end
        end
    end
})

riskyTab:CreateToggle({
    Name = "Auto Pickup Items",
    CurrentValue = false,
    Flag = "AutoPickup",
    Callback = function(Value)
        autoPickupEnabled = Value
    end
})

riskyTab:CreateSlider({
    Name = "Pickup Speed (Seconds)",
    Range = {0.1, 3.5},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = autoPickupSpeed,
    Flag = "PickupSpeed",
    Callback = function(Value)
        autoPickupSpeed = Value
    end
})

dupeTab:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        local TeleportService = game:GetService("TeleportService")
        local localPlayer = Players.LocalPlayer
        if not localPlayer then return end
        local placeId = game.PlaceId
        local playerId = localPlayer.UserId
        -- Teleport the player to the same place to force rejoin
        pcall(function()
            TeleportService:Teleport(placeId, localPlayer)
        end)
    end,
})

dupeTab:CreateButton({
   Name = "Setup Dupe",
   Callback = function()
ReplicatedStorage.Remotes.ChangeFireMode:FireServer(ReplicatedStorage.Players[game.Players.LocalPlayer.Name].Equipment.DV2, "\255")
   end,
})

dupeTab:CreateParagraph({Title = "Finally Got A Working Dupe", Content = "Here's what you need to do"})
dupeTab:CreateParagraph({Title = "Step 1:", Content = "Join the server and take all the items you want to dupe out of the vault, "})
dupeTab:CreateParagraph({Title = "Step 2:", Content = "Press the Rejoin Server button and join the server again"})
dupeTab:CreateParagraph({Title = "Step 3:", Content = "Press the Setup Dupe button then put the items into the vault that you want to dupe"})
dupeTab:CreateParagraph({Title = "Step 4:", Content = "Press the rejoin button again and enjoy (:"})
dupeTab:CreateParagraph({Title = "To Loop Its Simple", Content = "After you collect the duped items from the vault just rejoin then hit the Setup Dupe button again"})

creditsTab:CreateParagraph({ Title = "Scripted by breakneckv09", Content = "Thanks for using my script!" })
creditsTab:CreateButton({ Name = "Official Server Invite", Callback = function() setclipboard("discord.gg/faV3GCjebC") Rayfield:Notify({Title = "Copied Link!", Content = "Discord invite copied to clipboard.", Duration = 4}) end })