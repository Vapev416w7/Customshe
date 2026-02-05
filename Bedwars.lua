if game.PlaceId == 6872265039 or game.PlaceId == 8560631822 then
--================== INIT ==================--
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
  Name = "Bedwars",
  Icon = 0,
  LoadingTitle = "ggware",
  LoadingSubtitle = "ggra",
  ShowText = "Rayfield",
  Theme = "Default",
  ToggleUIKeybind = "K",
  DisableRayfieldPrompts = false,
  DisableBuildWarnings = false,
  ConfigurationSaving = {
    Enabled = true,
    FolderName = "ggware",
    FileName = "ggware"
  }
})

--================= COMBAT TAB =================--
local CombatTab = Window:CreateTab("⚔️Combat", nil)
CombatTab:CreateSection("⚔️Combat")

-- Remote to hit players
local swordHitEvent = ReplicatedStorage:WaitForChild("rbxts_include")
:WaitForChild("node_modules")
:WaitForChild("@rbxts")
:WaitForChild("net")
:WaitForChild("out")
:WaitForChild("_NetManaged")
:WaitForChild("SwordHit")

-- Remote to equip sword
local SetInvItemRemote = ReplicatedStorage:WaitForChild("rbxts_include")
:WaitForChild("node_modules")
:WaitForChild("@rbxts")
:WaitForChild("net")
:WaitForChild("out")
:WaitForChild("_NetManaged")
:WaitForChild("SetInvItem")

-- Sword priority list
local swordNames = {
  "emerald_sword", "diamond_sword", "iron_sword", "stone_sword", "wood_sword"
}

-- Auto-equip the best sword in inventory
local function autoEquipSword()
local inventory = ReplicatedStorage:WaitForChild("Inventories"):FindFirstChild(player.Name)
if not inventory then return end

for _, swordName in ipairs(swordNames) do
local sword = inventory:FindFirstChild(swordName)
if sword then
local args = {
  {
    hand = sword
  }
}
SetInvItemRemote:InvokeServer(unpack(args))
return -- equip first available sword
end
end
end

-- Killaura variables
local killauraEnabled = false
local maxDistance = 20 -- safe extended range
local attackDelay = 0 -- faster hitting-- Add this near the top of your script with other variables
local groundPos = nil 

CombatTab:CreateToggle({
  Name = "Killaura",
  CurrentValue = false,
  Flag = "killaura",
  Callback = function(Value)
  killauraEnabled = Value
  task.spawn(function()
    while killauraEnabled do
    task.wait(attackDelay)
    local char = player.Character
    if not char then continue end
    local selfPart = char:FindFirstChild("HumanoidRootPart")
    if not selfPart then continue end

    -- Use ground position if God Mode is active, otherwise use current position
    local currentPos = (godModeEnabled and groundPos) and groundPos or selfPart.Position

    for _, victim in pairs(Players:GetPlayers()) do
    if victim ~= player and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") then
    local targetPart = victim.Character:FindFirstChild("HumanoidRootPart")
    
    local distance = (currentPos - targetPart.Position).Magnitude
    if distance <= maxDistance then
      
      autoEquipSword()
      
    local inventory = ReplicatedStorage:WaitForChild("Inventories"):FindFirstChild(player.Name)
    local weapon
    for _, swordName in ipairs(swordNames) do
        weapon = inventory and inventory:FindFirstChild(swordName)
        if weapon then break end
    end
    if not weapon then continue end

    local args = {{
      chargedAttack = { chargeRatio = 0 },
      entityInstance = victim.Character,
      validate = {
        selfPosition = {
          value = vector.create(currentPos.X, currentPos.Y, currentPos.Z)
        },
        targetPosition = {
          value = vector.create(targetPart.Position.X, targetPart.Position.Y, targetPart.Position.Z)
        }
      },
      weapon = weapon
    }}
    swordHitEvent:FireServer(unpack(args))
    end
    end
    end
    end
    end)
  end
})

local Slider = CombatTab:CreateSlider({
  Name = "range",
  Range = {
    0, 100
  },
  Increment = 1,
  Suffix = "range",
  CurrentValue = 20,
  Flag = "range",
  Callback = function(Value)
  maxDistance = Value
  end,
})

local Slider = CombatTab:CreateSlider({
  Name = "sword delay",
  Range = {
    0, 100
  },
  Increment = 1,
  Suffix = "sword delay",
  CurrentValue = 0,
  Flag = "sword delay",
  Callback = function(Value)
  attackDelay = Value
  end,
})

--================= STATE-BASED ANTI-KB =================--
CombatTab:CreateSection("🛡️ Smooth Physics")

pcall(function()
    local KnockbackModule = require(ReplicatedStorage.TS.damage["knockback-util"])
    local KnockbackUtil = KnockbackModule.KnockbackUtil
    local oldApplyKnockback = KnockbackUtil.applyKnockback

    local veloEnabled = false
    local horizontalValue = 0
    local verticalValue = 0
    local chanceValue = 100
    local rand = Random.new()

    CombatTab:CreateToggle({
        Name = "Velocity",
        CurrentValue = false,
        Flag = "velo_toggle",
        Callback = function(callback)
            veloEnabled = callback
            if veloEnabled then
                KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
                    if rand:NextNumber(0, 100) > chanceValue then 
                        return oldApplyKnockback(root, mass, dir, knockback, ...) 
                    end
                    knockback = knockback or {}
                    if horizontalValue == 0 and verticalValue == 0 then return end

                    knockback.horizontal = (knockback.horizontal or 1) * (horizontalValue / 100)
                    knockback.vertical = (knockback.vertical or 1) * (verticalValue / 100)
                    return oldApplyKnockback(root, mass, dir, knockback, ...)
                end
            else
                KnockbackUtil.applyKnockback = oldApplyKnockback
            end
        end
    })
end)

