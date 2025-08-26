-- 使用完全闭合FOV圆圈的Aimbot脚本
local Aimbot = {
    Enabled = false,
    Settings = {
        FOV = 30,
        MaxDistance = 400,
        MaxTransparency = 0.1,
        TeamCheck = false,
        WallCheck = true,
        AimPart = "Head"
    },
    Connections = {},
    Target = nil,
    FOVGui = nil,
    FOVCircle = nil
}

local function createFOVCircle()
    local player = game.Players.LocalPlayer
    local camera = workspace.CurrentCamera
    
    -- 创建FOV圆圈容器
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimbotFOV"
    screenGui.Parent = player.PlayerGui
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = Aimbot.Enabled
    
    -- 创建圆形Frame
    local circle = Instance.new("Frame")
    circle.Name = "FOVCircle"
    circle.Size = UDim2.new(0, Aimbot.Settings.FOV * 2, 0, Aimbot.Settings.FOV * 2)
    circle.Position = UDim2.new(0.5, -Aimbot.Settings.FOV, 0.5, -Aimbot.Settings.FOV) -- 屏幕中央
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.BackgroundTransparency = 1  -- 完全透明背景
    circle.BorderSizePixel = 2         -- 边框粗细
    circle.BorderColor3 = Color3.fromRGB(255, 0, 0)  -- 红色边框
    circle.Visible = Aimbot.Enabled
    circle.Parent = screenGui
    
    -- 使用UICorner创建圆形
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)  -- 完全圆形
    corner.Parent = circle
    
    Aimbot.FOVGui = screenGui
    Aimbot.FOVCircle = circle
    return screenGui
end

local function updateFOVCircle()
    if not Aimbot.FOVGui or not Aimbot.FOVGui.Parent then
        createFOVCircle()
        return
    end
    
    if not Aimbot.FOVCircle then
        return
    end
    
    Aimbot.FOVGui.Enabled = Aimbot.Enabled
    Aimbot.FOVCircle.Visible = Aimbot.Enabled
    
    -- 更新圆圈大小（保持屏幕中央）
    local diameter = Aimbot.Settings.FOV * 2
    Aimbot.FOVCircle.Size = UDim2.new(0, diameter, 0, diameter)
    Aimbot.FOVCircle.Position = UDim2.new(0.5, -Aimbot.Settings.FOV, 0.5, -Aimbot.Settings.FOV)
end

local function cleanupFOV()
    if Aimbot.FOVGui then
        Aimbot.FOVGui:Destroy()
        Aimbot.FOVGui = nil
    end
    Aimbot.FOVCircle = nil
end

local function lookAt(target)
    if not Aimbot.Enabled then return end
    local lookVector = (target - workspace.CurrentCamera.CFrame.Position).unit
    local newCFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + lookVector)
    workspace.CurrentCamera.CFrame = newCFrame
end

local function calculateTransparency(distance)
    local transparency = (1 - (distance / Aimbot.Settings.FOV)) * Aimbot.Settings.MaxTransparency
    return math.clamp(transparency, 0.1, 1)
end

local function isPlayerAlive(player)
    local character = player.Character
    return character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0
end

local function isPlayerVisibleThroughWalls(player, trg_part)
    if not Aimbot.Settings.WallCheck then
        return true
    end

    local localPlayerCharacter = game:GetService("Players").LocalPlayer.Character
    if not localPlayerCharacter then
        return false
    end

    local part = player.Character and player.Character:FindFirstChild(trg_part)
    if not part then
        return false
    end

    local ray = Ray.new(workspace.CurrentCamera.CFrame.Position, part.Position - workspace.CurrentCamera.CFrame.Position)
    local hit, _ = workspace:FindPartOnRayWithIgnoreList(ray, {localPlayerCharacter})

    if hit and hit:IsDescendantOf(player.Character) then
        return true
    end

    local direction = (part.Position - workspace.CurrentCamera.CFrame.Position).unit
    local nearRay = Ray.new(workspace.CurrentCamera.CFrame.Position + direction * 2, direction * Aimbot.Settings.MaxDistance)
    local nearHit, _ = workspace:FindPartOnRayWithIgnoreList(nearRay, {localPlayerCharacter})

    return nearHit and nearHit:IsDescendantOf(player.Character)
end

local function getClosestPlayerInFOV()
    local nearest = nil
    local last = math.huge
    local playerMousePos = workspace.CurrentCamera.ViewportSize / 2
    local localPlayer = game:GetService("Players").LocalPlayer

    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        if player ~= localPlayer and (not Aimbot.Settings.TeamCheck or player.Team ~= localPlayer.Team) and isPlayerAlive(player) then
            local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
            local part = player.Character and player.Character:FindFirstChild(Aimbot.Settings.AimPart)
            if humanoid and part then
                local ePos, isVisible = workspace.CurrentCamera:WorldToViewportPoint(part.Position)
                local distance = (Vector2.new(ePos.x, ePos.y) - playerMousePos).Magnitude

                if distance < last and isVisible and distance < Aimbot.Settings.FOV and distance < Aimbot.Settings.MaxDistance and isPlayerVisibleThroughWalls(player, Aimbot.Settings.AimPart) then
                    last = distance
                    nearest = player
                end
            end
        end
    end

    return nearest
end

local function updateFOVColor(transparency)
    if Aimbot.FOVCircle then
        Aimbot.FOVCircle.BorderColor3 = Color3.fromRGB(255, 0, 0)
        Aimbot.FOVCircle.BorderSizePixel = 2
    end
end

local function mainLoop()
    if not Aimbot.Enabled then 
        if Aimbot.FOVGui then
            Aimbot.FOVGui.Enabled = false
        end
        return 
    end
    
    -- 更新FOV圆圈
    updateFOVCircle()
    
    Aimbot.Target = getClosestPlayerInFOV()

    if Aimbot.Target and Aimbot.Target.Character:FindFirstChild(Aimbot.Settings.AimPart) then
        lookAt(Aimbot.Target.Character[Aimbot.Settings.AimPart].Position)
        
        local part = Aimbot.Target.Character[Aimbot.Settings.AimPart]
        local ePos = workspace.CurrentCamera:WorldToViewportPoint(part.Position)
        local distance = (Vector2.new(ePos.x, ePos.y) - (workspace.CurrentCamera.ViewportSize / 2)).Magnitude
        updateFOVColor(calculateTransparency(distance))
    else
        updateFOVColor(Aimbot.Settings.MaxTransparency)
    end
end

function Aimbot:Init()
    if self.Enabled then return end
    
    -- 创建FOV圆圈
    createFOVCircle()
    
    table.insert(self.Connections, game:GetService("RunService").RenderStepped:Connect(mainLoop))
    
    self.Enabled = true
    print("Aimbot已启用")
end

function Aimbot:Disable()
    if not self.Enabled then return end
    
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Connections = {}
    
    -- 清理FOV圆圈
    cleanupFOV()
    
    self.Enabled = false
    self.Target = nil
    print("Aimbot已禁用")
end

function Aimbot:Configure(settings)
    for k, v in pairs(settings) do
        if self.Settings[k] ~= nil then
            self.Settings[k] = v
        end
    end
    
    -- 更新FOV大小
    if self.FOVCircle then
        updateFOVCircle()
    end
end

return Aimbot