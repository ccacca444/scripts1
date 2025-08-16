--NU-FWQ
--[[
    Integrated ESP LocalScript with Rayfield UI, Role Detection, Distance Locking,
    and Enhanced Hint Matching including AssignedTask check.
    Fixed issue where players were tagged as hint match when no hints were present.
    Updated hint parsing to handle AssignedTask directly after "Is often seen ".
    Corrected hint matching logic to handle hints with only traits or only tasks,
    and only performs hint matching if the local player is the killer based on the hint text prefix.
    UPDATED: Modified hint parsing and matching to check AssignedTask or Configuration.Value based on hint type ("Is often seen" presence).
    Ensured Hint Match tagging is correctly prioritized and applied.
    FIXED: Ensure "Hints : ", " + ", and "[1] ", "[2] " (including spaces) are removed during parsing.
    ADDED: More detailed debug prints to specifically track tagging logic in detectRoles, including hint match conditions.
    ADDED: Automatic hint text check if the local player is the solo killer under the New Highest Priority rule.
]]

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create the window
local Window = Rayfield:CreateWindow({
    Name = "Blood Debt Role Detector",
    Icon = 0,
    LoadingTitle = "Rayfield Role Detector",
    LoadingSubtitle = "by Sirius",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "Big Hub"
    }
})

-- Create the tab
local Tab = Window:CreateTab("Players", "rewind")


