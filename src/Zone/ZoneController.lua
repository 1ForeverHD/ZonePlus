--[[ zone_controller:header
## Functions

#### getZones
```lua
local zonesArray = ZoneController.getZones()
```

----
#### getCharacterRegion
```lua
local charRegion, regionCFrame, charSize = ZoneController.getCharacterRegion(player)
```

----
#### getTouchingZones
```lua
local touchingZonesArray = ZoneController.getTouchingZones(player)
```

----
#### getHeightOfParts
```lua
local height, minY, maxY = ZoneController.getHeightOfParts(tableOfParts)
```

----
#### vectorIsBetweenYBounds
```lua
local bool = ZoneController.vectorIsBetweenYBounds(vector, tableOfParts)
```

----
#### verifyTouchingParts
```lua
local bool = ZoneController.verifyTouchingParts(vectors, tableOfParts)
```

----
--]]



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
local allParts = {}
local allPartToZone = {}
local bodyParts = {}
local activeConnections = 0
local runService = game:GetService("RunService")
local heartbeat = runService.Heartbeat
local heartbeatConnections = {}
local localPlayer = runService:IsClient() and players.LocalPlayer
local playerExitDetections = {}
local WHOLE_BODY_DETECTION_LIMIT = 729000 -- This is roughly the volume where Region3 checks begin to exceed 0.5% in Script Performance



-- LOCAL FUNCTIONS
local function dictLength(dictionary)
	local count = 0
	for _, _ in pairs(dictionary) do
		count += 1
	end
	return count
end

local function fillOccupants(zonesAndOccupantsTable, zone, occupant)
	local occupantsDict = zonesAndOccupantsTable[zone]
	if not occupantsDict then
		occupantsDict = {}
		zonesAndOccupantsTable[zone] = occupantsDict
	end
	occupantsDict[occupant] = true
end

local heartbeatActions = {
	["player"] = function(recommendedDetection)
		return ZoneController._getZonesAndPlayers(activeZones, activeZonesTotalVolume, true, recommendedDetection)
	end,
	["localPlayer"] = function(recommendedDetection)
		local zonesAndOccupants = {}
		local touchingZones = ZoneController.getTouchingZones(localPlayer, true, recommendedDetection)
		for _, zone in pairs(touchingZones) do
			if zone.activeTriggers["localPlayer"] then
				fillOccupants(zonesAndOccupants, zone, localPlayer)
			end
		end
		return zonesAndOccupants
	end,
}



-- CHARACTER HANDLER
-- This enables character data (volume, HumanoidRootParts, etc) to be handled on
-- an event-basis, instead of being retrieved every interval
local function updateCharactersTotalVolume()
	charactersTotalVolume = 0
	bodyParts = {}
	-- We ignore these due to their insignificance (e.g. we ignore the lower and
	-- upper torso because the HumanoidRootPart also covers these areas)
	-- This ultimately reduces the burden on the player region checks
	local bodyPartsToIgnore = {
		UpperTorso = true,
		LowerTorso = true,
		Torso = true,
		LeftHand = true,
		RightHand = true,
		LeftFoot = true,
		RightFoot = true,
	}
	for _, plr in pairs(players:GetPlayers()) do
		local charRegion = ZoneController.getCharacterRegion(plr)
		if charRegion then
			local rSize = charRegion.Size
			local charVolume = rSize.X*rSize.Y*rSize.Z
			charactersTotalVolume += charVolume
			for _, part in pairs(plr.Character:GetChildren()) do
				if part:IsA("BasePart") and not bodyPartsToIgnore[part.Name] then
					table.insert(bodyParts, part)
				end
			end
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
	playerExitDetections[plr] = nil
end)



-- PRIVATE FUNCTIONS
function ZoneController._registerZone(zone)
   	registeredZones[zone] = true
	local registeredMaid = zone._maid:give(Maid.new())
	zone._registeredMaid = registeredMaid
	registeredMaid:give(zone.updated:Connect(function()
		ZoneController._updateZoneDetails()
	end))
   ZoneController._updateZoneDetails()
end

function ZoneController._deregisterZone(zone)
	registeredZones[zone] = nil
	zone._registeredMaid:clean()
	zone._registeredMaid = nil
	ZoneController._updateZoneDetails()
