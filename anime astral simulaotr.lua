local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SETTINGS_FOLDER = "Potassium"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/hide_loading_screens_" .. tostring(player.UserId) .. ".json"

local function loadSavedSettings()
    if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" or not isfile(SETTINGS_FILE) then
        return {}
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(SETTINGS_FILE))
    end)

    if ok and type(decoded) == "table" then
        return decoded
    end

    warn("[Potassium] Saved settings could not be decoded; using defaults.")
    return {}
end

local savedSettings = loadSavedSettings()

local WAIT_AT_LOCATION = 0.1
local WORLD_CHANGE_TIMEOUT = 12
local TARGET_FIND_TIMEOUT = 8
local TARGET_DEATH_TIMEOUT = 45
local TARGET_SEARCH_RADIUS = 5000
local WORLD_ROUTE_CYCLE_DELAY = 0.25
local SINGLE_BOSS_RESPAWN_POLL_INTERVAL = 0.5
local UNIVERSAL_COMBAT_TIMEOUT = 6
local WAVE_TRANSITION_TIMEOUT = 30
local GATE_FINAL_WAVE = 50
local GATE_COMPLETION_RETURN_GRACE = 1.25
local GATE_AUTO_ARISE_RETRY_INTERVAL = 1
local DUNGEON_SCAN_INTERVAL = 0.15
local FIRE_CITY_GUI_SCAN_INTERVAL = 0.5
local GAMEMODE_GUI_SCAN_INTERVAL = 0.5
local GAMEMODE_OPEN_WINDOW = 60
local GAMEMODE_JOIN_COOLDOWN = 4
local PROMPT_SUPPRESSION_INACTIVE_GRACE = 5
local GATE_JOIN_CONFIRM_TIMEOUT = 10
local RAID_GATE_POLL_INTERVAL = 5
local AVAILABILITY_WAIT_LOG_INTERVAL = 10
local RAID_CREATE_JOIN_DELAY = 1
local PRIORITY_JOIN_AFTER_TITAN_LEAVE_DELAY = 2
local PRIORITY_JOIN_CONFIRM_TIMEOUT = 8
local PRIORITY_JOIN_RETRY_INTERVAL = 1
local AUTO_EXCHANGE_INTERVAL = 0.3
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
        Key = "World5",
        GateRank = "A",
        Name = "Gate Rank A",
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
    {
        Kind = "Defense",
        Key = "World4",
        Name = "Titan Wall Defense",
    },
    {
        Kind = "Defense",
        Key = "World8",
        Name = "Beach Defense",
    },
}

local old = getgenv and getgenv().PotassiumHideLoading
local restartDungeonFarmAfterReload = type(old) == "table"
    and (old.AutoDungeonRaidWanted == true or old.DungeonFarmRunning == true)
    or (type(old) ~= "table" and savedSettings.AutoDungeonRaidWanted == true)
local restartRouteAfterReload = type(old) == "table"
    and old.RouteRunning == true
    or (type(old) ~= "table" and savedSettings.RouteRunning == true)
if old and old.Disconnect then
    pcall(function()
        old:Disconnect()
    end)
end

local state = {
    Enabled = true,
    Connections = {},
    RouteRunning = false,
    RoutePausedForAutoJoin = false,
    DungeonFarmRunning = false,
    AutoDungeonRaidWanted = false,
    AutoExchangeLoopRunning = false,
    ExchangeRecipeCursor = 1,
    TokenRecipeCursor = 1,
    SelectedExchangeRecipes = {},
    SelectedTokenRecipes = {},
    ExchangeCategoryFilter = "Exchange",
    RouteGuiPosition = {
        X = 90,
        Y = 210,
    },
    RouteGuiMinimized = false,
    ExchangeGuiPosition = {
        X = 400,
        Y = 210,
    },
    ExchangeGuiMinimized = false,
    LastExchangeWarningAt = 0,
    LastDungeonToggleAt = 0,
    LastGamemodeJoinAt = 0,
    LastFireCityGuiScanAt = 0,
    LastGamemodeGuiScanAt = 0,
    LastResumeAttemptAt = 0,
    LastRaidGatePollAt = 0,
    LastAvailabilityWaitLogAt = 0,
    GamemodeActionBusy = false,
    AvailabilityHooksReady = false,
    WatchedAvailabilityBridges = {},
    RaidLifecycleHooksReady = false,
    WatchedRaidLifecycleBridges = {},
    AvailableGamemodes = {},
    PendingResumeGamemode = nil,
    GateOccurrenceRank = nil,
    GateOccurrenceClosesAt = 0,
    ConsumedGateRank = nil,
    ConsumedGateUntil = 0,
    LastAutoAriseAttemptAt = 0,
    LatestRaidState = nil,
    LatestRaidStateAt = 0,
    LatestRaidContextKey = nil,
    GateCompletionReady = false,
    GateCompletionAt = 0,
    LastJoinedPromptCards = {},
    SuppressedGamemodePrompts = {},
    HookedGuiObjects = setmetatable({}, { __mode = "k" }),
    HookedScreenGuis = setmetatable({}, { __mode = "k" }),
    HookedTeleportRoots = setmetatable({}, { __mode = "k" }),
    HookedWindows = setmetatable({}, { __mode = "k" }),
    SelectedLocations = {},
    SelectedArenaTypes = {
        Dungeon = true,
        Raid = true,
        TimeTrial = true,
        Defense = true,
    },
    SelectedGamemodes = {},
    SelectedGamemodeIds = {},
    GamemodePriority = {},
    ModeFilter = "All",
}

local function copyBooleanSettings(target, source)
    if type(source) ~= "table" then
        return
    end

    for key, enabled in pairs(source) do
        if type(key) == "string" and type(enabled) == "boolean" then
            target[key] = enabled
        end
    end
end

local function copyNumberSettings(target, source)
    if type(source) ~= "table" then
        return
    end

    for key, value in pairs(source) do
        if type(key) == "string" and type(value) == "number" then
            target[key] = value
        end
    end
end

local function applySavedGuiState(source)
    if type(source) ~= "table" then
        return
    end

    if type(source.RouteGuiPosition) == "table" then
        state.RouteGuiPosition.X = tonumber(source.RouteGuiPosition.X) or state.RouteGuiPosition.X
        state.RouteGuiPosition.Y = tonumber(source.RouteGuiPosition.Y) or state.RouteGuiPosition.Y
    end

    if type(source.ExchangeGuiPosition) == "table" then
        state.ExchangeGuiPosition.X = tonumber(source.ExchangeGuiPosition.X) or state.ExchangeGuiPosition.X
        state.ExchangeGuiPosition.Y = tonumber(source.ExchangeGuiPosition.Y) or state.ExchangeGuiPosition.Y
    end

    if type(source.RouteGuiMinimized) == "boolean" then
        state.RouteGuiMinimized = source.RouteGuiMinimized
    end

    if type(source.ExchangeGuiMinimized) == "boolean" then
        state.ExchangeGuiMinimized = source.ExchangeGuiMinimized
    end
end

if type(savedSettings) == "table" then
    copyBooleanSettings(state.SelectedLocations, savedSettings.SelectedLocations)
    copyBooleanSettings(state.SelectedArenaTypes, savedSettings.SelectedArenaTypes)
    copyBooleanSettings(state.SelectedExchangeRecipes, savedSettings.SelectedExchangeRecipes)
    copyBooleanSettings(state.SelectedTokenRecipes, savedSettings.SelectedTokenRecipes)

    if type(savedSettings.ModeFilter) == "string" then
        state.ModeFilter = savedSettings.ModeFilter
    end

    if savedSettings.ExchangeCategoryFilter == "Token" then
        state.ExchangeCategoryFilter = "Token"
    end

    applySavedGuiState(savedSettings)
end

if type(old) == "table" then
    state.AutoDungeonRaidWanted = restartDungeonFarmAfterReload

    if type(old.PendingResumeGamemode) == "table" then
        state.PendingResumeGamemode = old.PendingResumeGamemode
    end

    if type(old.LastJoinedPromptCards) == "table" then
        state.LastJoinedPromptCards = old.LastJoinedPromptCards
    end

    if type(old.SuppressedGamemodePrompts) == "table" then
        state.SuppressedGamemodePrompts = old.SuppressedGamemodePrompts
    end

    state.GateOccurrenceRank = old.GateOccurrenceRank
    state.GateOccurrenceClosesAt = tonumber(old.GateOccurrenceClosesAt) or 0
    state.ConsumedGateRank = old.ConsumedGateRank
    state.ConsumedGateUntil = tonumber(old.ConsumedGateUntil) or 0

    if type(old.SelectedArenaTypes) == "table" then
        for kind, enabled in pairs(old.SelectedArenaTypes) do
            state.SelectedArenaTypes[kind] = enabled
        end
    end

    if type(old.ModeFilter) == "string" then
        state.ModeFilter = old.ModeFilter
    end

    if type(old.SelectedExchangeRecipes) == "table" then
        for recipeId, enabled in pairs(old.SelectedExchangeRecipes) do
            state.SelectedExchangeRecipes[recipeId] = enabled == true
        end
    end

    if type(old.SelectedTokenRecipes) == "table" then
        for recipeId, enabled in pairs(old.SelectedTokenRecipes) do
            state.SelectedTokenRecipes[recipeId] = enabled == true
        end
    end

    if old.ExchangeCategoryFilter == "Token" then
        state.ExchangeCategoryFilter = "Token"
    end

    applySavedGuiState(old)
end

local addingGateRankA = type(old) == "table"
    and type(old.GamemodePriority) == "table"
    and old.GamemodePriority["Raid:World5:A"] == nil

for index, option in ipairs(gamemodeOptions) do
    local optionId = option.Kind .. ":" .. option.Key .. (option.GateRank and (":" .. option.GateRank) or "")
    state.SelectedGamemodes[option.Kind] = state.SelectedGamemodes[option.Kind] or {}

    local oldOptionSelected
    if type(old) == "table" and type(old.SelectedGamemodeIds) == "table" then
        oldOptionSelected = old.SelectedGamemodeIds[optionId]
    elseif type(savedSettings.SelectedGamemodeIds) == "table" then
        oldOptionSelected = savedSettings.SelectedGamemodeIds[optionId]
    end

    if oldOptionSelected ~= nil then
        state.SelectedGamemodeIds[optionId] = oldOptionSelected == true
        state.SelectedGamemodes[option.Kind][option.Key] = oldOptionSelected == true
    else
        state.SelectedGamemodeIds[optionId] = false
        state.SelectedGamemodes[option.Kind][option.Key] = false
    end

    local oldPriority
    if type(old) == "table" and type(old.GamemodePriority) == "table" then
        oldPriority = tonumber(old.GamemodePriority[optionId])
        if addingGateRankA and oldPriority and oldPriority >= 8 then
            oldPriority += 1
        end
    elseif type(savedSettings.GamemodePriority) == "table" then
        oldPriority = tonumber(savedSettings.GamemodePriority[optionId])
    end

    state.GamemodePriority[optionId] = oldPriority or index
end

if type(old) == "table" and type(old.SelectedLocations) == "table" then
    for name, enabled in pairs(old.SelectedLocations) do
        state.SelectedLocations[name] = enabled
    end
end

if getgenv then
    getgenv().PotassiumHideLoading = state
end

local settingsSavePending = false
local settingsSaveGeneration = 0

local function cloneBooleanSettings(source)
    local result = {}
    copyBooleanSettings(result, source)
    return result
end

local function cloneNumberSettings(source)
    local result = {}
    copyNumberSettings(result, source)
    return result
end

local function getSettingsSnapshot()
    return {
        Version = 1,
        RouteRunning = state.RouteRunning == true,
        AutoDungeonRaidWanted = state.AutoDungeonRaidWanted == true,
        SelectedLocations = cloneBooleanSettings(state.SelectedLocations),
        SelectedArenaTypes = cloneBooleanSettings(state.SelectedArenaTypes),
        SelectedGamemodeIds = cloneBooleanSettings(state.SelectedGamemodeIds),
        GamemodePriority = cloneNumberSettings(state.GamemodePriority),
        ModeFilter = state.ModeFilter,
        SelectedExchangeRecipes = cloneBooleanSettings(state.SelectedExchangeRecipes),
        SelectedTokenRecipes = cloneBooleanSettings(state.SelectedTokenRecipes),
        ExchangeCategoryFilter = state.ExchangeCategoryFilter,
        RouteGuiPosition = {
            X = state.RouteGuiPosition.X,
            Y = state.RouteGuiPosition.Y,
        },
        RouteGuiMinimized = state.RouteGuiMinimized == true,
        ExchangeGuiPosition = {
            X = state.ExchangeGuiPosition.X,
            Y = state.ExchangeGuiPosition.Y,
        },
        ExchangeGuiMinimized = state.ExchangeGuiMinimized == true,
    }
end

