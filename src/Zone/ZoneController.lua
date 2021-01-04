-- LOCAL
local ZoneController = {}
local Maid = require(script.Parent.Maid)
local RotatedRegion3 = require(script.Parent.RotatedRegion3)
local Enum_ = require(script.Parent.Enum)
local enum = Enum_.enums
local players = game:GetService("Players")
local activeZones = {}
local activeZonesTotalVolume = 0
local charactersTotalVolume = 0
local activeTriggers = {}
local registeredZones = {}
local activeParts = {}
local activePartToZone = {}
local playerHRPs = {}
local activeConnections = 0
local runService = game:GetService("RunService")
local heartbeat = runService.Heartbeat
local heartbeatConnection
local localPlayer = runService:IsClient() and players.LocalPlayer



-- LOCAL FUNCTIONS
local function dictLength(dictionary)
    local count = 0
    for _, _ in pairs(dictionary) do
        count += 1
    end
    return count
end



-- CHARACTER HANDLER
-- This enables character data (volume, HumanoidRootParts, etc) to be handled on
-- an event-basis, instead of being retrieved every interval
local function updateCharactersTotalVolume()
    charactersTotalVolume = 0
    playerHRPs = {}
    for _, plr in pairs(players:GetPlayers()) do
        local charRegion = ZoneController.getCharacterRegion(plr)
        if charRegion then
            local rSize = charRegion.Size
            local charVolume = rSize.X*rSize.Y*rSize.Z
            charactersTotalVolume += charVolume
            table.insert(playerHRPs, plr.Character.HumanoidRootPart)
        end
    end
end
players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        local humanoid = char:WaitForChild("Humanoid", 3)
        if humanoid then
            updateCharactersTotalVolume()
            for _, valueInstance in pairs(humanoid:GetChildren()) do
                if valueInstance:IsA("NumberValue") then
                    valueInstance.Changed:Connect(function()
                        updateCharactersTotalVolume()
                    end)
                end
            end
        end
    end)
end)
players.PlayerRemoving:Connect(function(plr)
    updateCharactersTotalVolume()
end)



-- PRIVATE FUNCTIONS
function ZoneController._registerZone(zoneToRegister)
   registeredZones[zoneToRegister] = true
end

function ZoneController._deregisterZone(zoneToRegister)
    registeredZones[zoneToRegister] = nil
end

function ZoneController._registerConnection(registeredZone, registeredTriggerType)
    local originalItems = dictLength(registeredZone.activeTriggers)
    activeConnections += 1
    if originalItems == 0 then
        activeZones[registeredZone] = true
        local activeMaid = registeredZone._maid:give(Maid.new())
        registeredZone._activeMaid = activeMaid
        activeMaid:give(registeredZone.updated:Connect(function()
            ZoneController._updateActiveParts()
        end))
        ZoneController._updateActiveParts()
    end
    local currentTriggerCount = activeTriggers[registeredTriggerType]
    activeTriggers[registeredTriggerType] = (currentTriggerCount and currentTriggerCount+1) or 1
    registeredZone.activeTriggers[registeredTriggerType] = true
    ZoneController.formHeartbeat()
end

