local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WAIT_AT_LOCATION = 0.1
local WORLD_CHANGE_TIMEOUT = 12
local TARGET_FIND_TIMEOUT = 8
local TARGET_DEATH_TIMEOUT = 45
local TARGET_SEARCH_RADIUS = 5000
local DUNGEON_MOB_TIMEOUT = 90
local RAID_MOB_TIMEOUT = 10
local TIME_TRIAL_MOB_TIMEOUT = 10
local DUNGEON_SCAN_INTERVAL = 0.15
local GAMEMODE_OPEN_WINDOW = 60
local GAMEMODE_JOIN_COOLDOWN = 4
local RAID_GATE_POLL_INTERVAL = 5
local AVAILABILITY_WAIT_LOG_INTERVAL = 10
local RAID_CREATE_JOIN_DELAY = 1
local FIRE_DUNGEON_GATE_SCAN_RADIUS = 12000
local FIRE_DUNGEON_GATE_TRY_SECONDS = 4
local AUTO_START_ROUTE = false
local GUI_FULL_HEIGHT = 600

local locations = {
    {
        Name = "Itache",
        EnemyName = "Itache",
        World = 1,
        Position = Vector3.new(-288.58, 224.01, -1395.00),
    },
    {
        Name = "Broly",
        EnemyName = "Broly",
        World = 2,
        Position = Vector3.new(3119.86, 731.89, -1963.69),
    },
    {
        Name = "White Beard",
        EnemyName = "White Beard",
        EnemyAliases = { "WhiteBeard" },
        World = 3,
        Position = Vector3.new(1620.64, 19.30, 1385.31),
    },
    {
        Name = "Armored Titan",
        EnemyName = "Armored Titan",
        EnemyAliases = { "ArmoredTitan" },
        World = 4,
        Position = Vector3.new(-1473.33, 142.69, 3328.64),
    },
    {
        Name = "Beleon",
        EnemyName = "Beleon",
        World = 5,
        Position = Vector3.new(2593.31, 331.04, -1477.78),
    },
    {
        Name = "Kokushibo",
        EnemyName = "Kokushibo",
        EnemyAliases = { "Kokachibo", "Kokushibo", "Kokeshebo" },
        World = 6,
        Position = Vector3.new(3631.51, 133.13, 4145.94),
    },
    {
        Name = "Lucies",
        EnemyName = "Lucies",
        World = 7,
        Position = Vector3.new(7590.57, -170.50, -430.24),
    },
    {
        Name = "Quinella",
        EnemyName = "Quinella",
        World = 8,
        Position = Vector3.new(8003.63, -85.05, -3847.23),
    },
}

local gamemodeOptions = {
    {
        Kind = "Dungeon",
        Key = "World9Dungeon",
        Name = "Fire City Dungeon",
    },
    {
        Kind = "Raid",
        Key = "World0",
        Name = "Timeless Raid",
    },
    {
        Kind = "Raid",
        Key = "World1",
        Name = "Ninja Raid",
    },
    {
        Kind = "Raid",
        Key = "World5",
        GateRank = "E",
        Name = "Gate Rank E",
    },
    {
        Kind = "Raid",
        Key = "World5",
        GateRank = "D",
        Name = "Gate Rank D",
    },
    {
        Kind = "Raid",
        Key = "World5",
        GateRank = "C",
        Name = "Gate Rank C",
    },
    {
        Kind = "Raid",
        Key = "World5",
        GateRank = "B",
        Name = "Gate Rank B",
    },
    {
        Kind = "Raid",
        Key = "World6",
        Name = "Infinity Castle",
    },
    {
        Kind = "Raid",
        Key = "World7",
        Name = "Clover Raid",
    },
    {
        Kind = "TimeTrial",
        Key = "Easy",
        Name = "Time Trial Easy",
    },
    {
        Kind = "TimeTrial",
        Key = "Medium",
        Name = "Time Trial Medium",
    },
}

local old = getgenv and getgenv().PotassiumHideLoading
if old and old.Disconnect then
    pcall(function()
        old:Disconnect()
    end)
end

local state = {
    Enabled = true,
    Connections = {},
    RouteRunning = false,
    DungeonFarmRunning = false,
    LastDungeonToggleAt = 0,
    LastGamemodeJoinAt = 0,
    LastRaidGatePollAt = 0,
    LastAvailabilityWaitLogAt = 0,
    AvailabilityHooksReady = false,
    AvailableGamemodes = {},
    SelectedLocations = {},
    SelectedArenaTypes = {
        Dungeon = true,
        Raid = true,
        TimeTrial = true,
    },
    SelectedGamemodes = {},
    SelectedGamemodeIds = {},
    ModeFilter = "All",
}

for _, option in ipairs(gamemodeOptions) do
    local optionId = option.Kind .. ":" .. option.Key .. (option.GateRank and (":" .. option.GateRank) or "")
    state.SelectedGamemodes[option.Kind] = state.SelectedGamemodes[option.Kind] or {}
    if state.SelectedGamemodes[option.Kind][option.Key] == nil then
        state.SelectedGamemodes[option.Kind][option.Key] = true
    end
    if state.SelectedGamemodeIds[optionId] == nil then
        state.SelectedGamemodeIds[optionId] = true
    end
end

if getgenv then
    getgenv().PotassiumHideLoading = state
end

local function addConnection(connection)
    table.insert(state.Connections, connection)
    return connection
end

function state:Disconnect()
    self.Enabled = false
    self.RouteRunning = false
    self.DungeonFarmRunning = false
    for _, child in ipairs(playerGui:GetChildren()) do
        if child.Name == "PotassiumRouteGui" then
            pcall(function()
                child:Destroy()
            end)
        end
    end
    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.Connections = {}
end

local function clearVisual(guiObject)
    if not guiObject:IsA("GuiObject") then
        return
    end

    pcall(function()
        guiObject.Visible = false
        guiObject.BackgroundTransparency = 1
    end)

    if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
        pcall(function()
            guiObject.ImageTransparency = 1
        end)
    end

    if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
        pcall(function()
            guiObject.TextTransparency = 1
            guiObject.TextStrokeTransparency = 1
        end)
    end

    if guiObject:IsA("CanvasGroup") then
        pcall(function()
            guiObject.GroupTransparency = 1
        end)
    end
end

local function clearOtherVisual(instance)
    if instance:IsA("UIStroke") then
        pcall(function()
            instance.Transparency = 1
        end)
    elseif instance:IsA("UIGradient") then
        pcall(function()
            instance.Enabled = false
        end)
    end
end

local function clearTree(root)
    if root:IsA("ScreenGui") then
        pcall(function()
            root.Enabled = false
            root.ResetOnSpawn = false
        end)
    elseif root:IsA("GuiObject") then
        clearVisual(root)
    else
        clearOtherVisual(root)
    end

    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("GuiObject") then
            clearVisual(descendant)
        else
            clearOtherVisual(descendant)
        end
    end
end

local function hideTeleportLoading()
    local windows = playerGui:FindFirstChild("Windows")
    local teleportLoading = windows and windows:FindFirstChild("TeleportLoading")

    if teleportLoading then
        clearTree(teleportLoading)
    end
end

local function hideLoadingScreen()
    local loadingScreen = playerGui:FindFirstChild("LoadingScreen")

    if loadingScreen then
        clearTree(loadingScreen)
    end
end

local function hideAll()
    if not state.Enabled then
        return
    end

    hideLoadingScreen()
    hideTeleportLoading()
end

local function hookGuiObject(guiObject)
    if not guiObject:IsA("GuiObject") then
        return
    end

    addConnection(guiObject:GetPropertyChangedSignal("Visible"):Connect(function()
        if state.Enabled and guiObject.Visible then
            clearVisual(guiObject)
        end
    end))

    addConnection(guiObject:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
        if state.Enabled and guiObject.BackgroundTransparency < 1 then
            guiObject.BackgroundTransparency = 1
        end
    end))

    if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
        addConnection(guiObject:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
            if state.Enabled and guiObject.ImageTransparency < 1 then
                guiObject.ImageTransparency = 1
            end
        end))
    end
end