local function saveSettingsNow()
    if typeof(writefile) ~= "function" then
        return false
    end

    local ok, errorMessage = pcall(function()
        if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(SETTINGS_FOLDER) then
            makefolder(SETTINGS_FOLDER)
        end

        writefile(SETTINGS_FILE, HttpService:JSONEncode(getSettingsSnapshot()))
    end)

    if not ok then
        warn(("[Potassium] Could not save settings: %s"):format(tostring(errorMessage)))
    end

    return ok
end

local function queueSettingsSave()
    if settingsSavePending then
        return
    end

    settingsSavePending = true
    settingsSaveGeneration += 1
    local generation = settingsSaveGeneration
    task.delay(0.2, function()
        if generation ~= settingsSaveGeneration or not state.Enabled then
            return
        end

        settingsSavePending = false
        saveSettingsNow()
    end)
end

local function addConnection(connection)
    table.insert(state.Connections, connection)
    return connection
end

function state:Disconnect()
    settingsSaveGeneration += 1
    settingsSavePending = false
    saveSettingsNow()
    self.Enabled = false
    self.RouteRunning = false
    self.DungeonFarmRunning = false
    self.AutoDungeonRaidWanted = false
    self.AutoExchangeLoopRunning = false
    self.GamemodeActionBusy = false
    for _, child in ipairs(playerGui:GetChildren()) do
        if child.Name == "PotassiumRouteGui" or child.Name == "PotassiumExchangeGui" then
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

local function isGuiHierarchyVisible(instance)
    if not instance or not instance.Parent then
        return false
    end

    local current = instance
    while current and current ~= playerGui do
        if current:IsA("ScreenGui") and not current.Enabled then
            return false
        end

        if current:IsA("GuiObject") and not current.Visible then
            return false
        end

        current = current.Parent
    end

    return current == playerGui
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

    if state.HookedGuiObjects[guiObject] then
        return
    end
    state.HookedGuiObjects[guiObject] = true

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
    if state.HookedScreenGuis[screenGui] then
        return
    end
    state.HookedScreenGuis[screenGui] = true

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

    if state.HookedTeleportRoots[teleportLoading] then
        clearTree(teleportLoading)
        return
    end
    state.HookedTeleportRoots[teleportLoading] = true

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

local function hookWindowsContainer(windowsContainer)
    if not windowsContainer or state.HookedWindows[windowsContainer] then
        return
    end
    state.HookedWindows[windowsContainer] = true

    addConnection(windowsContainer.ChildAdded:Connect(function(child)
        if child.Name == "TeleportLoading" then
            task.defer(function()
                hookTeleportLoading()
                hideTeleportLoading()
            end)
        end
    end))
end

hideAll()
hookLoadingScreen()
hookTeleportLoading()

local windows = playerGui:FindFirstChild("Windows")
if windows then
    hookWindowsContainer(windows)
end

addConnection(playerGui.ChildAdded:Connect(function(child)
    if child.Name == "LoadingScreen" then
        task.defer(function()
            hookLoadingScreen()
            hideLoadingScreen()
        end)
    elseif child.Name == "Windows" then
        task.defer(function()
            hookWindowsContainer(child)
            hookTeleportLoading()
            hideTeleportLoading()
        end)
    end
end))

task.spawn(function()
    while state.Enabled do
        hideAll()
        task.wait(0.25)
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

local function shouldPauseWorldRouteForAutoJoin()
    if not state.AutoDungeonRaidWanted then
        return false
    end

    if state.GamemodeActionBusy
        or state.PendingResumeGamemode ~= nil
        or os.clock() - (state.LastGamemodeJoinAt or 0) < PRIORITY_JOIN_CONFIRM_TIMEOUT then
        return true
    end

    local context = player:GetAttribute("VisibilityContext")
    local kind = type(context) == "string" and context:match("^([^:]+):") or nil
    return kind == "Dungeon"
        or kind == "Raid"
        or kind == "Trial"
        or kind == "TimeTrial"
        or kind == "Defense"
end

local function waitForWorldRouteResume()
    if not shouldPauseWorldRouteForAutoJoin() then
        state.RoutePausedForAutoJoin = false
        return state.Enabled and state.RouteRunning, false
    end

    if not state.RoutePausedForAutoJoin then
        state.RoutePausedForAutoJoin = true
        print("[Potassium] World Route paused while Auto Join owns movement.")
    end

    while state.Enabled and state.RouteRunning and shouldPauseWorldRouteForAutoJoin() do
        hideAll()
        task.wait(0.1)
    end

    local canResume = state.Enabled and state.RouteRunning
    if canResume then
        print("[Potassium] World Route resumed after Auto Join released movement.")
    end
    state.RoutePausedForAutoJoin = false
    return canResume, true
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
        local canResume, interrupted = waitForWorldRouteResume()
        if not canResume then
            return false, false
        elseif interrupted then
            return false, true
        end

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
            return false, false
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
        local canResume, interrupted = waitForWorldRouteResume()
        if not canResume then
            return false, false
        elseif interrupted then
            return false, true
        end

        if not enemy.Parent then
            print(("[Potassium] %s disappeared. Moving on."):format(location.Name))
            return true, false
        end

        health, maxHealth, dead = getEnemyHealth(enemy)

        if dead or (type(health) == "number" and health <= 0) then
            print(("[Potassium] %s is dead/HP is 0. Moving on."):format(location.Name))
            return true, false
        end

        if os.clock() - deathStarted > TARGET_DEATH_TIMEOUT then
            warn(("[Potassium] Timed out waiting for %s HP. Moving on."):format(location.Name))
            return false, false
        end

        hideAll()
        task.wait(0.1)
    end

    return false, false
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
    {
        RootName = "DefenseArenas",
        Kind = "Defense",
        LeaveBridge = "DefenseLeave",
    },
}

local arenaGuiByKind = {
    Dungeon = "DungeonGui",
    Raid = "RaidGui",
    TimeTrial = "TrialGui",
    Defense = "DefenseGui",
}

local arenaRootByKind = {}
for _, rootInfo in ipairs(arenaRoots) do
    arenaRootByKind[rootInfo.Kind] = rootInfo
end

local visibilityKindAliases = {
    Trial = "TimeTrial",
}

local visibilityPrefixByKind = {
    TimeTrial = "Trial",
}

local function getCombatVisibilityContext()
    local context = player:GetAttribute("VisibilityContext")
    if type(context) ~= "string" then
        return nil
    end

    local kind, key = context:match("^([^:]+):(.+)$")
    kind = visibilityKindAliases[kind] or kind
    if not kind or not key or not arenaRootByKind[kind] then
        return nil
    end

    return kind, key, context
end

local function isArenaGuiActive(kind)
    local guiName = arenaGuiByKind[kind]
    local gui = guiName and playerGui:FindFirstChild(guiName)
    local main = gui and gui:FindFirstChild("Main")

    return gui ~= nil
        and (not gui:IsA("ScreenGui") or gui.Enabled)
        and main ~= nil
        and isGuiHierarchyVisible(main)
end

local function makeArenaInfo(rootInfo, arena)
    if not rootInfo or not arena then
        return nil
    end

    return {
        RootInfo = rootInfo,
        Arena = arena,
        Enemies = arena:FindFirstChild("Enemies"),
        Key = rootInfo.RootName .. "/" .. arena.Name,
        VisibilityContext = (visibilityPrefixByKind[rootInfo.Kind] or rootInfo.Kind) .. ":" .. arena.Name,
    }
end

local function getArenaDistanceFromCharacter(enemies)
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart or not enemies then
        return math.huge
    end

    local bestDistance = math.huge
    for _, enemy in ipairs(enemies:GetDescendants()) do
        if isEnemyModel(enemy) then
            local position = getModelPosition(enemy)
            if position then
                bestDistance = math.min(bestDistance, (rootPart.Position - position).Magnitude)
            end
        end
    end

    return bestDistance
end

local function isWorldFiveGateKey(key)
    if type(key) ~= "string" then
        return false
    end

    return key == "World5" or key:match("^World5_") ~= nil
end

local function getGamemodeSelection(kind, key)
    if state.SelectedArenaTypes[kind] == false then
        return false
    end

    if kind == "Raid" and isWorldFiveGateKey(key) then
        for _, option in ipairs(gamemodeOptions) do
            if option.Kind == kind and option.Key == "World5" then
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
    queueSettingsSave()
end

local function isGamemodeOptionSelected(option)
    return state.SelectedGamemodeIds[getGamemodeOptionId(option)] ~= false
end

local function isGateOption(option)
    return option
        and option.Kind == "Raid"
        and option.Key == "World5"
        and option.GateRank ~= nil
end

local function normalizeGateRank(rank)
    if rank == nil then
        return nil
    end

    local normalized = tostring(rank):upper()
    if normalized == "A"
        or normalized == "B"
        or normalized == "C"
        or normalized == "D"
        or normalized == "E" then
        return normalized
    end

    return nil
end

local function parseGateRank(text)
    text = tostring(text or "")
    return normalizeGateRank(
        text:match("[Gg]ate%s+[Rr]ank%s*([ABCDEabcde])")
            or text:match("[Rr]ank%s*([ABCDEabcde])")
            or text:match("([ABCDEabcde])%s*[Rr]ank")
            or text:match("[Gg]ate%s*([ABCDEabcde])")
    )
end

local function markGateOccurrenceConsumed(option)
    if not isGateOption(option) then
        return
    end

    local now = os.clock()
    state.ConsumedGateRank = tostring(option.GateRank)
    state.ConsumedGateUntil = math.max(state.GateOccurrenceClosesAt or 0, now + GAMEMODE_OPEN_WINDOW)
    state.SuppressedGamemodePrompts[getGamemodeOptionId(option)] = {
        ExpiresAt = state.ConsumedGateUntil,
    }

    print(("[Potassium] Gate Rank %s consumed for this opening; normal routing will resume afterward."):format(tostring(option.GateRank)))
end

local function isGateRankSelected(rank)
    if not rank then
        return getGamemodeSelection("Raid", "World5")
    end

    local normalizedRank = normalizeGateRank(rank)
    return normalizedRank ~= nil
        and state.SelectedGamemodeIds["Raid:World5:" .. normalizedRank] ~= false
end

local function getGamemodePriority(option)
    return state.GamemodePriority[getGamemodeOptionId(option)] or 9999
end

local function getGamemodeOptionsByPriority()
    local options = {}

    for _, option in ipairs(gamemodeOptions) do
        table.insert(options, option)
    end

    table.sort(options, function(left, right)
        local leftPriority = getGamemodePriority(left)
        local rightPriority = getGamemodePriority(right)

        if leftPriority == rightPriority then
            return getGamemodeOptionId(left) < getGamemodeOptionId(right)
        end

        return leftPriority < rightPriority
    end)

    return options
end

local function payloadMatchesGamemodeOption(payload, option)
    local kind = payload and payload.GamemodeType
    if kind ~= option.Kind or payload.Key ~= option.Key then
        return false
    end

    if option.GateRank then
        local rank = normalizeGateRank(payload.GateRank or payload.Rank)
        return rank == normalizeGateRank(option.GateRank)
    end

    return true
end

local function getPayloadGamemodePriority(payload)
    local bestPriority = 9999

    for _, option in ipairs(gamemodeOptions) do
        if payloadMatchesGamemodeOption(payload, option) then
            bestPriority = math.min(bestPriority, getGamemodePriority(option))
        end
    end

    return bestPriority
end

local function getArenaGamemodePriority(arenaInfo)
    local kind = arenaInfo and arenaInfo.RootInfo and arenaInfo.RootInfo.Kind
    local key = arenaInfo and arenaInfo.Arena and arenaInfo.Arena.Name
    local optionKey = kind == "Raid" and isWorldFiveGateKey(key) and "World5" or key
    local bestPriority = 9999

    for _, option in ipairs(gamemodeOptions) do
        if option.Kind == kind and option.Key == optionKey and isGamemodeOptionSelected(option) then
            bestPriority = math.min(bestPriority, getGamemodePriority(option))
        end
    end

    return bestPriority
end

local function getArenaGamemodeOption(arenaInfo)
    local kind = arenaInfo and arenaInfo.RootInfo and arenaInfo.RootInfo.Kind
    local key = arenaInfo and arenaInfo.Arena and arenaInfo.Arena.Name
    local optionKey = kind == "Raid" and isWorldFiveGateKey(key) and "World5" or key

    for _, option in ipairs(gamemodeOptions) do
        if option.Kind == kind and option.Key == optionKey then
            return option
        end
    end

    return nil
end

local function getGamemodeOptionByKindKey(kind, key)
    for _, option in ipairs(gamemodeOptions) do
        if option.Kind == kind and option.Key == key then
            return option
        end
    end

    return nil
end

local function getGamemodeOptionForPayload(payload)
    for _, option in ipairs(gamemodeOptions) do
        if payloadMatchesGamemodeOption(payload, option) then
            return option
        end
    end

    return nil
end

local function recordJoinedPrompt(option, card)
    if option then
        state.LastJoinedPromptCards[getGamemodeOptionId(option)] = card
    end