--================= MOVEMENT TAB =================--
local MovementTab = Window:CreateTab("🛸Movement", nil)
MovementTab:CreateSection("🛸Movement")

local jumpConnection
local infJumpEnabled = false

local function setupCharacter(char)
if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end

if infJumpEnabled then
jumpConnection = UIS.JumpRequest:Connect(function()
  if char and char:FindFirstChildOfClass("Humanoid") then
  char:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
  end
  end)
end
end

-- InfJump toggle
MovementTab:CreateToggle({
  Name = "InfJump",
  CurrentValue = false,
  Flag = "InfJump",
  Callback = function(Value)
  infJumpEnabled = Value
  if player.Character then setupCharacter(player.Character) end
  end
})

-- Rebind toggles on respawn
player.CharacterAdded:Connect(setupCharacter)
if player.Character then setupCharacter(player.Character) end

local speedEnabled = false
local speedValue = 23
local speedConnection

MovementTab:CreateToggle({
  Name = "Speed",
  CurrentValue = false,
  Flag = "Speed",
  Callback = function(Value)
  speedEnabled = Value

  if speedEnabled then

  if speedConnection then

  speedConnection:Disconnect()
  speedConnection = nil
  end

  speedConnection = RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
    hum.WalkSpeed = speedValue
    end
    end)
  else
    if speedConnection then

  speedConnection:Disconnect()
  speedConnection = nil
  local char = player.Character
  if char and char:FindFirstChildOfClass("Humanoid") then
  char:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
  end
    end
end
end
})

player.CharacterAdded:Connect(function(char)
  task.wait(1)
  if speedEnabled and char then
  local hum = char:FindFirstChildOfClass("Humanoid")
  if hum then
  hum.WalkSpeed = speedValue
  end
  end
  end)


local Slider = MovementTab:CreateSlider({
  Name = "Speed",
  Range = {
    0, 100
  },
  Increment = 1,
  Suffix = "Speed",
  CurrentValue = 23,
  Flag = "Speedslider",
  Callback = function(Value)
  speedValue = Value
  end,
})

