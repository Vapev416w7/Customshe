if not game:IsLoaded() then game.Loaded:Wait() end

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local camera = Workspace.CurrentCamera


local folderName = "GGWARE"
local filePath = folderName .. "/settings.json"

if not isfolder(folderName) then
    makefolder(folderName)
end

local Settings = {}

local function saveSettings()
    writefile(filePath, HttpService:JSONEncode(Settings))
end

local function loadSettings()
    if isfile(filePath) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(filePath))
        end)
        if success and type(data) == "table" then
            Settings = data
        end
    end
end

loadSettings()

--// REMOTES
local bedwarsNet = ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
local swordHitRemote = bedwarsNet:WaitForChild("SwordHit")
local setInvItemRemote = bedwarsNet:WaitForChild("SetInvItem")

--// KILLAURA CONFIG (MAX SPEED)
local killaura = {
    Enabled = Settings.Killaura or false,
    Range = 50,
    TrueRange = 50,
    AttackRate = 0, -- MAX SPEED - every frame
    MultiHit = true,
    MaxTargets = 3,
    WallCheck = false,
    AutoEquip = true,
    FakePositionOffset = 10,
    InstantSwing = true,
    BypassValidation = true
}

local swordNames = {"rageblade","frosty_hammer","emerald_sword", "diamond_sword", "iron_sword", "stone_sword", "wood_sword"}

--// CACHED VARIABLES (NO LAG)
local cachedInventory = nil
local lastEquipTime = 0
local equipCooldown = 0.15-- Only equip every 300ms max
local currentWeapon = nil
local hasTarget = false

--// COMBAT-CONSTANT HOOK
local function setupCombatConstantHook()
    local success, combatConstant = pcall(function()
        local combatModule = ReplicatedStorage:WaitForChild("TS"):WaitForChild("combat"):WaitForChild("combat-constant")
        return require(combatModule)
    end)
    
    if success and combatConstant then
        if combatConstant.CombatConstant then
            combatConstant.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = 50
            combatConstant.CombatConstant.REGION_SWORD_CHARACTER_DISTANCE = 50
        end
        
        if combatConstant.SwordsConstants then
            combatConstant.SwordsConstants.swordSwingBufferMultiplier = 0
        end
        
        print("Combat-constant hooked | Reach: 30 | Buffer: 0")
    else
        warn("Failed to hook combat-constant")
    end
end

--// HELPER FUNCTIONS
local function isAlive(plr)
    if not plr then plr = player end
    return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0
end

local function getTeam(plr)
    return plr:GetAttribute("TeamId") or plr.TeamColor
end

local function getBestPart(targetModel)
    if not targetModel then return nil end
    local parts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "LeftFoot", "RightFoot", "LeftArm", "RightArm"}
    for _, name in pairs(parts) do
        local part = targetModel:FindFirstChild(name)
        if part then return part end
    end
    return targetModel:FindFirstChildWhichIsA("BasePart")
end

--// FAST AUTO-EQUIP - Only when needed
local function getInventory()
    if not cachedInventory then
        cachedInventory = ReplicatedStorage.Inventories:FindFirstChild(player.Name)
    end
    return cachedInventory
end

local function checkEquippedSword()
    local char = player.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and table.find(swordNames, tool.Name) then
        return tool
    end
    return nil
end

local function autoEquip(force)
    local now = tick()
    if not force and (now - lastEquipTime) < equipCooldown then return currentWeapon end
    
    -- Check if already has sword equipped
    local equipped = checkEquippedSword()
    if equipped then
        currentWeapon = equipped
        return equipped
    end
    
    local inv = getInventory()
    if not inv then return nil end
    
    for _, name in ipairs(swordNames) do
        local item = inv:FindFirstChild(name)
        if item then
            setInvItemRemote:InvokeServer({hand = item})
            lastEquipTime = now
            currentWeapon = item
            return item
        end
    end
    
    return nil
end

--// SWORD CONTROLLER HOOKS
local function setupSwordHooks()
    local success, swordController = pcall(function()
        return require(player.PlayerScripts.TS.controllers.global.combat.sword["sword-controller"])
    end)
    
    if success and swordController and swordController.SwordController then
        local controller = swordController.SwordController
        
        if controller.getRemainingSwingCooldown then
            controller.getRemainingSwingCooldown = function() return 0 end
        end
        if controller.getRemainingChargeCooldown then
            controller.getRemainingChargeCooldown = function() return 0 end
        end
        if controller.getRemainingCastingTime then
            controller.getRemainingCastingTime = function() return 0 end
        end
        if controller.isClickingTooFast then
            controller.isClickingTooFast = function() return false end
        end
        if controller.canSee then
            controller.canSee = function() return true end
        end
        
        print("Sword hooks applied")
    end
end

