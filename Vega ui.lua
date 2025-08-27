-- Xeno UI 适配版本 - 保留原功能
-- 这是专门为不适配UI注入器制作

-- Xeno UI 初始化
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/1f0t3/xeno-ui/main/lib.lua"))()
local Window = Library:CreateWindow({Name = "血债 byCCA", Description = "by cca"})

-- Create the tab
local Tab = Window:AddTab("Players")


--杀手
local killerWeapons = {
    ["CharcoalSteel JS-22"] = true,
    ["Hammer n Bullet"] = true,
    ["Pretty Pink RR-LCP"] = true,
    ["JS2-BondsDerringy"] = true,
    ["JTS-225"] = true,
    ["JTS-225 Monochrome"] = true,
    ["JTS-225 poly"] = true,
    ["JTS-225 Party cannon"] = true,
    ["GILDED"] = true,
    ["Kamatov"] = true,
    ["JS2-Derringy"] = true,
    ["JS-22"] = true,
    ["NGO"] = true,
    ["Throwing Dagger"] = true,
    ["SoundMaker"] = true,
    ["SoundMakerSlower"] = true,
    ["RR-LightCompactPistolS"] = true,
    ["J9-Mereta"] = true,
    ["RY's GG-17"] = true,
    ["RR-LCP"] = true,
    ["JS1 Competitor"] = true,
    ["AT's KAR15"] = true,
    ["VK's ANKM"] = true,
    ["Clothed Sawn-off"] = true,
    ["Sawn-off"] = true,
    ["Clothed Rosen-Obrez"] = true,
    ["Rosen-Obrez"] = true,
    ["GraySteel K1911"] = true,
    ["DarkSteel K1911"] = true,
    ["SilverSteel K1911"] = true,
    ["K1911"] = true,
    ["ZZ-90"] = true,
    ["SKORPION"] = true,
    ["Mares Leg"] = true,
    ["RR-LightCompactPistol"] = true,
    ["RR-LightCompactPistolS"] = true,
    ["KamatovS"] = true,
    ["Throwing Tomahawk"] = true,
    ["Throwing Kunai"] = true,
    ["ChromeSlide Turqoise RR-LCP"] = true,
    ["JS-1 CYCLOPS"] = true,
    ["THUMPA"] = true,
    ["LUT-E 'KRUS'"] = true
}

--警长
local vigilanteWeapons = {
    ["Beagle"] = true,
    ["IZVEKH-412"] = true,
    ["SilverSteel RR-Snubby"] = true,
    ["RR-Snubby"] = true,
    ["ZKZ-Obrez"] = true,
    ["Clothed ZKZ-Obrez"] = true,
    ["Buxxberg-COMPACT"] = true,
    ["pretty pink Buxxberg-COMPACT"] = true,
    ["JS-5A-OBREZ"] = true,
    ["GG-17"] = true,
    ["J9-M"] = true,
    ["J9-Meretta"] = true,
    ["Pretty Pink GG-17"] = true,
    ["GG-17 TAN"] = true,
    ["GG-17 GILDED"] = true,
    ["RR-Snubby GILDED"] = true,
    ["HWISSH-226"] = true,
    ["Dual Elites"] = true,
    ["ZKZ-Obrez10"] = true,
}

-- Define Special Killer weapons
local specialKillerWeapons = {
    ["RY's GG-17"] = true,
    ["AT's KAR15"] = true,
    ["VK's ANKM"] = true,
}

-- Define a combined list of all relevant weapons
local allRoleWeapons = {}
for name, _ in pairs(killerWeapons) do allRoleWeapons[name] = true end
for name, _ in pairs(vigilanteWeapons) do allRoleWeapons[name] = true end

-- Define Role Colors and Labels
local killerColor = Color3.fromRGB(255, 0, 0)
local killerLabel = "杀手"
local vigilanteColor = Color3.fromRGB(0, 255, 255)
local vigilanteLabel = "警官"
local innocentColor = Color3.fromRGB(0, 255, 0)
local innocentLabel = "中立"
local hintMatchColor = Color3.new(1, 1, 0)
local hintMatchLabel = "目标"
local vigilanteHintColor = Color3.fromRGB(128, 0, 128)
local vigilanteHintLabel = "警官 + 目标"