end

local function cleanupSuppressedGamemodePrompts()
    local now = os.clock()

    for optionId, entry in pairs(state.SuppressedGamemodePrompts) do
        if type(entry) ~= "table" or now >= (entry.ExpiresAt or 0) then
            state.SuppressedGamemodePrompts[optionId] = nil
        elseif entry.Card then
            if isGuiHierarchyVisible(entry.Card) then
                entry.InactiveSince = nil
            else
                entry.InactiveSince = entry.InactiveSince or now
                if now - entry.InactiveSince >= PROMPT_SUPPRESSION_INACTIVE_GRACE then
                    state.SuppressedGamemodePrompts[optionId] = nil
                end
            end
        end
    end
end

local function isGamemodePromptSuppressed(option, card)
    if not option then
        return false
    end

    cleanupSuppressedGamemodePrompts()

    local optionId = getGamemodeOptionId(option)
    local entry = state.SuppressedGamemodePrompts[optionId]
    if not entry then
        return false
    end

    if card and entry.Card and card ~= entry.Card then
        state.SuppressedGamemodePrompts[optionId] = nil
        return false
    end

    if card and not entry.Card then
        entry.Card = card
    end

    return true
end

local function suppressGamemodePromptForArena(arenaInfo)
    local option = getArenaGamemodeOption(arenaInfo)
    if not option then
        return
    end

    local optionId = getGamemodeOptionId(option)
    state.SuppressedGamemodePrompts[optionId] = {
        Card = state.LastJoinedPromptCards[optionId],
        ExpiresAt = os.clock() + GAMEMODE_OPEN_WINDOW,
    }

    print(("[Potassium] Suppressing the current %s prompt after timeout."):format(option.Name))
end

local function runGamemodeActionLocked(label, callback)
    if state.GamemodeActionBusy then
        return false
    end

    state.GamemodeActionBusy = true
    local ok, result = xpcall(callback, debug.traceback)
    state.GamemodeActionBusy = false

    if not ok then
        warn(("[Potassium] %s failed: %s"):format(tostring(label), tostring(result)))
        return false
    end

    return result == true
end

local function rememberResumeGamemodeFromArena(arenaInfo)
    local option = getArenaGamemodeOption(arenaInfo)
    if not option or option.Kind ~= "Defense" then
        return false
    end

    state.PendingResumeGamemode = {
        Kind = option.Kind,
        Key = option.Key,
        Name = option.Name,
        GateRank = option.GateRank,
    }

    print(("[Potassium] Will resume %s after priority mode."):format(option.Name))
    return true
end

local function swapGamemodePriority(leftOption, rightOption)
    if not leftOption or not rightOption then
        return
    end

    local leftId = getGamemodeOptionId(leftOption)
    local rightId = getGamemodeOptionId(rightOption)
    local leftPriority = state.GamemodePriority[leftId] or 9999
    local rightPriority = state.GamemodePriority[rightId] or 9999

    state.GamemodePriority[leftId] = rightPriority
    state.GamemodePriority[rightId] = leftPriority
    queueSettingsSave()
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
    local contextKind, contextKey = getCombatVisibilityContext()
    if contextKind and contextKey then
        local rootInfo = arenaRootByKind[contextKind]
        local root = rootInfo and workspace:FindFirstChild(rootInfo.RootName)
        local arena = root and root:FindFirstChild(contextKey)
        if arena then
            return makeArenaInfo(rootInfo, arena)
        end
    end

    local bestInfo
    local bestScore = -math.huge

    for _, rootInfo in ipairs(arenaRoots) do
        if isArenaGuiActive(rootInfo.Kind) then
            local root = workspace:FindFirstChild(rootInfo.RootName)
            if root then
                for _, arena in ipairs(root:GetChildren()) do
                    local info = makeArenaInfo(rootInfo, arena)
                    local distance = getArenaDistanceFromCharacter(info.Enemies)
                    local score = 1000

                    if distance < math.huge then
                        score += math.max(0, 500 - math.min(distance, 500))
                    end

                    if getGamemodeSelection(rootInfo.Kind, arena.Name) then
                        score += 10
                    end

                    if score > bestScore then
                        bestInfo = info
                        bestScore = score
                    end
                end
            end
        end
    end

    return bestInfo
end

local function getCombatArenaByKindKey(kind, key)
    for _, rootInfo in ipairs(arenaRoots) do
        if rootInfo.Kind == kind then
            local root = workspace:FindFirstChild(rootInfo.RootName)
            local arena = root and root:FindFirstChild(key)

            if arena then
                return makeArenaInfo(rootInfo, arena)
            end
        end
    end

    return nil
end

local function isArenaMembershipActive(arenaInfo)
    if not arenaInfo or not arenaInfo.RootInfo or not arenaInfo.Arena then
        return false
    end

    local contextKind, contextKey = getCombatVisibilityContext()
    if contextKind and contextKey then
        return contextKind == arenaInfo.RootInfo.Kind and contextKey == arenaInfo.Arena.Name
    end

    if player:GetAttribute("VisibilityContext") ~= nil then
        return false
    end

    return isArenaGuiActive(arenaInfo.RootInfo.Kind)
        and getArenaDistanceFromCharacter(arenaInfo.Enemies) <= 750
end

local function getEnemyTargetPosition(enemy)
    return getModelPosition(enemy)
end

local function getArenaEnemySnapshot(enemies)
    local liveEnemies = {}
    local liveSet = {}
    local bestEnemy
    local bestHealth = -math.huge

    if not enemies then
        return bestEnemy, bestHealth, liveEnemies, liveSet
    end

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

local function pressGuiButton(button)
    if not button or not button:IsA("GuiButton") or not isGuiHierarchyVisible(button) then
        return false
    end

    local pressed = false

    pcall(function()
        button:Activate()
        pressed = true
    end)

    if typeof(firesignal) == "function" then
        pcall(function()
            firesignal(button.Activated)
            pressed = true
        end)
        pcall(function()
            firesignal(button.MouseButton1Click)
            pressed = true
        end)
        pcall(function()
            firesignal(button.MouseButton1Down)
            pressed = true
        end)
        pcall(function()
            firesignal(button.MouseButton1Up)
            pressed = true
        end)
    end

    return pressed
end

local function getArenaLeaveButton(kind)
    local guiName = arenaGuiByKind[kind]
    local gui = guiName and playerGui:FindFirstChild(guiName)
    local main = gui and gui:FindFirstChild("Main")
    local leaveButton = main and main:FindFirstChild("Leave")

    if not isGuiHierarchyVisible(leaveButton) then
        return nil, guiName
    end

    return leaveButton, guiName
end

local function leaveActiveCombatArena(Library, arenaInfo, reason)
    if not arenaInfo then
        return
    end

    local kind = arenaInfo.RootInfo and arenaInfo.RootInfo.Kind
    local leaveButton, guiName = getArenaLeaveButton(kind)

    warn(("[Potassium] Leaving %s (%s) via %s.Main.Leave."):format(arenaInfo.Key, reason or "requested", tostring(guiName)))

    if pressGuiButton(leaveButton) then
        print(("[Potassium] Pressed %s.Main.Leave GUI button."):format(tostring(guiName)))
        local guiLeaveStarted = os.clock()
        repeat
            if not isArenaMembershipActive(arenaInfo) then
                return true
            end
            task.wait(0.05)
        until os.clock() - guiLeaveStarted >= 0.5
    end

    local bridgeName = arenaInfo.RootInfo.LeaveBridge
    local leaveBridge = Library and Library.getBridge(bridgeName)

    warn(("[Potassium] GUI leave did not change VisibilityContext. Falling back to %s."):format(tostring(bridgeName)))

    if leaveBridge then
        leaveBridge:Fire()
        return true
    else
        warn(("[Potassium] Could not find %s bridge."):format(bridgeName))
    end

    return false
end

local function waitForArenaToDisappear(arenaInfo, timeout)
    if not arenaInfo then
        task.wait(timeout or 0.5)
        return true
    end

    local started = os.clock()
    repeat
        if not isArenaMembershipActive(arenaInfo) then
            return true
        end
        task.wait(0.05)
    until os.clock() - started > (timeout or 2)

    return false
end

local function waitForArenaToBecomeActive(kind, key, timeout)
    local started = os.clock()

    repeat
        local contextKind, contextKey = getCombatVisibilityContext()
        if contextKind == kind and contextKey == key then
            return true
        end

        task.wait(0.1)
    until not state.Enabled or os.clock() - started > (timeout or 5)

    return false
end

local function leaveCombatArenaAndWait(Library, arenaInfo, reason, timeout, attempts)
    attempts = attempts or 2
    timeout = timeout or 2

    if not arenaInfo then
        return true
    end

    for attempt = 1, attempts do
        leaveActiveCombatArena(Library, arenaInfo, reason)

        if waitForArenaToDisappear(arenaInfo, timeout) then
            print(("[Potassium] Confirmed %s disappeared after leave."):format(arenaInfo.Key))
            return true
        end

        warn(("[Potassium] %s still exists after leave attempt %d/%d. Retrying."):format(arenaInfo.Key, attempt, attempts))
        task.wait(0.25)
    end

    return false
end

local function waitAfterLeavingTitanForPriority(arenaInfo)
    if arenaInfo
        and arenaInfo.RootInfo
        and arenaInfo.RootInfo.Kind == "Defense"
        and arenaInfo.Arena
        and arenaInfo.Arena.Name == "World4" then
        print(("[Potassium] Waiting %.1fs after leaving Titan before joining priority mode."):format(PRIORITY_JOIN_AFTER_TITAN_LEAVE_DELAY))
        task.wait(PRIORITY_JOIN_AFTER_TITAN_LEAVE_DELAY)
    end
end

local function getCombatMobTimeout(arenaInfo)
    return UNIVERSAL_COMBAT_TIMEOUT
end

local function isFireCityArena(arenaInfo)
    return arenaInfo
        and arenaInfo.RootInfo
        and arenaInfo.RootInfo.Kind == "Dungeon"
        and arenaInfo.Arena
        and arenaInfo.Arena.Name == "World9Dungeon"
end

local function isFireCityActuallyJoined(target)
    local contextKind, contextKey = getCombatVisibilityContext()
    if contextKind == "Dungeon" and contextKey == "World9Dungeon" then
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
    elseif payload.GamemodeType == "Defense" then
        return "Defense"
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

    local bridges = {
        "DungeonAnnouncement",
        "RaidAnnouncement",
        "TimeTrialAnnouncement",
        "DefenseAnnouncement",
    }

    local allReady = true

    for _, bridgeName in ipairs(bridges) do
        if not state.WatchedAvailabilityBridges[bridgeName] then
            local bridge = Library and Library.getBridge(bridgeName)
            if bridge then
                addConnection(bridge:Connect(function(payload)
                    if type(payload) == "table" and payload.NotifyKind == "GamemodeOpen" then
                        rememberOpenGamemode(payload)
                    end
                end))
                state.WatchedAvailabilityBridges[bridgeName] = true
                print(("[Potassium] Watching %s."):format(bridgeName))
            else
                allReady = false
                warn(("[Potassium] Could not watch %s yet."):format(bridgeName))
            end
        end
    end

    state.AvailabilityHooksReady = allReady

    if not allReady and state.Enabled then
        task.delay(2, function()
            setupGamemodeAvailabilityWatchers(Library)
        end)
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

    local gateRank = normalizeGateRank(gateState.Rank)
    local timeLeft = math.max(0, tonumber(gateState.TimeLeft) or 0)

    if gateState.IsOpen == true and gateRank then
        if state.GateOccurrenceRank ~= gateRank or now >= (state.GateOccurrenceClosesAt or 0) then
            state.ConsumedGateRank = nil
            state.ConsumedGateUntil = 0
        end

        state.GateOccurrenceRank = gateRank
        state.GateOccurrenceClosesAt = now + math.max(timeLeft, GAMEMODE_OPEN_WINDOW)

        if state.ConsumedGateRank == gateRank and now < (state.ConsumedGateUntil or 0) then
            state.AvailableGamemodes["Raid:World5"] = nil
            return
        end
    else
        state.GateOccurrenceRank = nil
        state.GateOccurrenceClosesAt = 0
        state.ConsumedGateRank = nil
        state.ConsumedGateUntil = 0
    end

    if gateState.IsOpen == true and isGateRankSelected(gateRank) then
        rememberOpenGamemode({
            NotifyKind = "GamemodeOpen",
            GamemodeType = "Raid",
            Key = "World5",
            Name = ("Gate Rank %s"):format(tostring(gateState.Rank or "?")),
            GateRank = gateRank,
            Rank = gateRank,
        })
    else
        state.AvailableGamemodes["Raid:World5"] = nil
    end
end