--// METADATA HOOK
local function setupMetadataHook()
    local success, runtime = pcall(function()
        return require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
    end)
    
    if not success then return end
    
    local oldImport = runtime.import
    runtime.import = function(script, rs, ...)
        local args = {...}
        local result = oldImport(script, rs, unpack(args))
        
        if #args >= 2 and args[#args-1] == "item" and args[#args] == "item-meta" then
            if result and result.getItemMeta then
                local oldGetItemMeta = result.getItemMeta
                result.getItemMeta = function(itemType)
                    local meta = oldGetItemMeta(itemType)
                    if meta and meta.sword then
                        local newMeta = {}
                        for k,v in pairs(meta) do newMeta[k] = v end
                        newMeta.sword = {}
                        for k,v in pairs(meta.sword) do newMeta.sword[k] = v end
                        
                        newMeta.sword.attackRange = 30
                        newMeta.sword.attackSpeed = 0.001
                        
                        if newMeta.sword.cooldown then
                            newMeta.sword.cooldown = 0
                        end
                        
                        if newMeta.sword.chargedAttack then
                            newMeta.sword.chargedAttack = {}
                            for k,v in pairs(meta.sword.chargedAttack) do 
                                newMeta.sword.chargedAttack[k] = v 
                            end
                            newMeta.sword.chargedAttack.attackRange = 30
                        end
                        
                        return newMeta
                    end
                    return meta
                end
            end
        end
        return result
    end
end

--// TARGETING (OPTIMIZED)
local myTeam, myPos, myRoot
local targetsCache = {}
local lastTargetUpdate = 0
local targetUpdateInterval = 0.05 -- Update targets every 50ms (20fps check, 60fps attack)

local function updateTargets()
    local now = tick()
    if now - lastTargetUpdate < targetUpdateInterval then
        return targetsCache
    end
    
    targetsCache = {}
    if not isAlive() then 
        hasTarget = false
        return targetsCache 
    end
    
    myTeam = getTeam(player)
    myRoot = player.Character.HumanoidRootPart
    myPos = myRoot.Position
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and isAlive(plr) and getTeam(plr) ~= myTeam then
            local char = plr.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (myPos - root.Position).Magnitude
                if dist <= killaura.Range then
                    local part = getBestPart(char)
                    if part then
                        table.insert(targetsCache, {
                            Character = char,
                            Part = part,
                            Distance = dist,
                            Player = plr
                        })
                    end
                end
            end
        end
    end
    
    table.sort(targetsCache, function(a, b) return a.Distance < b.Distance end)
    hasTarget = #targetsCache > 0
    lastTargetUpdate = now
    return targetsCache
end

--// MAX SPEED KILLAURA - NO LAG
local lastAttack = 0
local function startUltraKillaura()
    setupSwordHooks()
    setupMetadataHook()
    setupCombatConstantHook()
    
    RunService.Heartbeat:Connect(function()
        if not killaura.Enabled then return end
        if not isAlive() then return end
        
        -- MAX SPEED: No attack rate limit (0)
        -- Only check if we should throttle (optional safety)
        if killaura.AttackRate > 0 then
            local now = tick()
            if now - lastAttack < killaura.AttackRate then return end
            lastAttack = now
        end
        
        -- Get targets (cached, updates every 50ms)
        local targets = updateTargets()
        
        -- NO TARGETS - Don't equip sword, don't waste resources
        if #targets == 0 then 
            currentWeapon = nil
            return 
        end
        
        -- TARGETS FOUND - Equip sword (with cooldown to prevent lag)
        if not currentWeapon then
            autoEquip()
        end
        if not currentWeapon then return end
        
        local camPos = camera.CFrame.Position
        
        -- Attack all targets
        local hitCount = killaura.MultiHit and math.min(#targets, killaura.MaxTargets) or 1
        
        for i = 1, hitCount do
            local target = targets[i]
            if not target then break end
            
            local targetPos = target.Part.Position
            local dir = (targetPos - camPos).Unit
            
            -- FAKE POSITION
            local fakeSelfPos = myPos
            if killaura.FakePositionOffset > 0 then
                local toTarget = (targetPos - myPos).Unit
                fakeSelfPos = myPos + (toTarget * killaura.FakePositionOffset)
            end
            
            local args = {{
                chargedAttack = {chargeRatio = 0},
                lastSwingServerTimeDelta = 0.01,
                entityInstance = target.Character,
                validate = {
                    targetPosition = {value = targetPos},
                    raycast = {
                        cameraPosition = {value = camPos},
                        cursorDirection = {value = dir}
                    },
                    selfPosition = {value = fakeSelfPos}
                },
                weapon = currentWeapon
            }}
            
            swordHitRemote:FireServer(unpack(args))
        end
    end)
end

--// NOTIFICATION
local function showNotification(text)
    local gui = Instance.new("ScreenGui")
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.7, 0, 0.1, 0)
    frame.Position = UDim2.new(0.15, 0, 0.05, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.2
    frame.Parent = gui
    frame.ZIndex = 999

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0.1, 0)

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 1, -20)
    textLabel.Position = UDim2.new(0, 10, 0, 10)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Parent = frame

    frame.Position = UDim2.new(0.15, 0, -0.2, 0)
    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.15, 0, 0.05, 0)
    }):Play()

    task.delay(3, function()
        local tween = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.15, 0, -0.2, 0)
        })
        tween:Play()
        tween.Completed:Wait()
        gui:Destroy()
    end)