local function getClosestEnemy()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local closest, closestDist = nil, math.huge
    for _, victim in pairs(Players:GetPlayers()) do
        if victim ~= player and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") then
            local vRoot = victim.Character.HumanoidRootPart
            local hum = victim.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (root.Position - vRoot.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = victim
                end
            end
        end
    end
    return closest, closestDist
end

godModeEnabled = false
autoGodHealth = 20
godModeHeight = 80

CombatTab:CreateToggle({
   Name = "Bypass God Mode (No-Hit)",
   CurrentValue = godModeEnabled,
   Flag = "god",
   Callback = function(Value)
      godModeEnabled = Value
      if godModeEnabled then
          task.spawn(function()
              while godModeEnabled do
                  local char = player.Character
                  local root = char and char:FindFirstChild("HumanoidRootPart")
                  local hum = char and char:FindFirstChildOfClass("Humanoid")
                  
                  if root and hum then
                      local target, dist = getClosestEnemy()
                      -- Trigger if health is low OR enemy is within reach
                      if (hum.Health <= autoGodHealth) or (target and dist <= (maxDistance + 2)) then
                          local originalCFrame = root.CFrame
                          groundPos = originalCFrame.Position -- Tells Killaura where to hit from
                          
                          -- Teleport Up
                          root.CFrame = originalCFrame + Vector3.new(0, godModeHeight + math.random(-5, 5), 0)
                          
                          task.wait(0.2) -- Stay in air for 0.2 seconds
                          
                          -- Teleport Down
                          root.CFrame = originalCFrame
                          groundPos = nil 
                          
                          task.wait(0.08) -- Wait 0.1 seconds before being allowed to jump again
                      end
                  end
                  task.wait(0.01) -- Constant check loop
              end
          end)
      end
   end,
})

local camera = workspace.CurrentCamera
local camProxy = Instance.new("Part")
camProxy.Transparency = 1
camProxy.CanCollide = false
camProxy.Anchored = true
camProxy.Parent = workspace

godModeEnabled = false
autoGodHealth = 20
godModeHeight = 80

CombatTab:CreateToggle({
   Name = "Bypass God Mode (No-Hit)",
   CurrentValue = godModeEnabled,
   Flag = "god",
   Callback = function(Value)
      godModeEnabled = Value
      if godModeEnabled then
          task.spawn(function()
              while godModeEnabled do
                  local char = player.Character
                  local root = char and char:FindFirstChild("HumanoidRootPart")
                  local hum = char and char:FindFirstChildOfClass("Humanoid")
                  
                  if root and hum then
                      local target, dist = getClosestEnemy()
                      if (hum.Health <= autoGodHealth) or (target and dist <= (maxDistance + 2)) then
                          local originalCFrame = root.CFrame
                          groundPos = originalCFrame.Position 
                          
                          -- LOCK CAMERA: Set the camera to look at the proxy part on the ground
                          camProxy.CFrame = originalCFrame
                          camera.CameraSubject = camProxy
                          
                          -- Teleport Up
                          root.CFrame = originalCFrame + Vector3.new(0, godModeHeight + math.random(-5, 5), 0)
                          
                          task.wait(0.2) 
                          
                          -- Teleport Down
                          root.CFrame = originalCFrame
                          
                          -- UNLOCK CAMERA: Put camera back on player
                          camera.CameraSubject = hum
                          
                          groundPos = nil 
                          task.wait(0.08) 
                      end
                  end
                  task.wait(0.01) 
              end
              -- Reset camera if toggle is turned off
              if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
                  camera.CameraSubject = player.Character.Humanoid
              end
          end)
      end
   end,
})


local antiDeath = false
local maxHealth = 20 
local antiDeathHeight = 80
local groundPos = nil

local Toggle = CombatTab:CreateToggle({
   Name = "Anti-Death",
   CurrentValue = false,
   Flag = "antiDeath",
   Callback = function(Value)
      antiDeath = Value
      
      if antiDeath then
         task.spawn(function()
            while antiDeath do
               local char = player.Character
               local root = char and char:FindFirstChild("HumanoidRootPart")
               local hum = char and char:FindFirstChildOfClass("Humanoid")

               if hum and root and hum.Health > 0 and hum.Health <= maxHealth then
                  local originalCFrame = root.CFrame
                  groundPos = originalCFrame.Position
                  
                  -- Teleport Up
                  root.CFrame = originalCFrame + Vector3.new(0, antiDeathHeight + math.random(-5, 5), 0)
                  
                  task.wait(1)
                  
                  -- Teleport Down
                  root.CFrame = originalCFrame
                  groundPos = nil 
                  
                  task.wait(0.08)
               end
               task.wait(0.1) -- This MUST be outside the 'if' to prevent crashing
            end
         end)
      end
   end,
})

local players = game:GetService("Players")
local lplr = players.LocalPlayer
local cam = workspace.CurrentCamera
local runService = game:GetService("RunService")

-- ESP Settings (Initialized to prevent nil index errors)
local ESPEnabled = false
local NamesEnabled = false

local function isAlive(plr)
    return plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0
end

-- [[ ESP DRAWING LOGIC ]] --
local function createESP(plr)
    -- Fixed syntax for Drawing objects to prevent 'nil value' calls
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Visible = false
    
    local nameTag = Drawing.new("Text")
    nameTag.Size = 18
    nameTag.Center = true
    nameTag.Outline = true
    nameTag.Color = Color3.fromRGB(255, 255, 255)
    nameTag.Visible = false

    local connection
    connection = runService.RenderStepped:Connect(function()
        -- Checking if player exists and is alive to avoid 'index nil' crashes
        if ESPEnabled and isAlive(plr) and plr.Parent ~= nil then
            local rP = plr.Character.HumanoidRootPart
            local screenPos, onScreen = cam:WorldToViewportPoint(rP.Position)

            if onScreen then
                -- Calculation for Box size based on distance
                local sizeX = 2000 / screenPos.Z
                local sizeY = 3000 / screenPos.Z
                
                -- Update Box
                box.Visible = true
                box.Size = Vector2.new(sizeX, sizeY)
                box.Position = Vector2.new(screenPos.X - sizeX / 2, screenPos.Y - sizeY / 2)

                -- Update Name
                if NamesEnabled then
                    nameTag.Visible = true
                    nameTag.Text = plr.DisplayName or plr.Name
                    nameTag.Position = Vector2.new(screenPos.X, (screenPos.Y - sizeY / 2) - 20)
                else
                    nameTag.Visible = false
                end
            else
                box.Visible = false
                nameTag.Visible = false
            end
        else
            box.Visible = false
            nameTag.Visible = false
            
            -- Cleanup logic to stop RenderStepped when player leaves or ESP disabled
            if not plr.Parent or not ESPEnabled then
                box:Remove()
                nameTag:Remove()
                connection:Disconnect()
            end
        end
    end)
end


-- [[ UI TABS ]] --
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local WorldTab = Window:CreateTab("World", 4483362458)

VisualsTab:CreateToggle({
   Name = "Player Box ESP",
   CurrentValue = false,
   Callback = function(Value)
      ESPEnabled = Value
      if Value then
          -- Initialize for existing players when toggled on
          for _, v in pairs(players:GetPlayers()) do
              if v ~= lplr then createESP(v) end
          end
      end
   end,
})

VisualsTab:CreateToggle({
   Name = "Show Names",
   CurrentValue = false,
   Callback = function(Value)
      NamesEnabled = Value
   end,
})

-- [[ INITIALIZATION ]] --
Rayfield:Notify({
   Title = "ESP Loaded",
   Content = "Box and Name systems are active.",
   Duration = 3
})

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local lplr = Players.LocalPlayer

-- Remotes
local nukerRemote = ReplicatedStorage
    :WaitForChild("rbxts_include")
    :WaitForChild("node_modules")
    :WaitForChild("@easy-games")
    :WaitForChild("block-engine")
    :WaitForChild("node_modules")
    :WaitForChild("@rbxts")
    :WaitForChild("net")
    :WaitForChild("out")
    :WaitForChild("_NetManaged")
    :WaitForChild("DamageBlock")

local setInvItemRemote = ReplicatedStorage
    :WaitForChild("rbxts_include")
    :WaitForChild("node_modules")
    :WaitForChild("@rbxts")
    :WaitForChild("net")
    :WaitForChild("out")
    :WaitForChild("_NetManaged")
    :WaitForChild("SetInvItem")

-- Inventory
local inventories = ReplicatedStorage:WaitForChild("Inventories"):WaitForChild("idontcareicheat")

-- Wool names (Target List)
local woolNames = {
    blue_wool=true, pink_wool=true, red_wool=true, green_wool=true, yellow_wool=true,
    cyan_wool=true, purple_wool=true, orange_wool=true, white_wool=true, black_wool=true,
    gray_wool=true, light_gray_wool=true, lime_wool=true, brown_wool=true, magenta_wool=true,
    -- Add wood/stone here if you want to break strong defenses too
    oak_wood_plank=true, birch_wood_plank=true, stone_brick=true, blastproof_ceramic=true
}

-- Tool priority (Shears first for wool)
local toolPriority = {"shears", "diamond_pickaxe", "iron_pickaxe", "stone_pickaxe", "wood_pickaxe"}

local nukerEnabled = false
local nukerRange = 25

-- Character helper
local function getChar()
    local char = lplr.Character or lplr.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    return char, root
end

-- Equip best tool
local function equipBestTool()
    for _, toolName in ipairs(toolPriority) do
        local tool = inventories:FindFirstChild(toolName)
        if tool then
            setInvItemRemote:InvokeServer({{hand=tool}})
            return
        end
    end
end

-- Build DamageBlock args
local function makeDamageArgs(part)
    return {{
        blockRef = {
            blockPosition = vector.create(
                math.floor(part.Position.X / 3),
                math.floor(part.Position.Y / 3),
                math.floor(part.Position.Z / 3)
            )
        },
        hitPosition = vector.create(part.Position.X, part.Position.Y, part.Position.Z),
        hitNormal = vector.create(-1,0,0)
    }}
end

-- Helper to find the dynamic Blocks folder
local function getBlocksFolder()
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then return nil end
    local worldsFolder = mapFolder:FindFirstChild("Worlds")
    if not worldsFolder then return nil end
    for _, worldChild in pairs(worldsFolder:GetChildren()) do
        if worldChild:FindFirstChild("Blocks") then
            return worldChild.Blocks
        end
    end
    return nil
end

-- Nuker loop
local function startNuker()
    task.spawn(function()
        while nukerEnabled do
            task.wait(0.1) -- Loop speed
            local char, root = getChar()
            if not char or not root then continue end

            equipBestTool()
            
            local blocksFolder = getBlocksFolder()
            
            -- Scan for beds
            for _, bed in pairs(Workspace:GetDescendants()) do
                -- Check if it is a Bed, and NOT our team's bed
                if bed.Name == "bed" and bed:FindFirstChild("Blanket") and bed.Blanket.Color ~= lplr.TeamColor.Color then
                    
                    local bedPos = bed.Position
                    local distToBed = (root.Position - bedPos).Magnitude
                    
                    -- If the bed is within nuker range
                    if distToBed <= nukerRange then
                        
                        -- 1. Break the Bed itself
                        local argsBed = makeDamageArgs(bed)
                        nukerRemote:InvokeServer(unpack(argsBed))

                        -- 2. Break Wool ABOVE/AROUND this specific bed only
                        if blocksFolder then
                            for _, block in pairs(blocksFolder:GetChildren()) do
                                if woolNames[block.Name] then
                                    local bPos = block.Position
                                    
                                    -- Calculate vertical and horizontal distance relative to the BED
                                    local verticalDiff = bPos.Y - bedPos.Y
                                    local horizontalDist = (Vector3.new(bPos.X, 0, bPos.Z) - Vector3.new(bedPos.X, 0, bedPos.Z)).Magnitude

                                    -- Logic: Must be above bed (0 to 12 studs up) and close horizontally (within 5 studs radius)
                                    if verticalDiff >= -1 and verticalDiff <= 12 and horizontalDist <= 5 then
                                        local argsWool = makeDamageArgs(block)
                                        nukerRemote:InvokeServer(unpack(argsWool))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- UI
local Section = WorldTab:CreateSection("World")

WorldTab:CreateToggle({
    Name = "Nuker (Defenses Only)",
    CurrentValue = nukerEnabled,
    Flag = "nuker",
    Callback = function(Value)
        nukerEnabled = Value
        if nukerEnabled then startNuker() end
    end,
})

WorldTab:CreateSlider({
    Name = "Nuker Range",
    Range = {5, 30},
    Increment = 1,
    Suffix = "Studs",
    CurrentValue = nukerRange,
    Flag = "nukerRange",
    Callback = function(Value)
        nukerRange = Value
    end,
})
end

if game.PlaceId == 71480482338212 then

-- Load Rayfield UI-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create Window
local Window = Rayfield:CreateWindow({
  Name = "Bedwars",
  Icon = 0,
  LoadingTitle = "ggware",
  LoadingSubtitle = "ggra",
  ShowText = "Rayfield",
  Theme = "Default",
  ToggleUIKeybind = "K",
  DisableRayfieldPrompts = false,
  DisableBuildWarnings = false,
  ConfigurationSaving = {
    Enabled = true,
    FolderName = "ggware",
    FileName = "ggware"
  },
  Discord = {
    Enabled = false
  },
  KeySystem = false
})

-- Combat Tab
local CombatTab = Window:CreateTab("⚔️Combat", nil)
local CombatSection = CombatTab:CreateSection("⚔️Combat")

-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer
local swordRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemsRemotes"):WaitForChild("SwordHit")

local equipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemsRemotes"):WaitForChild("EquipTool")

-- Track character and root part (works on respawn)
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

localPlayer.CharacterAdded:Connect(function(newChar)
  character = newChar
  rootPart = character:WaitForChild("HumanoidRootPart")
end)

maxDistance = 50

-- Killaura Button
CombatTab:CreateToggle({
  Name = "Killaura",
  CurrentValue = false,
  Flag = "ka",
  Callback = function(Value)
  killauraEnabled = Value
  if killauraEnabled then
  task.spawn(function()
    local swordsToCheck = {
      "Diamond Sword", "Stone Sword", "Iron Sword", "Wooden Sword"
    }

    while killauraEnabled do
    task.wait(0.1)
    local char = localPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then continue end

-- 1. Find the best sword in inventory
    local weaponName = nil
    local backpack = localPlayer:FindFirstChild("Backpack")

    for _, sName in pairs(swordsToCheck) do
    if backpack:FindFirstChild(sName) or char:FindFirstChild(sName) then
    weaponName = sName
    break
    end
    end

    if weaponName then
-- 2. Equip it via Remote
    equipRemote:FireServer({
      weapon = weaponName
    })

-- 3. Look for targets
    for _, victim in pairs(Players:GetPlayers()) do
    if victim ~= localPlayer and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") then
    local dist = (char.HumanoidRootPart.Position - victim.Character.HumanoidRootPart.Position).Magnitude
    if dist <= maxDistance then
-- 4. Attack
    swordRemote:FireServer(victim.Character, weaponName)
    end
    end
    end
    end
    end
    end)
  end
  end
})

local Toggle = CombatTab:CreateToggle({
  Name = "Speed",
  CurrentValue = false,
  Flag = "speed",
  Callback = function(Value)
  local fastSpeed = 21
  local defaultSpeed = 16

  local function applySpeed()
  local character = localPlayer.Character
  if character then
  local humanoid = character:FindFirstChild("Humanoid")
  if humanoid then
  humanoid.WalkSpeed = Value and fastSpeed or defaultSpeed
  end
  end
  end

  applySpeed()

  localPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    applySpeed()
    end)
  end,
})
end

if game.PlaceId == 8951451142 then

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Bedwars Mobile",
    LoadingTitle = "ggware",
    LoadingSubtitle = "Mobile Edition",
    ConfigurationSaving = {Enabled = true, FolderName = "ggware", FileName = "ggware"}
})