local function hookScreenGui(screenGui)
    addConnection(screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if state.Enabled and screenGui.Enabled then
            screenGui.Enabled = false
        end
    end))

    addConnection(screenGui.DescendantAdded:Connect(function(descendant)
        task.defer(function()
            if descendant:IsA("GuiObject") then
                hookGuiObject(descendant)
                clearVisual(descendant)
            else
                clearOtherVisual(descendant)
            end
        end)
    end))

    for _, descendant in ipairs(screenGui:GetDescendants()) do
        if descendant:IsA("GuiObject") then
            hookGuiObject(descendant)
        end
    end
end

local function hookLoadingScreen()
    local loadingScreen = playerGui:FindFirstChild("LoadingScreen")
    if loadingScreen and loadingScreen:IsA("ScreenGui") then
        hookScreenGui(loadingScreen)
    end
end

local function hookTeleportLoading()
    local windows = playerGui:FindFirstChild("Windows")
    local teleportLoading = windows and windows:FindFirstChild("TeleportLoading")

    if not teleportLoading then
        return
    end

    if teleportLoading:IsA("GuiObject") then
        hookGuiObject(teleportLoading)
    end

    for _, descendant in ipairs(teleportLoading:GetDescendants()) do
        hookGuiObject(descendant)
    end

    addConnection(teleportLoading.DescendantAdded:Connect(function(descendant)
        task.defer(function()
            hookGuiObject(descendant)
            clearVisual(descendant)
        end)
    end))
end

hideAll()
hookLoadingScreen()
hookTeleportLoading()

local windows = playerGui:FindFirstChild("Windows")
if windows then
    addConnection(windows.ChildAdded:Connect(function(child)
        if child.Name == "TeleportLoading" then
            task.defer(function()
                hookTeleportLoading()
                hideTeleportLoading()
            end)
        end
    end))
end

addConnection(playerGui.ChildAdded:Connect(function(child)
    if child.Name == "LoadingScreen" then
        task.defer(function()
            hookLoadingScreen()
            hideLoadingScreen()
        end)
    elseif child.Name == "Windows" then
        task.defer(function()
            hookTeleportLoading()
            hideTeleportLoading()
        end)
    end
end))

addConnection(RunService.Heartbeat:Connect(hideAll))
addConnection(RunService.RenderStepped:Connect(hideAll))

task.spawn(function()
    while state.Enabled do
        hideAll()
        task.wait()
    end
end)

local function getCharacterRoot()
    local character = player.Character or player.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart", 8)
end

local function moveCharacterTo(position)
    local root = getCharacterRoot()
    if not root then
        warn("[Potassium] Could not find HumanoidRootPart.")
        return false
    end

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
    return true
end

local function normalizeName(name)
    local normalized = tostring(name):lower():gsub("%s+", "")
    return normalized
end

local function getTargetNames(location)
    local names = {
        normalizeName(location.EnemyName or location.Name),
        normalizeName(location.Name),
    }

    for _, alias in ipairs(location.EnemyAliases or {}) do
        table.insert(names, normalizeName(alias))
    end

    return names
end

local function doesNameMatch(enemyName, targetNames)
    local normalizedEnemyName = normalizeName(enemyName)

    for _, targetName in ipairs(targetNames) do
        if normalizedEnemyName == targetName
            or normalizedEnemyName:find(targetName, 1, true)
            or targetName:find(normalizedEnemyName, 1, true) then
            return true
        end
    end

    return false
end

local function getModelPosition(model)
    if model.PrimaryPart then
        return model.PrimaryPart.Position
    end

    local root = model:FindFirstChild("HumanoidRootPart", true)
        or model:FindFirstChild("Head", true)
        or model:FindFirstChildWhichIsA("BasePart", true)

    return root and root.Position or nil
end

local function isEnemyModel(instance)
    if not instance:IsA("Model") then
        return false
    end

    if instance:GetAttribute("HealthReal") ~= nil or instance:GetAttribute("MaxHealthReal") ~= nil or instance:GetAttribute("EnemyDead") ~= nil then
        return true
    end

    return instance:FindFirstChildOfClass("Humanoid") ~= nil or instance:FindFirstChild("Humanoid", true) ~= nil
end

local function getEnemyHealth(enemy)
    if not enemy or not enemy.Parent then
        return 0, 0, true
    end

    local health = enemy:GetAttribute("HealthReal")
    local maxHealth = enemy:GetAttribute("MaxHealthReal")
    local dead = enemy:GetAttribute("EnemyDead") == true

    if type(health) ~= "number" then
        local humanoid = enemy:FindFirstChildOfClass("Humanoid") or enemy:FindFirstChild("Humanoid", true)
        health = humanoid and humanoid.Health or nil
        maxHealth = humanoid and humanoid.MaxHealth or maxHealth
    end

    if type(maxHealth) ~= "number" then
        maxHealth = health or 0
    end

    return health, maxHealth, dead
end

local function formatHealth(value)
    if type(value) ~= "number" then
        return "?"
    end

    if value >= 1000000000000000 then
        return ("%.2e"):format(value)
    elseif value >= 1000000000000 then
        return ("%.2fT"):format(value / 1000000000000)
    elseif value >= 1000000000 then
        return ("%.2fB"):format(value / 1000000000)
    elseif value >= 1000000 then
        return ("%.2fM"):format(value / 1000000)
    elseif value >= 1000 then
        return ("%.2fK"):format(value / 1000)
    end

    return tostring(math.floor(value))
end

local function findTargetEnemy(location, allowNearest)
    local worlds = workspace:FindFirstChild("Worlds")
    local world = worlds and worlds:FindFirstChild(tostring(location.World))
    local enemies = world and world:FindFirstChild("Enemies")

    if not enemies then
        return nil
    end

    local targetNames = getTargetNames(location)
    local bestEnemy
    local bestDistance = math.huge

    for _, enemy in ipairs(enemies:GetDescendants()) do
        if isEnemyModel(enemy) then
            local modelPosition = getModelPosition(enemy)
            local distance = modelPosition and (modelPosition - location.Position).Magnitude or math.huge

            if doesNameMatch(enemy.Name, targetNames) then
                return enemy, distance, true
            end

            if distance <= TARGET_SEARCH_RADIUS and distance < bestDistance then
                bestEnemy = enemy
                bestDistance = distance
            end
        end
    end

    if allowNearest then
        return bestEnemy, bestDistance, false
    end

    return nil
end

local function waitForTargetDeath(location)
    local enemy
    local distance
    local exactMatch
    local findStarted = os.clock()

    repeat
        enemy, distance, exactMatch = findTargetEnemy(location, false)

        if enemy then
            break
        end

        hideAll()
        task.wait(0.1)
    until not state.Enabled or not state.RouteRunning or os.clock() - findStarted > TARGET_FIND_TIMEOUT

    if not enemy then
        enemy, distance, exactMatch = findTargetEnemy(location, true)
        if enemy then
            warn(("[Potassium] Could not find exact target for %s. Using nearest enemy fallback."):format(location.Name))
        else
            warn(("[Potassium] Could not find target HP for %s. Using fallback wait."):format(location.Name))
            task.wait(WAIT_AT_LOCATION)
            return false
        end
    end

    local health, maxHealth, dead = getEnemyHealth(enemy)
    print(("[Potassium] Waiting for %s HP on %s (%s, %.1f studs). Current: %s/%s"):format(
        location.Name,
        enemy:GetFullName(),
        exactMatch and "name match" or "nearest match",
        distance or -1,
        formatHealth(health),
        formatHealth(maxHealth)
    ))

    local deathStarted = os.clock()
    while state.Enabled and state.RouteRunning do
        if not enemy.Parent then
            print(("[Potassium] %s disappeared. Moving on."):format(location.Name))
            return true
        end

        health, maxHealth, dead = getEnemyHealth(enemy)

        if dead or (type(health) == "number" and health <= 0) then
            print(("[Potassium] %s is dead/HP is 0. Moving on."):format(location.Name))
            return true
        end

        if os.clock() - deathStarted > TARGET_DEATH_TIMEOUT then
            warn(("[Potassium] Timed out waiting for %s HP. Moving on."):format(location.Name))
            return false
        end

        hideAll()
        task.wait(0.1)
    end

    return false