-- Define the distance threshold
local distanceThreshold = 30

local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local NPCSFolder = Workspace:WaitForChild("NPCSFolder")
local BloodFolder = Workspace:WaitForChild("BloodFolder")

-- State variables for controlling ESP
local espEnabled = false
local stopEspLoop = false
local espPlayerAddedConnection = nil
local espCharacterAddedConnections = {}

-- State variables for the distance locking rule
local rolesLockedByDistance = false
local lockedDistanceRoles = {}

-- State variables for the Hint Matching rule
local playersMatchingHints = {}
local hintTextConnection = nil
local firstVigilanteTracker = {}

-- Add floating name tag
local function addNameTag(character, text, color)
    local head = character:FindFirstChild("Head")
    if not head then return end

    local oldTag = head:FindFirstChild("RoleBillboard")
    if oldTag then oldTag:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = "RoleBillboard"
    bb.Size = UDim2.new(0, 100, 0, 20)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.Adornee = head
    bb.AlwaysOnTop = true
    bb.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.2
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = bb
end

-- Clear previous overlays
local function clearOldStuff(character)
    if not character then return end

    local oldHighlight = character:FindFirstChild("RoleHighlight")
    if oldHighlight and oldHighlight:IsA("Highlight") then
        oldHighlight:Destroy()
    end

    local head = character:FindFirstChild("Head")
    if head then
        local tag = head:FindFirstChild("RoleBillboard")
        if tag then tag:Destroy() end
    end
end

-- Tag player by role
local function tagPlayer(player, roleColor, labelText)
    if not player.Character then return end
    clearOldStuff(player.Character)

    local highlight = Instance.new("Highlight", player.Character)
    highlight.Name = "RoleHighlight"
    highlight.Archivable = true
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = true
    highlight.FillColor = roleColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0

    if labelText then
        addNameTag(player.Character, labelText, roleColor)
    end
end

-- Helper function to collect a player's tools
local function collectPlayerTools(player)
    local tools = {}
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                 tools[tool.Name] = tool
            end
        end
    end
    if player.Character then
        for _, tool in ipairs(player.Character:GetChildren()) do
            if tool:IsA("Tool") then
                tools[tool.Name] = tool
            end
        end
    end

    if NPCSFolder then
        local playerNPCModel = NPCSFolder:FindFirstChild(player.Name)
        if playerNPCModel then
            for _, child in ipairs(playerNPCModel:GetChildren()) do
                if child:IsA("Tool") then
                    tools[child.Name] = child
                end
            end
        end
    end

    return tools
end

-- Helper function to get standard role based on weapons
local function getStandardRoleFromWeapons(toolsByName)
    local role = nil
    local color = nil
    local label = nil

    for weaponName, _ in pairs(killerWeapons) do
        if not specialKillerWeapons[weaponName] and toolsByName[weaponName] then
             role = "Killer"
             color = killerColor
             label = killerLabel
             return role, color, label
        end
    end

    for weaponName, _ in pairs(vigilanteWeapons) do
        if toolsByName[weaponName] then
            role = "Vigilante"
            color = vigilanteColor
            label = vigilanteLabel
            return role, color, label
        end
    end

    return nil, nil, nil
end

-- Function to parse a single string of hint content
local function parseSingleHint(hintContent)
    local hintType = "invalid"
    local hintValue = nil
    local cleanedContent = hintContent:match("^%s*(.-)%s*$") or ""

    if string.len(cleanedContent) == 0 then
        return hintType, hintValue
    end

    local taskMatch = cleanedContent:match("^Is often seen%s*(.*)$")
    if taskMatch then
        hintType = "task"
        hintValue = taskMatch:match("^%s*(.-)%s*$")
        return hintType, hintValue
    end

    local traitBracketMatch = cleanedContent:match("^%[.-%]$")
    if traitBracketMatch then
        local cleanClue = traitBracketMatch:gsub("[%[%]]", ""):match("^%s*(.-)%s*$") or ""
        if string.len(cleanClue) > 0 and cleanClue:lower() ~= "assigned task" and cleanClue:lower() ~= "seen" then
            hintType = "trait"
            hintValue = cleanClue
            return hintType, hintValue
        end
    end

    if hintType == "invalid" then
        hintType = "trait"
        hintValue = cleanedContent
    end

    return hintType, hintValue