end

function ZoneController._registerConnection(registeredZone, registeredTriggerType)
	local originalItems = dictLength(registeredZone.activeTriggers)
	activeConnections += 1
	if originalItems == 0 then
		activeZones[registeredZone] = true
		ZoneController._updateZoneDetails()
	end
	local currentTriggerCount = activeTriggers[registeredTriggerType]
	activeTriggers[registeredTriggerType] = (currentTriggerCount and currentTriggerCount+1) or 1
	registeredZone.activeTriggers[registeredTriggerType] = true
	if registeredZone.touchedConnectionActions[registeredTriggerType] then
		registeredZone:_formTouchedConnection(registeredTriggerType)
	end
	if heartbeatActions[registeredTriggerType] then
		ZoneController._formHeartbeat(registeredTriggerType)
	end
end

-- This decides what to do if detection is 'Automatic'
-- This is placed in ZoneController instead of the Zone object due to the ZoneControllers all-knowing group-minded logic
function ZoneController.updateDetection(zone)
	local detectionTypes = {
		["enterDetection"] = "_currentEnterDetection",
		["exitDetection"] = "_currentExitDetection",
	}
	for detectionType, currentDetectionName in pairs(detectionTypes) do
		local detection = zone[detectionType]
		if detection == enum.Detection.Automatic then
			if charactersTotalVolume > WHOLE_BODY_DETECTION_LIMIT then
				detection = enum.Detection.Centre
			else
				detection = enum.Detection.WholeBody
			end
		end
		zone[currentDetectionName] = detection
	end
end

function ZoneController._formHeartbeat(registeredTriggerType)
	local heartbeatConnection = heartbeatConnections[registeredTriggerType]
	if heartbeatConnection then return end
	-- This will only ever connect once per triggerType per server
	-- This means instead of initiating a loop per-zone we can handle everything within
	-- a singular connection. This is particularly beneficial for player-orinetated
	-- raycasting, where a raycast only needs to be cast once per interval, as apposed
	-- to every zone per interval
	-- I utilise heartbeat with os.clock() to provide precision (where needed) and flexibility
	local nextCheck = 0
	heartbeatConnection = heartbeat:Connect(function()
		local clockTime = os.clock()
		if clockTime >= nextCheck then
			local lowestAccuracy
			local lowestDetection
			for zone, _ in pairs(activeZones) do
				if zone.activeTriggers[registeredTriggerType] then
					local zAccuracy = zone.accuracy
					if lowestAccuracy == nil or zAccuracy < lowestAccuracy then
						lowestAccuracy = zAccuracy
					end
					ZoneController.updateDetection(zone)
					local zDetection = zone._currentEnterDetection
					if lowestDetection == nil or zDetection < lowestDetection then
						lowestDetection = zDetection
					end
				end
			end
			local highestAccuracy = lowestAccuracy
			local zonesAndOccupants = heartbeatActions[registeredTriggerType](lowestDetection)
			for zone, _ in pairs(activeZones) do
				if zone.activeTriggers[registeredTriggerType] then
					local zAccuracy = zone.accuracy
					local occupantsDict = zonesAndOccupants[zone] or {}
					local occupantsPresent = false
					for k,v in pairs(occupantsDict) do
						occupantsPresent = true
						break
					end
					if occupantsPresent and zAccuracy > highestAccuracy then
						highestAccuracy = zAccuracy
					end
					zone:_updateOccupants(registeredTriggerType, occupantsDict)
				end
			end
			----
			local cooldown = enum.Accuracy.getProperty(highestAccuracy)
			nextCheck = clockTime + cooldown
			----
		end
	end)
	heartbeatConnections[registeredTriggerType] = heartbeatConnection
end