function ZoneController.formHeartbeat()
    if heartbeatConnection then return end
    -- This will only ever connect once per server
    -- This means instead of initiating a loop per-zone we can handle everything within
    -- a singular connection. This is particularly beneficial for player-orinetated
    -- raycasting, where a raycast only needs to be cast once per interval, as apposed
    -- to every zone per interval
    -- I utilise heartbeat with os.clock() to provide precision (where needed) and flexibility
    local nextCheck = 0
    local triggerTypeActions = {
        ["player"] = function()
            local actions = {}
            local function fillActionTable(zone, plr)
                local zoneTable = actions[zone]
                if not zoneTable then
                    zoneTable = {}
                    actions[zone] = zoneTable
                end
                table.insert(zoneTable, plr)
            end
            print(charactersTotalVolume, activeZonesTotalVolume, charactersTotalVolume < activeZonesTotalVolume)
            if charactersTotalVolume < activeZonesTotalVolume then
                -- If the volume of all *characters* within the server is *less than* the total
                -- volume of all active zones (i.e. zones which listen for .playerEntered)
                -- then it's more efficient cast regions and rays within each character and
                -- then determine the zones they belong to
                for _, plr in pairs(players:GetPlayers()) do
                    local touchingZones = ZoneController.getTouchingZones(plr)
                    for _, zone in pairs(touchingZones) do
                        if zone.activeTriggers["player"] then
                            fillActionTable(zone, plr)
                        end
                    end
                end
            else
                -- If the volume of all *active zones* within the server is *less than* the total
                -- volume of all characters, then it's more efficient to perform the region and raycast
                -- checks directly within each zone to determine players inside
                for zone, _ in pairs(activeZones) do
                    if zone.activeTriggers["player"] then
                        local result = workspace:FindPartsInRegion3WithWhiteList(zone.region, playerHRPs, #playerHRPs)
                        for _, HRP in pairs(result) do
                            local plr = players:GetPlayerFromCharacter(HRP.Parent)
                            if plr and zone:findPlayer(plr) then
                                fillActionTable(zone, plr)
                            end
                        end
                    end
                end
            end
            for zone, zoneTable in pairs(actions) do
                print(#zoneTable)
                for _, plr in pairs(zoneTable) do
                    -- Inform zone which then calls playerEntering/Exiting
                end
            end
        end,

		["part"] = function()
            --local maxParts = (not zone.ignoreRecommendedMaxParts and zone.recommendedMaxParts) or math.huge
        end,

		["localPlayer"] = function()
            local touchingZones = ZoneController.getTouchingZones(localPlayer)
            for zone, _ in pairs(touchingZones) do
                if zone.activeTriggers["localPlayer"] then
                    -- Inform zone which then calls localPlayerEntering/Exiting
                end
            end
        end,
	}
    heartbeatConnection = heartbeat:Connect(function()
        local clockTime = os.clock()
        if clockTime >= nextCheck then
            ----------
            --if .accuracy == enum.Accuracy.Precise
            nextCheck = clockTime + 0.1
            ----------
            for triggerName, _ in pairs(activeTriggers) do
                triggerTypeActions[triggerName]()
            end
        end
    end)
end

function ZoneController._deregisterConnection(registeredZone, registeredTriggerType)
    activeConnections -= 1
    if activeTriggers[registeredTriggerType] == 1 then
        activeTriggers[registeredTriggerType] = nil
    end
    registeredZone.activeTriggers[registeredTriggerType] = nil
    if dictLength(registeredZone.activeTriggers) == 0 then
        activeZones[registeredZone] = nil
        registeredZone._activeMaid:clean()
        ZoneController._updateActiveParts()
    end
    if activeConnections <= 0 and heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
end

function ZoneController._updateActiveParts()
    activeParts = {}
    activePartToZone = {}
    activeZonesTotalVolume = 0
    for zone, _ in pairs(activeZones) do
        activeZonesTotalVolume += zone.volume
        for _, zonePart in pairs(zone.groupParts) do
             table.insert(activeParts, zonePart)
            activePartToZone[zonePart] = zone
        end
    end
end



-- PUBLIC FUNCTIONS
function ZoneController.getZones()
    local registeredZonesArray = {}
    for zone, _ in pairs(registeredZones) do
        table.insert(registeredZonesArray, zone)
    end
    return registeredZonesArray
end

function ZoneController.getActiveZones()
    local zonesArray = {}
    for _, zone in pairs(activeZones) do
        table.insert(zonesArray, zone)
    end
    return zonesArray
end

function ZoneController.getCharacterRegion(player)
    local char = player.Character
    local head = char and char:FindFirstChild("Head")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not(hrp or head) then return nil end
    local headY = head.Size.Y
    local hrpSize = hrp.Size
    local charSize = (hrpSize * Vector3.new(2, 2, 1)) + Vector3.new(0, headY, 0)
    local regionCFrame = hrp.CFrame * CFrame.new(0, headY/2 - hrpSize.Y/2, 0)
    local charRegion = RotatedRegion3.new(regionCFrame, charSize)
    return charRegion, regionCFrame, charSize
end

function ZoneController.getTouchingZones(player)
    local charRegion = ZoneController.getCharacterRegion(player)
    if not charRegion then return {} end
    --[[
    local part = Instance.new("Part")
    part.Size = charSize
    part.CFrame = regionCFrame
    part.Anchored = true
    part.CanCollide = false
    part.Color = Color3.fromRGB(255, 0, 0)
    part.Transparency = 0.4
    part.Parent = workspace
    game:GetService("Debris"):AddItem(part, 2)
    --]]
    local parts = charRegion:FindPartsInRegion3WithWhiteList(activeParts, #activeParts)
    local zonesDict = {}
    for _, part in pairs(parts) do
        local correspondingZone = activePartToZone[part]
        zonesDict[correspondingZone] = true
    end
    local touchingZonesArray = {}
    for zone, _ in pairs(zonesDict) do
        table.insert(touchingZonesArray, zone)
    end
    return touchingZonesArray
end



return ZoneController