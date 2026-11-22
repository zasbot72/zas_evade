-- ============================================================
-- ZAYN SUITE | Evade Roblox
-- Executor: Delta | Engine: Luau
-- Mechanism: HumanoidRootPart + Drawing + hookmetamethod
-- ============================================================

local CONFIG = {
    -- Speed
    SPEED           = true,
    WALK_SPEED      = 28,        -- default 16

    -- Auto Jump
    AUTO_JUMP       = false,     -- di Evade lebih baik manual
    JUMP_POWER      = 80,

    -- Infinite Stamina
    INF_STAMINA     = true,

    -- No Clip (phase through walls)
    NOCLIP          = false,     -- toggle Q
    NOCLIP_KEY      = Enum.KeyCode.X,

    -- ESP
    ESP             = true,
    ESP_BOX         = true,
    NAME_TAG        = true,
    DISTANCE        = true,
    MONSTER_ESP     = true,      -- highlight monster/killer
    ESP_COLOR_PLR   = Color3.fromRGB(0, 255, 100),
    ESP_COLOR_MON   = Color3.fromRGB(255, 0, 0),

    -- Teleport to exit
    TP_EXIT         = false,
    TP_KEY          = Enum.KeyCode.E,

    DEBUG           = true,
}

-- ============================================================
-- SERVICES
-- ============================================================
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInputSvc  = game:GetService("UserInputService")
local lp            = Players.LocalPlayer
local camera        = workspace.CurrentCamera

local char, hum, hrp

local function getChar()
    char = lp.Character or lp.CharacterAdded:Wait()
    hum  = char:WaitForChild("Humanoid", 5)
    hrp  = char:WaitForChild("HumanoidRootPart", 5)
end

getChar()
lp.CharacterAdded:Connect(function()
    task.wait(1)
    getChar()
    if CONFIG.SPEED then hum.WalkSpeed = CONFIG.WALK_SPEED end
    if CONFIG.AUTO_JUMP then hum.JumpPower = CONFIG.JUMP_POWER end
end)

-- ============================================================
-- 1. SPEED HACK
-- ============================================================
if CONFIG.SPEED then
    task.spawn(function()
        while task.wait(0.1) do
            if hum then
                hum.WalkSpeed = CONFIG.WALK_SPEED
            end
        end
    end)
end

-- ============================================================
-- 2. INFINITE STAMINA
-- Evade pakai stamina bar → spoof via RemoteEvent / local value
-- ============================================================
if CONFIG.INF_STAMINA then
    task.spawn(function()
        while task.wait(0.1) do
            -- cari stamina value di character / playerGui
            local gui = lp.PlayerGui
            for _, v in ipairs(char:GetDescendants()) do
                if v.Name:lower():find("stamina") and v:IsA("NumberValue") then
                    v.Value = v.MaxValue or 100
                end
            end
            -- coba dari gui juga
            for _, v in ipairs(gui:GetDescendants()) do
                if v.Name:lower():find("stamina") and v:IsA("NumberValue") then
                    v.Value = 100
                end
            end
        end
    end)
end