function ZoneController._deregisterConnection(registeredZone, registeredTriggerType)
	activeConnections -= 1
	if activeTriggers[registeredTriggerType] == 1 then
		activeTriggers[registeredTriggerType] = nil
		local heartbeatConnection = heartbeatConnections[registeredTriggerType]
		if heartbeatConnection then
			heartbeatConnections[registeredTriggerType] = nil
			heartbeatConnection:Disconnect()
		end
	end
	registeredZone.activeTriggers[registeredTriggerType] = nil
	if dictLength(registeredZone.activeTriggers) == 0 then
		activeZones[registeredZone] = nil
		ZoneController._updateZoneDetails()
	end
	if registeredZone.touchedConnectionActions[registeredTriggerType] then
		registeredZone:_disconnectTouchedConnection(registeredTriggerType)
	end
end

function ZoneController._updateZoneDetails()
	activeParts = {}
	activePartToZone = {}
	allParts = {}
	allPartToZone = {}
	activeZonesTotalVolume = 0
	for zone, _ in pairs(registeredZones) do
		local isActive = activeZones[zone]
		if isActive then
			activeZonesTotalVolume += zone.volume
		end
		for _, zonePart in pairs(zone.groupParts) do
			if isActive then
				table.insert(activeParts, zonePart)
				activePartToZone[zonePart] = zone
			end
			table.insert(allParts, zonePart)
			allPartToZone[zonePart] = zone
		end
	end
end