local function getNextJoinableGamemode()
    cleanAvailableGamemodes()

    for _, option in ipairs(getGamemodeOptionsByPriority()) do
        if isGamemodeOptionSelected(option)
            and getGamemodeSelection(option.Kind, option.Key)
            and not isGamemodePromptSuppressed(option) then
            if not isGateOption(option) then
                for key, entry in pairs(state.AvailableGamemodes) do
                    if entry.Kind == option.Kind
                        and payloadMatchesGamemodeOption(entry.Payload, option) then
                        return key, entry.Payload
                    end
                end
            end

            if option.Kind == "Raid" and option.Key ~= "World5" then
                return "RaidCreate:" .. option.Key, {
                    NotifyKind = "ManualStart",
                    GamemodeType = "Raid",
                    Key = option.Key,
                    Name = option.Name,
                    CreateFirst = true,
                }
            elseif option.Kind == "Defense" then
                return "DefenseStart:" .. option.Key, {
                    NotifyKind = "ManualStart",
                    GamemodeType = "Defense",
                    Key = option.Key,
                    Name = option.Name,
                    CreateFirst = true,
                }
            end
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

local function getDefenseWorldId(Library, defenseKey)
    local ok, defenseConfig = pcall(function()
        return Library and Library.getConfig("DefenseConfig")
    end)

    if ok and defenseConfig and type(defenseConfig.GetDefense) == "function" then
        local defense = defenseConfig:GetDefense(defenseKey)
        if defense and type(defense.WorldId) == "number" then
            return defense.WorldId
        end
    end

    local parsed = tostring(defenseKey):match("^World(%d+)$")
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

local function startOrJoinDefense(Library, payload)
    local bridge = Library and Library.getBridge("DefenseJoin")
    if not bridge then
        warn("[Potassium] Could not find DefenseJoin for defense start.")
        return false
    end

    local worldId = getDefenseWorldId(Library, payload.Key)
    if not requestWorldAndWait(Library, worldId) then
        warn(("[Potassium] Could not switch to world %s for defense %s."):format(tostring(worldId), tostring(payload.Key)))
        return false
    end

    if payload.CreateFirst == true then
        bridge:Fire("Create", payload.Key)
        print(("[Potassium] Starting defense %s via DefenseJoin Create."):format(tostring(payload.Key)))
        task.wait(RAID_CREATE_JOIN_DELAY)
    end

    bridge:Fire("Join", payload.Key)
    print(("[Potassium] Entering defense %s via DefenseJoin Join."):format(tostring(payload.Key)))
    return true
end

local function resumePendingGamemode(Library)
    local pending = state.PendingResumeGamemode
    if type(pending) ~= "table" then
        return false
    end

    if os.clock() - (state.LastResumeAttemptAt or 0) < 2 then
        return false
    end
    state.LastResumeAttemptAt = os.clock()

    if pending.Kind == "Defense" then
        print(("[Potassium] Resuming %s after priority mode."):format(tostring(pending.Name or pending.Key)))
        local ok = startOrJoinDefense(Library, {
            NotifyKind = "ManualResume",
            GamemodeType = "Defense",
            Key = pending.Key,
            Name = pending.Name,
            CreateFirst = true,
        })

        if ok and waitForArenaToBecomeActive(pending.Kind, pending.Key, 5) then
            state.PendingResumeGamemode = nil
            print(("[Potassium] Confirmed resumed %s via VisibilityContext."):format(tostring(pending.Name or pending.Key)))
            return true
        end

        warn(("[Potassium] Resume request for %s was not confirmed; keeping it pending."):format(tostring(pending.Name or pending.Key)))
        return false
    end

    return false
end

local function confirmAutomaticGateTeleport(option)
    if not isGateOption(option) then
        return true
    end

    local started = os.clock()
    print(("[Potassium] Gate Rank %s YES pressed. Waiting for the game's automatic teleport."):format(tostring(option.GateRank)))

    while state.Enabled
        and state.AutoDungeonRaidWanted
        and isGamemodeOptionSelected(option)
        and os.clock() - started <= GATE_JOIN_CONFIRM_TIMEOUT do
        local contextKind, contextKey = getCombatVisibilityContext()
        if contextKind == "Raid" and isWorldFiveGateKey(contextKey) then
            markGateOccurrenceConsumed(option)
            print(("[Potassium] Confirmed automatic Gate Rank %s teleport via VisibilityContext %s."):format(
                tostring(option.GateRank),
                tostring(contextKey)
            ))
            return true
        end

        task.wait(0.1)
    end

    local contextKind, contextKey = getCombatVisibilityContext()
    if contextKind == "Raid" and isWorldFiveGateKey(contextKey) then
        markGateOccurrenceConsumed(option)
        return true
    end

    warn(("[Potassium] Gate Rank %s automatic teleport was not confirmed within %ds."):format(
        tostring(option.GateRank),
        GATE_JOIN_CONFIRM_TIMEOUT
    ))
    return false
end

local function tryJoinGamemode(Library, payload)
    local kind = getGamemodeKind(payload)
    if not kind or not getGamemodeSelection(kind, payload.Key) then
        return false
    end

    if kind == "Raid" and payload.Key == "World5" and not isGateRankSelected(payload.GateRank or payload.Rank) then
        return false
    end

    if kind == "Raid" and payload.Key == "World5" then
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
    elseif kind == "Defense" then
        if startOrJoinDefense(Library, payload) then
            state.LastGamemodeJoinAt = os.clock()
            return true
        end

        return false
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
    return pressGuiButton(button)
end

local function isGateRaidArena(arenaInfo)
    return arenaInfo
        and arenaInfo.RootInfo
        and arenaInfo.RootInfo.Kind == "Raid"
        and arenaInfo.Arena
        and isWorldFiveGateKey(arenaInfo.Arena.Name)
end

local function isGateRaidContextActive()
    local contextKind, contextKey = getCombatVisibilityContext()
    return contextKind == "Raid" and isWorldFiveGateKey(contextKey)
end

local function clearGateCompletionState()
    state.LatestRaidState = nil
    state.LatestRaidStateAt = 0
    state.LatestRaidContextKey = nil
    state.GateCompletionReady = false
    state.GateCompletionAt = 0
end

local function ensureGateAutoArise(Library, arenaInfo)
    if arenaInfo and not isGateRaidArena(arenaInfo) then
        return false
    end

    if not isGateRaidContextActive() then
        return false
    end

    local raidGui = playerGui:FindFirstChild("RaidGui")
    local main = raidGui and raidGui:FindFirstChild("Main")
    local autoArise = main and main:FindFirstChild("AutoArise")
    local onButton = autoArise and autoArise:FindFirstChild("ON")
    local offButton = autoArise and autoArise:FindFirstChild("OFF")

    if not raidGui or not raidGui.Enabled or not autoArise or not autoArise.Visible then
        return false
    end

    if onButton and onButton:IsA("GuiObject") and onButton.Visible then
        return true
    end

    if not offButton or not offButton:IsA("GuiButton") or not offButton.Visible then
        return false
    end

    local now = os.clock()
    if now - (state.LastAutoAriseAttemptAt or 0) < GATE_AUTO_ARISE_RETRY_INTERVAL then
        return false
    end

    state.LastAutoAriseAttemptAt = now
    if fireGuiButton(offButton) then
        print("[Potassium] Enabled Gate Auto Arise through RaidGui.Main.AutoArise.OFF.")
        return true
    end

    local autoAriseBridge = Library and Library.getBridge("RaidAutoArise")
    if autoAriseBridge then
        autoAriseBridge:Fire(true)
        print("[Potassium] Enabled Gate Auto Arise through RaidAutoArise fallback.")
        return true
    end

    return false
end

local function setupRaidLifecycleWatchers(Library)
    if state.RaidLifecycleHooksReady then
        return
    end

    local allReady = true
    local raidStateBridge = Library and Library.getBridge("RaidState")
    local raidEndedBridge = Library and Library.getBridge("RaidEnded")

    if not state.WatchedRaidLifecycleBridges.RaidState then
        if raidStateBridge then
            addConnection(raidStateBridge:Connect(function(payload)
                if type(payload) ~= "table" then
                    return
                end

                local contextKind, contextKey = getCombatVisibilityContext()
                state.LatestRaidState = payload
                state.LatestRaidStateAt = os.clock()
                state.LatestRaidContextKey = contextKind == "Raid" and contextKey or nil

                if contextKind ~= "Raid" or not isWorldFiveGateKey(contextKey) then
                    return
                end

                local wave = tonumber(payload.Wave)
                local totalWaves = tonumber(payload.TotalWaves)
                local enemyCount = tonumber(payload.EnemyCount)
                local nextWaveDelay = tonumber(payload.TimeToNextWave) or 0
                local reachedFinalWave = wave
                    and wave >= GATE_FINAL_WAVE
                    and (not totalWaves or wave >= totalWaves)
                local finalWaveCleared = reachedFinalWave
                    and enemyCount
                    and enemyCount <= 0
                    and nextWaveDelay <= 0

                if finalWaveCleared and not state.GateCompletionReady then
                    state.GateCompletionReady = true
                    state.GateCompletionAt = os.clock()
                    print(('[Potassium] Gate complete: wave %d/%d has 0 enemies. Waiting for the normal return.'):format(
                        wave,
                        totalWaves or GATE_FINAL_WAVE
                    ))
                elseif wave and wave < GATE_FINAL_WAVE and state.GateCompletionReady then
                    state.GateCompletionReady = false
                    state.GateCompletionAt = 0
                end
            end))
            state.WatchedRaidLifecycleBridges.RaidState = true
            print("[Potassium] Watching RaidState for Gate wave 50/50 completion.")
        else
            allReady = false
        end
    end

    if not state.WatchedRaidLifecycleBridges.RaidEnded then
        if raidEndedBridge then
            addConnection(raidEndedBridge:Connect(function()
                if isWorldFiveGateKey(state.LatestRaidContextKey) or state.GateCompletionReady then
                    print("[Potassium] Gate RaidEnded received; normal routing can resume.")
                end
                clearGateCompletionState()
            end))
            state.WatchedRaidLifecycleBridges.RaidEnded = true
        else
            allReady = false
        end
    end

    state.RaidLifecycleHooksReady = allReady
    if not allReady and state.Enabled then
        task.delay(2, function()
            setupRaidLifecycleWatchers(Library)
        end)
    end
end

local function finishCompletedGate(Library, arenaInfo)
    return runGamemodeActionLocked("Gate wave 50 completion", function()
        if arenaInfo then
            return leaveCombatArenaAndWait(
                Library,
                arenaInfo,
                "Gate wave 50/50 complete",
                3,
                3
            )
        end

        local leaveButton = getArenaLeaveButton("Raid")
        pressGuiButton(leaveButton)

        if isGateRaidContextActive() then
            local raidLeave = Library and Library.getBridge("RaidLeave")
            if raidLeave then
                raidLeave:Fire()
            end
        end

        local started = os.clock()
        while state.Enabled and isGateRaidContextActive() and os.clock() - started < 3 do
            task.wait(0.1)
        end

        return not isGateRaidContextActive()
    end)
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

function joinFireCityDungeon(Library)
    local bridge = Library and Library.getBridge("DungeonJoin")
    local fired = false

    if pressVisibleFireCityYes and pressVisibleFireCityYes() then
        fired = true
    elseif tryGamemodeControllerJoin({
        NotifyKind = "GamemodeOpen",
        GamemodeType = "Dungeon",
        Key = "World9Dungeon",
        Name = "Fire City Dungeon",
    }) then
        fired = true
    elseif bridge then
        bridge:Fire("Join", "World9Dungeon")
        fired = true
    elseif fireRawBridgeName("DungeonJoin", "Join", "World9Dungeon") then
        fired = true
    end

    if fired then
        state.LastGamemodeJoinAt = os.clock()
        print("[Potassium] Fired Fire City Dungeon join remote: DungeonJoin Join World9Dungeon.")
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
    local addedCards = {}
    local ignoredNotifyChildren = {
        UIListLayout = true,
        HideLeft = true,
        HideRight = true,
        NotifyTemplate = true,
    }

    if not notifyRoot then
        return cards
    end

    local function addCard(card, payload)
        if not card or addedCards[card] or not card:IsA("GuiObject") or not card.Visible then
            return
        end

        local kind = getGamemodeKind(payload)
        local actions = card:FindFirstChild("Actions")
        local yes = actions and actions:FindFirstChild("YES")
        local description = card:FindFirstChild("Description")
        local descriptionText = description and description:IsA("TextLabel") and description.Text or ""
        local gateRank = parseGateRank(descriptionText)

        if kind and yes and yes:IsA("GuiButton") then
            if kind == "Raid" and payload.Key == "World5" and gateRank then
                payload.GateRank = gateRank
                payload.Rank = gateRank
            end

            addedCards[card] = true
            table.insert(cards, {
                Kind = kind,
                Payload = payload,
                Button = yes,
                Card = card,
                Description = descriptionText,
            })
        end
    end

    local directTimeTrialCards = {
        Notify_TimeTrial_Easy = "Easy",
        Notify_TimeTrial_Medium = "Medium",
    }

    for cardName, key in pairs(directTimeTrialCards) do
        addCard(notifyRoot:FindFirstChild(cardName), {
            NotifyKind = "GamemodeOpen",
            GamemodeType = "TimeTrial",
            Key = key,
        })
    end

    for _, card in ipairs(notifyRoot:GetChildren()) do
        if not ignoredNotifyChildren[card.Name] and card:IsA("GuiObject") and card.Visible then
            local gamemodeType, key = card.Name:match("^Notify_([^_]+)_(.+)$")
            addCard(card, {
                NotifyKind = "GamemodeOpen",
                GamemodeType = gamemodeType,
                Key = key,
            })
        end
    end

    return cards