-- Services
local WorkSpace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer

-- Fix: Timeout prevents the UI from "vanishing" if the remote isn't found
local swordRemote = ReplicatedStorage:WaitForChild("Kw8", 5):FindFirstChild("93b2718b-2b2a-4859-b36e-fd4614c7f0c9")
local nukerRemote = ReplicatedStorage:WaitForChild("Kw8"):WaitForChild("f32c9bc1-cb4b-4616-96ac-bddaefd35e92")

-- Global Variables
local killauraEnabled = false
local flyEnabled = false
local attackDelay = 0
local maxDistance = 18
local flySpeed = 50

--================= COMBAT TAB =================--
local CombatTab = Window:CreateTab("⚔️ Combat")

CombatTab:CreateToggle({
    Name = "Killaura",
    CurrentValue = false,
    Flag = "ka",
    Callback = function(Value)
        killauraEnabled = Value
        if killauraEnabled then
            task.spawn(function()
                while killauraEnabled do
                    task.wait(attackDelay)
                    local char = localPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    
                    if not root then continue end

                    for _, victim in pairs(Players:GetPlayers()) do
                      local victimTeam = victim:GetAttribute("TeamId")
                      local myTeam = localPlayer:GetAttribute("TeamId")
                      
                        if victim ~= localPlayer and victimTeam ~= myTeam and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") then
                            local targetPart = victim.Character.HumanoidRootPart
                            local mag = (root.Position - targetPart.Position).Magnitude
                            
                            if mag <= maxDistance and swordRemote then
                                -- CORRECTED: Firing direct victim object based on your args
                                swordRemote:FireServer(victim)
                            end
                        end
                    end
                end
            end)
        end
    end
})