end

--// GUI CREATION
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "GGWARE_Loader"
MainGui.ResetOnSpawn = false
MainGui.Parent = playerGui

local Frame_ggware_294 = Instance.new("Frame")
Frame_ggware_294.Name = [[ggware]]
Frame_ggware_294.Size = UDim2.new(1, 0, 1, 0)
Frame_ggware_294.Position = UDim2.new(0, 0, 0, 0)
Frame_ggware_294.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Frame_ggware_294.BackgroundTransparency = 1
Frame_ggware_294.Visible = true
Frame_ggware_294.ZIndex = 1
Frame_ggware_294.Style = Enum.FrameStyle.Custom
Frame_ggware_294.Parent = MainGui

local TextButton_ggware_660 = Instance.new("TextButton")
TextButton_ggware_660.Name = [[ggware]]
TextButton_ggware_660.Size = UDim2.new(0, 80, 0, 30)
TextButton_ggware_660.Position = UDim2.new(0, 780, 0, 0)
TextButton_ggware_660.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_ggware_660.BackgroundTransparency = 1
TextButton_ggware_660.Text = [[ggware]]
TextButton_ggware_660.TextColor3 = Color3.fromRGB(0, 0, 255)
TextButton_ggware_660.TextSize = 8
TextButton_ggware_660.Font = Enum.Font.Legacy
TextButton_ggware_660.TextScaled = false
TextButton_ggware_660.Visible = true
TextButton_ggware_660.ZIndex = 1
TextButton_ggware_660.Style = Enum.ButtonStyle.RobloxButtonDefault
TextButton_ggware_660.Parent = Frame_ggware_294

local Frame_Frame_337 = Instance.new("Frame")
Frame_Frame_337.Name = [[Frame]]
Frame_Frame_337.Size = UDim2.new(0, 120, 0, 200)
Frame_Frame_337.Position = UDim2.new(0, 0, 0, 0)
Frame_Frame_337.BackgroundColor3 = Color3.fromRGB(104, 85, 255)
Frame_Frame_337.BackgroundTransparency = 0
Frame_Frame_337.Visible = false
Frame_Frame_337.ZIndex = 1
Frame_Frame_337.Style = Enum.FrameStyle.RobloxRound
Frame_Frame_337.Parent = Frame_ggware_294

local TextButton_Combat_414 = Instance.new("TextButton")
TextButton_Combat_414.Name = [[Combat]]
TextButton_Combat_414.Size = UDim2.new(0, 107, 0, 35)
TextButton_Combat_414.Position = UDim2.new(0, 0, 0, 35)
TextButton_Combat_414.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_Combat_414.BackgroundTransparency = 1
TextButton_Combat_414.Text = [[Combat]]
TextButton_Combat_414.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_Combat_414.TextSize = 8
TextButton_Combat_414.Font = Enum.Font.Legacy
TextButton_Combat_414.TextScaled = false
TextButton_Combat_414.Visible = true
TextButton_Combat_414.ZIndex = 1
TextButton_Combat_414.Style = Enum.ButtonStyle.Custom
TextButton_Combat_414.Parent = Frame_Frame_337

local Frame_Frame_390 = Instance.new("Frame")
Frame_Frame_390.Name = [[Frame]]
Frame_Frame_390.Size = UDim2.new(0, 120, 0, 300)
Frame_Frame_390.Position = UDim2.new(0, 180, 0, -50)
Frame_Frame_390.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
Frame_Frame_390.BackgroundTransparency = 0
Frame_Frame_390.Visible = false
Frame_Frame_390.ZIndex = 1
Frame_Frame_390.Style = Enum.FrameStyle.RobloxRound
Frame_Frame_390.Parent = TextButton_Combat_414

local TextLabel_TextLabel_642 = Instance.new("TextLabel")
TextLabel_TextLabel_642.Name = [[TextLabel]]
TextLabel_TextLabel_642.Size = UDim2.new(0, 107, 0, 35)
TextLabel_TextLabel_642.Position = UDim2.new(0, 0, 0, 0)
TextLabel_TextLabel_642.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextLabel_TextLabel_642.BackgroundTransparency = 1
TextLabel_TextLabel_642.Text = [[Combat]]
TextLabel_TextLabel_642.TextColor3 = Color3.fromRGB(0, 0, 255)
TextLabel_TextLabel_642.TextSize = 8
TextLabel_TextLabel_642.Font = Enum.Font.Legacy
TextLabel_TextLabel_642.TextScaled = false
TextLabel_TextLabel_642.Visible = true
TextLabel_TextLabel_642.ZIndex = 1
TextLabel_TextLabel_642.Parent = Frame_Frame_390