end

pressVisibleFireCityYes = function()
    local now = os.clock()
    if now - (state.LastFireCityGuiScanAt or 0) < FIRE_CITY_GUI_SCAN_INTERVAL then
        return false
    end
    state.LastFireCityGuiScanAt = now

    local hud = playerGui:FindFirstChild("HUD")
    local main = hud and hud:FindFirstChild("Main")
    local notifyRoot = main and main:FindFirstChild("GamemodeNotify")
    local directCard = notifyRoot and notifyRoot:FindFirstChild("Notify_Dungeon_World9Dungeon")
    local directActions = directCard and directCard:FindFirstChild("Actions")
    local directYes = directActions and directActions:FindFirstChild("YES")
    local fireCityOption = getGamemodeOptionByKindKey("Dungeon", "World9Dungeon")

    if directCard
        and directYes
        and directYes:IsA("GuiButton")
        and isGuiHierarchyVisible(directCard)
        and isGuiHierarchyVisible(directYes)
        and not isGamemodePromptSuppressed(fireCityOption, directCard) then
        if fireGuiButton(directYes) then
            recordJoinedPrompt(fireCityOption, directCard)
            state.LastGamemodeJoinAt = os.clock()
            print("[Potassium] Pressed Notify_Dungeon_World9Dungeon.Actions.YES for Fire City Dungeon.")
            return true
        end
    end

    for _, cardInfo in ipairs(getVisibleGamemodeCards()) do
        if cardInfo.Kind == "Dungeon"
            and (cardInfo.Payload.Key == "World9Dungeon" or tostring(cardInfo.Description):lower():find("fire city", 1, true)) then
            if isGamemodePromptSuppressed(fireCityOption, cardInfo.Card) then
                continue
            end

            if fireGuiButton(cardInfo.Button) then
                recordJoinedPrompt(fireCityOption, cardInfo.Card)
                state.LastGamemodeJoinAt = os.clock()
                print("[Potassium] Pressed actual YES button for Fire City Dungeon.")
                return true
            end
        end
    end

    return false
end

local getExactGamemodeNotifyButton

local function isPriorityResumeArena(arenaInfo)
    return isFireCityArena(arenaInfo)
        or (
            arenaInfo
            and arenaInfo.RootInfo
            and arenaInfo.RootInfo.Kind == "TimeTrial"
            and arenaInfo.Arena
            and (arenaInfo.Arena.Name == "Easy" or arenaInfo.Arena.Name == "Medium")
        )
end

local function pressExactGamemodeNotifyYes(option)
    if not option or not isGamemodeOptionSelected(option) or not getGamemodeSelection(option.Kind, option.Key) then
        return false
    end

    local yesButton, cardName, card = getExactGamemodeNotifyButton(option)
    if not yesButton then
        return false
    end

    if isGamemodePromptSuppressed(option, card) then
        return false
    end

    if fireGuiButton(yesButton) then
        recordJoinedPrompt(option, card)
        state.LastGamemodeJoinAt = os.clock()
        print(("[Potassium] Pressed %s.Actions.YES."):format(cardName))

        if isGateOption(option) then
            return confirmAutomaticGateTeleport(option)
        end

        return true
    end

    return false
end

getExactGamemodeNotifyButton = function(option)
    if not option or not isGamemodeOptionSelected(option) or not getGamemodeSelection(option.Kind, option.Key) then
        return nil
    end

    local hud = playerGui:FindFirstChild("HUD")
    local main = hud and hud:FindFirstChild("Main")
    local notifyRoot = main and main:FindFirstChild("GamemodeNotify")
    local cardName = ("Notify_%s_%s"):format(option.Kind, option.Key)
    local card = notifyRoot and notifyRoot:FindFirstChild(cardName)
    local actions = card and card:FindFirstChild("Actions")
    local yesButton = actions and actions:FindFirstChild("YES")

    if not (card and yesButton and yesButton:IsA("GuiButton"))
        or not isGuiHierarchyVisible(card)
        or not isGuiHierarchyVisible(yesButton) then
        return nil
    end

    if option.Kind == "Raid" and option.Key == "World5" and option.GateRank then
        local description = card:FindFirstChild("Description")
        local descriptionText = description and description:IsA("TextLabel") and description.Text or ""
        local rank = parseGateRank(descriptionText)

        if rank ~= normalizeGateRank(option.GateRank) then
            return nil
        end
    end

    return yesButton, cardName, card
end

local function getExactSelectedGamemodeOption(maxPriorityExclusive)
    local now = os.clock()
    if now - (state.LastGamemodeGuiScanAt or 0) < GAMEMODE_GUI_SCAN_INTERVAL then
        return nil
    end
    state.LastGamemodeGuiScanAt = now

    for _, option in ipairs(getGamemodeOptionsByPriority()) do
        local priority = getGamemodePriority(option)
        if not maxPriorityExclusive or priority < maxPriorityExclusive then
            local yesButton, _, card = getExactGamemodeNotifyButton(option)
            if yesButton and not isGamemodePromptSuppressed(option, card) then
                return option
            end
        end
    end

    return nil
end

local function requiresPriorityJoinConfirmation(option)
    return option
        and (
            (option.Kind == "Dungeon" and option.Key == "World9Dungeon")
            or (
                option.Kind == "TimeTrial"
                and (option.Key == "Easy" or option.Key == "Medium")
            )
        )
end

local function confirmPriorityGamemodeJoin(option)
    local started = os.clock()
    local lastRetryAt = started

    while state.Enabled
        and state.AutoDungeonRaidWanted
        and os.clock() - started < PRIORITY_JOIN_CONFIRM_TIMEOUT do
        local contextKind, contextKey = getCombatVisibilityContext()
        if contextKind == option.Kind and contextKey == option.Key then
            print(("[Potassium] Confirmed priority join: %s:%s."):format(option.Kind, option.Key))
            return true
        end

        local now = os.clock()
        if now - lastRetryAt >= PRIORITY_JOIN_RETRY_INTERVAL then
            lastRetryAt = now
            local retryButton, cardName, card = getExactGamemodeNotifyButton(option)
            if retryButton and fireGuiButton(retryButton) then
                recordJoinedPrompt(option, card)
                state.LastGamemodeJoinAt = now
                print(("[Potassium] Re-pressed %s.Actions.YES while awaiting destination context."):format(tostring(cardName)))
            end
        end

        task.wait(0.1)
    end

    warn(("[Potassium] %s:%s did not become active within %ds after YES."):format(
        option.Kind,
        option.Key,
        PRIORITY_JOIN_CONFIRM_TIMEOUT
    ))
    return false
end

local function handleExactGamemodePrompt(Library, option)
    if not option then
        return false
    end

    return runGamemodeActionLocked(option.Name .. " prompt", function()
        local yesButton, cardName, card = getExactGamemodeNotifyButton(option)
        if not yesButton or isGamemodePromptSuppressed(option, card) then
            return false
        end

        local arenaInfo = getActiveCombatArena()
        if isGateRaidContextActive() or isGateRaidArena(arenaInfo) then
            return false
        end

        local optionPriority = getGamemodePriority(option)
        local currentPriority = arenaInfo and getArenaGamemodePriority(arenaInfo) or nil
        local sameArena = arenaInfo
            and arenaInfo.RootInfo.Kind == option.Kind
            and arenaInfo.Arena.Name == option.Key

        if sameArena or (currentPriority and optionPriority >= currentPriority) then
            return false
        end

        if arenaInfo then
            warn(("[Potassium] Higher priority %s appeared. Leaving %s to join it."):format(option.Name, arenaInfo.Key))
            if (option.Kind == "Dungeon" and option.Key == "World9Dungeon")
                or (option.Kind == "TimeTrial" and (option.Key == "Easy" or option.Key == "Medium")) then
                rememberResumeGamemodeFromArena(arenaInfo)
            end

            if not leaveCombatArenaAndWait(Library, arenaInfo, ("Higher priority %s available"):format(option.Name), 2, 3) then
                warn(("[Potassium] Could not confirm leaving %s; not pressing %s."):format(arenaInfo.Key, cardName))
                return false
            end

            waitAfterLeavingTitanForPriority(arenaInfo)
        end

        yesButton, cardName, card = getExactGamemodeNotifyButton(option)
        if not yesButton or isGamemodePromptSuppressed(option, card) then
            warn(("[Potassium] %s disappeared before the join could be pressed."):format(option.Name))
            return false
        end

        if fireGuiButton(yesButton) then
            recordJoinedPrompt(option, card)
            state.LastGamemodeJoinAt = os.clock()
            print(("[Potassium] Watcher pressed %s.Actions.YES."):format(tostring(cardName)))

            if isGateOption(option) then
                return confirmAutomaticGateTeleport(option)
            end

            if requiresPriorityJoinConfirmation(option) then
                return confirmPriorityGamemodeJoin(option)
            end

            return true
        end

        return false
    end)
end

local function pressExactSelectedGamemodeYes()
    local option = getExactSelectedGamemodeOption()
    if option and pressExactGamemodeNotifyYes(option) then
        if requiresPriorityJoinConfirmation(option) then
            return confirmPriorityGamemodeJoin(option)
        end

        return true
    end

    return false
end

local function runExactGamemodePromptWatcher(Library)
    local lastPressedAt = {}

    while state.Enabled and state.DungeonFarmRunning do
        for _, option in ipairs(getGamemodeOptionsByPriority()) do
            local yesButton, cardName, card = getExactGamemodeNotifyButton(option)
            local pressKey = cardName or getGamemodeOptionId(option)

            if yesButton
                and not isGamemodePromptSuppressed(option, card)
                and os.clock() - (lastPressedAt[pressKey] or 0) >= 1 then
                if handleExactGamemodePrompt(Library, option) then
                    lastPressedAt[pressKey] = os.clock()
                end
                break
            end
        end

        task.wait(0.1)
    end
end

local function pressVisibleGamemodeYes(Library)
    if pressExactSelectedGamemodeYes() then
        return true
    end

    if os.clock() - (state.LastGamemodeJoinAt or 0) < GAMEMODE_JOIN_COOLDOWN then
        return false
    end

    local cards = getVisibleGamemodeCards()
    table.sort(cards, function(left, right)
        return getPayloadGamemodePriority(left.Payload) < getPayloadGamemodePriority(right.Payload)
    end)

    for _, cardInfo in ipairs(cards) do
        local option = getGamemodeOptionForPayload(cardInfo.Payload)
        if state.SelectedArenaTypes[cardInfo.Kind] ~= false
            and getGamemodeSelection(cardInfo.Kind, cardInfo.Payload.Key)
            and option
            and not isGamemodePromptSuppressed(option, cardInfo.Card)
            and not (cardInfo.Kind == "Raid" and cardInfo.Payload.Key == "World5" and not isGateRankSelected(cardInfo.Payload.GateRank or cardInfo.Payload.Rank)) then
            if fireGuiButton(cardInfo.Button) then
                recordJoinedPrompt(option, cardInfo.Card)
                state.LastGamemodeJoinAt = os.clock()
                print(("[Potassium] Pressed YES for %s %s."):format(cardInfo.Kind, tostring(cardInfo.Payload.Key)))

                if isGateOption(option) then
                    return confirmAutomaticGateTeleport(option)
                end

                if requiresPriorityJoinConfirmation(option) then
                    return confirmPriorityGamemodeJoin(option)
                end

                return true
            end
        end
    end

    return false
end

local function handleArenaTimeout(Library, arenaInfo, reason)
    return runGamemodeActionLocked("arena timeout leave", function()
        local shouldResume = isPriorityResumeArena(arenaInfo)
        if shouldResume then
            suppressGamemodePromptForArena(arenaInfo)
        end

        local left = leaveCombatArenaAndWait(Library, arenaInfo, reason, shouldResume and 3 or 2, shouldResume and 3 or 2)
        if not left then
            warn(("[Potassium] %s is still active after timeout leave attempts."):format(arenaInfo.Key))
            return false
        end

        if shouldResume and state.PendingResumeGamemode then
            resumePendingGamemode(Library)
        end

        return true
    end)
end

local runDungeonRaidFarm

