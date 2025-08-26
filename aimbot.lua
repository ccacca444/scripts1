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
    FOVring = nil
}

local function initDrawings()
    -- 检查Drawing库是否可用
    if not Drawing then
        warn("Drawing库不可用，FOV圆圈将无法显示")
        return
    end
    
    Aimbot.FOVring = Drawing.new("Circle")
    Aimbot.FOVring.Visible = Aimbot.Enabled
    Aimbot.FOVring.Thickness = 2
    Aimbot.FOVring.Color = Color3.fromRGB(255, 0, 0)  -- 改为红色更明显
    Aimbot.FOVring.Filled = false
    Aimbot.FOVring.Radius = Aimbot.Settings.FOV
    Aimbot.FOVring.Position = workspace.CurrentCamera.ViewportSize / 2
    Aimbot.FOVring.Transparency = 0.5  -- 设置为半透明
    Aimbot.FOVring.ZIndex = 999  -- 确保在最前面
end

local function updateDrawings()
    if Aimbot.FOVring then
        Aimbot.FOVring.Visible = Aimbot.Enabled
        Aimbot.FOVring.Position = workspace.CurrentCamera.ViewportSize / 2
        Aimbot.FOVring.Radius = Aimbot.Settings.FOV
    end
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

local function mainLoop()
    if not Aimbot.Enabled then 
        if Aimbot.FOVring then
            Aimbot.FOVring.Visible = false
        end
        return 
    end
    
    updateDrawings()
    Aimbot.Target = getClosestPlayerInFOV()

    if Aimbot.Target and Aimbot.Target.Character:FindFirstChild(Aimbot.Settings.AimPart) then
        lookAt(Aimbot.Target.Character[Aimbot.Settings.AimPart].Position)
        
        local part = Aimbot.Target.Character[Aimbot.Settings.AimPart]
        local ePos = workspace.CurrentCamera:WorldToViewportPoint(part.Position)
        local distance = (Vector2.new(ePos.x, ePos.y) - (workspace.CurrentCamera.ViewportSize / 2)).Magnitude
        if Aimbot.FOVring then
            Aimbot.FOVring.Transparency = calculateTransparency(distance)
        end
    else
        if Aimbot.FOVring then
            Aimbot.FOVring.Transparency = 0.5  -- 没有目标时保持半透明
        end
    end
end

function Aimbot:Init()
    if self.Enabled then return end
    
    initDrawings()
    
    table.insert(self.Connections, game:GetService("RunService").RenderStepped:Connect(mainLoop))
    
    self.Enabled = true
    print("Aimbot已启用")
    
    -- 立即更新一次绘图
    updateDrawings()
end

function Aimbot:Disable()
    if not self.Enabled then return end
    
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Connections = {}
    
    if self.FOVring then
        self.FOVring:Remove()
        self.FOVring = nil
    end
    
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
    
    if self.FOVring then
        self.FOVring.Radius = self.Settings.FOV
    end
end

return Aimbot