local TextButton_TextButton_659 = Instance.new("TextButton")
TextButton_TextButton_659.Name = [[TextButton]]
TextButton_TextButton_659.Size = UDim2.new(0, 107, 0, 35)
TextButton_TextButton_659.Position = UDim2.new(0, 0, 0, 35)
TextButton_TextButton_659.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_TextButton_659.BackgroundTransparency = 1
TextButton_TextButton_659.Text = [[killaura]]
TextButton_TextButton_659.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_TextButton_659.TextSize = 8
TextButton_TextButton_659.Font = Enum.Font.Legacy
TextButton_TextButton_659.TextScaled = false
TextButton_TextButton_659.Visible = true
TextButton_TextButton_659.ZIndex = 1
TextButton_TextButton_659.Style = Enum.ButtonStyle.Custom
TextButton_TextButton_659.Parent = Frame_Frame_390

local TextLabel_ggware_697 = Instance.new("TextLabel")
TextLabel_ggware_697.Name = [[ggware]]
TextLabel_ggware_697.Size = UDim2.new(0, 107, 0, 35)
TextLabel_ggware_697.Position = UDim2.new(0, 0, 0, 0)
TextLabel_ggware_697.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextLabel_ggware_697.BackgroundTransparency = 1
TextLabel_ggware_697.Text = [[ggware]]
TextLabel_ggware_697.TextColor3 = Color3.fromRGB(0, 0, 255)
TextLabel_ggware_697.TextSize = 8
TextLabel_ggware_697.Font = Enum.Font.Legacy
TextLabel_ggware_697.TextScaled = false
TextLabel_ggware_697.Visible = true
TextLabel_ggware_697.ZIndex = 1
TextLabel_ggware_697.Parent = Frame_Frame_337

local TextButton_World_252 = Instance.new("TextButton")
TextButton_World_252.Name = [[World]]
TextButton_World_252.Size = UDim2.new(0, 107, 0, 35)
TextButton_World_252.Position = UDim2.new(0, 0, 0, 105)
TextButton_World_252.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_World_252.BackgroundTransparency = 1
TextButton_World_252.Text = [[world]]
TextButton_World_252.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_World_252.TextSize = 8
TextButton_World_252.Font = Enum.Font.Legacy
TextButton_World_252.TextScaled = false
TextButton_World_252.Visible = true
TextButton_World_252.ZIndex = 1
TextButton_World_252.Style = Enum.ButtonStyle.Custom
TextButton_World_252.Parent = Frame_Frame_337

local Frame_Frame_423 = Instance.new("Frame")
Frame_Frame_423.Name = [[Frame]]
Frame_Frame_423.Size = UDim2.new(0, 120, 0, 300)
Frame_Frame_423.Position = UDim2.new(0, 500, 0, -110)
Frame_Frame_423.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
Frame_Frame_423.BackgroundTransparency = 0
Frame_Frame_423.Visible = false
Frame_Frame_423.ZIndex = 1
Frame_Frame_423.Style = Enum.FrameStyle.RobloxRound
Frame_Frame_423.Parent = TextButton_World_252

local TextLabel_World_754 = Instance.new("TextLabel")
TextLabel_World_754.Name = [[World]]
TextLabel_World_754.Size = UDim2.new(0, 107, 0, 35)
TextLabel_World_754.Position = UDim2.new(0, 0, 0, 0)
TextLabel_World_754.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextLabel_World_754.BackgroundTransparency = 1
TextLabel_World_754.Text = [[World]]
TextLabel_World_754.TextColor3 = Color3.fromRGB(0, 0, 255)
TextLabel_World_754.TextSize = 8
TextLabel_World_754.Font = Enum.Font.Legacy
TextLabel_World_754.TextScaled = false
TextLabel_World_754.Visible = true
TextLabel_World_754.ZIndex = 1
TextLabel_World_754.Parent = Frame_Frame_423

local TextButton_nuker_164 = Instance.new("TextButton")
TextButton_nuker_164.Name = [[nuker]]
TextButton_nuker_164.Size = UDim2.new(0, 107, 0, 35)
TextButton_nuker_164.Position = UDim2.new(0, 0, 0, 35)
TextButton_nuker_164.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_nuker_164.BackgroundTransparency = 1
TextButton_nuker_164.Text = [[nuker]]
TextButton_nuker_164.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_nuker_164.TextSize = 8
TextButton_nuker_164.Font = Enum.Font.Legacy
TextButton_nuker_164.TextScaled = false
TextButton_nuker_164.Visible = true
TextButton_nuker_164.ZIndex = 1
TextButton_nuker_164.Style = Enum.ButtonStyle.Custom
TextButton_nuker_164.Parent = Frame_Frame_423

local TextButton_Utility_675 = Instance.new("TextButton")
TextButton_Utility_675.Name = [[Utility]]
TextButton_Utility_675.Size = UDim2.new(0, 107, 0, 35)
TextButton_Utility_675.Position = UDim2.new(0, 0, 0, 70)
TextButton_Utility_675.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_Utility_675.BackgroundTransparency = 1
TextButton_Utility_675.Text = [[utility]]
TextButton_Utility_675.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_Utility_675.TextSize = 8
TextButton_Utility_675.Font = Enum.Font.Legacy
TextButton_Utility_675.TextScaled = false
TextButton_Utility_675.Visible = true
TextButton_Utility_675.ZIndex = 1
TextButton_Utility_675.Style = Enum.ButtonStyle.Custom
TextButton_Utility_675.Parent = Frame_Frame_337