end

local arenaRoots = {
    {
        RootName = "DungeonArenas",
        Kind = "Dungeon",
        LeaveBridge = "DungeonLeave",
    },
    {
        RootName = "RaidArenas",
        Kind = "Raid",
        LeaveBridge = "RaidLeave",
    },
    {
        RootName = "TimeTrialArenas",
        Kind = "TimeTrial",
        LeaveBridge = "TimeTrialLeave",
    },
}

local function getGamemodeSelection(kind, key)
    if state.SelectedArenaTypes[kind] == false then
        return false
    end

    if kind == "Raid" and key == "World5" then
        for _, option in ipairs(gamemodeOptions) do
            if option.Kind == kind and option.Key == key then
                local optionId = option.Kind .. ":" .. option.Key .. ":" .. option.GateRank
                if state.SelectedGamemodeIds[optionId] ~= false then
                    return true
                end
            end
        end

        return false
    end

    return state.SelectedGamemodeIds[kind .. ":" .. key] ~= false
end

local function setGamemodeSelection(kind, key, enabled)
    state.SelectedGamemodes[kind] = state.SelectedGamemodes[kind] or {}
    state.SelectedGamemodes[kind][key] = enabled == true
end

local function getGamemodeOptionId(option)
    return option.Kind .. ":" .. option.Key .. (option.GateRank and (":" .. option.GateRank) or "")
end

local function setGamemodeOptionSelection(option, enabled)
    state.SelectedGamemodeIds[getGamemodeOptionId(option)] = enabled == true
    setGamemodeSelection(option.Kind, option.Key, enabled)
end

local function isGamemodeOptionSelected(option)
    return state.SelectedGamemodeIds[getGamemodeOptionId(option)] ~= false
end

local function getSelectedGateRank()
    for _, option in ipairs(gamemodeOptions) do
        if option.Kind == "Raid" and option.Key == "World5" and option.GateRank and isGamemodeOptionSelected(option) then
            return option.GateRank
        end
    end

    return nil
end

local function isGateRankSelected(rank)
    if not rank then
        return getGamemodeSelection("Raid", "World5")
    end

    return state.SelectedGamemodeIds["Raid:World5:" .. tostring(rank)] ~= false
end

local function getGamemodeLabel(kind, key)
    for _, option in ipairs(gamemodeOptions) do
        if option.Kind == kind and option.Key == key then
            return option.Name
        end
    end

    return tostring(key)
end

local function getActiveCombatArena()
    for _, rootInfo in ipairs(arenaRoots) do
        if state.SelectedArenaTypes[rootInfo.Kind] == false then
            continue
        end

        local root = workspace:FindFirstChild(rootInfo.RootName)
        if root then
            for _, arena in ipairs(root:GetChildren()) do
                if not getGamemodeSelection(rootInfo.Kind, arena.Name) then
                    continue
                end

                local enemies = arena:FindFirstChild("Enemies")
                if enemies then
                    return {
                        RootInfo = rootInfo,
                        Arena = arena,
                        Enemies = enemies,
                        Key = rootInfo.RootName .. "/" .. arena.Name,
                    }
                end
            end
        end
    end

    return nil
end

local function getEnemyTargetPosition(enemy)
    return getModelPosition(enemy)
end

local function getArenaEnemySnapshot(enemies)
    local liveEnemies = {}
    local liveSet = {}
    local bestEnemy
    local bestHealth = -math.huge

    for _, enemy in ipairs(enemies:GetDescendants()) do
        if isEnemyModel(enemy) then
            local health, maxHealth, dead = getEnemyHealth(enemy)
            local hasHealth = type(health) == "number"

            if not dead and (not hasHealth or health > 0) then
                table.insert(liveEnemies, enemy)
                liveSet[enemy] = true

                local score = hasHealth and health or (type(maxHealth) == "number" and maxHealth or 0)
                if score > bestHealth then
                    bestHealth = score
                    bestEnemy = enemy
                end
            end
        end
    end

    return bestEnemy, bestHealth, liveEnemies, liveSet
end

local function leaveActiveCombatArena(Library, arenaInfo, reason)
    if not arenaInfo then
        return
    end

    local bridgeName = arenaInfo.RootInfo.LeaveBridge
    local leaveBridge = Library and Library.getBridge(bridgeName)

    warn(("[Potassium] %s timeout in %s. Leaving via %s."):format(reason or "Kill", arenaInfo.Key, bridgeName))

    if leaveBridge then
        leaveBridge:Fire()
    else
        warn(("[Potassium] Could not find %s bridge."):format(bridgeName))
    end
end

local function getCombatMobTimeout(arenaInfo)
    local kind = arenaInfo and arenaInfo.RootInfo and arenaInfo.RootInfo.Kind

    if kind == "Raid" then
        return RAID_MOB_TIMEOUT
    elseif kind == "TimeTrial" then
        return TIME_TRIAL_MOB_TIMEOUT
    end

    return DUNGEON_MOB_TIMEOUT
end

local function isFireCityArena(arenaInfo)
    return arenaInfo
        and arenaInfo.RootInfo
        and arenaInfo.RootInfo.Kind == "Dungeon"
        and arenaInfo.Arena
        and arenaInfo.Arena.Name == "World9Dungeon"
end

local function isFireCityActuallyJoined(target)
    local dungeonGui = playerGui:FindFirstChild("DungeonGui")
    if dungeonGui and dungeonGui:IsA("ScreenGui") and dungeonGui.Enabled then
        return true
    end

    local targetPosition = target and getEnemyTargetPosition(target)
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    return targetPosition ~= nil
        and rootPart ~= nil
        and (rootPart.Position - targetPosition).Magnitude <= 500
end

local function getGamemodeKind(payload)
    if type(payload) ~= "table" then
        return nil
    end

    if payload.GamemodeType == "Dungeon" then
        return "Dungeon"
    elseif payload.GamemodeType == "Raid" then
        return "Raid"
    elseif payload.GamemodeType == "TimeTrial" then
        return "TimeTrial"
    end

    return nil
end

local function getGamemodeOpenKey(payload)
    local kind = getGamemodeKind(payload)
    if not kind or type(payload.Key) ~= "string" then
        return nil
    end

    return kind .. ":" .. payload.Key
end

local function rememberOpenGamemode(payload)
    local openKey = getGamemodeOpenKey(payload)
    local kind = getGamemodeKind(payload)

    if not openKey or not kind then
        return
    end

    if kind == "Raid" and payload.Key == "World5" and not isGateRankSelected(payload.GateRank or payload.Rank) then
        return
    end

    if not getGamemodeSelection(kind, payload.Key) then
        return
    end

    state.AvailableGamemodes[openKey] = {
        Kind = kind,
        Payload = payload,
        ExpiresAt = os.clock() + GAMEMODE_OPEN_WINDOW,
    }

    print(("[Potassium] %s available: %s."):format(kind, payload.Key))
end

local function cleanAvailableGamemodes()
    local now = os.clock()

    for key, entry in pairs(state.AvailableGamemodes) do
        if type(entry) ~= "table" or now > (entry.ExpiresAt or 0) then
            state.AvailableGamemodes[key] = nil
        end
    end
end

local function setupGamemodeAvailabilityWatchers(Library)
    if state.AvailabilityHooksReady then
        return
    end

    state.AvailabilityHooksReady = true

    local bridges = {
        "DungeonAnnouncement",
        "RaidAnnouncement",
        "TimeTrialAnnouncement",
    }

    for _, bridgeName in ipairs(bridges) do
        local bridge = Library and Library.getBridge(bridgeName)
        if bridge then
            addConnection(bridge:Connect(function(payload)
                if type(payload) == "table" and payload.NotifyKind == "GamemodeOpen" then
                    rememberOpenGamemode(payload)
                end
            end))
            print(("[Potassium] Watching %s."):format(bridgeName))
        else
            warn(("[Potassium] Could not watch %s."):format(bridgeName))
        end
    end
end