local function runDungeonRaidFarmCore()
    if state.DungeonFarmRunning then
        return
    end

    state.AutoDungeonRaidWanted = true
    state.DungeonFarmRunning = true

    local ok, Library = pcall(function()
        return require(ReplicatedStorage:WaitForChild("SimpleWorld"):WaitForChild("Library"))
    end)

    if not ok or not Library then
        warn("[Potassium] Could not load SimpleWorld Library for dungeon/raid farm.")
        state.DungeonFarmRunning = false
        if state.AutoDungeonRaidWanted and state.Enabled then
            task.delay(2, runDungeonRaidFarm)
        end
        return
    end

    setupGamemodeAvailabilityWatchers(Library)
    setupRaidLifecycleWatchers(Library)
    task.spawn(function()
        while state.Enabled and state.DungeonFarmRunning do
            local watcherOk, watcherError = xpcall(function()
                runExactGamemodePromptWatcher(Library)
            end, debug.traceback)

            if watcherOk or not state.DungeonFarmRunning then
                break
            end

            warn(("[Potassium] Exact prompt watcher failed: %s. Restarting."):format(tostring(watcherError)))
            task.wait(1)
        end
    end)

    local lastArenaKey
    local observedLiveSet = {}
    local lastKillAt = os.clock()
    local currentTarget
    local currentTargetHealth
    local lastArenaRoom
    local waitingForMobSpawn = false

    while state.Enabled and state.AutoDungeonRaidWanted do
        local arenaInfo = getActiveCombatArena()

        if not arenaInfo then
            local contextKind, contextKey = getCombatVisibilityContext()
            local gateContextActive = contextKind == "Raid" and isWorldFiveGateKey(contextKey)

            if gateContextActive then
                ensureGateAutoArise(Library)

                if state.GateCompletionReady
                    and os.clock() - (state.GateCompletionAt or 0) >= GATE_COMPLETION_RETURN_GRACE
                    and finishCompletedGate(Library, nil) then
                    print("[Potassium] Gate 50/50 cleared without an arena folder; resumed normal auto-join scanning.")
                    clearGateCompletionState()
                end

                currentTarget = nil
                currentTargetHealth = nil
                observedLiveSet = {}
                lastArenaKey = nil
                lastKillAt = os.clock()
                lastArenaRoom = nil
                waitingForMobSpawn = false
                hideAll()
                task.wait(0.25)
                continue
            end

            if contextKind and contextKey then
                currentTarget = nil
                currentTargetHealth = nil
                observedLiveSet = {}
                lastArenaKey = nil
                lastKillAt = os.clock()
                lastArenaRoom = nil
                waitingForMobSpawn = false
                hideAll()
                task.wait(0.25)
                continue
            end

            if state.GateCompletionReady and not (contextKind == "Raid" and isWorldFiveGateKey(contextKey)) then
                clearGateCompletionState()
            end

            currentTarget = nil
            currentTargetHealth = nil
            observedLiveSet = {}
            lastArenaKey = nil
            lastKillAt = os.clock()
            lastArenaRoom = nil
            waitingForMobSpawn = false
            pollRaidGateState()

            if state.GamemodeActionBusy then
                task.wait(0.1)
            elseif state.PendingResumeGamemode then
                runGamemodeActionLocked("resume pending mode", function()
                    return resumePendingGamemode(Library)
                end)
                task.wait(0.5)
            elseif runGamemodeActionLocked("visible gamemode prompt", function()
                return pressVisibleGamemodeYes(Library)
            end) then
                task.wait(1.25)
            else
                local openKey, payload = getNextJoinableGamemode()
                if payload then
                    state.AvailableGamemodes[openKey] = nil
                    runGamemodeActionLocked("manual gamemode join", function()
                        return tryJoinGamemode(Library, payload)
                    end)
                    task.wait(1.25)
                else
                    logAvailabilityWait()
                    task.wait(0.5)
                end
            end

            hideAll()
            continue
        end

        local currentArenaPriority = getArenaGamemodePriority(arenaInfo)
        local higherPriorityOption
        if not isGateRaidArena(arenaInfo) then
            higherPriorityOption = getExactSelectedGamemodeOption(currentArenaPriority)
        end
        if higherPriorityOption then
            handleExactGamemodePrompt(Library, higherPriorityOption)

            currentTarget = nil
            currentTargetHealth = nil
            observedLiveSet = {}
            lastArenaKey = nil
            lastKillAt = os.clock()
            lastArenaRoom = nil
            waitingForMobSpawn = false
            hideAll()
            task.wait(1.25)
            continue
        end

        if not getGamemodeSelection(arenaInfo.RootInfo.Kind, arenaInfo.Arena.Name) then
            hideAll()
            task.wait(0.25)
            continue
        end

        if isGateRaidArena(arenaInfo) then
            ensureGateAutoArise(Library, arenaInfo)

            if state.GateCompletionReady
                and os.clock() - (state.GateCompletionAt or 0) >= GATE_COMPLETION_RETURN_GRACE then
                local leftGate = finishCompletedGate(Library, arenaInfo)

                if leftGate then
                    print("[Potassium] Gate 50/50 cleared; resumed normal auto-join scanning.")
                    clearGateCompletionState()
                    currentTarget = nil
                    currentTargetHealth = nil
                    observedLiveSet = {}
                    lastArenaKey = nil
                    lastKillAt = os.clock()
                    lastArenaRoom = nil
                    waitingForMobSpawn = false
                    hideAll()
                    task.wait(0.5)
                    continue
                end
            end
        end

        if arenaInfo.Key ~= lastArenaKey then
            print(("[Potassium] Dungeon/Raid farm attached to %s."):format(arenaInfo.Key))
            if isGateRaidArena(arenaInfo) then
                print(("[Potassium] Gate session locked against priority preemption; the universal %ds live-mob timeout remains active."):format(UNIVERSAL_COMBAT_TIMEOUT))
            end
            currentTarget = nil
            currentTargetHealth = nil
            observedLiveSet = {}
            lastArenaKey = arenaInfo.Key
            lastKillAt = os.clock()
            lastArenaRoom = arenaInfo.Arena:GetAttribute("CurrentRoom")
            waitingForMobSpawn = false
        end

        local target, targetHealth, liveEnemies, liveSet = getArenaEnemySnapshot(arenaInfo.Enemies)
        if currentTarget and liveSet[currentTarget] then
            local stickyHealth = getEnemyHealth(currentTarget)
            target = currentTarget
            targetHealth = stickyHealth
        end

        local killedSomething = false
        local currentArenaRoom = arenaInfo.Arena:GetAttribute("CurrentRoom")
        if currentArenaRoom ~= nil and lastArenaRoom ~= nil and currentArenaRoom ~= lastArenaRoom then
            lastKillAt = os.clock()
            print(("[Potassium] Arena advanced from room %s to %s. Timeout reset."):format(tostring(lastArenaRoom), tostring(currentArenaRoom)))
        end
        lastArenaRoom = currentArenaRoom or lastArenaRoom

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
        local mobTimeout = getCombatMobTimeout(arenaInfo)

        if #liveEnemies == 0 then
            if not waitingForMobSpawn then
                waitingForMobSpawn = true
                lastKillAt = os.clock()
            end
        elseif waitingForMobSpawn then
            waitingForMobSpawn = false
            lastKillAt = os.clock()
            print(('[Potassium] Mob spawned; universal %ds kill timer started.'):format(mobTimeout))
        end

        if target and target ~= currentTarget then
            currentTarget = target
            currentTargetHealth = targetHealth
            print(("[Potassium] Dungeon/Raid target: %s (%s HP)."):format(target.Name, formatHealth(targetHealth)))
        elseif target and type(targetHealth) == "number" then
            currentTargetHealth = targetHealth
        end

        if isFireCityArena(arenaInfo) and target and not isFireCityActuallyJoined(target) then
            if os.clock() - lastKillAt > mobTimeout then
                handleArenaTimeout(Library, arenaInfo, ("Could not confirm Fire City join for %ds"):format(mobTimeout))
                currentTarget = nil
                currentTargetHealth = nil
                observedLiveSet = {}
                lastArenaKey = nil
                lastKillAt = os.clock()
                task.wait(1.25)
                continue
            end

            if not state.GamemodeActionBusy and os.clock() - (state.LastGamemodeJoinAt or 0) >= GAMEMODE_JOIN_COOLDOWN then
                runGamemodeActionLocked("retry Fire City join", function()
                    if pressVisibleFireCityYes() then
                        return true
                    end

                    return joinFireCityDungeon(Library)
                end)
            end

            hideAll()
            task.wait(0.5)
            continue
        end

        local timeoutLimit = #liveEnemies == 0 and WAVE_TRANSITION_TIMEOUT or mobTimeout

        if os.clock() - lastKillAt > timeoutLimit then
            handleArenaTimeout(Library, arenaInfo, ("No combat progress for %ds"):format(timeoutLimit))
            currentTarget = nil
            currentTargetHealth = nil
            observedLiveSet = {}
            lastArenaKey = nil
            lastKillAt = os.clock()
            waitingForMobSpawn = false
            task.wait(1.25)
            continue
        end

        if #liveEnemies == 0 then
            currentTarget = nil
            currentTargetHealth = nil
            hideAll()
            task.wait(0.35)
            continue
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
    if state.Enabled and state.AutoDungeonRaidWanted then
        warn("[Potassium] Dungeon/Raid farm loop exited while still wanted. Restarting.")
        task.delay(0.75, runDungeonRaidFarm)
    end
    print("[Potassium] Dungeon/Raid farm stopped.")
end

runDungeonRaidFarm = function()
    local ok, errorMessage = xpcall(runDungeonRaidFarmCore, debug.traceback)
    if ok then
        return
    end

    state.DungeonFarmRunning = false
    state.GamemodeActionBusy = false
    warn(("[Potassium] Dungeon/Raid farm crashed: %s"):format(tostring(errorMessage)))

    if state.Enabled and state.AutoDungeonRaidWanted then
        task.delay(1, runDungeonRaidFarm)
    end
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

    local function waitForSingleBossRespawn(location)
        print(("[Potassium] %s is down. Waiting for its next spawn."):format(location.Name))

        while state.Enabled
            and state.RouteRunning
            and state.SelectedLocations[location.Name] ~= false do
            local canResume, interrupted = waitForWorldRouteResume()
            if not canResume then
                return false
            elseif interrupted then
                return true
            end

            local enemy = findTargetEnemy(location, false)
            if enemy then
                local health, _, dead = getEnemyHealth(enemy)
                if not dead and type(health) == "number" and health > 0 then
                    print(("[Potassium] %s respawned. Resuming the route."):format(location.Name))
                    return false
                end
            end

            hideAll()
            task.wait(SINGLE_BOSS_RESPAWN_POLL_INTERVAL)
        end

        return false
    end

    local function runSelectedLocation(location, selectedCount)
        local canResume, interrupted = waitForWorldRouteResume()
        if not canResume then
            return false
        elseif interrupted then
            return true
        end

        local currentWorld
        pcall(function()
            currentWorld = WorldController:GetCurrentWorld()
        end)

        if currentWorld ~= location.World then
            print(("[Potassium] Switching to world %d for %s."):format(location.World, location.Name))
            requestChangeWorld:Fire(location.World)

            local started = os.clock()
            repeat
                if shouldPauseWorldRouteForAutoJoin() then
                    waitForWorldRouteResume()
                    return true
                end

                hideAll()
                task.wait(0.15)
                pcall(function()
                    currentWorld = WorldController:GetCurrentWorld()
                end)
            until currentWorld == location.World
                or os.clock() - started > WORLD_CHANGE_TIMEOUT
                or not state.Enabled
                or not state.RouteRunning

            task.wait(0.35)

            if currentWorld ~= location.World then
                warn(("[Potassium] World %d did not load for %s; skipping its coordinates."):format(location.World, location.Name))
                return false
            end
        end

        canResume, interrupted = waitForWorldRouteResume()
        if not canResume then
            return false
        elseif interrupted then
            return true
        end

        print(("[Potassium] Teleporting to %s."):format(location.Name))
        moveCharacterTo(location.Position)
        local targetDied, targetInterrupted = waitForTargetDeath(location)
        if targetInterrupted then
            return true
        end

        if targetDied and selectedCount <= 1 then
            return waitForSingleBossRespawn(location)
        end

        return false
    end

    while state.Enabled and state.RouteRunning do
        local ranAny = false
        local selectedCount = 0

        for _, location in ipairs(locations) do
            if state.SelectedLocations[location.Name] ~= false then
                selectedCount += 1
            end
        end

        for _, location in ipairs(locations) do
            if not state.Enabled or not state.RouteRunning then
                break
            end

            if state.SelectedLocations[location.Name] == false then
                continue
            end

            ranAny = true
            local interrupted
            repeat
                interrupted = runSelectedLocation(location, selectedCount)
            until not interrupted
                or not state.Enabled
                or not state.RouteRunning
                or state.SelectedLocations[location.Name] == false
        end

        if not ranAny then
            warn("[Potassium] No route locations are checked.")
            task.wait(0.5)
        else
            task.wait(WORLD_ROUTE_CYCLE_DELAY)
        end
    end

    state.RouteRunning = false
    state.RoutePausedForAutoJoin = false
    print("[Potassium] Location route stopped.")