local Frame_Frame_518 = Instance.new("Frame")
Frame_Frame_518.Name = [[Frame]]
Frame_Frame_518.Size = UDim2.new(0, 120, 0, 300)
Frame_Frame_518.Position = UDim2.new(0, 360, 0, -80)
Frame_Frame_518.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
Frame_Frame_518.BackgroundTransparency = 0
Frame_Frame_518.Visible = false
Frame_Frame_518.ZIndex = 1
Frame_Frame_518.Style = Enum.FrameStyle.RobloxRound
Frame_Frame_518.Parent = TextButton_Utility_675

local TextLabel_utility_139 = Instance.new("TextLabel")
TextLabel_utility_139.Name = [[utility]]
TextLabel_utility_139.Size = UDim2.new(0, 107, 0, 35)
TextLabel_utility_139.Position = UDim2.new(0, 0, 0, 0)
TextLabel_utility_139.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextLabel_utility_139.BackgroundTransparency = 1
TextLabel_utility_139.Text = [[utility]]
TextLabel_utility_139.TextColor3 = Color3.fromRGB(0, 0, 255)
TextLabel_utility_139.TextSize = 8
TextLabel_utility_139.Font = Enum.Font.Legacy
TextLabel_utility_139.TextScaled = false
TextLabel_utility_139.Visible = true
TextLabel_utility_139.ZIndex = 1
TextLabel_utility_139.Parent = Frame_Frame_518

local TextButton_autokit_588 = Instance.new("TextButton")
TextButton_autokit_588.Name = [[autokit]]
TextButton_autokit_588.Size = UDim2.new(0, 107, 0, 35)
TextButton_autokit_588.Position = UDim2.new(0, 0, 0, 140)
TextButton_autokit_588.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_autokit_588.BackgroundTransparency = 1
TextButton_autokit_588.Text = [[autokit]]
TextButton_autokit_588.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_autokit_588.TextSize = 8
TextButton_autokit_588.Font = Enum.Font.Legacy
TextButton_autokit_588.TextScaled = false
TextButton_autokit_588.Visible = true
TextButton_autokit_588.ZIndex = 1
TextButton_autokit_588.Style = Enum.ButtonStyle.Custom
TextButton_autokit_588.Parent = Frame_Frame_518

local TextButton_FOV_578 = Instance.new("TextButton")
TextButton_FOV_578.Name = [[FOV]]
TextButton_FOV_578.Size = UDim2.new(0, 107, 0, 35)
TextButton_FOV_578.Position = UDim2.new(0, 0, 0, 140)
TextButton_FOV_578.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_FOV_578.BackgroundTransparency = 1
TextButton_FOV_578.Text = [[FOV]]
TextButton_FOV_578.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_FOV_578.TextSize = 8
TextButton_FOV_578.Font = Enum.Font.Legacy
TextButton_FOV_578.TextScaled = false
TextButton_FOV_578.Visible = true
TextButton_FOV_578.ZIndex = 1
TextButton_FOV_578.Style = Enum.ButtonStyle.Custom
TextButton_FOV_578.Parent = Frame_Frame_518

local TextButton_velocity_963 = Instance.new("TextButton")
TextButton_velocity_963.Name = [[velocity]]
TextButton_velocity_963.Size = UDim2.new(0, 107, 0, 35)
TextButton_velocity_963.Position = UDim2.new(0, 0, 0, 35)
TextButton_velocity_963.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_velocity_963.BackgroundTransparency = 1
TextButton_velocity_963.Text = [[velocity]]
TextButton_velocity_963.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_velocity_963.TextSize = 8
TextButton_velocity_963.Font = Enum.Font.Legacy
TextButton_velocity_963.TextScaled = false
TextButton_velocity_963.Visible = true
TextButton_velocity_963.ZIndex = 1
TextButton_velocity_963.Style = Enum.ButtonStyle.Custom
TextButton_velocity_963.Parent = Frame_Frame_518

local TextButton_antideath_187 = Instance.new("TextButton")
TextButton_antideath_187.Name = [[antideath]]
TextButton_antideath_187.Size = UDim2.new(0, 107, 0, 35)
TextButton_antideath_187.Position = UDim2.new(0, 0, 0, 105)
TextButton_antideath_187.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_antideath_187.BackgroundTransparency = 1
TextButton_antideath_187.Text = [[antideath]]
TextButton_antideath_187.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_antideath_187.TextSize = 8
TextButton_antideath_187.Font = Enum.Font.Legacy
TextButton_antideath_187.TextScaled = false
TextButton_antideath_187.Visible = true
TextButton_antideath_187.ZIndex = 1
TextButton_antideath_187.Style = Enum.ButtonStyle.Custom
TextButton_antideath_187.Parent = Frame_Frame_518

