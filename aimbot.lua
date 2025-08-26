-- 使用替代FOV圆圈方案的Aimbot脚本
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
    FOVSegments = {}
}

local function createAlternativeFOV()
    local player = game.Players.LocalPlayer
    local camera = workspace.CurrentCamera
    
    -- 创建FOV圆圈容器
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimbotFOV"
    screenGui.Parent = player.PlayerGui
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = Aimbot.Enabled
    
    -- 创建多个线段来模拟圆形
    local segments = 36  -- 线段数量
    local radius = Aimbot.Settings.FOV
    local center = camera.ViewportSize / 2
    
    for i = 1, segments do
        local angle1 = (i / segments) * math.pi * 2
        local angle2 = ((i + 1) / segments) * math.pi * 2
        
        local startPos = center + Vector2.new(
            math.cos(angle1) * radius,
            math.sin(angle1) * radius
        )
        
        local endPos = center + Vector2.new(
            math.cos(angle2) * radius,
            math.sin(angle2) * radius
        )
        
        -- 计算线段长度和角度
        local segmentLength = (endPos - startPos).Magnitude
        local segmentAngle = math.atan2(endPos.Y - startPos.Y, endPos.X - startPos.X)
        
        local line = Instance.new("Frame")
        line.Size = UDim2.new(0, segmentLength, 0, 2)
        line.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
        line.AnchorPoint = Vector2.new(0, 0.5)
        line.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        line.BorderSizePixel = 0
        line.Rotation = math.deg(segmentAngle)
        line.Visible = Aimbot.Enabled
        line.Parent = screenGui
        
        table.insert(Aimbot.FOVSegments, line)
    end
    
    Aimbot.FOVGui = screenGui
    return screenGui
end

local function updateAlternativeFOV()
    if not Aimbot.FOVGui or not Aimbot.FOVGui.Parent then
        createAlternativeFOV()
        return
    end
    
    local camera = workspace.CurrentCamera
    local center = camera.ViewportSize / 2
    local radius = Aimbot.Settings.FOV
    
    Aimbot.FOVGui.Enabled = Aimbot.Enabled
    
    for i, line in ipairs(Aimbot.FOVSegments) do
        local segments = #Aimbot.FOVSegments
        local angle1 = (i / segments) * math.pi * 2
        local angle2 = ((i + 1) / segments) * math.pi * 2
        
        local startPos = center + Vector2.new(
            math.cos(angle1) * radius,
            math.sin(angle1) * radius
        )
        
        local endPos = center + Vector2.new(
            math.cos(angle2) * radius,
            math.sin(angle2) * radius
        )
        
        -- 计算线段长度和角度
        local segmentLength = (endPos - startPos).Magnitude
        local segmentAngle = math.atan2(endPos.Y - startPos.Y, endPos.X - startPos.X)
        
        line.Size = UDim2.new(0, segmentLength, 0, 2)
        line.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
        line.Rotation = math.deg(segmentAngle)
        line.Visible = Aimbot.Enabled
    end
end

local function cleanupFOV()
    if Aimbot.FOVGui then
        Aimbot.FOVGui:Destroy()
        Aimbot.FOVGui = nil
    end
    Aimbot.FOVSegments = {}
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
    for _, line in ipairs(Aimbot.FOVSegments) do
        local color = Color3.fromRGB(255, 0, 0)
        line.BackgroundColor3 = color
        line.BackgroundTransparency = transparency
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
    updateAlternativeFOV()
    
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
    
    -- 创建替代FOV圆圈
    createAlternativeFOV()
    
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
    if self.FOVGui then
        updateAlternativeFOV()
    end
end

return Aimbot