-- Weapon lists (UPDATED AS PROVIDED in the larger script)
local killerWeapons = {
    ["CharcoalSteel JS-22"] = true,
    ["Pretty Pink RR-LCP"] = true,
    ["JS2-BondsDerringy"] = true,
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
    ["RY's GG-17"] = true,   -- Special Killer Weapon
    ["RR-LCP"] = true,
    ["JS1 Competitor"] = true,
    ["AT's KAR15"] = true,  -- Special Killer Weapon
    ["VK's ANKM"] = true,    -- Special Killer Weapon
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
    ["Mares Leg"] = true, -- Added
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

local vigilanteWeapons = {
    ["Beagle"] = true,
    ["IZVEKH-412"] = true,
    ["SilverSteel RR-Snubby"] = true,
    ["RR-Snubby"] = true,
    ["ZKZ-Obrez"] = true,
    ["GG-17"] = true,
    ["J9-M"] = true,
    ["J9-Meretta"] = true, -- Typo? Should this be J9-Mereta? Keeping as is from 
    ["Pretty Pink GG-17"] = true, -- Added
    ["GG-17 TAN"] = true, -- Added
    ["GG-17 GILDED"] = true, -- Added
    ["RR-Snubby GILDED"] = true, -- Added
    ["HWISSH-226"] = true, -- Added
    ["ZKZ-Obrez10"] = true, -- Added
}

-- Define Special Killer weapons (for the global check)
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
local killerColor = Color3.fromRGB(255, 0, 0) -- Red
local killerLabel = "KILLER"
local vigilanteColor = Color3.fromRGB(0, 255, 255) -- Cyan
local vigilanteLabel = "VIGILANTE"
local innocentColor = Color3.fromRGB(0, 255, 0) -- Green
local innocentLabel = "INNOCENT"
local hintMatchColor = Color3.new(1, 1, 0) -- Yellow
local hintMatchLabel = "HINT MATCH"
local vigilanteHintColor = Color3.fromRGB(128, 0, 128) -- Purple -- THIS IS THE PURPLE COLOR
local vigilanteHintLabel = "VIGILANTE + HINT MATCH" -- THIS IS THE PURPLE LABEL


-- Define the distance threshold for the new rule
local distanceThreshold = 30


local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local NPCSFolder = Workspace:WaitForChild("NPCSFolder") -- Ensure NPCSFolder is waited for
local BloodFolder = Workspace:WaitForChild("BloodFolder") -- Ensure BloodFolder is waited for

-- State variables for controlling ESP
local espEnabled = false
local stopEspLoop = false -- Signal to stop the detection loop
local espPlayerAddedConnection = nil -- Store the main PlayerAdded connection
local espCharacterAddedConnections = {} -- Store per-player CharacterAdded connections

-- State variables for the distance locking rule
local rolesLockedByDistance = false -- Flag indicating if distance roles are locked
local lockedDistanceRoles = {} -- Stores the determined distance role ("Killer" or "Innocent")

-- State variables for the Hint Matching rule
local playersMatchingHints = {} -- Stores players who currently match hints (populated by updateMatchingHintPlayers)
local hintTextConnection = nil -- Stores the signal connection for the hint text
local firstVigilanteTracker = {} -- Stores the first player detected as Vigilante (player -> true)


-- Add floating name tag (smaller and neater)
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
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- White outline
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0

    if labelText then
        addNameTag(player.Character, labelText, roleColor)
    end
end

-- Helper function to collect a player's tools
-- UPDATED: Now checks the player's model within NPCSFolder for tools as well.
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

    -- NEW: Check the player's model within NPCSFolder for tools
    if NPCSFolder then -- Ensure NPCSFolder exists
        local playerNPCModel = NPCSFolder:FindFirstChild(player.Name)
        if playerNPCModel then
            for _, child in ipairs(playerNPCModel:GetChildren()) do
                if child:IsA("Tool") then
                    tools[child.Name] = child -- Add tools found in the NPCSFolder model
                end
            end
        end
    end

    return tools -- Return table keyed by tool name
end

-- Helper function to get standard role based on weapons (excluding special killer check)
local function getStandardRoleFromWeapons(toolsByName)
    local role = nil
    local color = nil
    local label = nil

    -- Check standard Killer weapons first (priority), *excluding* special ones here
    for weaponName, _ in pairs(killerWeapons) do
        if not specialKillerWeapons[weaponName] and toolsByName[weaponName] then
             role = "Killer"
             color = killerColor
             label = killerLabel
             return role, color, label -- Standard Killer overrides Vigilante
        end
    end

    -- Check Vigilante weapons if no standard Killer weapon found
    for weaponName, _ in pairs(vigilanteWeapons) do
        if toolsByName[weaponName] then
            role = "Vigilante"
            color = vigilanteColor
            label = vigilanteLabel
            return role, color, label -- Found a Vigilante weapon
        end
    end

    -- No standard role weapon found
    return nil, nil, nil
end

-- Function to parse a single string of hint content (after removing prefixes like [1] or [2])
-- Returns the type ("task" or "trait") and the extracted value, or "invalid" and nil.
local function parseSingleHint(hintContent)
    local hintType = "invalid"
    local hintValue = nil
    local cleanedContent = hintContent:match("^%s*(.-)%s*$") or "" -- Trim leading/trailing whitespace

    print("DEBUG: parseSingleHint called with:", cleanedContent)

    if string.len(cleanedContent) == 0 then
        print("DEBUG: parseSingleHint: Empty content after trimming.")
        return hintType, hintValue
    end

    -- Check for task hint format: "Is often seen " followed by the task
    local taskMatch = cleanedContent:match("^Is often seen%s*(.*)$")
    if taskMatch then
        hintType = "task"
        hintValue = taskMatch:match("^%s*(.-)%s*$") -- Trim extracted task
        print("DEBUG: Parsed as Task. Value:", hintValue)
        return hintType, hintValue
    end

    -- Check for trait hint format: text within square brackets []
    local traitBracketMatch = cleanedContent:match("^%[.-%]$") -- Check if the whole part is just a bracketed trait
    if traitBracketMatch then
        -- Extract content within brackets
        local cleanClue = traitBracketMatch:gsub("[%[%]]", ""):match("^%s*(.-)%s*$") or ""
        if string.len(cleanClue) > 0 and cleanClue:lower() ~= "assigned task" and cleanClue:lower() ~= "seen" then
            hintType = "trait"
            hintValue = cleanClue
            print("DEBUG: Parsed as Bracketed Trait. Value:", hintValue)
            return hintType, hintValue
        end
    end

    -- If neither format matched, treat the entire cleaned content as a single unbracketed trait.
    -- This handles cases like "Has no clothes covering their knee" or "Has long sleeves".
    if hintType == "invalid" then
        hintType = "trait" -- Assume it's an unbracketed trait
        hintValue = cleanedContent
        print("DEBUG: Parsed as Unbracketed Trait. Value:", hintValue)
    end

    return hintType, hintValue
end


-- Function to update the playersMatchingHints table based on current GUI hints
-- MODIFIED: Now correctly handles hints for multiple targets ([1], [2], etc.)
-- A player matches if they meet ALL conditions for AT LEAST ONE target.
local function updateMatchingHintPlayers()
    print("DEBUG: updateMatchingHintPlayers called")
    playersMatchingHints = {} -- Clear the previous results
    print("DEBUG: playersMatchingHints cleared")

    if not espEnabled then print("DEBUG: updateMatchingHintPlayers: ESP not enabled"); return end -- Only update if ESP is on


    local PlayerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then print("DEBUG: updateMatchingHintPlayers: PlayerGui not found"); return end

    -- Safely find the TARGETHINT label. Assuming it's under RESETONDEATHStatusGui based on the larger script.
    local TargetHintLabel = PlayerGui:FindFirstChild("RESETONDEATHStatusGui") and PlayerGui.RESETONDEATHStatusGui:FindFirstChild("TARGETHINT") -- Corrected path based on typical GUI structure

    if not TargetHintLabel or not TargetHintLabel:IsA("TextLabel") then
        -- warn("Blood Debt Role Detector: TARGETHINT label not found or not a TextLabel.") -- Optional warning
        print("DEBUG: updateMatchingHintPlayers: TARGETHINT label not found or invalid")
        return
    end

    local hintText = TargetHintLabel.Text
    print("DEBUG: Raw TARGETHINT text:", hintText) -- Print raw hint text

    if string.len(string.gsub(hintText, "%s", "")) == 0 then -- Check if the hint text is empty or just whitespace
        -- No hints means no one can match all hints
        print("DEBUG: Hint text is empty.") -- Optional Debug
        return
    end

    -- Check if the local player is the killer based on the hint text prefix
    local hintPrefix = "Hints : " -- Note: Capitalized 'H' as per your example
    local lowerHintText = string.lower(hintText) -- Store lowercased text in a variable
    local lowerHintPrefix = string.lower(hintPrefix) -- Lowercase the prefix for comparison

    if lowerHintText:sub(1, string.len(lowerHintPrefix)) ~= lowerHintPrefix then
        print("DEBUG: Local player is not the killer ('" .. hintText:sub(1, string.len(hintPrefix)) .. "' != '" .. hintPrefix .. "'). Skipping hint matching.") -- Optional Debug
        return -- Exit if the hint text doesn't start with "Hints : "
    end

    -- Remove the "Hints : " prefix and any trailing space
    local actualHintContent = hintText:sub(string.len(hintPrefix) + 1):match("^%s*(.-)%s*$")
    print("DEBUG: Raw Hint Content (after removing 'Hints : ' and trimming):", actualHintContent) -- Print raw hint content

    -- Split the hint content by " + " into individual hint parts.
    -- Each part might belong to a different target indicated by [1], [2], etc.
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
            currentPos = string.len(actualHintContent) + 1 -- Exit loop
        end
    end

    -- Handle the case of a single hint without " + "
    if #individualHintParts == 0 and string.len(actualHintContent) > 0 then
        table.insert(individualHintParts, actualHintContent)
    end

    print("DEBUG: Split into Individual Hint Parts:", individualHintParts)

    local targetConditions = {} -- Table to hold conditions, grouped by target number

    for i, hintPartContent in ipairs(individualHintParts) do
        -- Extract target number and cleaned content from the hint part
        local targetNumberMatch = hintPartContent:match("^%[%s*(%d+)%s*%]") -- Capture the number inside brackets
        local targetNumber = tonumber(targetNumberMatch) or 1 -- Default to target 1 if no number found
        local cleanedHintPartContent = hintPartContent:gsub("^%[%s*%d+%s*%]%s*", ""):match("^%s*(.-)%s*$") or "" -- Remove [number] prefix and trim

        print("DEBUG: Processing Hint Part:", hintPartContent, "Target Number:", targetNumber, "Cleaned Content:", cleanedHintPartContent)

        local hintType, hintValue = parseSingleHint(cleanedHintPartContent)

        if hintType ~= "invalid" and hintValue and string.len(hintValue) > 0 then
            -- Add the parsed condition to the list for this target number
            if not targetConditions[targetNumber] then
                targetConditions[targetNumber] = {}
            end
            table.insert(targetConditions[targetNumber], { type = hintType, value = hintValue })
            print("DEBUG: Parsed Condition for Target", targetNumber, ": Type =", hintType, "Value =", hintValue)
        else
             print("DEBUG: Hint Part", i, "contained no valid condition after parsing. Skipping.")
        end
    end

    -- Now, check each player. A player matches if they meet ALL conditions for AT LEAST ONE target.
    if next(targetConditions) == nil then -- Check if the table is empty
        print("DEBUG: No valid target conditions parsed from hint text. No players will match.")
        return -- No conditions means no matches
    end


    -- Ensure NPCSFolder is available (waited for at the top)
    if not NPCSFolder then
        warn("Blood Debt Role Detector: NPCSFolder not available for hint matching.")
        return
    end

    for _, player in Players:GetPlayers() do
        -- Only check other players
        if player ~= lp then
            local playerNPCModel = NPCSFolder:FindFirstChild(player.Name)

            if playerNPCModel then
                 local configObject = playerNPCModel:FindFirstChild("Configuration")
                 -- Configuration object is needed for trait checks

                 local playerMatchesAnyTarget = false -- Flag to see if player matches ANY target's conditions

                 for targetNumber, conditionsForTarget in pairs(targetConditions) do -- Iterate through each target's conditions
                     local playerMatchesAllConditionsForTarget = true -- Flag to see if player matches ALL conditions for THIS target

                     print("DEBUG: Checking player", player.Name, "against conditions for Target", targetNumber)

                     for i, condition in ipairs(conditionsForTarget) do -- Iterate through each condition for the current target
                         print("DEBUG:   Checking Condition", i, " (Type:", condition.type, ", Value:", condition.value, ") for Target", targetNumber)

                         local conditionMet = false

                         if condition.type == "task" then
                             -- Check AssignedTask directly under the player's NPC model
                             local assignedTaskObject = playerNPCModel:FindFirstChild("AssignedTask")
                             print("DEBUG:     Checking Task for player", player.Name, ": Hint Value =", condition.value, ", AssignedTask Object Found =", assignedTaskObject ~= nil, ", AssignedTask Value =", assignedTaskObject and assignedTaskObject.Value or "N/A")
                             if assignedTaskObject and assignedTaskObject:IsA("StringValue") and assignedTaskObject.Value == condition.value then
                                 conditionMet = true
                                 print("DEBUG:     Player", player.Name, "MATCHES Task:", condition.value, " for Target", targetNumber)
                             else
                                 print("DEBUG:     Player", player.Name, "does NOT match Task:", condition.value, " for Target", targetNumber)
                             end
                         elseif condition.type == "trait" then
                             -- Check for the trait under Configuration.Value
                             if configObject then -- Ensure Configuration exists for trait checks
                                  -- MODIFIED: Iterate through all children of Configuration
                                  print("DEBUG:     Checking Trait for player", player.Name, ": Hint Value =", condition.value, ". Searching Configuration children.")
                                  for _, configChild in ipairs(configObject:GetChildren()) do
                                      if configChild:IsA("StringValue") then
                                          print("DEBUG:       Checking Configuration StringValue:", configChild.Name, ", Value:", configChild.Value)
                                          if configChild.Value == condition.value then
                                              conditionMet = true
                                              print("DEBUG:       Player", player.Name, "MATCHES Trait (Configuration child):", condition.value, " via StringValue:", configChild.Name, " for Target", targetNumber)
                                              break -- Found a matching trait, no need to check other StringValues in Configuration for this condition
                                          end
                                      end
                                  end
                                  if not conditionMet then
                                      print("DEBUG:     Player", player.Name, "does NOT match Trait (Configuration children):", condition.value, " for Target", targetNumber)
                                  end
                             else
                                 print("DEBUG:     Player", player.Name, "NPC model does not have 'Configuration' object. Cannot check trait for Target", targetNumber)
                             end
                         end

                         -- If the player does NOT meet this specific condition for THIS target, they do NOT match ALL conditions for THIS target
                         if not conditionMet then
                             playerMatchesAllConditionsForTarget = false
                             print("DEBUG: Player", player.Name, "does NOT match Condition", i, " for Target", targetNumber, ". Marking as NOT matching ALL conditions for THIS target.")
                             break -- Player doesn't match this condition for this target, no need to check other conditions for THIS target
                         end
                     end -- End of loop through conditions for the current target

                     -- If the player matched ALL conditions for THIS target, they match ANY target
                     if playerMatchesAllConditionsForTarget then
                         playerMatchesAnyTarget = true
                         print("DEBUG: Player", player.Name, "MATCHES ALL conditions for Target", targetNumber, ". Marking as matching ANY target.")
                         break -- Player matches this target, no need to check other targets for this player
                     end
                 end -- End of loop through targets

                 -- If the player matched ANY target's conditions, add them to playersMatchingHints
                 if playerMatchesAnyTarget then
                     playersMatchingHints[player] = true
                     print("DEBUG: Player", player.Name, "MARKED as playersMatchingHints (matched ANY target).") -- Optional Debug
                 -- else
                      -- print("DEBUG: Player", player.Name, "does NOT match ANY target's conditions.") -- Optional Debug
                 end

              -- else
                  -- print("DEBUG: Player", player.Name, "model under NPCSFolder does not have 'Configuration' object.") -- Optional Debug
              end
         -- else
              -- print("DEBUG: Player", player.Name, "model not found under NPCSFolder.") -- Optional Debug
         end
     end
end -- End of updateMatchingHintPlayers function


-- Function to connect the hint text changed signal (called when ESP is enabled, and now on character added)
local function connectHintTextSignal()
     if not espEnabled then return end
     -- Disconnect existing connection before trying to connect a new one
     if hintTextConnection then
         print("DEBUG: Disconnecting existing hintTextConnection.")
         hintTextConnection:Disconnect()
         hintTextConnection = nil
     end

     local PlayerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
     if not PlayerGui then print("DEBUG: connectHintTextSignal: PlayerGui not found"); return end

     -- Safely wait for the GUI elements needed for the hint
     -- Increased wait times slightly for robustness
     local statusGui = PlayerGui:WaitForChild("RESETONDEATHStatusGui", 20) -- Increased wait time
     if not statusGui then
         warn("Blood Debt Role Detector: Could not find RESETONDEATHStatusGui after waiting. Hint matching disabled.")
         print("DEBUG: connectHintTextSignal: RESETONDEATHStatusGui not found.")
         return
     end

     local TargetHintLabel = statusGui:WaitForChild("TARGETHINT", 10) -- Increased wait time
     if not TargetHintLabel or not TargetHintLabel:IsA("TextLabel") then
         warn("Blood Debt Role Detector: Could not find TARGETHINT TextLabel or it's not a TextLabel after waiting. Hint matching disabled.")
         print("DEBUG: connectHintTextSignal: TARGETHINT TextLabel not found or invalid.")
         return
     end

     -- Connect the signal from TargetHintLabel directly
     hintTextConnection = TargetHintLabel:GetPropertyChangedSignal("Text"):Connect(updateMatchingHintPlayers)
     print("Blood Debt Role Detector: TARGETHINT TextLabel signal connected.")
     updateMatchingHintPlayers() -- Run initial check immediately after connecting
end


-- Detect and apply roles - Integrated updated logic and priorities
local function detectRoles()
    if not espEnabled then print("DEBUG: detectRoles: ESP not enabled, skipping."); return end -- Safety check
    print("DEBUG: detectRoles called.")

    -- State for New Highest Priority Killer rule (1 Vigilante + 1 Killer Gun)
    local newHighestPriorityKillerDetected = false
    local theSingleKillerGunHolder = nil

    -- State for existing Special Killer rule (Priority 2)
    local specialKillerDetected = false
    local playersWithSpecialWeapons = {}

    -- State for Distance Locking rule (Priority 3)
    local everyoneHasGunConditionMet = false
    local noOneHasGunConditionMet = false
    -- rolesLockedByDistance and lockedDistanceRoles are state variables outside this function


    local playersWithValidCharacters = {} -- Track players who are not local and have characters/HRP
    local playersWithoutAnyGun = {}         -- Track players without *any* role weapon
    local playersWithAnyGun = {}            -- Track players with *any* role weapon
    local playersWithVigilanteWeapons = {}  -- Track players with Vigilante weapons

    -- Counts for New Highest Priority Killer rule
    local vigilanteCount = 0
    local killerGunHoldersCount = 0
    local singleKillerGunHolderCandidate = nil


    -- **Pass 1: Scan for conditions and identify player states**
    for _, player in ipairs(Players:GetPlayers()) do
        -- Only process players who are not the local player and have a valid character model with HRP
        -- NOTE: We still check player.Character here for tagging purposes, even though hint data is elsewhere
        if player ~= lp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
             playersWithValidCharacters[player] = true -- Mark as valid target for tagging

             local toolsByName = collectPlayerTools(player)
             local hasAnyRoleWeapon = false
             local hasVigilanteWeapon = false
             local hasKillerWeapon = false

             -- Check for conditions and weapons on this player
             for name, tool in pairs(toolsByName) do
                 -- Check for Special Killers (for Priority 2)
                 if specialKillerWeapons[name] then
                     specialKillerDetected = true
                     playersWithSpecialWeapons[player] = true
                 end
                 -- Check if it's *any* role weapon (for Everyone Has Gun/No One Has Gun)
                 if allRoleWeapons[name] then
                      hasAnyRoleWeapon = true
                 end
                 -- Check for Vigilante weapon (for New #1 rule and First Vigilante)
                 if vigilanteWeapons[name] then
                     hasVigilanteWeapon = true
                     playersWithVigilanteWeapons[player] = true -- Mark player as having a Vigilante weapon
                 end
                 -- Check for ANY Killer weapon (for New #1 rule) - Use updated killerWeapons list
                 if killerWeapons[name] then
                     hasKillerWeapon = true
                 end
             end

             if hasVigilanteWeapon then
                  vigilanteCount = vigilanteCount + 1
                  -- Track the first vigilante detected across all ESP runs
                  if firstVigilanteTracker[player] == nil then
                      firstVigilanteTracker[player] = true
                  end
             end

              if hasKillerWeapon then
                  killerGunHoldersCount = killerGunHoldersCount + 1
                  singleKillerGunHolderCandidate = player -- Candidate for the single killer gun holder
             end


             if not hasAnyRoleWeapon then
                 playersWithoutAnyGun[player] = true -- Mark if they have no role weapon
             else
                 playersWithAnyGun[player] = true -- Mark if they DO have a role weapon
             end

        else
            -- Player is local player or without a valid character - ensure tags are cleared
            clearOldStuff(player.Character)
        end
    end

    -- **Step 2: Determine if the New Highest Priority Killer rule applies**
    if vigilanteCount == 1 and killerGunHoldersCount == 1 and singleKillerGunHolderCandidate then
         newHighestPriorityKillerDetected = true
         theSingleKillerGunHolder = singleKillerGunHolderCandidate
         -- Note: This rule overrides lower priority conditions if it applies
         specialKillerDetected = false
         playersWithSpecialWeapons = {}
         everyoneHasGunConditionMet = false -- Ensure distance lock rule is NOT checked if this one is ON
         rolesLockedByDistance = false      -- Ensure distance lock is OFF if this one is ON
         lockedDistanceRoles = {}

         -- ADDED: If local player is the New Highest Priority Killer, trigger hint check
         if theSingleKillerGunHolder == lp then
             print("DEBUG: Local player is New #1 Killer. Triggering updateMatchingHintPlayers.")
             updateMatchingHintPlayers()
         end

         -- print("DEBUG: New Highest Priority Killer rule MET (1 Vigilante, 1 Killer Gun).") -- DEBUG
    -- else
         -- print("DEBUG: New Highest Priority Killer rule NOT MET. Vigilante Count:", vigilanteCount, "Killer Gun Holders:", killerGunHoldersCount) -- Optional DEBUG
    end


    -- **Step 3: Determine the state of "Everyone has a gun" and "No one has a gun" conditions (Only if no New Highest Killer)**
    if not newHighestPriorityKillerDetected then -- Check these ONLY if New #1 rule is OFF
         -- Check "Everyone has a gun" (only if no special killer)
         local allValidTargetsHaveGun = true
         local otherPlayersWithCharCount = 0
         for player, _ in pairs(playersWithValidCharacters) do
             if player ~= lp then otherPlayersWithCharCount = otherPlayersWithCharCount + 1 end
             if playersWithoutAnyGun[player] then
                 allValidTargetsHaveGun = false -- Found someone without a gun
                 break
             end
         end
         -- Condition is met if all valid targets had a gun AND there is at least one valid target besides local player
         if allValidTargetsHaveGun and otherPlayersWithCharCount > 0 then
             everyoneHasGunConditionMet = true
             -- print("DEBUG: 'Everyone has a gun' condition MET.") -- DEBUG
         -- else
             -- print("DEBUG: 'Everyone has a gun' condition NOT MET.") -- DEBUG
         end

         -- Check "No one has a gun" (only if no special killer)
         local anyValidTargetHasGun = false
         for player, _ in pairs(playersWithValidCharacters) do
              if playersWithAnyGun[player] then
                  anyValidTargetHasGun = true -- Found someone *with* a gun
                  break
              end
         end
         -- Condition is met if NO valid target has a gun AND there is at least one valid target
         if not anyValidTargetHasGun and otherPlayersWithCharCount > 0 then
              noOneHasGunConditionMet = true
              -- print("DEBUG: 'No one has a gun' condition MET.") -- DEBUG
         -- else
             -- print("DEBUG: 'No one has a gun' condition NOT MET.") -- Optional Debug
         end
    end


    -- **Step 4: Manage the distance locking state (rolesLockedByDistance)**
    -- Note: This lock is independent of the New Highest Priority rule, but *depends* on it being OFF to trigger
    -- local prevRolesLockedByDistance = rolesLockedByDistance -- Store state before checking transitions (not strictly needed for logic, but useful for debugging)

    -- Condition to ACTIVATE lock: No New Highest Killer AND No special killer AND Everyone has a gun AND Not already locked
    if not newHighestPriorityKillerDetected and not specialKillerDetected and everyoneHasGunConditionMet and not rolesLockedByDistance then
         rolesLockedByDistance = true -- Activate the lock
         lockedDistanceRoles = {} -- Clear any old locked roles
         print("Blood Debt Role Detector: Distance Lock ACTIVATED.") -- DEBUG

         -- Determine and store the distance-based roles for locking
         local localHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") -- Need local HRP for distance

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
                 else
                      -- Should not happen if playersWithValidCharacters is correct, but safety
                 end
             end
         else
              -- Local player HRP missing - cannot lock distance roles
              rolesLockedByDistance = false -- Force lock off if cannot calculate distance
              lockedDistanceRoles = {}
              warn("Blood Debt Role Detector: Distance Lock failed to activate: Local HRP missing.")
         end
    end

    -- Condition to DEACTIVATE lock: No New Highest Killer AND No special killer AND No one has a gun AND Currently locked
    if not newHighestPriorityKillerDetected and not specialKillerDetected and noOneHasGunConditionMet and rolesLockedByDistance then
         rolesLockedByDistance = false -- Deactivate the lock
         lockedDistanceRoles = {} -- Clear stored roles
         print("Blood Debt Role Detector: Distance Lock DEACTIVATED.") -- DEBUG
    end

    -- Note: If neither transition happens, rolesLockedByDistance keeps its state


    -- **Step 5: Trigger Hint Matching Update**
    -- This is called here to ensure playersMatchingHints is up-to-date before applying tags.
    -- It's also connected to the TextChanged signal for real-time updates.
    -- The New #1 Killer check above also triggers this.
    -- RESTORED: Call updateMatchingHintPlayers regularly in the loop
    updateMatchingHintPlayers()


    -- **Pass 2: Apply Tags based on determined state (New #1 > Special Killer > Distance Locked > Vigilante+Hint > Hint Match > Standard)**
    for _, player in ipairs(Players:GetPlayers()) do
        -- Only process players who were marked as valid targets in Pass 1
        if playersWithValidCharacters[player] then

             if newHighestPriorityKillerDetected and player == theSingleKillerGunHolder then
                 -- NEW Highest Priority: New #1 Killer Rule
                 print("DEBUG: Applying New #1 Killer tag for", player.Name)
                 tagPlayer(player, killerColor, killerLabel)

             elseif specialKillerDetected then
                 -- Priority 2: Special Killer rule (Existing)
                 -- Rule: Holder is Killer. Everyone else is Innocent when special is present.
                 if playersWithSpecialWeapons[player] then
                     print("DEBUG: Applying Special Killer tag for", player.Name)
                     tagPlayer(player, killerColor, killerLabel)
                 else
                     print("DEBUG: Applying Innocent tag (under Special Killer Rule) for", player.Name)
                     tagPlayer(player, innocentColor, innocentLabel)
                 end

             elseif rolesLockedByDistance then
                 -- Priority 3: Roles locked by "Everyone has a gun" rule - Use LOCKED distance roles
                 local lockedRole = lockedDistanceRoles[player] -- Look up the stored distance role string
                 print("DEBUG: Applying Distance Locked Rule for", player.Name, "Locked Role:", lockedRole)

                 if lockedRole then
                      if lockedRole == "Killer" then
                           print("DEBUG: Tagging", player.Name, "as KILLER (by locked distance).")
                           tagPlayer(player, killerColor, killerLabel)
                      elseif lockedRole == "Innocent" then
                           print("DEBUG: Tagging", player.Name, "as INNOCENT (by locked distance).")
                           tagPlayer(player, innocentColor, innocentLabel)
                      end
                 else
                     -- Player somehow valid but not in lockedDistanceRoles - safety clear
                     clearOldStuff(player.Character)
                     print("DEBUG: Player", player.Name, "valid but not in lockedDistanceRoles. Clearing.")
                 end

             -- NEW: Priority 4: Vigilante + Hint Match (Purple)
             -- Apply this tag if the player matches hints AND has a vigilante weapon.
             print("DEBUG: Checking Vigilante + Hint Match condition for", player.Name, ": playersMatchingHints[player] =", playersMatchingHints[player] ~= nil, ", playersWithVigilanteWeapons[player] =", playersWithVigilanteWeapons[player] ~= nil)
             -- REMOVED: 'and not firstVigilanteTracker[player]' to tag ALL matching vigilantes
             elseif playersMatchingHints[player] and playersWithVigilanteWeapons[player] then
                  print("DEBUG: Applying VIGILANTE + HINT MATCH tag for", player.Name, ". Condition met.")
                  tagPlayer(player, vigilanteHintColor, vigilanteHintLabel)


             elseif playersMatchingHints[player] and not firstVigilanteTracker[player] then
                 -- Priority 5: Hint Matching Yellow Color (Original Priority 4)
                 -- Tag yellow if matches hints AND is *not* the first detected Vigilante (to avoid overriding Cyan tag)
                 -- This priority is now below the purple tag, so a matching vigilante gets purple.
                 print("DEBUG: Applying HINT MATCH tag (Yellow) for", player.Name, ". Condition met.")
                 tagPlayer(player, hintMatchColor, hintMatchLabel)


             else
                 -- Priority 6: Standard detection (Original Priority 5)
                 local toolsByName = collectPlayerTools(player)
                 local standardRole, standardColor, standardLabel = getStandardRoleFromWeapons(toolsByName)
                 print("DEBUG: Applying Standard Detection for", player.Name, ". Standard Role:", standardLabel)
                 if standardRole then
                     tagPlayer(player, standardColor, standardLabel)
                 else
                     tagPlayer(player, innocentColor, innocentLabel)
                 end
             end

        else
            -- Players not in playersWithValidCharacters were handled in Pass 1 (cleared)
            print("DEBUG: Skipping tagging for", player.Name, " (not a valid target)")
        end
    end

    -- No need to update previous state flags like prevEveryoneHasGunConditionMet
    -- because the lock state `rolesLockedByDistance` directly controls the behavior.

end -- End of detectRoles function


-- Function to disable ESP - Shared logic (Includes clearing lock/hint state)
local function disableEsp()
    if espEnabled then -- Only disable if it's currently enabled
        espEnabled = false
        stopEspLoop = true -- Signal to stop the loop
        print("Blood Debt Role Detector: ESP Disabled")

        -- Clear state variables
        rolesLockedByDistance = false
        lockedDistanceRoles = {}
        playersMatchingHints = {} -- Clear hint matches
        -- Do NOT clear firstVigilanteTracker, it should persist across disable/enable

        -- Disconnect the main PlayerAdded connection
        if espPlayerAddedConnection then
            espPlayerAddedConnection:Disconnect()
            espPlayerAddedConnection = nil
        end

        -- Disconnect hint text signal
        if hintTextConnection then
            print("DEBUG: Disconnecting hintTextConnection during disable.")
            hintTextConnection:Disconnect()
            hintTextConnection = nil
        end

        -- Disconnect all stored CharacterAdded connections
        for player, connection in pairs(espCharacterAddedConnections) do
             if connection and typeof(connection) == "RBXScriptConnection" then -- Safety check connection type
                connection:Disconnect()
            end
            espCharacterAddedConnections[player] = nil
        end
        espCharacterAddedConnections = {} -- Clear the table itself


        -- Clear ESP visuals for all players currently in the game
        for _, player in ipairs(Players:GetPlayers()) do
             if player.Character then
                clearOldStuff(player.Character)
            end
        end
         Rayfield:Notify({
            Title = "ESP Disabled",
            Content = "Role detection has been turned off.",
            Duration = 3,
            Image = 4483362458 -- Replace with a suitable asset ID
        })
    end
end


-- Function to teleport to dropped gun - Includes all relevant weapons
local function tpToDroppedGun()
    -- Ensure BloodFolder is available (waited for at the top)
    if not BloodFolder then
         warn("Blood Debt Role Detector: BloodFolder not available for teleport.")
         Rayfield:Notify({
            Title = "Error",
            Content = "BloodFolder not found in Workspace.",
            Duration = 5,
            Image = 4483362458 -- Replace with a suitable asset ID
        })
        return
    end

    local foundGun = false
    for _, item in ipairs(BloodFolder:GetChildren()) do
        -- Check if the dropped item is a Killer, Vigilante, or Special Killer weapon
        if item:IsA("Tool") and (killerWeapons[item.Name] or vigilanteWeapons[item.Name] or specialKillerWeapons[item.Name]) then
            local targetPosition = item.Position + Vector3.new(0, 5, 0) -- Teleport slightly above the item
            if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                 lp.Character:SetPrimaryPartCFrame(CFrame.new(targetPosition))
                 foundGun = true
                 break -- Teleported to the first found gun
            else
                 warn("Blood Debt Role Detector: Local player character or HRP not found for teleport.")
                 Rayfield:Notify({
                    Title = "Error",
                    Content = "Cannot teleport: Your character is not ready.",
                    Duration = 5,
                    Image = 4483362458 -- Replace with a suitable asset ID
                })
                return -- Exit if character not ready
            end
        end
    end

    if not foundGun then
        Rayfield:Notify({
            Title = "No Gun Found",
            Content = "There are no valid guns in the BloodFolder.",
            Duration = 5,
            Image = 4483362458 -- Replace with a suitable asset ID
        })
    end
end

-- Add a button for teleporting to the dropped gun
local ButtonTPGunCreateSuccess, ButtonTPGun = pcall(function()
    return Tab:CreateButton({
        Name = "Teleport to Dropped Gun",
        Callback = function()
            tpToDroppedGun()
        end
    })
end)

if not ButtonTPGunCreateSuccess or not ButtonTPGun then
    warn("Blood Debt Role Detector: Failed to create Teleport to Dropped Gun button. Success:", ButtonTPGunCreateSuccess)
else
    print("Blood Debt Role Detector: Teleport to Dropped Gun button created successfully.")
end


-- Create Enable ESP button - Only enables if not already enabled
local ButtonEnableESPCreateSuccess, ButtonEnableESP = pcall(function()
    return Tab:CreateButton({
        Name = "Enable ESP",
        Callback = function()
            if not espEnabled then -- Only enable if it's currently disabled
                espEnabled = true
                stopEspLoop = false -- Ensure loop will run
                print("Blood Debt Role Detector: ESP Enabled")

                -- Start the detection loop in a new thread/coroutine
                task.spawn(function()
                    while espEnabled and not stopEspLoop do -- Loop condition
                        task.wait(0.5) -- Adjust wait time as needed
                        detectRoles() -- detectRoles has its own espEnabled check
                    end
                     print("Blood Debt Role Detector: ESP Detection loop stopped.")
                end)

                -- Connect PlayerAdded/CharacterAdded events for new players joining
                espPlayerAddedConnection = game.Players.PlayerAdded:Connect(function(player)
                     local charAddedConn = player.CharacterAdded:Connect(function(character)
                         task.wait(0.1) -- Give a small delay for character/GUI to potentially load
                         connectHintTextSignal() -- Attempt to reconnect the hint signal for the new player's GUI
                         detectRoles() -- Run detection for the new player
                     end)
                     espCharacterAddedConnections[player] = charAddedConn -- Store connection

                     -- Also run detectRoles if character already exists (e.g., joining mid-game)
                     if player.Character then
                          task.wait(0.1)
                          detectRoles()
                     end
                end)

                -- Connect PlayerRemoving for cleanup
                 game.Players.PlayerRemoving:Connect(function(player)
                    if espCharacterAddedConnections[player] then
                        if typeof(espCharacterAddedConnections[player]) == "RBXScriptConnection" then -- Safety check
                            espCharacterAddedConnections[player]:Disconnect()
                        end
                        espCharacterAddedConnections[player] = nil
                    end
                    -- Clear visuals for the player who is leaving
                    clearOldStuff(player.Character)
                end)

                -- Connect the hint text signal for real-time hint updates (Initial connection attempt)
                -- This is crucial for hint matching to work.
                connectHintTextSignal()

                -- Initial detection right after enabling for players already in game
                detectRoles()

                Rayfield:Notify({
                    Title = "ESP Enabled",
                    Content = "Role detection has been turned on.",
                    Duration = 3,
                    Image = 4483362458 -- Replace with a suitable asset ID
                })

            else
                print("Blood Debt Role Detector: ESP is already enabled.")
                 Rayfield:Notify({
                    Title = "ESP Already On",
                    Content = "Role detection is already running.",
                    Duration = 3,
                    Image = 4483362458 -- Replace with a suitable asset ID
                })
            end
        end
    })
end)

if not ButtonEnableESPCreateSuccess or not ButtonEnableESP then
    warn("Blood Debt Role Detector: Failed to create Enable ESP button. Success:", ButtonEnableESPCreateSuccess)
else
    print("Blood Debt Role Detector: Enable ESP button created successfully.")
end


-- Create Disable ESP button - Calls the shared disable function
local ButtonDisableESPCreateSuccess, ButtonDisableESP = pcall(function()
    return Tab:CreateButton({
        Name = "Disable ESP",
        Callback = function()
            disableEsp() -- Call the shared disable function
        end
    })
end)

if not ButtonDisableESPCreateSuccess or not ButtonDisableESP then
    warn("Blood Debt Role Detector: Failed to create Disable ESP button. Success:", ButtonDisableESPCreateSuccess)
else
    print("Blood Debt Role Detector: Disable ESP button created successfully.")
end


-- Notify the user about ESP - Adjusted to mention two buttons
-- This notification might appear before the buttons are fully visible, depending on Rayfield's rendering.
-- It's more of a confirmation that the script ran through the UI creation steps.
Rayfield:Notify({
    Title = "ESP Script Initialized",
    Content = "Attempted to create UI elements. Check output for details.",
    Duration = 5,
    Image = 4483362458 -- Replace with a suitable asset ID
})

-- The Z Key Bind Functionality from the original large script was removed as it was commented out.

-- End of Script