local TextButton_godMode_589 = Instance.new("TextButton")
TextButton_godMode_589.Name = [[godMode]]
TextButton_godMode_589.Size = UDim2.new(0, 107, 0, 35)
TextButton_godMode_589.Position = UDim2.new(0, 0, 0, 70)
TextButton_godMode_589.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_godMode_589.BackgroundTransparency = 1
TextButton_godMode_589.Text = [[godMode]]
TextButton_godMode_589.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_godMode_589.TextSize = 8
TextButton_godMode_589.Font = Enum.Font.Legacy
TextButton_godMode_589.TextScaled = false
TextButton_godMode_589.Visible = true
TextButton_godMode_589.ZIndex = 1
TextButton_godMode_589.Style = Enum.ButtonStyle.Custom
TextButton_godMode_589.Parent = Frame_Frame_518

local TextButton_speed_339 = Instance.new("TextButton")
TextButton_speed_339.Name = [[speed]]
TextButton_speed_339.Size = UDim2.new(0, 107, 0, 35)
TextButton_speed_339.Position = UDim2.new(0, 0, 0, 210)
TextButton_speed_339.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_speed_339.BackgroundTransparency = 1
TextButton_speed_339.Text = [[speed]]
TextButton_speed_339.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_speed_339.TextSize = 8
TextButton_speed_339.Font = Enum.Font.Legacy
TextButton_speed_339.TextScaled = false
TextButton_speed_339.Visible = true
TextButton_speed_339.ZIndex = 1
TextButton_speed_339.Style = Enum.ButtonStyle.Custom
TextButton_speed_339.Parent = Frame_Frame_518

local TextButton_InfJump_997 = Instance.new("TextButton")
TextButton_InfJump_997.Name = [[InfJump]]
TextButton_InfJump_997.Size = UDim2.new(0, 107, 0, 35)
TextButton_InfJump_997.Position = UDim2.new(0, 0, 0, 175)
TextButton_InfJump_997.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_InfJump_997.BackgroundTransparency = 1
TextButton_InfJump_997.Text = [[InfJump]]
TextButton_InfJump_997.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_InfJump_997.TextSize = 8
TextButton_InfJump_997.Font = Enum.Font.Legacy
TextButton_InfJump_997.TextScaled = false
TextButton_InfJump_997.Visible = true
TextButton_InfJump_997.ZIndex = 1
TextButton_InfJump_997.Style = Enum.ButtonStyle.Custom
TextButton_InfJump_997.Parent = Frame_Frame_518

local TextButton_esp_218 = Instance.new("TextButton")
TextButton_esp_218.Name = [[esp]]
TextButton_esp_218.Size = UDim2.new(0, 107, 0, 35)
TextButton_esp_218.Position = UDim2.new(0, 0, 0, 245)
TextButton_esp_218.BackgroundColor3 = Color3.fromRGB(104, 84, 255)
TextButton_esp_218.BackgroundTransparency = 1
TextButton_esp_218.Text = [[esp]]
TextButton_esp_218.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton_esp_218.TextSize = 8
TextButton_esp_218.Font = Enum.Font.Legacy
TextButton_esp_218.TextScaled = false
TextButton_esp_218.Visible = true
TextButton_esp_218.ZIndex = 1
TextButton_esp_218.Style = Enum.ButtonStyle.Custom
TextButton_esp_218.Parent = Frame_Frame_518

--// GUI LOGIC
local openCloseButton = TextButton_ggware_660
local mainFrame = Frame_Frame_337

openCloseButton.MouseButton1Click:Connect(function()
    if mainFrame.Visible == true then
        mainFrame.Visible = false
        openCloseButton.Text = "Open ggware"
    else
        mainFrame.Visible = true
        openCloseButton.Text = "Close ggware"
    end
end)

local openCloseCombat = TextButton_Combat_414
local combatFrame = Frame_Frame_390

openCloseCombat.MouseButton1Click:connect(function()
  if combatFrame.Visible == false then
    combatFrame.Visible = true
    openCloseCombat.TextColor3 = Color3.fromRGB(0, 0, 255)
    else
      if combatFrame.Visible == true then
        combatFrame.Visible = false
        openCloseCombat.TextColor3 = Color3.fromRGB(255, 255, 255)
      end
  end
end)

local openCloseUtility = TextButton_Utility_675
local utilityFrame = Frame_Frame_518

openCloseUtility.MouseButton1Click:connect(function()
  if utilityFrame.Visible == false then
    utilityFrame.Visible = true
    openCloseUtility.TextColor3 = Color3.fromRGB(0, 0, 255)
    else
      if utilityFrame.Visible == true then
        utilityFrame.Visible = false
        openCloseUtility.TextColor3 = Color3.fromRGB(255, 255, 255)
      end
  end
end)

local openCloseWorld = TextButton_World_252
local WorldFrame = Frame_Frame_423

openCloseWorld.MouseButton1Click:connect(function()
  if WorldFrame.Visible == false then
    WorldFrame.Visible = true
    openCloseWorld.TextColor3 = Color3.fromRGB(0, 0, 255)
    else
      if WorldFrame.Visible == true then
        WorldFrame.Visible = false
    openCloseWorld.TextColor3 = Color3.fromRGB(255, 255, 255)
      end
  end
end)