-- ============================================================
-- 3. NO CLIP
-- ============================================================
if CONFIG.NOCLIP then
    local noclipActive = false

    UserInputSvc.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == CONFIG.NOCLIP_KEY then
            noclipActive = not noclipActive
            if CONFIG.DEBUG then
                print("[ZAYN] Noclip:", noclipActive)
            end
        end
    end)

    RunService.Stepped:Connect(function()
        if noclipActive and char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

-- ============================================================
-- 4. ESP
-- ============================================================
local espPool = {}

local function newDraw(type_, props)
    local d = Drawing.new(type_)
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function buildESP(player)
    if player == lp then return end
    espPool[player] = {
        box  = newDraw("Square", {
            Thickness = 1.5, Filled = false,
            Color = CONFIG.ESP_COLOR_PLR, Visible = false
        }),
        name = newDraw("Text", {
            Size = 13, Font = Drawing.Fonts.UI,
            Color = CONFIG.ESP_COLOR_PLR,
            Outline = true, Visible = false, Text = player.Name
        }),
        dist = newDraw("Text", {
            Size = 11, Font = Drawing.Fonts.UI,
            Color = Color3.fromRGB(255,255,255),
            Outline = true, Visible = false, Text = ""
        }),
    }
end

local function clearESP(player)
    if espPool[player] then
        for _, d in pairs(espPool[player]) do d:Remove() end
        espPool[player] = nil
    end
end

if CONFIG.ESP then
    for _, p in ipairs(Players:GetPlayers()) do buildESP(p) end
    Players.PlayerAdded:Connect(buildESP)
    Players.PlayerRemoving:Connect(clearESP)

    -- Monster ESP — cari NPC killer di workspace
    local function findMonster()
        for _, obj in ipairs(workspace:GetChildren()) do
            -- Evade monster biasanya ada Humanoid tapi bukan player
            local h = obj:FindFirstChild("Humanoid")
            local r = obj:FindFirstChild("HumanoidRootPart")
            local isPlayer = false
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character == obj then isPlayer = true break end
            end
            if h and r and not isPlayer then
                return obj, r
            end
        end
        return nil, nil
    end

    -- monster drawing
    local monBox = newDraw("Square", {
        Thickness = 2, Filled = false,
        Color = CONFIG.ESP_COLOR_MON, Visible = false
    })
    local monLabel = newDraw("Text", {
        Size = 14, Font = Drawing.Fonts.UI,
        Color = CONFIG.ESP_COLOR_MON,
        Outline = true, Visible = false, Text = "⚠ MONSTER"
    })

    RunService.RenderStepped:Connect(function()
        if not hrp then return end

        -- player esp
        for player, obj in pairs(espPool) do
            local pc = player.Character
            local show = false
            if pc then
                local root = pc:FindFirstChild("HumanoidRootPart")
                local ph   = pc:FindFirstChild("Humanoid")
                if root and ph and ph.Health > 0 then
                    local sp, onScreen = camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        show = true
                        local dist = (hrp.Position - root.Position).Magnitude
                        local scale = 1 / sp.Z * 100
                        local w, h  = scale * 2, scale * 3.5

                        if CONFIG.ESP_BOX then
                            obj.box.Size     = Vector2.new(w, h)
                            obj.box.Position = Vector2.new(sp.X - w/2, sp.Y - h/2)
                            obj.box.Visible  = true
                        end
                        if CONFIG.NAME_TAG then
                            obj.name.Text     = player.Name
                            obj.name.Position = Vector2.new(sp.X, sp.Y - h/2 - 16)
                            obj.name.Visible  = true
                        end
                        if CONFIG.DISTANCE then
                            obj.dist.Text     = string.format("%.0fm", dist)
                            obj.dist.Position = Vector2.new(sp.X, sp.Y + h/2 + 2)
                            obj.dist.Visible  = true
                        end
                    end
                end
            end
            if not show then
                obj.box.Visible  = false
                obj.name.Visible = false
                obj.dist.Visible = false
            end
        end

        -- monster esp
        if CONFIG.MONSTER_ESP then
            local mon, monRoot = findMonster()
            if mon and monRoot then
                local sp, onScreen = camera:WorldToViewportPoint(monRoot.Position)
                if onScreen then
                    local scale = 1 / sp.Z * 100
                    local w, h  = scale * 2.5, scale * 4
                    monBox.Size     = Vector2.new(w, h)
                    monBox.Position = Vector2.new(sp.X - w/2, sp.Y - h/2)
                    monBox.Visible  = true
                    monLabel.Position = Vector2.new(sp.X, sp.Y - h/2 - 18)
                    monLabel.Visible  = true
                else
                    monBox.Visible   = false
                    monLabel.Visible = false
                end
            else
                monBox.Visible   = false
                monLabel.Visible = false
            end
        end
    end)
end

-- ============================================================
-- 5. TP TO EXIT (cari part bernama Exit/Door di workspace)
-- ============================================================
if CONFIG.TP_EXIT then
    UserInputSvc.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == CONFIG.TP_KEY then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name:lower():find("exit") or obj.Name:lower():find("door") then
                    if obj:IsA("BasePart") then
                        hrp.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                        if CONFIG.DEBUG then print("[ZAYN] TP to:", obj.Name) end
                        break
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- LOADED
-- ============================================================
print("[ZAYN] Evade Suite loaded!")
print("Speed:", CONFIG.WALK_SPEED, "| ESP:", CONFIG.ESP, "| Stamina:", CONFIG.INF_STAMINA)