local function pollRaidGateState()
    if not getGamemodeSelection("Raid", "World5") then
        return
    end

    local now = os.clock()
    if now - (state.LastRaidGatePollAt or 0) < RAID_GATE_POLL_INTERVAL then
        return
    end

    state.LastRaidGatePollAt = now

    local functionsFolder = ReplicatedStorage:FindFirstChild("SimpleWorld")
        and ReplicatedStorage.SimpleWorld:FindFirstChild("Library")
        and ReplicatedStorage.SimpleWorld.Library:FindFirstChild("Network")
        and ReplicatedStorage.SimpleWorld.Library.Network:FindFirstChild("Functions")

    local getRaidGateState = functionsFolder and functionsFolder:FindFirstChild("GetRaidGateState")
    if not getRaidGateState then
        return
    end

    local ok, gateState = pcall(function()
        return getRaidGateState:InvokeServer("World5")
    end)

    if not ok or type(gateState) ~= "table" then
        return
    end

    if gateState.IsOpen == true and isGateRankSelected(gateState.Rank) then
        rememberOpenGamemode({
            NotifyKind = "GamemodeOpen",
            GamemodeType = "Raid",
            Key = "World5",
            Name = ("Gate Rank %s"):format(tostring(gateState.Rank or "?")),
            GateRank = gateState.Rank,
            Rank = gateState.Rank,
            GateTeleport = true,
        })
    else
        state.AvailableGamemodes["Raid:World5"] = nil
    end
end

local function getNextJoinableGamemode()
    cleanAvailableGamemodes()

    local kindOrder = { "Dungeon", "Raid", "TimeTrial" }
    for _, kind in ipairs(kindOrder) do
        if state.SelectedArenaTypes[kind] ~= false then
            for key, entry in pairs(state.AvailableGamemodes) do
                if entry.Kind == kind
                    and getGamemodeSelection(kind, entry.Payload.Key)
                    and not (kind == "Raid" and entry.Payload.Key == "World5" and not isGateRankSelected(entry.Payload.GateRank or entry.Payload.Rank)) then
                    return key, entry.Payload
                end
            end
        end
    end

    for _, option in ipairs(gamemodeOptions) do
        if option.Kind == "Raid"
            and option.Key ~= "World5"
            and isGamemodeOptionSelected(option)
            and getGamemodeSelection(option.Kind, option.Key) then
            return "RaidCreate:" .. option.Key, {
                NotifyKind = "ManualStart",
                GamemodeType = "Raid",
                Key = option.Key,
                Name = option.Name,
                CreateFirst = true,
            }
        end
    end

    return nil
end

local function getSelectedArenaTypeText()
    local names = {}

    for _, option in ipairs(gamemodeOptions) do
        if isGamemodeOptionSelected(option) then
            table.insert(names, option.Name)
        end
    end

    if #names == 0 then
        return "nothing selected"
    end

    return table.concat(names, "/")
end

local function logAvailabilityWait()
    local now = os.clock()
    if now - (state.LastAvailabilityWaitLogAt or 0) < AVAILABILITY_WAIT_LOG_INTERVAL then
        return
    end

    state.LastAvailabilityWaitLogAt = now
    print(("[Potassium] Waiting for available %s card/gate..."):format(getSelectedArenaTypeText()))
end

local joinFireCityDungeon
local pressVisibleFireCityYes

local function getServerCurrentWorld()
    local functionsFolder = ReplicatedStorage:FindFirstChild("SimpleWorld")
        and ReplicatedStorage.SimpleWorld:FindFirstChild("Library")
        and ReplicatedStorage.SimpleWorld.Library:FindFirstChild("Network")
        and ReplicatedStorage.SimpleWorld.Library.Network:FindFirstChild("Functions")
    local getCurrentWorld = functionsFolder and functionsFolder:FindFirstChild("GetCurrentWorld")

    if not getCurrentWorld then
        return nil
    end

    local ok, result = pcall(function()
        return getCurrentWorld:InvokeServer()
    end)

    if ok then
        return result
    end

    return nil
end

local function getRaidWorldId(Library, raidKey)
    local ok, raidConfig = pcall(function()
        return Library and Library.getConfig("RaidConfig")
    end)

    if ok and raidConfig and type(raidConfig.GetRaid) == "function" then
        local raid = raidConfig:GetRaid(raidKey)
        if raid and type(raid.WorldId) == "number" then
            return raid.WorldId
        end
    end

    local parsed = tostring(raidKey):match("^World(%d+)$")
    return parsed and tonumber(parsed) or nil
end

local function requestWorldAndWait(Library, worldId)
    if type(worldId) ~= "number" then
        return true
    end

    if getServerCurrentWorld() == worldId then
        return true
    end

    local requestChangeWorld = Library and Library.getBridge("RequestChangeWorld")
    if not requestChangeWorld then
        warn("[Potassium] RequestChangeWorld bridge was not found for raid start.")
        return false
    end

    print(("[Potassium] Switching to world %d before raid start."):format(worldId))
    requestChangeWorld:Fire(worldId)

    local started = os.clock()
    repeat
        hideAll()
        task.wait(0.2)
    until getServerCurrentWorld() == worldId or os.clock() - started > WORLD_CHANGE_TIMEOUT or not state.Enabled

    return getServerCurrentWorld() == worldId
end

local function createAndJoinRaid(Library, payload)
    local bridge = Library and Library.getBridge("RaidJoin")
    if not bridge then
        warn("[Potassium] Could not find RaidJoin for raid create/start.")
        return false
    end

    local worldId = getRaidWorldId(Library, payload.Key)
    if not requestWorldAndWait(Library, worldId) then
        warn(("[Potassium] Could not switch to world %s for raid %s."):format(tostring(worldId), tostring(payload.Key)))
        return false
    end

    bridge:Fire("Create", payload.Key)
    print(("[Potassium] Creating raid %s via RaidJoin Create."):format(tostring(payload.Key)))
    task.wait(RAID_CREATE_JOIN_DELAY)
    bridge:Fire("Join", payload.Key)
    print(("[Potassium] Joining raid %s via RaidJoin Join."):format(tostring(payload.Key)))
    return true
end

local function tryJoinGamemode(Library, payload)
    local kind = getGamemodeKind(payload)
    if not kind or not getGamemodeSelection(kind, payload.Key) then
        return false
    end

    if kind == "Raid" and payload.Key == "World5" and not isGateRankSelected(payload.GateRank or payload.Rank) then
        return false
    end

    if os.clock() - (state.LastGamemodeJoinAt or 0) < GAMEMODE_JOIN_COOLDOWN then
        return false
    end

    local bridgeName
    local bridge

    if kind == "Dungeon" then
        if payload.Key == "World9Dungeon" then
            return joinFireCityDungeon(Library)
        end

        bridgeName = "DungeonJoin"
        bridge = Library and Library.getBridge(bridgeName)
        if bridge then
            bridge:Fire("Join", payload.Key)
        end
    elseif kind == "TimeTrial" then
        bridgeName = "TimeTrialJoin"
        bridge = Library and Library.getBridge(bridgeName)
        if bridge then
            bridge:Fire("Join", payload.Key)
        end
    elseif kind == "Raid" then
        if payload.GateTeleport == true then
            bridgeName = "RaidGateTeleport"
            bridge = Library and Library.getBridge(bridgeName)
            if bridge then
                bridge:Fire(payload.Key)
            end
        else
            bridgeName = "RaidJoin"
            if payload.CreateFirst == true then
                if createAndJoinRaid(Library, payload) then
                    state.LastGamemodeJoinAt = os.clock()
                    return true
                end
            else
                bridge = Library and Library.getBridge(bridgeName)
                if bridge then
                    bridge:Fire("Join", payload.Key)
                end
            end
        end
    end

    if not bridge then
        warn(("[Potassium] Could not find %s for %s %s."):format(tostring(bridgeName), tostring(kind), tostring(payload.Key)))
        return false
    end

    state.LastGamemodeJoinAt = os.clock()
    print(("[Potassium] Auto joining %s %s via %s."):format(kind, tostring(payload.Key), bridgeName))
    return true
end