--// KILLAURA BUTTON
local button = TextButton_TextButton_659
button.TextColor3 = killaura.Enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
button.Text = killaura.Enabled and "Killaura [ON]" or "Killaura [OFF]"

button.MouseButton1Click:Connect(function()
    killaura.Enabled = not killaura.Enabled
    Settings.Killaura = killaura.Enabled
    saveSettings()
    button.TextColor3 = killaura.Enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
    button.Text = killaura.Enabled and "Killaura [ON]" or "Killaura [OFF]"
    
    if killaura.Enabled then
        showNotification("Killaura: ON (60Hz)")
    else
        showNotification("Killaura: OFF")
    end
end)

-- Auto start
if killaura.Enabled then
    startUltraKillaura()
end

player.CharacterAdded:Connect(function()
    task.wait(1)
    cachedInventory = nil
    currentWeapon = nil
    setupSwordHooks()
    setupMetadataHook()
    setupCombatConstantHook()
end)

--// INF JUMP
local infJumpEnabled = Settings.InfJump or false
TextButton_InfJump_997.TextColor3 = infJumpEnabled and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 255, 255)

TextButton_InfJump_997.MouseButton1Click:Connect(function()
    infJumpEnabled = not infJumpEnabled
    Settings.InfJump = infJumpEnabled
    saveSettings()
    TextButton_InfJump_997.TextColor3 = infJumpEnabled and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 255, 255)
end)

UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and isAlive() then
        player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

--// FOV
local fovEnabled = Settings.FOV or false
local DEFAULT_FOV = 70
local CUSTOM_FOV = 120

local function applyFOV()
    if camera then
        camera.FieldOfView = fovEnabled and CUSTOM_FOV or DEFAULT_FOV
    end
end

applyFOV()
TextButton_FOV_578.Text = fovEnabled and "FOV: 120" or "FOV: 70"
TextButton_FOV_578.TextColor3 = fovEnabled and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 255, 255)

TextButton_FOV_578.MouseButton1Click:Connect(function()
    fovEnabled = not fovEnabled
    Settings.FOV = fovEnabled
    saveSettings()
    applyFOV()
    TextButton_FOV_578.Text = fovEnabled and "FOV: 120" or "FOV: 70"
    TextButton_FOV_578.TextColor3 = fovEnabled and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 255, 255)
end)

player.CharacterAdded:Connect(function()
    task.wait(1)
    applyFOV()
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    camera = workspace.CurrentCamera
    applyFOV()
end)

--// VELOCITY
pcall(function()
    local knockbackPath = ReplicatedStorage:WaitForChild("TS"):WaitForChild("damage"):WaitForChild("knockback-util")
    local KnockbackUtil = require(knockbackPath).KnockbackUtil
    local oldApplyKnockback = KnockbackUtil.applyKnockback

    local veloEnabled = Settings.Velocity or false

    local function applyVelocity()
        if veloEnabled then
            KnockbackUtil.applyKnockback = function() return end
        else
            KnockbackUtil.applyKnockback = oldApplyKnockback
        end
    end

    applyVelocity()
    TextButton_velocity_963.TextColor3 = veloEnabled and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 255, 255)

    TextButton_velocity_963.MouseButton1Click:Connect(function()
        veloEnabled = not veloEnabled
        Settings.Velocity = veloEnabled
        saveSettings()
        applyVelocity()
        TextButton_velocity_963.TextColor3 = veloEnabled and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 255, 255)
        showNotification(veloEnabled and "Velocity Enabled" or "Velocity Disabled")
    end)

    player.CharacterAdded:Connect(function()
        task.wait(1)
        applyVelocity()
    end)
end)

--// SPEED
local speedToggle = TextButton_speed_339
local maxSpeed = 23
local DEFAULT_SPEED = 20
local speedEnabled = Settings.Speed or false
speedToggle.TextColor3 = speedEnabled and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 255, 255)

local function applySpeed()
    if not isAlive() then return end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = speedEnabled and maxSpeed or DEFAULT_SPEED
    end
end

applySpeed()

speedToggle.MouseButton1Click:Connect(function()
    speedEnabled = not speedEnabled
    Settings.Speed = speedEnabled
    saveSettings()
    speedToggle.TextColor3 = speedEnabled and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 255, 255)
    
    if speedEnabled then
        showNotification("Speed Enabled")
        task.spawn(function()
            while speedEnabled do
                task.wait()
                applySpeed()
            end
        end)
    else
        applySpeed()
        showNotification("Speed Disabled")
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(1)
    applySpeed()
end)

--// NUKER
local lplr = player
local nukerRemote = ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@easy-games"):WaitForChild("block-engine"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("DamageBlock")
local setInvItemRemote2 = ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("SetInvItem")