--================= MOVEMENT TAB =================--
local MovementTab = Window:CreateTab("🛸 Movement")

MovementTab:CreateToggle({
    Name = "Mobile Fly (Jump = Up)",
    CurrentValue = false,
    Flag = "mFly",
    Callback = function(Value)
        flyEnabled = Value
        
        task.spawn(function()
            while flyEnabled do
                task.wait()
                local char = localPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")

                if root and hum then
                    -- Ensure Velocity object exists
                    local velo = root:FindFirstChild("FlyVelocity") or Instance.new("BodyVelocity")
                    velo.Name = "FlyVelocity"
                    velo.Parent = root
                    velo.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    
                    -- Falling Animation
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                    
                    -- Movement Logic
                    local moveDir = hum.MoveDirection * flySpeed
                    local upDir = hum.Jump and 45 or 0 -- Rises when jump button is active
                    
                    velo.Velocity = Vector3.new(moveDir.X, upDir, moveDir.Z)
                end
            end
            
            -- Cleanup on toggle off
            local char = localPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local v = char.HumanoidRootPart:FindFirstChild("FlyVelocity")
                if v then v:Destroy() end
                char.Humanoid:ChangeState(Enum.HumanoidStateType.Land)
            end
        end)
    end
})

local Slider = MovementTab:CreateSlider({
   Name = "flySpeed",
   Range = {0, 500},
   Increment = 10,
   Suffix = "flySpeed",
   CurrentValue = 50,
   Flag = "fly speed", 
   Callback = function(Value)
     flySpeed = Value
   end,
})