local function fireGuiButton(button)
    if not button then
        return false
    end

    local fired = false

    pcall(function()
        if button.Activate then
            button:Activate()
            fired = true
        end
    end)

    if typeof(firesignal) == "function" then
        pcall(function()
            firesignal(button.Activated)
            fired = true
        end)
        pcall(function()
            firesignal(button.MouseButton1Click)
            fired = true
        end)
        pcall(function()
            firesignal(button.MouseButton1Down)
            fired = true
        end)
        pcall(function()
            firesignal(button.MouseButton1Up)
            fired = true
        end)
    end

    return fired
end

local function fireRawBridgeTuple(identifier, ...)
    local bridgeFolder = ReplicatedStorage:FindFirstChild("BridgeNet2")
    local dataRemote = bridgeFolder and bridgeFolder:FindFirstChild("dataRemoteEvent")

    if not dataRemote then
        return false
    end

    dataRemote:FireServer({
        {
            __BridgeTuplePayload__ = true,
            Payload = table.pack(...),
        },
        identifier,
    })

    return true
end

local function fireRawBridgeName(bridgeName, ...)
    local bridgeFolder = ReplicatedStorage:FindFirstChild("BridgeNet2")
    local identifierStorage = bridgeFolder and bridgeFolder:FindFirstChild("identifierStorage")
    local identifier = identifierStorage and identifierStorage:GetAttribute(bridgeName)

    if not identifier then
        return false
    end

    return fireRawBridgeTuple(identifier, ...)
end

local function tryGamemodeControllerJoin(payload)
    local clientFolder = ReplicatedStorage:FindFirstChild("SimpleWorld")
        and ReplicatedStorage.SimpleWorld:FindFirstChild("Library")
        and ReplicatedStorage.SimpleWorld.Library:FindFirstChild("Client")
    local controllerScript = clientFolder and clientFolder:FindFirstChild("GamemodeNotifyController")

    if not controllerScript then
        return false
    end

    local ok, controller = pcall(require, controllerScript)
    if not ok or type(controller) ~= "table" or type(controller.TryJoin) ~= "function" then
        return false
    end

    local joinOk = pcall(function()
        controller:TryJoin(payload)
    end)

    return joinOk == true
end

local function isRememberedFireCityDungeonOpen()
    local entry = state.AvailableGamemodes["Dungeon:World9Dungeon"]

    return type(entry) == "table"
        and entry.Kind == "Dungeon"
        and type(entry.Payload) == "table"
        and entry.Payload.Key == "World9Dungeon"
        and os.clock() <= (entry.ExpiresAt or 0)
end

local function getFireDungeonGateText(instance)
    local texts = {}

    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local text = tostring(descendant.Text or "")
            if text ~= "" then
                table.insert(texts, text)
            end
        elseif descendant:IsA("ProximityPrompt") then
            local text = table.concat({
                tostring(descendant.ActionText or ""),
                tostring(descendant.ObjectText or ""),
            }, " ")
            if text ~= " " then
                table.insert(texts, text)
            end
        end
    end

    return table.concat(texts, " "):lower()
end

local function scoreFireDungeonGateCandidate(instance)
    local path = instance:GetFullName():lower()
    local name = instance.Name:lower()
    local text = getFireDungeonGateText(instance)
    local score = 0

    for _, source in ipairs({ path, name, text }) do
        if source:find("world9dungeon", 1, true) then
            score += 80
        end
        if source:find("fire city", 1, true) or source:find("firecity", 1, true) then
            score += 60
        end
        if source:find("dungeon", 1, true) then
            score += 40
        end
        if source:find("gate", 1, true) or source:find("portal", 1, true) then
            score += 25
        end
        if source:find("enter", 1, true) or source:find("join", 1, true) or source:find("yes", 1, true) then
            score += 15
        end
        if source:find("locked", 1, true) or source:find("closed", 1, true) then
            score -= 100
        end
    end

    if instance:IsA("ProximityPrompt") then
        score += instance.Enabled and 35 or -100
    elseif instance:IsA("ClickDetector") or instance:IsA("TouchTransmitter") then
        score += 20
    elseif instance:IsA("BasePart") and instance:GetAttribute("SystemType") == "Dungeon" then
        score += 90
        if instance:GetAttribute("SystemDificult") == "Easy" then
            score += 20
        end
    elseif instance:IsA("BasePart") and name == "dungeonstation" then
        score += 80
    end

    return score
end

local function getFireDungeonGatePosition(instance)
    local candidate = instance
    if not candidate:IsA("BasePart") then
        candidate = instance:FindFirstAncestorWhichIsA("BasePart")
    end

    if candidate then
        return candidate.Position, candidate
    end

    local model = instance:FindFirstAncestorWhichIsA("Model")
    if model then
        return getModelPosition(model), nil
    end

    return nil, nil
end

local function getFireDungeonGateCandidates()
    local worlds = workspace:FindFirstChild("Worlds")
    local world9 = worlds and worlds:FindFirstChild("9")
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local candidates = {}

    if not world9 or not rootPart then
        return candidates
    end

    for _, instance in ipairs(world9:GetDescendants()) do
        if instance:IsA("ProximityPrompt")
            or instance:IsA("ClickDetector")
            or instance:IsA("TouchTransmitter")
            or (instance:IsA("BasePart") and (instance.Name == "DungeonStation" or instance:GetAttribute("SystemType") == "Dungeon")) then
            local score = scoreFireDungeonGateCandidate(instance)
            local position, part = getFireDungeonGatePosition(instance)

            if score > 0 and position and (position - rootPart.Position).Magnitude <= FIRE_DUNGEON_GATE_SCAN_RADIUS then
                table.insert(candidates, {
                    Instance = instance,
                    Part = part,
                    Position = position,
                    Score = score,
                })
            end
        end
    end

    table.sort(candidates, function(left, right)
        return left.Score > right.Score
    end)

    return candidates
end

local function triggerFireDungeonGateCandidate(candidate)
    local instance = candidate and candidate.Instance
    local rootPart = getCharacterRoot()

    if not instance or not rootPart then
        return false
    end

    moveCharacterTo(candidate.Position)
    task.wait(0.25)

    if instance:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
        pcall(function()
            fireproximityprompt(instance, math.max(instance.HoldDuration, 0.1))
        end)
        return true
    elseif instance:IsA("ClickDetector") and typeof(fireclickdetector) == "function" then
        pcall(function()
            fireclickdetector(instance)
        end)
        return true
    elseif instance:IsA("TouchTransmitter") and candidate.Part and typeof(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(rootPart, candidate.Part, 0)
            task.wait(0.1)
            firetouchinterest(rootPart, candidate.Part, 1)
        end)
        return true
    elseif instance:IsA("BasePart") then
        moveCharacterTo(instance.Position)
        task.wait(0.5)
        return true
    elseif candidate.Part then
        moveCharacterTo(candidate.Part.Position)
        return true
    end

    return false
end

local function tryEnterFireCityDungeonGate(Library)
    if not requestWorldAndWait(Library, 9) then
        return false
    end

    local candidates = getFireDungeonGateCandidates()
    if #candidates == 0 then
        return false
    end

    print(("[Potassium] Trying Fire City Dungeon gate path: %s."):format(candidates[1].Instance:GetFullName()))

    for _, candidate in ipairs(candidates) do
        if triggerFireDungeonGateCandidate(candidate) then
            local started = os.clock()
            repeat
                if pressVisibleFireCityYes and pressVisibleFireCityYes() then
                    return true
                end
                task.wait(0.25)
            until os.clock() - started > FIRE_DUNGEON_GATE_TRY_SECONDS or not state.Enabled
        end
    end

    return false
end

function joinFireCityDungeon(Library)
    local bridge = Library and Library.getBridge("DungeonJoin")
    local fired = false
    local rememberedOpen = isRememberedFireCityDungeonOpen()

    if pressVisibleFireCityYes and pressVisibleFireCityYes() then
        fired = true
    elseif tryEnterFireCityDungeonGate(Library) then
        fired = true
    elseif rememberedOpen and tryGamemodeControllerJoin({
        NotifyKind = "GamemodeOpen",
        GamemodeType = "Dungeon",
        Key = "World9Dungeon",
        Name = "Fire City Dungeon",
    }) then
        fired = true
    elseif rememberedOpen and bridge then
        bridge:Fire("Join", "World9Dungeon")
        fired = true
    elseif rememberedOpen and fireRawBridgeName("DungeonJoin", "Join", "World9Dungeon") then
        fired = true
    end

    if fired then
        state.LastGamemodeJoinAt = os.clock()
        print("[Potassium] Fired Fire City Dungeon join remote: DungeonJoin Join World9Dungeon.")
    elseif not rememberedOpen then
        print("[Potassium] Fire City Dungeon is locked; waiting for open card/gate.")
    else
        warn("[Potassium] Could not fire Fire City Dungeon join remote.")
    end

    return fired