end

local exchangeRuntime

local function warnAutoExchange(message)
    if os.clock() - (state.LastExchangeWarningAt or 0) < 5 then
        return
    end

    state.LastExchangeWarningAt = os.clock()
    warn(("[Potassium] Auto exchange: %s"):format(tostring(message)))
end

local function getExchangeRuntime()
    if exchangeRuntime
        and exchangeRuntime.Config
        and exchangeRuntime.Request
        and exchangeRuntime.GetData
        and exchangeRuntime.GetData.Parent then
        return exchangeRuntime
    end

    local ok, Library = pcall(function()
        return require(ReplicatedStorage:WaitForChild("SimpleWorld"):WaitForChild("Library"))
    end)

    if not ok or not Library then
        return nil, "SimpleWorld Library was not available"
    end

    local config = Library.getConfig("ExchangeConfig")
    local resources = Library.getConfig("ResourcesConfig")
    local request = Library.getBridge("ExchangeCraftRequest")
    local simpleWorld = ReplicatedStorage:FindFirstChild("SimpleWorld")
    local libraryFolder = simpleWorld and simpleWorld:FindFirstChild("Library")
    local network = libraryFolder and libraryFolder:FindFirstChild("Network")
    local functions = network and network:FindFirstChild("Functions")
    local getData = functions and functions:FindFirstChild("GetExchangeData")

    if not config or not resources or not request or not getData then
        return nil, "ExchangeConfig, ResourcesConfig, ExchangeCraftRequest, or GetExchangeData was not found"
    end

    exchangeRuntime = {
        Config = config,
        Resources = resources,
        Request = request,
        GetData = getData,
    }

    return exchangeRuntime
end

local function getRecipeSelection(category)
    return category == "Exchange" and state.SelectedExchangeRecipes or state.SelectedTokenRecipes
end

local function hasSelectedExchangeRecipes(selection)
    for _, enabled in pairs(selection) do
        if enabled == true then
            return true
        end
    end

    return false
end

local function countSelectedExchangeRecipes(recipes, selection)
    local count = 0
    for _, recipe in ipairs(recipes) do
        if selection[tostring(recipe.RecipeId or "")] == true then
            count += 1
        end
    end

    return count
end

local function getNextAffordableExchange(recipes, playerData, cursor, selection)
    local recipeCount = #recipes
    if recipeCount == 0 then
        return
    end

    local startIndex = math.clamp(math.floor(tonumber(cursor) or 1), 1, recipeCount)
    for offset = 0, recipeCount - 1 do
        local index = ((startIndex + offset - 1) % recipeCount) + 1
        local recipe = recipes[index]
        local sacrificeItemId = tostring(recipe.SacrificeItemId or "")
        local sacrificeAmount = math.max(1, math.floor(tonumber(recipe.SacrificeAmount) or 0))
        local available = math.max(0, math.floor(tonumber(playerData[sacrificeItemId]) or 0))
        local recipeId = tostring(recipe.RecipeId or "")

        if selection[recipeId] == true and available >= sacrificeAmount then
            return recipe, index, available, sacrificeAmount
        end
    end
end