end

-- Function to update the playersMatchingHints table
local function updateMatchingHintPlayers()
    playersMatchingHints = {}

    if not espEnabled then return end

    local PlayerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return end

    local TargetHintLabel = PlayerGui:FindFirstChild("RESETONDEATHStatusGui") and PlayerGui.RESETONDEATHStatusGui:FindFirstChild("TARGETHINT")

    if not TargetHintLabel or not TargetHintLabel:IsA("TextLabel") then
        return
    end

    local hintText = TargetHintLabel.Text

    if string.len(string.gsub(hintText, "%s", "")) == 0 then
        return
    end

    local hintPrefix = "Hints : "
    local lowerHintText = string.lower(hintText)
    local lowerHintPrefix = string.lower(hintPrefix)

    if lowerHintText:sub(1, string.len(lowerHintPrefix)) ~= lowerHintPrefix then
        return
    end

    local actualHintContent = hintText:sub(string.len(hintPrefix) + 1):match("^%s*(.-)%s*$")
    local individualHintParts = {}
    local currentPos = 1

    while currentPos <= string.len(actualHintContent) do
        local nextPlus = string.find(actualHintContent, " + ", currentPos, true)
        if nextPlus then
            local hintPart = string.sub(actualHintContent, currentPos, nextPlus - 1)
            table.insert(individualHintParts, hintPart)
            currentPos = nextPlus + string.len(" + ")
        else
            local hintPart = string.sub(actualHintContent, currentPos)
            table.insert(individualHintParts, hintPart)
            currentPos = string.len(actualHintContent) + 1
        end
    end

    if #individualHintParts == 0 and string.len(actualHintContent) > 0 then
        table.insert(individualHintParts, actualHintContent)
    end

    local targetConditions = {}

    for i, hintPartContent in ipairs(individualHintParts) do
        local targetNumberMatch = hintPartContent:match("^%[%s*(%d+)%s*%]")
        local targetNumber = tonumber(targetNumberMatch) or 1
        local cleanedHintPartContent = hintPartContent:gsub("^%[%s*%d+%s*%]%s*", ""):match("^%s*(.-)%s*$") or ""

        local hintType, hintValue = parseSingleHint(cleanedHintPartContent)

        if hintType ~= "invalid" and hintValue and string.len(hintValue) > 0 then
            if not targetConditions[targetNumber] then
                targetConditions[targetNumber] = {}
            end
            table.insert(targetConditions[targetNumber], { type = hintType, value = hintValue })
        end
    end

    if next(targetConditions) == nil then
        return
    end

    if not NPCSFolder then
        return
    end

    for _, player in Players:GetPlayers() do
        if player ~= lp then
            local playerNPCModel = NPCSFolder:FindFirstChild(player.Name)

            if playerNPCModel then
                 local configObject = playerNPCModel:FindFirstChild("Configuration")
                 local playerMatchesAnyTarget = false

                 for targetNumber, conditionsForTarget in pairs(targetConditions) do
                     local playerMatchesAllConditionsForTarget = true

                     for i, condition in ipairs(conditionsForTarget) do
                         local conditionMet = false

                         if condition.type == "task" then
                             local assignedTaskObject = playerNPCModel:FindFirstChild("AssignedTask")
                             if assignedTaskObject and assignedTaskObject:IsA("StringValue") and assignedTaskObject.Value == condition.value then
                                 conditionMet = true
                             end
                         elseif condition.type == "trait" then
                             if configObject then
                                  for _, configChild in ipairs(configObject:GetChildren()) do
                                      if configChild:IsA("StringValue") and configChild.Value == condition.value then
                                          conditionMet = true
                                          break
                                      end
                                  end
                             end
                         end

                         if not conditionMet then
                             playerMatchesAllConditionsForTarget = false
                             break
                         end
                     end

                     if playerMatchesAllConditionsForTarget then
                         playerMatchesAnyTarget = true
                         break
                     end
                 end

                 if playerMatchesAnyTarget then
                     playersMatchingHints[player] = true
                 end
            end
        end
    end