end

local function getVisibleGamemodeCards()
    local hud = playerGui:FindFirstChild("HUD")
    local main = hud and hud:FindFirstChild("Main")
    local notifyRoot = main and main:FindFirstChild("GamemodeNotify")
    local cards = {}

    if not notifyRoot then
        return cards
    end

    for _, card in ipairs(notifyRoot:GetChildren()) do
        if card:IsA("GuiObject") and card.Visible and card.Name ~= "NotifyTemplate" then
            local gamemodeType, key = card.Name:match("^Notify_([^_]+)_(.+)$")
            local payload = {
                NotifyKind = "GamemodeOpen",
                GamemodeType = gamemodeType,
                Key = key,
            }

            local kind = getGamemodeKind(payload)
            local actions = card:FindFirstChild("Actions")
            local yes = actions and actions:FindFirstChild("YES")
            local description = card:FindFirstChild("Description")
            local descriptionText = description and description:IsA("TextLabel") and description.Text or ""
            local gateRank = descriptionText:match("[Gg]ate%s+[Rr]ank%s*([EDCB])")
                or descriptionText:match("[Rr]ank%s*([EDCB])")

            if kind and yes and yes:IsA("GuiButton") then
                if kind == "Raid" and payload.Key == "World5" and gateRank then
                    payload.GateRank = gateRank
                    payload.Rank = gateRank
                end

                table.insert(cards, {
                    Kind = kind,
                    Payload = payload,
                    Button = yes,
                    Card = card,
                    Description = descriptionText,
                })
            end
        end
    end

    return cards
end

pressVisibleFireCityYes = function()
    local directYes = playerGui:FindFirstChild("HUD")
        and playerGui.HUD:FindFirstChild("Main")
        and playerGui.HUD.Main:FindFirstChild("GamemodeNotify")
        and playerGui.HUD.Main.GamemodeNotify:FindFirstChild("Notify_Dungeon_World9Dungeon")
        and playerGui.HUD.Main.GamemodeNotify.Notify_Dungeon_World9Dungeon:FindFirstChild("Actions")
        and playerGui.HUD.Main.GamemodeNotify.Notify_Dungeon_World9Dungeon.Actions:FindFirstChild("YES")

    if directYes and directYes:IsA("GuiButton") and fireGuiButton(directYes) then
        state.LastGamemodeJoinAt = os.clock()
        print("[Potassium] Pressed Fire City Dungeon YES button.")
        return true
    end

    for _, cardInfo in ipairs(getVisibleGamemodeCards()) do
        if cardInfo.Kind == "Dungeon"
            and (cardInfo.Payload.Key == "World9Dungeon" or tostring(cardInfo.Description):lower():find("fire city", 1, true)) then
            if fireGuiButton(cardInfo.Button) then
                state.LastGamemodeJoinAt = os.clock()
                print("[Potassium] Pressed actual YES button for Fire City Dungeon.")
                return true
            end
        end
    end

    return false
end

local function pressVisibleGamemodeYes(Library)
    if os.clock() - (state.LastGamemodeJoinAt or 0) < GAMEMODE_JOIN_COOLDOWN then
        return false
    end

    local cards = getVisibleGamemodeCards()
    local kindOrder = { "Dungeon", "Raid", "TimeTrial" }

    for _, kind in ipairs(kindOrder) do
        if state.SelectedArenaTypes[kind] ~= false then
            for _, cardInfo in ipairs(cards) do
                if cardInfo.Kind == kind
                    and getGamemodeSelection(cardInfo.Kind, cardInfo.Payload.Key)
                    and not (cardInfo.Kind == "Raid" and cardInfo.Payload.Key == "World5" and not isGateRankSelected(cardInfo.Payload.GateRank or cardInfo.Payload.Rank)) then
                    if cardInfo.Kind == "Dungeon"
                        and (cardInfo.Payload.Key == "World9Dungeon" or tostring(cardInfo.Description):lower():find("fire city", 1, true)) then
                        if pressVisibleFireCityYes() then
                            return true
                        end

                        return joinFireCityDungeon(Library)
                    end

                    if fireGuiButton(cardInfo.Button) then
                        state.LastGamemodeJoinAt = os.clock()
                        print(("[Potassium] Pressed YES for %s %s."):format(cardInfo.Kind, tostring(cardInfo.Payload.Key)))
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function runDungeonRaidFarm()
    if state.DungeonFarmRunning then
        return
    end

    state.DungeonFarmRunning = true

    local ok, Library = pcall(function()
        return require(ReplicatedStorage:WaitForChild("SimpleWorld"):WaitForChild("Library"))
    end)

    if not ok or not Library then
        warn("[Potassium] Could not load SimpleWorld Library for dungeon/raid farm.")
        state.DungeonFarmRunning = false
        return
    end

    setupGamemodeAvailabilityWatchers(Library)

    local lastArenaKey
    local observedLiveSet = {}
    local lastKillAt = os.clock()
    local currentTarget
    local currentTargetHealth

    while state.Enabled and state.DungeonFarmRunning do
        local arenaInfo = getActiveCombatArena()

        if not arenaInfo then
            currentTarget = nil
            currentTargetHealth = nil
            observedLiveSet = {}
            lastArenaKey = nil
            lastKillAt = os.clock()
            pollRaidGateState()

            if pressVisibleGamemodeYes(Library) then
                task.wait(1.25)
            else
                local openKey, payload = getNextJoinableGamemode()
                if payload then
                    state.AvailableGamemodes[openKey] = nil
                    tryJoinGamemode(Library, payload)
                    task.wait(1.25)
                else
                    logAvailabilityWait()
                    task.wait(0.5)
                end
            end

            hideAll()
            continue
        end

        if arenaInfo.Key ~= lastArenaKey then
            print(("[Potassium] Dungeon/Raid farm attached to %s."):format(arenaInfo.Key))
            currentTarget = nil
            currentTargetHealth = nil
            observedLiveSet = {}
            lastArenaKey = arenaInfo.Key
            lastKillAt = os.clock()
        end

        local target, targetHealth, liveEnemies, liveSet = getArenaEnemySnapshot(arenaInfo.Enemies)
        local killedSomething = false

        for enemy in pairs(observedLiveSet) do
            if not liveSet[enemy] then
                killedSomething = true
                break
            end
        end

        if killedSomething then
            lastKillAt = os.clock()
            currentTarget = nil
            currentTargetHealth = nil
            print("[Potassium] Dungeon/Raid mob killed. Timeout reset.")
        end

        observedLiveSet = liveSet

        if #liveEnemies == 0 then
            if isFireCityArena(arenaInfo) and not isFireCityActuallyJoined(nil) then
                if os.clock() - (state.LastGamemodeJoinAt or 0) >= GAMEMODE_JOIN_COOLDOWN then
                    if not pressVisibleFireCityYes() then
                        joinFireCityDungeon(Library)
                    end
                end
            end

            currentTarget = nil
            currentTargetHealth = nil
            lastKillAt = os.clock()
            hideAll()
            task.wait(0.35)
            continue
        end

        if isFireCityArena(arenaInfo) and target and not isFireCityActuallyJoined(target) then
            if os.clock() - (state.LastGamemodeJoinAt or 0) >= GAMEMODE_JOIN_COOLDOWN then
                if not pressVisibleFireCityYes() then
                    joinFireCityDungeon(Library)
                end
            end

            lastKillAt = os.clock()
            hideAll()
            task.wait(0.5)
            continue
        end

        local mobTimeout = getCombatMobTimeout(arenaInfo)
        if os.clock() - lastKillAt > mobTimeout then
            leaveActiveCombatArena(Library, arenaInfo, ("No kill/progress for %ds"):format(mobTimeout))
            state.DungeonFarmRunning = false
            break
        end

        if target and target ~= currentTarget then
            currentTarget = target
            currentTargetHealth = targetHealth
            print(("[Potassium] Dungeon/Raid target: %s (%s HP)."):format(target.Name, formatHealth(targetHealth)))
        elseif target and type(targetHealth) == "number" then
            if type(currentTargetHealth) == "number" and targetHealth < currentTargetHealth then
                lastKillAt = os.clock()
            end

            currentTargetHealth = targetHealth
        end

        if target then
            local position = getEnemyTargetPosition(target)
            if position then
                moveCharacterTo(position)
            end
        end

        hideAll()
        task.wait(DUNGEON_SCAN_INTERVAL)
    end

    state.DungeonFarmRunning = false
    print("[Potassium] Dungeon/Raid farm stopped.")