local eggsFolder = WorkSpace:FindFirstChild("Eggs")
local nukerEnabled = false
maxDistance = 20
nukerDelay = 0

local Toggle = CombatTab:CreateToggle({
   Name = "nuker",
   CurrentValue = false,
   Flag = "nuker",
   Callback = function(Value)
     nukerEnabled = Value
     if nukerEnabled then
       task.spawn(function()
         while nukerEnabled do
           task.wait(nukerDelay)
           local char = localPlayer.Character
           if not char then continue end
           
           for _, egg in pairs(eggsFolder:GetChildren()) do
             local eggTeam = egg:GetAttribute("TeamId")
             local myEgg = localPlayer:GetAttribute("TeamId")
            
             if eggTeam ~= myEgg then
              
              local pos = egg:GetPivot().Position
              local selfPart = char:WaitForChild("HumanoidRootPart")
              local distance = (selfPart.Position - pos).Magnitude
              
              if distance <= maxDistance then
              nukerRemote:FireServer(egg)
              end
             end
           end
         end
       end)
      end
   end,
  })

local playerTpEnabled = false
playertpDelay = 0.1

local Toggle = MovementTab:CreateToggle({
   Name = "player tp",
   CurrentValue = false,
   Flag = "player tp",
   Callback = function(Value)
     playerTpEnabled = Value
     if playerTpEnabled then
       task.spawn(function()
         while playerTpEnabled do
           task.wait(playertpDelay)
           local char = localPlayer.Character
           if not char then continue end
           local root = char:WaitForChild("HumanoidRootPart")
           if not root then continue end
           
           for _, tp in pairs(Players:GetChildren()) do
             local targetTeam = tp:GetAttribute("TeamId")
             local myteam = localPlayer:GetAttribute("TeamId")
             
             if tp ~= localPlayer and targetTeam ~= myteam then
              
               local TargetChar = tp.Character
               if TargetChar then
               local targetRoot = TargetChar:WaitForChild("HumanoidRootPart")
               if targetRoot then
                 
                 root.CFrame = targetRoot.CFrame * CFrame.new(0, 10, 0)
               end
               end
             end
           end
         end
       end)
     end
   end,
})

local eggtp = false
local eggtpDelay = 0.1
local egghealth = 0

local Toggle = MovementTab:CreateToggle({
   Name = "egg tp",
   CurrentValue = false,
   Flag = "egg tp", 
   Callback = function(Value)
     eggtp = Value
     if eggtp then
       task.spawn(function()
         while eggtp do
           task.wait(eggtpDelay)
           local char = localPlayer.Character
           if not char then continue end
           local selfPart = char:WaitForChild("HumanoidRootPart")
           if not selfPart then continue end
          for _, egg in pairs(eggsFolder:GetChildren()) do
            local eggTeam = egg:GetAttribute("TeamId")
            local myEgg = localPlayer:GetAttribute("TeamId")
            
            if eggTeam ~= myEgg then
              local pos = egg:GetPivot().Position
              local diatance = (selfPart.Position - pos).Magnitude
              local health = egg:GetAttribute("Health")
              
              if health > egghealth then 
                
                selfPart.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
              end
            end
          end
         end
       end)
     end
   end,
})

autoWinEnabled = false

local Toggle = MovementTab:CreateToggle({
    Name = "auto win",
    CurrentValue = false,
    Flag = "autoWin",
    Callback = function(Value)
        autoWinEnabled = Value

        if autoWinEnabled then
            task.spawn(function()
                nukerEnabled = true
                eggtp = true
                killauraEnabled = false
                playerTpEnabled = false

                while autoWinEnabled do
                    task.wait(0.1)

                    local char = localPlayer.Character
                    if not char then continue end
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if not root then continue end

                    --==================== NUKER ====================
                    for _, egg in pairs(eggsFolder:GetChildren()) do
                        local eggTeam = egg:GetAttribute("TeamId")
                        local myEgg = localPlayer:GetAttribute("TeamId")
                        local health = egg:GetAttribute("Health") or 0

                        if eggTeam ~= myEgg and health > 0 then
                            local pos = egg:GetPivot().Position
                            local distance = (root.Position - pos).Magnitude
                            if distance <= maxDistance then
                                nukerRemote:FireServer(egg)
                            end
                        end
                    end

                    --==================== EGG TP ====================
                    for _, egg in pairs(eggsFolder:GetChildren()) do
                        local eggTeam = egg:GetAttribute("TeamId")
                        local myEgg = localPlayer:GetAttribute("TeamId")
                        local health = egg:GetAttribute("Health") or 0

                        if eggTeam ~= myEgg and health > 0 then
                            local pos = egg:GetPivot().Position
                            root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
                        end
                    end

                    --==================== CHECK IF EGGS DESTROYED ====================
                    local allEggsDestroyed = true
                    for _, egg in pairs(eggsFolder:GetChildren()) do
                        local eggTeam = egg:GetAttribute("TeamId")
                        local myEgg = localPlayer:GetAttribute("TeamId")
                        local health = egg:GetAttribute("Health") or 0
                        if eggTeam ~= myEgg and health > 0 then
                            allEggsDestroyed = false
                            break
                        end
                    end

                    if allEggsDestroyed then
                        -- Enable Killaura & Player TP after all enemy eggs are gone
                        killauraEnabled = true
                        playerTpEnabled = true

                        -- Attack all enemies within range
                        task.spawn(function()
                            while killauraEnabled do
                                task.wait(attackDelay)
                                local char = localPlayer.Character
                                local root = char and char:FindFirstChild("HumanoidRootPart")
                                if not root then continue end

                                for _, victim in pairs(Players:GetPlayers()) do
                                    local victimTeam = victim:GetAttribute("TeamId")
                                    local myTeam = localPlayer:GetAttribute("TeamId")

                                    if victim ~= localPlayer and victimTeam ~= myTeam and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") then
                                        local targetPart = victim.Character.HumanoidRootPart
                                        local mag = (root.Position - targetPart.Position).Magnitude

                                        if mag <= maxDistance and swordRemote then
                                            swordRemote:FireServer(victim)
                                        end
                                    end
                                end
                            end
                        end)

                        -- Teleport to enemies continuously
                        task.spawn(function()
                            while playerTpEnabled do
                                task.wait(playertpDelay)
                                local char = localPlayer.Character
                                local root = char and char:FindFirstChild("HumanoidRootPart")
                                if not root then continue end

                                for _, tp in pairs(Players:GetPlayers()) do
                                    local targetTeam = tp:GetAttribute("TeamId")
                                    local myTeam = localPlayer:GetAttribute("TeamId")

                                    if tp ~= localPlayer and targetTeam ~= myTeam then
                                        local targetChar = tp.Character
                                        if targetChar then
                                            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                                            if targetRoot then
                                                root.CFrame = targetRoot.CFrame * CFrame.new(0, 6, 0)
                                            end
                                        end
                                    end
                                end
                            end
                        end)

                        -- Stop auto-win loop, we are now in combat mode
                        autoWinEnabled = false
                    end
                end
            end)
        else
            autoWinEnabled = false
        end
    end
})
end