end

-- Function to connect the hint text changed signal
local function connectHintTextSignal()
     if not espEnabled then return end
     if hintTextConnection then
         hintTextConnection:Disconnect()
         hintTextConnection = nil
     end

     local PlayerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
     if not PlayerGui then return end

     local statusGui = PlayerGui:WaitForChild("RESETONDEATHStatusGui", 20)
     if not statusGui then
         return
     end

     local TargetHintLabel = statusGui:WaitForChild("TARGETHINT", 10)
     if not TargetHintLabel or not TargetHintLabel:IsA("TextLabel") then
         return
     end

     hintTextConnection = TargetHintLabel:GetPropertyChangedSignal("Text"):Connect(updateMatchingHintPlayers)
     updateMatchingHintPlayers()
end

-- Detect and apply roles
local function detectRoles()
    if not espEnabled then return end

    local newHighestPriorityKillerDetected = false
    local theSingleKillerGunHolder = nil
    local specialKillerDetected = false
    local playersWithSpecialWeapons = {}
    local everyoneHasGunConditionMet = false
    local noOneHasGunConditionMet = false

    local playersWithValidCharacters = {}
    local playersWithoutAnyGun = {}
    local playersWithAnyGun = {}
    local playersWithVigilanteWeapons = {}
    local vigilanteCount = 0
    local killerGunHoldersCount = 0
    local singleKillerGunHolderCandidate = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
             playersWithValidCharacters[player] = true

             local toolsByName = collectPlayerTools(player)
             local hasAnyRoleWeapon = false
             local hasVigilanteWeapon = false
             local hasKillerWeapon = false

             for name, tool in pairs(toolsByName) do
                 if specialKillerWeapons[name] then
                     specialKillerDetected = true
                     playersWithSpecialWeapons[player] = true
                 end
                 if allRoleWeapons[name] then
                      hasAnyRoleWeapon = true
                 end
                 if vigilanteWeapons[name] then
                     hasVigilanteWeapon = true
                     playersWithVigilanteWeapons[player] = true
                 end
                 if killerWeapons[name] then
                     hasKillerWeapon = true
                 end
             end

             if hasVigilanteWeapon then
                  vigilanteCount = vigilanteCount + 1
                  if firstVigilanteTracker[player] == nil then
                      firstVigilanteTracker[player] = true
                  end
             end

              if hasKillerWeapon then
                  killerGunHoldersCount = killerGunHoldersCount + 1
                  singleKillerGunHolderCandidate = player
             end

             if not hasAnyRoleWeapon then
                 playersWithoutAnyGun[player] = true
             else
                 playersWithAnyGun[player] = true
             end
        else
            clearOldStuff(player.Character)
        end
    end

    if vigilanteCount == 1 and killerGunHoldersCount == 1 and singleKillerGunHolderCandidate then
         newHighestPriorityKillerDetected = true
         theSingleKillerGunHolder = singleKillerGunHolderCandidate
         specialKillerDetected = false
         playersWithSpecialWeapons = {}
         everyoneHasGunConditionMet = false
         rolesLockedByDistance = false
         lockedDistanceRoles = {}

         if theSingleKillerGunHolder == lp then
             updateMatchingHintPlayers()
         end
    end

    if not newHighestPriorityKillerDetected then
         local allValidTargetsHaveGun = true
         local otherPlayersWithCharCount = 0
         for player, _ in pairs(playersWithValidCharacters) do
             if player ~= lp then otherPlayersWithCharCount = otherPlayersWithCharCount + 1 end
             if playersWithoutAnyGun[player] then
                 allValidTargetsHaveGun = false
                 break
             end
         end
         if allValidTargetsHaveGun and otherPlayersWithCharCount > 0 then
             everyoneHasGunConditionMet = true
         end

         local anyValidTargetHasGun = false
         for player, _ in pairs(playersWithValidCharacters) do
              if playersWithAnyGun[player] then
                  anyValidTargetHasGun = true
                  break
              end
         end
         if not anyValidTargetHasGun and otherPlayersWithCharCount > 0 then
              noOneHasGunConditionMet = true
         end
    end

    if not newHighestPriorityKillerDetected and not specialKillerDetected and everyoneHasGunConditionMet and not rolesLockedByDistance then
         rolesLockedByDistance = true
         lockedDistanceRoles = {}

         local localHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

         if localHRP then
             for player, _ in pairs(playersWithValidCharacters) do
                 local playerHRP = player.Character:FindFirstChild("HumanoidRootPart")
                 if playerHRP then
                     local distance = (localHRP.Position - playerHRP.Position).Magnitude
                     if distance >= distanceThreshold then
                          lockedDistanceRoles[player] = "Killer"
                     else
                          lockedDistanceRoles[player] = "Innocent"
                     end
                 end
             end
         else
              rolesLockedByDistance = false
              lockedDistanceRoles = {}
         end
    end

    if not newHighestPriorityKillerDetected and not specialKillerDetected and noOneHasGunConditionMet and rolesLockedByDistance then
         rolesLockedByDistance = false
         lockedDistanceRoles = {}
    end

    updateMatchingHintPlayers()

    for _, player in ipairs(Players:GetPlayers()) do
        if playersWithValidCharacters[player] then
             if newHighestPriorityKillerDetected and player == theSingleKillerGunHolder then
                 tagPlayer(player, killerColor, killerLabel)
             elseif specialKillerDetected then
                 if playersWithSpecialWeapons[player] then
                     tagPlayer(player, killerColor, killerLabel)
                 else
                     tagPlayer(player, innocentColor, innocentLabel)
                 end
             elseif rolesLockedByDistance then
                 local lockedRole = lockedDistanceRoles[player]
                 if lockedRole then
                      if lockedRole == "Killer" then
                           tagPlayer(player, killerColor, killerLabel)
                      elseif lockedRole == "Innocent" then
                           tagPlayer(player, innocentColor, innocentLabel)
                      end
                 else
                     clearOldStuff(player.Character)
                 end
             elseif playersMatchingHints[player] and playersWithVigilanteWeapons[player] then
                  tagPlayer(player, vigilanteHintColor, vigilanteHintLabel)
             elseif playersMatchingHints[player] and not firstVigilanteTracker[player] then
                 tagPlayer(player, hintMatchColor, hintMatchLabel)
             else
                 local toolsByName = collectPlayerTools(player)
                 local standardRole, standardColor, standardLabel = getStandardRoleFromWeapons(toolsByName)
                 if standardRole then
                     tagPlayer(player, standardColor, standardLabel)
                 else
                     tagPlayer(player, innocentColor, innocentLabel)
                 end
             end
        end
    end
