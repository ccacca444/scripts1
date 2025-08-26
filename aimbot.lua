-- 修复FOV圆圈显示问题的Aimbot脚本
local Aimbot = {
    Enabled = false,
    Settings = {
        FOV = 100,  -- 增大FOV值使其更明显
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
    if not player then return end
    
    -- 等待PlayerGui加载
    if not player:FindFirstChild("PlayerGui") then
        player:WaitForChild("PlayerGui")
    end
    
    -- 移除旧的FOVGui（如果存在）
    if Aimbot.FOVGui then
        Aimbot.FOVGui:Destroy()
    end
    
    -- 创建FOV圆圈容器
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimbotFOV"
    screenGui.Parent = player.PlayerGui
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999  -- 确保在最前面
    screenGui.Enabled = true  -- 始终启用，通过子元素控制可见性
    
    -- 创建圆形Frame
    local circle = Instance.new("Frame")
    circle.Name = "FOVCircle"
    circle.Size = UDim2.new(0, Aimbot.Settings.FOV * 2, 0, Aimbot.Settings.FOV * 2)
    circle.Position = UDim2.new(0.5, -Aimbot.Settings.FOV, 0.5, -Aimbot.Settings.FOV)
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.BackgroundTransparency = 1  -- 透明背景
    circle.BorderSizePixel = 2         -- 边框粗细
    circle.BorderColor3 = Color3.fromRGB(255, 0, 0)  -- 红色边框
    circle.Visible = Aimbot.Enabled    -- 根据启用状态控制可见性
    circle.ZIndex = 999
    circle.Parent = screenGui
    
    -- 使用UICorner创建圆形
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)  -- 完全圆形
    corner.Parent = circle
    
    Aimbot.FOVGui = screenGui
    Aimbot.FOVCircle = circle
    
    print("FOV圆圈创建成功，大小:", Aimbot.Settings.FOV * 2)
    return screenGui
end

local function updateFOVCircle()
    if not Aimbot.Enabled then
        if Aimbot.FOVCircle then
            Aimbot.FOVCircle.Visible = false
        end
        return
    end
    
    -- 确保FOV圆圈存在
    if not Aimbot.FOVGui or not Aimbot.FOVGui.Parent or not Aimbot.FOVCircle then
        createFOVCircle()
        return
    end
    
    -- 更新可见性
    Aimbot.FOVCircle.Visible = true
    
    -- 更新圆圈大小和位置
    local diameter = Aimbot.Settings.FOV * 2
    Aimbot.FOVCircle.Size = UDim2.new(0, diameter, 0, diameter)
    Aimbot.FOVCircle.Position = UDim2.new(0.5, -Aimbot.Settings.FOV, 0.5, -Aimbot.Settings.FOV)
    Aimbot.FOVCircle.BorderColor3 = Color3.fromRGB(255, 0, 0)
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

local function updateFOVAppearance(hasTarget)
    if not Aimbot.FOVCircle then return end
    
    if hasTarget then
        -- 有目标时改变外观
        Aimbot.FOVCircle.BorderColor3 = Color3.fromRGB(0, 255, 0)  -- 绿色
        Aimbot.FOVCircle.BorderSizePixel = 3
    else
        -- 无目标时恢复原样
        Aimbot.FOVCircle.BorderColor3 = Color3.fromRGB(255, 0, 0)  -- 红色
        Aimbot.FOVCircle.BorderSizePixel = 2
    end
end

local function mainLoop()
    -- 更新FOV圆圈
    updateFOVCircle()
    
    if not Aimbot.Enabled then 
        return 
    end
    
    Aimbot.Target = getClosestPlayerInFOV()

    if Aimbot.Target and Aimbot.Target.Character:FindFirstChild(Aimbot.Settings.AimPart) then
        lookAt(Aimbot.Target.Character[Aimbot.Settings.AimPart].Position)
        updateFOVAppearance(true)
    else
        updateFOVAppearance(false)
    end
end

function Aimbot:Init()
    if self.Enabled then return end
    
    -- 创建FOV圆圈
    createFOVCircle()
    
    -- 创建主循环
    table.insert(self.Connections, game:GetService("RunService").RenderStepped:Connect(mainLoop))
    
    self.Enabled = true
    print("Aimbot已启用 - FOV大小:", self.Settings.FOV)
end

function Aimbot:Disable()
    if not self.Enabled then return end
    
    -- 断开所有连接
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

-- 添加调试功能
function Aimbot:DebugFOV()
    print("FOV调试信息:")
    print("- 启用状态:", self.Enabled)
    print("- FOV大小:", self.Settings.FOV)
    print("- FOVGui存在:", self.FOVGui ~= nil)
    print("- FOVCircle存在:", self.FOVCircle ~= nil)
    
    if self.FOVGui then
        print("- FOVGui父级:", self.FOVGui.Parent and self.FOVGui.Parent.Name or "无")
        print("- FOVGui启用:", self.FOVGui.Enabled)
    end
    
    if self.FOVCircle then
        print("- FOVCircle可见:", self.FOVCircle.Visible)
        print("- FOVCircle大小:", self.FOVCircle.Size)
        print("- FOVCircle位置:", self.FOVCircle.Position)
    end
end

return Aimbot