function ZoneController._getZonesAndPlayers(zonesDictToCheck, zoneCustomVolume, onlyActiveZones, recommendedDetection)
	local totalZoneVolume = zoneCustomVolume
	if not totalZoneVolume then
		for zone, _ in pairs(zonesDictToCheck) do
			totalZoneVolume += zone.volume
		end
	end
	local zonesAndOccupants = {}
	if charactersTotalVolume < totalZoneVolume then
		-- If the volume of all *characters* within the server is *less than* the total
		-- volume of all active zones (i.e. zones which listen for .playerEntered)
		-- then it's more efficient cast regions and rays within each character and
		-- then determine the zones they belong to
		for _, plr in pairs(players:GetPlayers()) do
			local touchingZones = ZoneController.getTouchingZones(plr, onlyActiveZones, recommendedDetection)
			for _, zone in pairs(touchingZones) do
				if not onlyActiveZones or zone.activeTriggers["player"] then
					fillOccupants(zonesAndOccupants, zone, plr)
				end
			end
		end
	else
		-- If the volume of all *active zones* within the server is *less than* the total
		-- volume of all characters, then it's more efficient to perform the region and raycast
		-- checks directly within each zone to determine players inside
		for zone, _ in pairs(zonesDictToCheck) do
			if not onlyActiveZones or zone.activeTriggers["player"] then
				local result = workspace:FindPartsInRegion3WithWhiteList(zone.region, bodyParts, #bodyParts)
				local playersDict = {}
				for _, bodyPart in pairs(result) do
					local parentName = bodyPart.Parent.Name
					if not playersDict[parentName] then
						playersDict[parentName] = players:GetPlayerFromCharacter(bodyPart.Parent)
					end
				end
				for _, plr in pairs(playersDict) do
					if plr and zone:findPlayer(plr) then
						fillOccupants(zonesAndOccupants, zone, plr)
					end
				end
			end
		end
	end
	return zonesAndOccupants
end



-- PUBLIC FUNCTIONS
function ZoneController.getZones()
	local registeredZonesArray = {}
	for zone, _ in pairs(registeredZones) do
		table.insert(registeredZonesArray, zone)
	end
	return registeredZonesArray
end

--[[
-- the player touched events which utilise active zones at the moment may change to the new CanTouch method for parts in the future
-- hence im disabling this as it may be depreciated quite soon
function ZoneController.getActiveZones()
	local zonesArray = {}
	for zone, _ in pairs(activeZones) do
		table.insert(zonesArray, zone)
	end
	return zonesArray
end
--]]

function ZoneController.getCharacterRegion(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not(hrp and head) then return nil end
	local headY = head.Size.Y
	local hrpSize = hrp.Size
	local charSize = (hrpSize * Vector3.new(2, 2, 1)) + Vector3.new(0, headY, 0)
	local regionCFrame = hrp.CFrame * CFrame.new(0, headY/2 - hrpSize.Y/2, 0)
	local charRegion = RotatedRegion3.new(regionCFrame, charSize)
	return charRegion, regionCFrame, charSize
end

function ZoneController.getTouchingZones(player, onlyActiveZones, recommendedDetection)
	local exitDetection = playerExitDetections[player]
	playerExitDetections[player] = nil
	local finalDetection = exitDetection or recommendedDetection
	local charRegion
	if finalDetection == enum.Detection.WholeBody then
		charRegion = ZoneController.getCharacterRegion(player)
	else
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local regionCFrame = hrp and hrp.CFrame
		charRegion = regionCFrame and RotatedRegion3.new(regionCFrame, Vector3.new(0.1, 0.1, 0.1))
	end
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
	local partsTable = (onlyActiveZones and activeParts) or allParts
	local partToZoneDict = (onlyActiveZones and activePartToZone) or allPartToZone
	local parts = charRegion:FindPartsInRegion3WithWhiteList(partsTable, #partsTable)
	if #parts > 0 then
		local hrp = player.Character.HumanoidRootPart
		local hrpCFrame = hrp.CFrame
		local hrpSizeX = hrp.Size.X
		local pointsToVerify
		if finalDetection == enum.Detection.WholeBody then
			pointsToVerify = {
				(hrpCFrame * CFrame.new(-hrpSizeX, 0, 0)).Position,
				(hrpCFrame * CFrame.new(hrpSizeX, 0, 0)).Position,
			}
		else
			pointsToVerify = {
				hrp.Position,
			}
		end
		if not ZoneController.verifyTouchingParts(pointsToVerify, parts) then
			return {}
		end
	end
	local zonesDict = {}
	for _, part in pairs(parts) do
		local correspondingZone = partToZoneDict[part]
		zonesDict[correspondingZone] = true
	end
	local touchingZonesArray = {}
	local newExitDetection
	for zone, _ in pairs(zonesDict) do
		if newExitDetection == nil or zone._currentExitDetection < newExitDetection then
			newExitDetection = zone._currentExitDetection
		end
		table.insert(touchingZonesArray, zone)
	end
	if newExitDetection then
		playerExitDetections[player] = newExitDetection
	end
	return touchingZonesArray
end

function ZoneController.getHeightOfParts(tableOfParts)
	local maxY
	local minY
	for _, groupPart in pairs(tableOfParts) do
		local partHeight = groupPart.Size.Y + 10
		local partYHalf = partHeight/2
		local partTopY = groupPart.Position.Y + partYHalf
		local partBottomY = groupPart.Position.Y - partYHalf
		if maxY == nil or partTopY > maxY then
			maxY = partTopY
		end
		if minY == nil or partBottomY < minY then
			minY = partBottomY
		end
	end
	local height = maxY - minY
	return height, minY, maxY
end

function ZoneController.vectorIsBetweenYBounds(vectorToCheck, tableOfParts)
	local height, minY, maxY = ZoneController.getHeightOfParts(tableOfParts)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = tableOfParts
	raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
	for i = 1, 2 do
		local startVector = Vector3.new(vectorToCheck.X, (i == 1 and maxY) or minY, vectorToCheck.Z)
		local directionVector = Vector3.new(0, (i == 1 and -height) or height, 0)
		local raycastResult = workspace:Raycast(startVector, directionVector, raycastParams)
		local vectorY = vectorToCheck.Y
		local intersectionY = (raycastResult and raycastResult.Position.Y)
		if not intersectionY or (i == 1 and vectorY > intersectionY) or (i == 2 and vectorY < intersectionY) then
			return false
		end
	end
	return true
end

function ZoneController.verifyTouchingParts(vectorsToCheck, tableOfParts)
	-- Region3 checks are unreliable for some baseparts such as MeshParts and UnionOperations, therefore
	-- we perform additional raycast checks to confirm whether the touching parts are actually within the zone
	local classesToCheck = {
		MeshPart = true,
		UnionOperation = true,
	}
	local additionalCheckRequired = true
	for _, part in pairs(tableOfParts) do
		if not classesToCheck[part.ClassName] then
			additionalCheckRequired = false
		end
	end
	if not additionalCheckRequired then
		return true
	end
	for _, vector in pairs(vectorsToCheck) do
		if ZoneController.vectorIsBetweenYBounds(vector, tableOfParts) then
			return true
		end
	end
	return false
end


return ZoneController