end

-- Function to disable ESP
local function disableEsp()
    if espEnabled then
        espEnabled = false
        stopEspLoop = true

        rolesLockedByDistance = false
        lockedDistanceRoles = {}
        playersMatchingHints = {}

        if espPlayerAddedConnection then
            espPlayerAddedConnection:Disconnect()
            espPlayerAddedConnection = nil
        end

        if hintTextConnection then
            hintTextConnection:Disconnect()
            hintTextConnection = nil
        end

        for player, connection in pairs(espCharacterAddedConnections) do
             if connection and typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
            end
            espCharacterAddedConnections[player] = nil
        end
        espCharacterAddedConnections = {}

        for _, player in ipairs(Players:GetPlayers()) do
             if player.Character then
                clearOldStuff(player.Character)
            end
        end
         Library:SendNotification("ESP Disabled", "Role detection has been turned off.", 3)
    end
end

-- Function to teleport to dropped gun
local function tpToDroppedGun()
    if not BloodFolder then
         Library:SendNotification("Error", "BloodFolder not found in Workspace.", 5)
        return
    end

    local foundGun = false
    for _, item in ipairs(BloodFolder:GetChildren()) do
        if item:IsA("Tool") and (killerWeapons[item.Name] or vigilanteWeapons[item.Name] or specialKillerWeapons[item.Name]) then
            local targetPosition = item.Position + Vector3.new(0, 5, 0)
            if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                 lp.Character:SetPrimaryPartCFrame(CFrame.new(targetPosition))
                 foundGun = true
                 break
            else
                 Library:SendNotification("Error", "Cannot teleport: Your character is not ready.", 5)
                return
            end
        end
    end

    if not foundGun then
        Library:SendNotification("No Gun Found", "There are no valid guns in the BloodFolder.", 5)
    end