end

local function runLocationRoute()
    if state.RouteRunning then
        return
    end

    state.RouteRunning = true

    local ok, Library = pcall(function()
        return require(ReplicatedStorage:WaitForChild("SimpleWorld"):WaitForChild("Library"))
    end)

    if not ok or not Library then
        warn("[Potassium] Could not load SimpleWorld Library.")
        state.RouteRunning = false
        return
    end

    local okWorldController, WorldController = pcall(function()
        return require(ReplicatedStorage.SimpleWorld.Library.Client.WorldController)
    end)

    if not okWorldController or not WorldController then
        warn("[Potassium] Could not load WorldController.")
        state.RouteRunning = false
        return
    end

    local requestChangeWorld = Library.getBridge("RequestChangeWorld")
    if not requestChangeWorld then
        warn("[Potassium] RequestChangeWorld bridge was not found.")
        state.RouteRunning = false
        return
    end

    while state.Enabled and state.RouteRunning do
        local ranAny = false

        for _, location in ipairs(locations) do
            if not state.Enabled or not state.RouteRunning then
                break
            end

            if state.SelectedLocations[location.Name] == false then
                continue
            end

            ranAny = true

            local currentWorld
            pcall(function()
                currentWorld = WorldController:GetCurrentWorld()
            end)

            if currentWorld ~= location.World then
                print(("[Potassium] Switching to world %d for %s."):format(location.World, location.Name))
                requestChangeWorld:Fire(location.World)

                local started = os.clock()
                repeat
                    hideAll()
                    task.wait(0.15)

                    pcall(function()
                        currentWorld = WorldController:GetCurrentWorld()
                    end)
                until currentWorld == location.World or os.clock() - started > WORLD_CHANGE_TIMEOUT or not state.Enabled or not state.RouteRunning

                task.wait(0.35)
            end

            if not state.Enabled or not state.RouteRunning then
                break
            end

            print(("[Potassium] Teleporting to %s."):format(location.Name))
            moveCharacterTo(location.Position)
            waitForTargetDeath(location)
        end

        if not ranAny then
            warn("[Potassium] No route locations are checked.")
            task.wait(0.5)
        end
    end

    state.RouteRunning = false
    print("[Potassium] Location route stopped.")
end