if game.PlaceId == 8542275097 then
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Bedwars Mobile",
    LoadingTitle = "ggware",
    LoadingSubtitle = "Mobile Edition solo skywars",
    ConfigurationSaving = {Enabled = true, FolderName = "ggware", FileName = "ggware"}
})

-- Services
local WorkSpace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer

-- Fix: Timeout prevents the UI from "vanishing" if the remote isn't found
local swordRemote = ReplicatedStorage:WaitForChild("rM9"):WaitForChild("0f825f49-002e-4b7b-8d8c-24dbb3494845")

-- Global Variables
local killauraEnabled = false
local flyEnabled = false
local attackDelay = 0
local maxDistance = 18
local flySpeed = 50

--================= COMBAT TAB =================--
local CombatTab = Window:CreateTab("⚔️ Combat")

CombatTab:CreateToggle({
    Name = "Killaura",
    CurrentValue = false,
    Flag = "Ka",
    Callback = function(Value)
        killauraEnabled = Value
        if killauraEnabled then
            task.spawn(function()
                while killauraEnabled do
                    task.wait(attackDelay)
                    local char = localPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    
                    if not root then continue end

                    for _, victim in pairs(Players:GetPlayers()) do
                      local victimTeam = victim:GetAttribute("TeamId")
                      local myTeam = localPlayer:GetAttribute("TeamId")
                      
                        if victim ~= localPlayer and victimTeam ~= myTeam and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") then
                            local targetPart = victim.Character.HumanoidRootPart
                            local mag = (root.Position - targetPart.Position).Magnitude
                            
                            if mag <= maxDistance and swordRemote then
                                -- CORRECTED: Firing direct victim object based on your args
                                swordRemote:FireServer(victim)
                            end
                        end
                    end
                end
            end)
        end
    end
})

--================= MOVEMENT TAB =================--
local MovementTab = Window:CreateTab("🛸 Movement")

MovementTab:CreateToggle({
    Name = "Mobile Fly (Jump = Up)",
    CurrentValue = false,
    Flag = "MFly",
    Callback = function(Value)
        flyEnabled = Value
        
        task.spawn(function()
            while flyEnabled do
                task.wait()
                local char = localPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")

                if root and hum then
                    -- Ensure Velocity object exists
                    local velo = root:FindFirstChild("FlyVelocity") or Instance.new("BodyVelocity")
                    velo.Name = "FlyVelocity"
                    velo.Parent = root
                    velo.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    
                    -- Falling Animation
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                    
                    -- Movement Logic
                    local moveDir = hum.MoveDirection * flySpeed
                    local upDir = hum.Jump and 45 or 0 -- Rises when jump button is active
                    
                    velo.Velocity = Vector3.new(moveDir.X, upDir, moveDir.Z)
                end
            end
            
            -- Cleanup on toggle off
            local char = localPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local v = char.HumanoidRootPart:FindFirstChild("FlyVelocity")
                if v then v:Destroy() end
                char.Humanoid:ChangeState(Enum.HumanoidStateType.Land)
            end
        end)
    end
})

local Slider = MovementTab:CreateSlider({
   Name = "flySpeed",
   Range = {0, 500},
   Increment = 10,
   Suffix = "flySpeed",
   CurrentValue = 50,
   Flag = "fly speed", 
   Callback = function(Value)
     flySpeed = Value
   end,
})

local chestStealer = false
local chestsFolder = Workspace:WaitForChild("BlockContainer"):WaitForChild("Map"):WaitForChild("Chests")
local itemsLookup = ReplicatedStorage:WaitForChild("Items")
local remoteFolder = ReplicatedStorage:WaitForChild("rM9")

local processedChests = {}