end

-- Create Enable ESP button
Tab:AddButton("启动 ESP", function()
    if not espEnabled then
        espEnabled = true
        stopEspLoop = false

        task.spawn(function()
            while espEnabled and not stopEspLoop do
                task.wait(0.5)
                detectRoles()
            end
        end)

        espPlayerAddedConnection = game.Players.PlayerAdded:Connect(function(player)
             local charAddedConn = player.CharacterAdded:Connect(function(character)
                 task.wait(0.1)
                 connectHintTextSignal()
                 detectRoles()
             end)
             espCharacterAddedConnections[player] = charAddedConn

             if player.Character then
                  task.wait(0.1)
                  detectRoles()
             end
        end)

         game.Players.PlayerRemoving:Connect(function(player)
            if espCharacterAddedConnections[player] then
                if typeof(espCharacterAddedConnections[player]) == "RBXScriptConnection" then
                    espCharacterAddedConnections[player]:Disconnect()
                end
                espCharacterAddedConnections[player] = nil
            end
            clearOldStuff(player.Character)
        end)

        connectHintTextSignal()
        detectRoles()

        Library:SendNotification("ESP Enabled", "Role detection has been turned on.", 3)
    else
        Library:SendNotification("ESP Already On", "Role detection is already running.", 3)
    end
end)

-- Create Disable ESP button
Tab:AddButton("禁用 ESP", function()
    disableEsp()
end)

-- Create Teleport to Gun button
Tab:AddButton("传送到枪", function()
    tpToDroppedGun()
end)

Library:SendNotification("ESP Script Initialized", "Attempted to create UI elements. Check output for details.", 5)

local AimbotTab = Window:AddTab("Aimbot")

local aimbotScript = nil
local aimbotEnabled = false
local uiElementsAdded = false  -- 标记UI元素是否已添加

-- 先定义 disableAimbot 函数
local function disableAimbot()
    if aimbotEnabled and aimbotScript and aimbotScript.Disable then
        aimbotScript:Disable()
        aimbotEnabled = false
        Library:SendNotification("Aimbot", "Aimbot 已禁用", 3)
    end
end

AimbotTab:AddButton("加载aimbot", function()
    pcall(function()
        disableAimbot()

        -- 加载并执行Aimbot脚本
        local success, result = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/ccacca444/scripts1/main/aimbotXenoUI.lua", true))()
        end)

        if success and result then
            aimbotScript = result
            
            -- 只在第一次加载时添加UI元素
            if not uiElementsAdded then
                AimbotTab:AddButton("启用 Aimbot", function()
                    if aimbotScript and aimbotScript.Init then
                        aimbotScript:Init()
                        aimbotEnabled = true
                        Library:SendNotification("Aimbot", "Aimbot 已启用", 3)
                    end
                end)

                AimbotTab:AddButton("禁用 Aimbot", function()
                    disableAimbot()
                end)

                AimbotTab:AddToggle("WallHack", function(Value)
                    if aimbotScript and aimbotScript.SetWallHack then
                        aimbotScript:SetWallHack(Value)
                        Library:SendNotification("WallHack", Value and "已开启" or "已关闭", 3)
                    end
                end, false)
                
                uiElementsAdded = true
            end

            Library:SendNotification("成功", "Aimbot 加载完成", 3)
        else
            Library:SendNotification("错误", "Aimbot 加载失败: " .. tostring(result), 5)
        end
    end)
end)