local function buildRouteGui()
    for _, child in ipairs(playerGui:GetChildren()) do
        if child.Name == "PotassiumRouteGui" then
            child:Destroy()
        end
    end

    for _, location in ipairs(locations) do
        if state.SelectedLocations[location.Name] == nil then
            state.SelectedLocations[location.Name] = true
        end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "PotassiumRouteGui"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.fromOffset(292, GUI_FULL_HEIGHT)
    frame.Position = UDim2.fromOffset(90, 210)
    frame.BackgroundColor3 = Color3.fromRGB(22, 24, 31)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(67, 95, 142)
    stroke.Thickness = 1
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -50, 0, 34)
    title.Position = UDim2.fromOffset(12, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "World Route"
    title.TextColor3 = Color3.fromRGB(245, 247, 255)
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local minimize = Instance.new("TextButton")
    minimize.Name = "Minimize"
    minimize.Size = UDim2.fromOffset(30, 26)
    minimize.Position = UDim2.new(1, -36, 0, 4)
    minimize.BackgroundColor3 = Color3.fromRGB(41, 47, 62)
    minimize.BorderSizePixel = 0
    minimize.Font = Enum.Font.GothamBold
    minimize.Text = "-"
    minimize.TextColor3 = Color3.fromRGB(245, 247, 255)
    minimize.TextSize = 18
    minimize.Parent = frame

    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 6)
    minimizeCorner.Parent = minimize

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -24, 1, -44)
    content.Position = UDim2.fromOffset(12, 40)
    content.BackgroundTransparency = 1
    content.Parent = frame

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, 0, 0, 22)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextColor3 = Color3.fromRGB(190, 205, 235)
    status.TextSize = 13
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = content

    local rows = {}
    local arenaRows = {}
    local filterButtons = {}
    local filterNames = {
        All = true,
        Dungeon = true,
        Raid = true,
        Gate = true,
        TimeTrial = true,
    }
    state.ModeFilter = filterNames[state.ModeFilter] and state.ModeFilter or "All"
    local activeModeFilter = state.ModeFilter
    local filterClicksEnabledAt = os.clock() + 0.4
    local dungeonButton
    local modeList

    local function isOptionVisibleForFilter(option)
        if activeModeFilter == "All" then
            return true
        elseif activeModeFilter == "Dungeon" then
            return option.Kind == "Dungeon"
        elseif activeModeFilter == "Raid" then
            return option.Kind == "Raid" and option.Key ~= "World5"
        elseif activeModeFilter == "Gate" then
            return option.Kind == "Raid" and option.Key == "World5"
        elseif activeModeFilter == "TimeTrial" then
            return option.Kind == "TimeTrial"
        end

        return true
    end

    local function updateStatus()
        local selected = 0
        for _, location in ipairs(locations) do
            if state.SelectedLocations[location.Name] ~= false then
                selected += 1
            end
        end

        status.Text = ("Route %s | Raid %s | %d/%d"):format(
            state.RouteRunning and "RUNNING" or "READY",
            state.DungeonFarmRunning and "ON" or "OFF",
            selected,
            #locations
        )

        if dungeonButton then
            dungeonButton.Text = state.DungeonFarmRunning and "Stop Dungeon/Raid" or "Auto Dungeon/Raid"
            dungeonButton.BackgroundColor3 = state.DungeonFarmRunning and Color3.fromRGB(130, 68, 58) or Color3.fromRGB(54, 82, 125)
        end

        for _, row in pairs(rows) do
            local enabled = state.SelectedLocations[row.name] ~= false
            row.box.Text = enabled and "✓" or ""
            row.button.BackgroundColor3 = enabled and Color3.fromRGB(38, 58, 88) or Color3.fromRGB(41, 47, 62)
        end
    end

    local function makeRow(location, y)
        local button = Instance.new("TextButton")
        button.Name = location.Name:gsub("%s+", "")
        button.Size = UDim2.new(1, 0, 0, 28)
        button.Position = UDim2.fromOffset(0, y)
        button.BackgroundColor3 = Color3.fromRGB(41, 47, 62)
        button.BorderSizePixel = 0
        button.Text = ""
        button.Parent = content

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button

        local box = Instance.new("TextLabel")
        box.Name = "Check"
        box.Size = UDim2.fromOffset(24, 24)
        box.Position = UDim2.fromOffset(4, 2)
        box.BackgroundColor3 = Color3.fromRGB(18, 21, 29)
        box.BorderSizePixel = 0
        box.Font = Enum.Font.GothamBold
        box.TextColor3 = Color3.fromRGB(120, 220, 145)
        box.TextSize = 16
        box.Parent = button

        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 5)
        boxCorner.Parent = box

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, -38, 1, 0)
        label.Position = UDim2.fromOffset(36, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.Text = ("W%d  %s"):format(location.World, location.Name)
        label.TextColor3 = Color3.fromRGB(245, 247, 255)
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = button

        button.MouseButton1Click:Connect(function()
            state.SelectedLocations[location.Name] = not (state.SelectedLocations[location.Name] ~= false)
            updateStatus()
        end)

        rows[location.Name] = {
            name = location.Name,
            button = button,
            box = box,
        }
    end

    for index, location in ipairs(locations) do
        makeRow(location, 28 + ((index - 1) * 32))
    end

    local arenaTitle = Instance.new("TextLabel")
    arenaTitle.Name = "ArenaTitle"
    arenaTitle.Size = UDim2.new(1, 0, 0, 18)
    arenaTitle.Position = UDim2.fromOffset(0, 286)
    arenaTitle.BackgroundTransparency = 1
    arenaTitle.Font = Enum.Font.GothamBold
    arenaTitle.Text = "Auto Join Modes"
    arenaTitle.TextColor3 = Color3.fromRGB(190, 205, 235)
    arenaTitle.TextSize = 12
    arenaTitle.TextXAlignment = Enum.TextXAlignment.Left
    arenaTitle.Parent = content

    local function refreshArenaRows()
        local y = 0

        for _, option in ipairs(gamemodeOptions) do
            local row = arenaRows[getGamemodeOptionId(option)]
            if not row then
                continue
            end

            local visible = isOptionVisibleForFilter(option)

            local enabled = isGamemodeOptionSelected(row.option)
            row.box.Text = enabled and "ON" or ""
            row.button.BackgroundColor3 = enabled and Color3.fromRGB(38, 58, 88) or Color3.fromRGB(41, 47, 62)
            row.button.Visible = visible

            if visible then
                row.button.Position = UDim2.fromOffset(0, y)
                y += 28
            end
        end

        if modeList then
            modeList.CanvasSize = UDim2.fromOffset(0, y)
        end

        for name, button in pairs(filterButtons) do
            button.BackgroundColor3 = activeModeFilter == name and Color3.fromRGB(76, 105, 152) or Color3.fromRGB(41, 47, 62)
        end
    end

    local function makeFilterButton(name, text, x, y, width)
        local button = Instance.new("TextButton")
        button.Name = name .. "Filter"
        button.Size = UDim2.fromOffset(width, 24)
        button.Position = UDim2.fromOffset(x, y)
        button.BackgroundColor3 = Color3.fromRGB(41, 47, 62)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.Text = text
        button.TextColor3 = Color3.fromRGB(245, 247, 255)
        button.TextSize = 11
        button.Parent = content

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button

        button.MouseButton1Click:Connect(function()
            if os.clock() < filterClicksEnabledAt then
                return
            end
            activeModeFilter = name
            state.ModeFilter = name
            refreshArenaRows()
        end)

        filterButtons[name] = button
    end

    makeFilterButton("All", "All", 0, 308, 42)
    makeFilterButton("Dungeon", "Dgn", 48, 308, 46)
    makeFilterButton("Raid", "Raid", 100, 308, 46)
    makeFilterButton("Gate", "Gate", 152, 308, 46)
    makeFilterButton("TimeTrial", "Trial", 204, 308, 62)

    modeList = Instance.new("ScrollingFrame")
    modeList.Name = "ModeList"
    modeList.Size = UDim2.new(1, 0, 0, 114)
    modeList.Position = UDim2.fromOffset(0, 342)
    modeList.BackgroundTransparency = 1
    modeList.BorderSizePixel = 0
    modeList.ScrollBarThickness = 4
    modeList.CanvasSize = UDim2.fromOffset(0, 0)
    modeList.Parent = content

    local function makeArenaRow(option, y)
        local button = Instance.new("TextButton")
        button.Name = option.Name:gsub("%W+", "") .. "Toggle"
        button.Size = UDim2.new(1, 0, 0, 24)
        button.Position = UDim2.fromOffset(0, y or 0)
        button.BackgroundColor3 = Color3.fromRGB(41, 47, 62)
        button.BorderSizePixel = 0
        button.Text = ""
        button.Parent = modeList

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button

        local box = Instance.new("TextLabel")
        box.Name = "Check"
        box.Size = UDim2.fromOffset(30, 20)
        box.Position = UDim2.fromOffset(4, 2)
        box.BackgroundColor3 = Color3.fromRGB(18, 21, 29)
        box.BorderSizePixel = 0
        box.Font = Enum.Font.GothamBold
        box.TextColor3 = Color3.fromRGB(120, 220, 145)
        box.TextSize = 11
        box.Parent = button

        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 5)
        boxCorner.Parent = box

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, -44, 1, 0)
        label.Position = UDim2.fromOffset(42, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.Text = option.Name
        label.TextColor3 = Color3.fromRGB(245, 247, 255)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = button

        button.MouseButton1Click:Connect(function()
            setGamemodeOptionSelection(option, not isGamemodeOptionSelected(option))
            refreshArenaRows()
            updateStatus()
        end)

        arenaRows[getGamemodeOptionId(option)] = {
            option = option,
            button = button,
            box = box,
        }
    end

    for _, option in ipairs(gamemodeOptions) do
        makeArenaRow(option)
    end

    local startButton = Instance.new("TextButton")
    startButton.Name = "StartStop"
    startButton.Size = UDim2.new(1, 0, 0, 32)
    startButton.Position = UDim2.fromOffset(0, 468)
    startButton.BackgroundColor3 = Color3.fromRGB(54, 82, 125)
    startButton.BorderSizePixel = 0
    startButton.Font = Enum.Font.GothamBold
    startButton.Text = "Start Route"
    startButton.TextColor3 = Color3.fromRGB(245, 247, 255)
    startButton.TextSize = 13
    startButton.Parent = content

    local startCorner = Instance.new("UICorner")
    startCorner.CornerRadius = UDim.new(0, 6)
    startCorner.Parent = startButton

    dungeonButton = Instance.new("TextButton")
    dungeonButton.Name = "DungeonRaidToggle"
    dungeonButton.Size = UDim2.new(1, 0, 0, 32)
    dungeonButton.Position = UDim2.fromOffset(0, 506)
    dungeonButton.BackgroundColor3 = Color3.fromRGB(54, 82, 125)
    dungeonButton.BorderSizePixel = 0
    dungeonButton.Font = Enum.Font.GothamBold
    dungeonButton.Text = "Auto Dungeon/Raid"
    dungeonButton.TextColor3 = Color3.fromRGB(245, 247, 255)
    dungeonButton.TextSize = 13
    dungeonButton.Parent = content

    local dungeonCorner = Instance.new("UICorner")
    dungeonCorner.CornerRadius = UDim.new(0, 6)
    dungeonCorner.Parent = dungeonButton

    startButton.MouseButton1Click:Connect(function()
        if state.RouteRunning then
            state.RouteRunning = false
            startButton.Text = "Start Route"
            updateStatus()
            return
        end

        startButton.Text = "Stop Route"
        task.spawn(function()
            runLocationRoute()
            startButton.Text = "Start Route"
            updateStatus()
        end)
        updateStatus()
    end)

    dungeonButton.MouseButton1Click:Connect(function()
        local now = os.clock()
        if now - (state.LastDungeonToggleAt or 0) < 0.5 then
            return
        end
        state.LastDungeonToggleAt = now

        if state.DungeonFarmRunning then
            state.DungeonFarmRunning = false
            updateStatus()
            return
        end

        task.spawn(function()
            runDungeonRaidFarm()
            updateStatus()
        end)
        updateStatus()
    end)

    local minimized = false
    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        content.Visible = not minimized
        frame.Size = minimized and UDim2.fromOffset(292, 34) or UDim2.fromOffset(292, GUI_FULL_HEIGHT)
        minimize.Text = minimized and "+" or "-"
    end)

    local dragging = false
    local dragStart
    local frameStart

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            frameStart = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            frameStart.X.Scale,
            frameStart.X.Offset + delta.X,
            frameStart.Y.Scale,
            frameStart.Y.Offset + delta.Y
        )
    end)

    addConnection(gui.Destroying:Connect(function()
        state.RouteRunning = false
        state.DungeonFarmRunning = false
    end))

    activeModeFilter = "All"
    state.ModeFilter = "All"
    refreshArenaRows()
    updateStatus()
end

buildRouteGui()

if AUTO_START_ROUTE then
    task.spawn(runLocationRoute)
end

print("[Potassium] Loading hider and route GUI enabled.")