local function processExchangeCategory(runtime, category, playerData)
    local recipes = runtime.Config:GetRecipesSorted(category)
    local selection = getRecipeSelection(category)
    local cursorField = category == "Exchange" and "ExchangeRecipeCursor" or "TokenRecipeCursor"
    local recipe, index, available, sacrificeAmount = getNextAffordableExchange(
        recipes,
        playerData,
        state[cursorField],
        selection
    )

    if not recipe then
        return false
    end

    local spendAmount
    local selectedCount = countSelectedExchangeRecipes(recipes, selection)
    if category == "Exchange" or selectedCount == 1 then
        spendAmount = math.floor(available / sacrificeAmount) * sacrificeAmount
    else
        -- Selected Token recipes share one Exchange Token balance. Rotate one
        -- craft at a time when several outputs are selected.
        spendAmount = sacrificeAmount
    end

    runtime.Request:Fire(tostring(recipe.RecipeId or ""), spendAmount)
    playerData[tostring(recipe.SacrificeItemId or "")] = math.max(0, available - spendAmount)
    state[cursorField] = (index % #recipes) + 1
    return true
end

local function runAutoExchangeLoop()
    if state.AutoExchangeLoopRunning then
        return
    end

    state.AutoExchangeLoopRunning = true

    while state.Enabled do
        local exchangeSelected = hasSelectedExchangeRecipes(state.SelectedExchangeRecipes)
        local tokensSelected = hasSelectedExchangeRecipes(state.SelectedTokenRecipes)

        if exchangeSelected or tokensSelected then
            local runtime, runtimeError = getExchangeRuntime()
            if not runtime then
                warnAutoExchange(runtimeError)
            else
                local ok, playerData = pcall(function()
                    return runtime.GetData:InvokeServer()
                end)

                if not ok or type(playerData) ~= "table" then
                    warnAutoExchange("GetExchangeData did not return player data")
                else
                    if exchangeSelected then
                        processExchangeCategory(runtime, "Exchange", playerData)
                    end

                    if tokensSelected then
                        processExchangeCategory(runtime, "Token", playerData)
                    end
                end
            end
        end

        task.wait(AUTO_EXCHANGE_INTERVAL)
    end

    state.AutoExchangeLoopRunning = false
end

local function getExchangeResourceName(runtime, itemId)
    local items = runtime.Resources and runtime.Resources.Items
    local item = items and items[itemId]
    return item and tostring(item.Name or itemId) or tostring(itemId)
end

local function buildExchangeGui()
    local existing = playerGui:FindFirstChild("PotassiumExchangeGui")
    if existing then
        existing:Destroy()
    end

    local runtime, runtimeError = getExchangeRuntime()
    if not runtime then
        warnAutoExchange(runtimeError)
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "PotassiumExchangeGui"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 101
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.fromOffset(336, 500)
    frame.Position = UDim2.fromOffset(state.ExchangeGuiPosition.X, state.ExchangeGuiPosition.Y)
    frame.BackgroundColor3 = Color3.fromRGB(22, 24, 31)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = gui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 8)
    frameCorner.Parent = frame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(139, 104, 42)
    frameStroke.Thickness = 1
    frameStroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -50, 0, 34)
    title.Position = UDim2.fromOffset(12, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "Auto Exchange"
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

    local exchangeTab = Instance.new("TextButton")
    exchangeTab.Name = "ExchangeTab"
    exchangeTab.Size = UDim2.fromOffset(153, 28)
    exchangeTab.Position = UDim2.fromOffset(0, 0)
    exchangeTab.BackgroundColor3 = Color3.fromRGB(76, 105, 152)
    exchangeTab.BorderSizePixel = 0
    exchangeTab.Font = Enum.Font.GothamBold
    exchangeTab.Text = "EXCHANGE"
    exchangeTab.TextColor3 = Color3.fromRGB(245, 247, 255)
    exchangeTab.TextSize = 12
    exchangeTab.Parent = content

    local exchangeTabCorner = Instance.new("UICorner")
    exchangeTabCorner.CornerRadius = UDim.new(0, 6)
    exchangeTabCorner.Parent = exchangeTab

    local tokenTab = Instance.new("TextButton")
    tokenTab.Name = "TokensTab"
    tokenTab.Size = UDim2.fromOffset(153, 28)
    tokenTab.Position = UDim2.fromOffset(159, 0)
    tokenTab.BackgroundColor3 = Color3.fromRGB(41, 47, 62)
    tokenTab.BorderSizePixel = 0
    tokenTab.Font = Enum.Font.GothamBold
    tokenTab.Text = "TOKENS"
    tokenTab.TextColor3 = Color3.fromRGB(245, 247, 255)
    tokenTab.TextSize = 12
    tokenTab.Parent = content

    local tokenTabCorner = Instance.new("UICorner")
    tokenTabCorner.CornerRadius = UDim.new(0, 6)
    tokenTabCorner.Parent = tokenTab

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, 0, 0, 20)
    status.Position = UDim2.fromOffset(0, 34)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextColor3 = Color3.fromRGB(190, 205, 235)
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = content

    local allButton = Instance.new("TextButton")
    allButton.Name = "SelectAll"
    allButton.Size = UDim2.new(1, 0, 0, 28)
    allButton.Position = UDim2.fromOffset(0, 58)
    allButton.BackgroundColor3 = Color3.fromRGB(41, 47, 62)
    allButton.BorderSizePixel = 0
    allButton.Text = ""
    allButton.Parent = content

    local allCorner = Instance.new("UICorner")
    allCorner.CornerRadius = UDim.new(0, 6)
    allCorner.Parent = allButton

    local allBox = Instance.new("TextLabel")
    allBox.Name = "Check"
    allBox.Size = UDim2.fromOffset(32, 20)
    allBox.Position = UDim2.fromOffset(4, 4)
    allBox.BackgroundColor3 = Color3.fromRGB(18, 21, 29)
    allBox.BorderSizePixel = 0
    allBox.Font = Enum.Font.GothamBold
    allBox.TextColor3 = Color3.fromRGB(120, 220, 145)
    allBox.TextSize = 10
    allBox.Parent = allButton

    local allBoxCorner = Instance.new("UICorner")
    allBoxCorner.CornerRadius = UDim.new(0, 5)
    allBoxCorner.Parent = allBox

    local allLabel = Instance.new("TextLabel")
    allLabel.Name = "Label"
    allLabel.Size = UDim2.new(1, -46, 1, 0)
    allLabel.Position = UDim2.fromOffset(44, 0)
    allLabel.BackgroundTransparency = 1
    allLabel.Font = Enum.Font.GothamSemibold
    allLabel.TextColor3 = Color3.fromRGB(245, 247, 255)
    allLabel.TextSize = 12
    allLabel.TextXAlignment = Enum.TextXAlignment.Left
    allLabel.Parent = allButton

    local list = Instance.new("ScrollingFrame")
    list.Name = "RecipeList"
    list.Size = UDim2.new(1, 0, 0, 360)
    list.Position = UDim2.fromOffset(0, 92)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 5
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.Parent = content

    local rows = {
        Exchange = {},
        Token = {},
    }

    local function makeRecipeRow(category, recipe)
        local recipeId = tostring(recipe.RecipeId or "")
        local selection = getRecipeSelection(category)
        local button = Instance.new("TextButton")
        button.Name = recipeId:gsub("%W+", "") .. "Toggle"
        button.Size = UDim2.new(1, -7, 0, 26)
        button.BackgroundColor3 = Color3.fromRGB(41, 47, 62)
        button.BorderSizePixel = 0
        button.Text = ""
        button.Visible = false
        button.Parent = list

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button

        local box = Instance.new("TextLabel")
        box.Name = "Check"
        box.Size = UDim2.fromOffset(28, 20)
        box.Position = UDim2.fromOffset(4, 3)
        box.BackgroundColor3 = Color3.fromRGB(18, 21, 29)
        box.BorderSizePixel = 0
        box.Font = Enum.Font.GothamBold
        box.TextColor3 = Color3.fromRGB(120, 220, 145)
        box.TextSize = 10
        box.Parent = button

        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 5)
        boxCorner.Parent = box

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, -42, 1, 0)
        label.Position = UDim2.fromOffset(38, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.Text = ("%s -> %s"):format(
            getExchangeResourceName(runtime, tostring(recipe.SacrificeItemId or "")),
            getExchangeResourceName(runtime, tostring(recipe.RewardItemId or ""))
        )
        label.TextColor3 = Color3.fromRGB(245, 247, 255)
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = button

        button.MouseButton1Click:Connect(function()
            selection[recipeId] = not (selection[recipeId] == true)
            rows.Refresh()
            queueSettingsSave()
        end)

        rows[category][recipeId] = {
            Button = button,
            Box = box,
            Recipe = recipe,
        }
    end

    for _, category in ipairs({ "Exchange", "Token" }) do
        for _, recipe in ipairs(runtime.Config:GetRecipesSorted(category)) do
            makeRecipeRow(category, recipe)
        end
    end

    function rows.Refresh()
        local category = state.ExchangeCategoryFilter == "Token" and "Token" or "Exchange"
        local selection = getRecipeSelection(category)
        local recipes = runtime.Config:GetRecipesSorted(category)
        local selectedCount = countSelectedExchangeRecipes(recipes, selection)
        local y = 0

        for rowCategory, categoryRows in pairs(rows) do
            if type(categoryRows) == "table" then
                for _, row in pairs(categoryRows) do
                    row.Button.Visible = false
                end
            end
        end

        for _, recipe in ipairs(recipes) do
            local recipeId = tostring(recipe.RecipeId or "")
            local row = rows[category][recipeId]
            local selected = selection[recipeId] == true
            if row then
                row.Button.Visible = true
                row.Button.Position = UDim2.fromOffset(0, y)
                row.Button.BackgroundColor3 = selected and Color3.fromRGB(38, 88, 61) or Color3.fromRGB(41, 47, 62)
                row.Box.Text = selected and "ON" or ""
                y += 30
            end
        end

        list.CanvasSize = UDim2.fromOffset(0, y)
        status.Text = ("%d/%d selected | %.1fs"):format(selectedCount, #recipes, AUTO_EXCHANGE_INTERVAL)
        allBox.Text = selectedCount == #recipes and "ON" or (selectedCount > 0 and "-" or "")
        allLabel.Text = category == "Exchange" and "All Exchange recipes" or "All Token recipes"
        allButton.BackgroundColor3 = selectedCount > 0 and Color3.fromRGB(38, 58, 88) or Color3.fromRGB(41, 47, 62)
        exchangeTab.BackgroundColor3 = category == "Exchange" and Color3.fromRGB(76, 105, 152) or Color3.fromRGB(41, 47, 62)
        tokenTab.BackgroundColor3 = category == "Token" and Color3.fromRGB(76, 105, 152) or Color3.fromRGB(41, 47, 62)
    end

    exchangeTab.MouseButton1Click:Connect(function()
        state.ExchangeCategoryFilter = "Exchange"
        list.CanvasPosition = Vector2.zero
        rows.Refresh()
        queueSettingsSave()
    end)

    tokenTab.MouseButton1Click:Connect(function()
        state.ExchangeCategoryFilter = "Token"
        list.CanvasPosition = Vector2.zero
        rows.Refresh()
        queueSettingsSave()
    end)

    allButton.MouseButton1Click:Connect(function()
        local category = state.ExchangeCategoryFilter == "Token" and "Token" or "Exchange"
        local selection = getRecipeSelection(category)
        local recipes = runtime.Config:GetRecipesSorted(category)
        local enable = countSelectedExchangeRecipes(recipes, selection) < #recipes

        for _, recipe in ipairs(recipes) do
            selection[tostring(recipe.RecipeId or "")] = enable
        end

        rows.Refresh()
        queueSettingsSave()
    end)

    local minimized = state.ExchangeGuiMinimized == true
    content.Visible = not minimized
    frame.Size = minimized and UDim2.fromOffset(336, 34) or UDim2.fromOffset(336, 500)
    minimize.Text = minimized and "+" or "-"

    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        state.ExchangeGuiMinimized = minimized
        content.Visible = not minimized
        frame.Size = minimized and UDim2.fromOffset(336, 34) or UDim2.fromOffset(336, 500)
        minimize.Text = minimized and "+" or "-"
        queueSettingsSave()
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
                    state.ExchangeGuiPosition.X = frame.Position.X.Offset
                    state.ExchangeGuiPosition.Y = frame.Position.Y.Offset
                    queueSettingsSave()
                end
            end)
        end
    end)

    addConnection(UserInputService.InputChanged:Connect(function(input)
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
    end))

    rows.Refresh()
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
    frame.Position = UDim2.fromOffset(state.RouteGuiPosition.X, state.RouteGuiPosition.Y)
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
        Defense = true,
    }
    state.ModeFilter = filterNames[state.ModeFilter] and state.ModeFilter or "All"
    local activeModeFilter = state.ModeFilter
    local filterClicksEnabledAt = os.clock() + 0.4
    local rowActionAt = 0
    local startButton
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
        elseif activeModeFilter == "Defense" then
            return option.Kind == "Defense"
        end

        return true
    end

    local function getFilteredPriorityOptions()
        local options = {}

        for _, option in ipairs(getGamemodeOptionsByPriority()) do
            if isOptionVisibleForFilter(option) then
                table.insert(options, option)
            end
        end

        return options
    end

    local function moveGamemodePriority(option, direction)
        local options = getFilteredPriorityOptions()

        for index, visibleOption in ipairs(options) do
            if getGamemodeOptionId(visibleOption) == getGamemodeOptionId(option) then
                local swapWith = options[index + direction]
                if swapWith then
                    swapGamemodePriority(option, swapWith)
                end
                return
            end
        end
    end

    local function updateStatus()
        local selected = 0
        for _, location in ipairs(locations) do
            if state.SelectedLocations[location.Name] ~= false then
                selected += 1
            end
        end

        local routeStatus = state.RoutePausedForAutoJoin and "PAUSED"
            or (state.RouteRunning and "RUNNING" or "READY")
        status.Text = ("Route %s | Raid %s | %d/%d"):format(
            routeStatus,
            state.AutoDungeonRaidWanted and "ON" or "OFF",
            selected,
            #locations
        )

        if startButton then
            startButton.Text = state.RouteRunning and "Stop Route" or "Start Route"
            startButton.BackgroundColor3 = state.RouteRunning and Color3.fromRGB(130, 68, 58) or Color3.fromRGB(54, 82, 125)
        end

        if dungeonButton then
            dungeonButton.Text = state.AutoDungeonRaidWanted and "Stop Dungeon/Raid" or "Auto Dungeon/Raid"
            dungeonButton.BackgroundColor3 = state.AutoDungeonRaidWanted and Color3.fromRGB(130, 68, 58) or Color3.fromRGB(54, 82, 125)
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
            queueSettingsSave()
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
    arenaTitle.Text = "Auto Join Priority"
    arenaTitle.TextColor3 = Color3.fromRGB(190, 205, 235)
    arenaTitle.TextSize = 12
    arenaTitle.TextXAlignment = Enum.TextXAlignment.Left
    arenaTitle.Parent = content

    local function refreshArenaRows()
        local y = 0
        local visibleOptions = getFilteredPriorityOptions()

        for _, option in ipairs(gamemodeOptions) do
            local row = arenaRows[getGamemodeOptionId(option)]
            if not row then
                continue
            end

            local enabled = isGamemodeOptionSelected(row.option)
            row.box.Text = enabled and "ON" or ""
            row.button.BackgroundColor3 = enabled and Color3.fromRGB(38, 58, 88) or Color3.fromRGB(41, 47, 62)
            row.button.Visible = false
        end

        for index, option in ipairs(visibleOptions) do
            local row = arenaRows[getGamemodeOptionId(option)]
            if row then
                row.priority.Text = tostring(getGamemodePriority(option))
                row.up.TextColor3 = index == 1 and Color3.fromRGB(105, 115, 135) or Color3.fromRGB(245, 247, 255)
                row.down.TextColor3 = index == #visibleOptions and Color3.fromRGB(105, 115, 135) or Color3.fromRGB(245, 247, 255)
                row.button.Visible = true
                row.button.Position = UDim2.fromOffset(0, y)
                y += 30
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
            queueSettingsSave()
        end)

        filterButtons[name] = button
    end

    makeFilterButton("All", "All", 0, 308, 34)
    makeFilterButton("Dungeon", "Dgn", 38, 308, 42)
    makeFilterButton("Raid", "Raid", 84, 308, 42)
    makeFilterButton("Gate", "Gate", 130, 308, 42)
    makeFilterButton("TimeTrial", "Trial", 176, 308, 50)
    makeFilterButton("Defense", "Def", 230, 308, 36)

    modeList = Instance.new("ScrollingFrame")
    modeList.Name = "ModeList"
    modeList.Size = UDim2.new(1, 0, 0, 114)
    modeList.Position = UDim2.fromOffset(0, 342)
    modeList.BackgroundTransparency = 1
    modeList.BorderSizePixel = 0
    modeList.ScrollBarThickness = 4
    modeList.CanvasSize = UDim2.fromOffset(0, 0)
    modeList.Parent = content

    local function connectGuiButton(guiButton, callback)
        local lastClickAt = 0

        guiButton.MouseButton1Click:Connect(function()
            lastClickAt = os.clock()
            callback()
        end)

        guiButton.Activated:Connect(function()
            if os.clock() - lastClickAt < 0.08 then
                return
            end

            callback()
        end)
    end

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
        box.Size = UDim2.fromOffset(28, 20)
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

        local priority = Instance.new("TextLabel")
        priority.Name = "Priority"
        priority.Size = UDim2.fromOffset(22, 20)
        priority.Position = UDim2.fromOffset(36, 2)
        priority.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
        priority.BorderSizePixel = 0
        priority.Font = Enum.Font.GothamBold
        priority.TextColor3 = Color3.fromRGB(165, 190, 230)
        priority.TextSize = 11
        priority.Parent = button

        local priorityCorner = Instance.new("UICorner")
        priorityCorner.CornerRadius = UDim.new(0, 5)
        priorityCorner.Parent = priority

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, -120, 1, 0)
        label.Position = UDim2.fromOffset(64, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.Text = option.Name
        label.TextColor3 = Color3.fromRGB(245, 247, 255)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = button

        local up = Instance.new("TextButton")
        up.Name = "PriorityUp"
        up.Size = UDim2.fromOffset(22, 20)
        up.Position = UDim2.new(1, -50, 0, 2)
        up.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
        up.BorderSizePixel = 0
        up.Font = Enum.Font.GothamBold
        up.Text = "^"
        up.TextColor3 = Color3.fromRGB(245, 247, 255)
        up.TextSize = 12
        up.Parent = button

        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 5)
        upCorner.Parent = up

        local down = Instance.new("TextButton")
        down.Name = "PriorityDown"
        down.Size = UDim2.fromOffset(22, 20)
        down.Position = UDim2.new(1, -24, 0, 2)
        down.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
        down.BorderSizePixel = 0
        down.Font = Enum.Font.GothamBold
        down.Text = "v"
        down.TextColor3 = Color3.fromRGB(245, 247, 255)
        down.TextSize = 12
        down.Parent = button

        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 5)
        downCorner.Parent = down

        connectGuiButton(button, function()
            if os.clock() - rowActionAt < 0.1 then
                return
            end

            setGamemodeOptionSelection(option, not isGamemodeOptionSelected(option))
            refreshArenaRows()
            updateStatus()
        end)

        connectGuiButton(up, function()
            rowActionAt = os.clock()
            moveGamemodePriority(option, -1)
            refreshArenaRows()
        end)

        connectGuiButton(down, function()
            rowActionAt = os.clock()
            moveGamemodePriority(option, 1)
            refreshArenaRows()
        end)

        arenaRows[getGamemodeOptionId(option)] = {
            option = option,
            button = button,
            box = box,
            priority = priority,
            up = up,
            down = down,
        }
    end

    for _, option in ipairs(gamemodeOptions) do
        makeArenaRow(option)
    end

    startButton = Instance.new("TextButton")
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
            queueSettingsSave()
            return
        end

        startButton.Text = "Stop Route"
        task.spawn(function()
            runLocationRoute()
            startButton.Text = "Start Route"
            updateStatus()
        end)
        updateStatus()
        queueSettingsSave()
    end)

    dungeonButton.MouseButton1Click:Connect(function()
        local now = os.clock()
        if now - (state.LastDungeonToggleAt or 0) < 0.5 then
            return
        end
        state.LastDungeonToggleAt = now

        if state.AutoDungeonRaidWanted then
            state.AutoDungeonRaidWanted = false
            state.DungeonFarmRunning = false
            updateStatus()
            queueSettingsSave()
            return
        end

        state.AutoDungeonRaidWanted = true
        task.spawn(function()
            runDungeonRaidFarm()
            updateStatus()
        end)
        updateStatus()
        queueSettingsSave()
    end)

    local minimized = state.RouteGuiMinimized == true
    content.Visible = not minimized
    frame.Size = minimized and UDim2.fromOffset(292, 34) or UDim2.fromOffset(292, GUI_FULL_HEIGHT)
    minimize.Text = minimized and "+" or "-"

    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        state.RouteGuiMinimized = minimized
        content.Visible = not minimized
        frame.Size = minimized and UDim2.fromOffset(292, 34) or UDim2.fromOffset(292, GUI_FULL_HEIGHT)
        minimize.Text = minimized and "+" or "-"
        queueSettingsSave()
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
                    state.RouteGuiPosition.X = frame.Position.X.Offset
                    state.RouteGuiPosition.Y = frame.Position.Y.Offset
                    queueSettingsSave()
                end
            end)
        end
    end)

    addConnection(UserInputService.InputChanged:Connect(function(input)
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
    end))

    addConnection(gui.Destroying:Connect(function()
        state.RouteRunning = false
        state.DungeonFarmRunning = false
        state.AutoDungeonRaidWanted = false
    end))

    refreshArenaRows()
    updateStatus()
    task.spawn(function()
        while state.Enabled and gui.Parent do
            updateStatus()
            task.wait(0.25)
        end
    end)
end

buildRouteGui()
buildExchangeGui()
task.spawn(runAutoExchangeLoop)

if AUTO_START_ROUTE or restartRouteAfterReload then
    task.spawn(runLocationRoute)
end

if restartDungeonFarmAfterReload then
    task.spawn(runDungeonRaidFarm)
end

queueSettingsSave()
print("[Potassium] Loading hider and route GUI enabled.")