local Toggle = CombatTab:CreateToggle({
    Name = "Master Chest Stealer (All Items) doesnt work",
    CurrentValue = false,
    Flag = "chestStealer",
    Callback = function(Value)
        chestStealer = Value

        if chestStealer then
            task.spawn(function()
                while chestStealer do
                    -- Loop through every chest in the map
                    for _, chest in pairs(chestsFolder:GetChildren()) do
                        if not chestStealer then break end
                        
                        if not processedChests[chest] then
                            -- 1. Focus the chest
                            remoteFolder:WaitForChild("1b702374-6e55-4aa2-a7fa-4531cb9af1df"):FireServer(chest)
                            
                            -- 2. Iterate through every item name in the game's item folder
                            for _, itemTemplate in pairs(itemsLookup:GetChildren()) do
                                if not chestStealer then break end
                                
                                local itemName = itemTemplate.Name
                                
                                -- 3. Fire grab remote
                                remoteFolder:WaitForChild("41b07193-ec28-449b-8542-fff50405a58e"):FireServer(chest, itemName, -1)
                                
                                -- 4. Fire equip remote
                                remoteFolder:WaitForChild("8dd94a0e-0dd9-409c-8847-de1054173265"):FireServer(itemName)
                                
                                -- Small wait to prevent the game from freezing or kicking for spam
                                task.wait(0.01) 
                            end

                            processedChests[chest] = true
                        end
                    end
                    task.wait(1) -- Wait before checking for new/respawned chests
                end
            end)
        else
            processedChests = {}
        end
    end
})



local playerTpEnabled = false
playertpDelay = 0.1

local Toggle = MovementTab:CreateToggle({
   Name = "player tp",
   CurrentValue = false,
   Flag = "player tp",
   Callback = function(Value)
     playerTpEnabled = Value
     if playerTpEnabled then
       task.spawn(function()
         while playerTpEnabled do
           task.wait(playertpDelay)
           local char = localPlayer.Character
           if not char then continue end
           local root = char:WaitForChild("HumanoidRootPart")
           if not root then continue end
           
           for _, tp in pairs(Players:GetChildren()) do
             local targetTeam = tp:GetAttribute("TeamId")
             local myteam = localPlayer:GetAttribute("TeamId")
             
             if tp ~= localPlayer and targetTeam ~= myteam then
              
               local TargetChar = tp.Character
               if TargetChar then
               local targetRoot = TargetChar:WaitForChild("HumanoidRootPart")
               if targetRoot then
                 
                 root.CFrame = targetRoot.CFrame * CFrame.new(0, 10, 0)
               end
               end
             end
           end
         end
       end)
     end
   end,
})
end

if game.PlaceId == 7777 then
  local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Bedwars Mobile",
    LoadingTitle = "ggware",
    LoadingSubtitle = "Mobile Edition lobby",
    ConfigurationSaving = {Enabled = true, FolderName = "ggware", FileName = "ggware"}
})

-- Services
local WorkSpace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer

local flyEnabled = false
local attackDelay = 0
local maxDistance = 18
local flySpeed = 50


--================= MOVEMENT TAB =================--
local MovementTab = Window:CreateTab("🛸 Movement")

MovementTab:CreateToggle({
    Name = "Mobile Fly (Jump = Up)",
    CurrentValue = false,
    Flag = "MFly",
    Callback = function(Value)
        flyEnabled = Value
        
        task.spawn(function()
            while flyEnabled do
                task.wait()
                local char = localPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")

                if root and hum then
                    -- Ensure Velocity object exists
                    local velo = root:FindFirstChild("FlyVelocity") or Instance.new("BodyVelocity")
                    velo.Name = "FlyVelocity"
                    velo.Parent = root
                    velo.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    
                    -- Falling Animation
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                    
                    -- Movement Logic
                    local moveDir = hum.MoveDirection * flySpeed
                    local upDir = hum.Jump and 45 or 0 -- Rises when jump button is active
                    
                    velo.Velocity = Vector3.new(moveDir.X, upDir, moveDir.Z)
                end
            end
            
            -- Cleanup on toggle off
            local char = localPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local v = char.HumanoidRootPart:FindFirstChild("FlyVelocity")
                if v then v:Destroy() end
                char.Humanoid:ChangeState(Enum.HumanoidStateType.Land)
            end
        end)
    end
})

local Slider = MovementTab:CreateSlider({
   Name = "flySpeed",
   Range = {0, 500},
   Increment = 10,
   Suffix = "flySpeed",
   CurrentValue = 50,
   Flag = "fly speed", 
   Callback = function(Value)
     flySpeed = Value
   end,
})

local playerTpEnabled = false
playertpDelay = 0.1

local Toggle = MovementTab:CreateToggle({
   Name = "player tp",
   CurrentValue = false,
   Flag = "player tp",
   Callback = function(Value)
     playerTpEnabled = Value
     if playerTpEnabled then
       task.spawn(function()
         while playerTpEnabled do
           task.wait(playertpDelay)
           local char = localPlayer.Character
           if not char then continue end
           local root = char:WaitForChild("HumanoidRootPart")
           if not root then continue end
           
           for _, tp in pairs(Players:GetChildren()) do
             local targetTeam = tp:GetAttribute("TeamId")
             local myteam = localPlayer:GetAttribute("TeamId")
             
             if tp ~= localPlayer and targetTeam ~= myteam then
              
               local TargetChar = tp.Character
               if TargetChar then
               local targetRoot = TargetChar:WaitForChild("HumanoidRootPart")
               if targetRoot then
                 
                 root.CFrame = targetRoot.CFrame * CFrame.new(0, 10, 0)
               end
               end
             end
           end
         end
       end)
     end
   end,
})
end