local inventories = ReplicatedStorage:WaitForChild("Inventories"):WaitForChild(lplr.Name)
local targetNames = {
    wool_blue=true, wool_pink=true, wool_red=true, wool_green=true, wool_yellow=true,
    wool_cyan=true, wool_purple=true, wool_orange=true, wool_white=true, wool_black=true,
    wood_plank_spruce=true, wood_plank_oak=true, stone_brick=true, ceramic=true
}
local toolPriority = {"shears", "diamond_pickaxe", "iron_pickaxe", "stone_pickaxe", "wood_pickaxe"}

local nukerEnabled = Settings.Nuker or false
local nukerRange = 25
local enemyBeds = {}

local function cacheEnemyBeds()
    table.clear(enemyBeds)
    for _, bed in pairs(Workspace:GetDescendants()) do
        if bed.Name == "bed" and bed:IsA("BasePart") then
            local blanket = bed:FindFirstChild("Bed")
            if blanket and blanket.Color ~= lplr.TeamColor.Color then
                table.insert(enemyBeds, bed)
            end
        end
    end
end

local function getBlocksFolder()
    local map = Workspace:FindFirstChild("Map")
    local worlds = map and map:FindFirstChild("Worlds")
    if worlds then
        for _, world in pairs(worlds:GetChildren()) do
            local blocks = world:FindFirstChild("Blocks")
            if blocks then return blocks end
        end
    end
    return nil
end

local function equipBestTool()
    for _, toolName in ipairs(toolPriority) do
        local tool = inventories:FindFirstChild(toolName)
        if tool then
            setInvItemRemote2:InvokeServer({{hand=tool}})
            return
        end
    end
end

local function makeDamageArgs(part)
    local p = part.Position
    return {{
        blockRef = {
            blockPosition = vector.create(math.floor(p.X / 3), math.floor(p.Y / 3), math.floor(p.Z / 3))
        },
        hitPosition = vector.create(p.X, p.Y + 1.45, p.Z),
        hitNormal = vector.create(0, 1, 0)
    }}
end

local function startNuker()
    task.spawn(function()
        cacheEnemyBeds()
        while nukerEnabled do
            task.wait(0.05)
            local char = lplr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end

            local rootPos = vector.create(root.Position.X, root.Position.Y, root.Position.Z)
            local blocksFolder = getBlocksFolder()

            for i, bed in ipairs(enemyBeds) do
                if not bed or not bed.Parent then
                    table.remove(enemyBeds, i)
                    continue
                end

                local bedPos = vector.create(bed.Position.X, bed.Position.Y, bed.Position.Z)
                local distToBed = (rootPos - bedPos).magnitude

                if distToBed <= nukerRange then
                    local validBlocks = {}
                    if blocksFolder then
                        for _, block in pairs(blocksFolder:GetChildren()) do
                            if targetNames[block.Name] and block:IsA("BasePart") then
                                local bPos = vector.create(block.Position.X, block.Position.Y, block.Position.Z)
                                local horizontalDist = (vector.create(bPos.x, 0, bPos.z) - vector.create(bedPos.x, 0, bedPos.z)).magnitude
                                local verticalDiff = bPos.y - bedPos.y
                                local playerDistToBlock = (rootPos - bPos).magnitude

                                if verticalDiff >= 2.5 and verticalDiff <= 12 and horizontalDist <= 2.8 and playerDistToBlock <= nukerRange then
                                    table.insert(validBlocks, block)
                                end
                            end
                        end
                    end

                    if #validBlocks > 1 then
                        table.sort(validBlocks, function(a, b) return a.Position.Y > b.Position.Y end)
                    end

                    local target = validBlocks[1] or bed
                    if target == bed then
                        nukerRemote:InvokeServer(unpack(makeDamageArgs(bed)))
                    else
                        equipBestTool()
                        nukerRemote:InvokeServer(unpack(makeDamageArgs(target)))
                    end
                    break
                end
            end
        end
    end)
end

local nukerButton = TextButton_nuker_164
nukerButton.TextColor3 = nukerEnabled and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 255, 255)

if nukerEnabled then
    startNuker()
end

nukerButton.MouseButton1Click:Connect(function()
    nukerEnabled = not nukerEnabled
    Settings.Nuker = nukerEnabled
    saveSettings()
    nukerButton.TextColor3 = nukerEnabled and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 255, 255)
    
    if nukerEnabled then
        showNotification("Nuker Enabled")
        startNuker()
    else
        showNotification("Nuker Disabled")
    end
end)

lplr.CharacterAdded:Connect(function()
    task.wait(1)
    if nukerEnabled then
        startNuker()
    end
end)

--// PLACEHOLDER BUTTONS
TextButton_godMode_589.MouseButton1Click:Connect(function()
    showNotification("GodMode not implemented")
end)

TextButton_antideath_187.MouseButton1Click:Connect(function()
    showNotification("AntiDeath not implemented")
end)

TextButton_autokit_588.MouseButton1Click:Connect(function()
    showNotification("AutoKit not implemented")
end)

TextButton_esp_218.MouseButton1Click:Connect(function()
    showNotification("ESP not implemented")
end)

print("GGWARE Loaded | 60Hz | Smart Equip | No Lag")
