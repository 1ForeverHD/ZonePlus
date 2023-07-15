-- CONFIG
local WHOLE_BODY_DETECTION_LIMIT = 729000 -- This is roughly the volume where Region3 checks begin to exceed 0.5% in Script Performance



-- LOCAL
local Janitor = require(script.Parent.Janitor)
local Enum_ = require(script.Parent.Enum)
local Signal = require(script.Parent.Signal)
local Tracker = require(script.Tracker)
local CollectiveWorldModel = require(script.CollectiveWorldModel)
local enum = Enum_.enums
local players = game:GetService("Players")
local activeZones = {}
local activeZonesTotalVolume = 0
local activeTriggers = {}
local registeredZones = {}
local activeParts = {}
local activePartToZone = {}
local allParts = {}
local allPartToZone = {}
local activeConnections = 0
local runService = game:GetService("RunService")
local heartbeat = runService.Heartbeat
local heartbeatConnections = {}
local localPlayer = runService:IsClient() and players.LocalPlayer



-- PUBLIC
local ZoneController = {}
local trackers = {}
trackers.player = Tracker.new("player")
trackers.item = Tracker.new("item")
ZoneController.trackers = trackers



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
	local prevCharacter = occupant:IsA("Player") and occupant.Character
	occupantsDict[occupant] = (prevCharacter or true)
end

local heartbeatActions = {
	["player"] = function(recommendedDetection)
		return ZoneController._getZonesAndItems("player", activeZones, activeZonesTotalVolume, true, recommendedDetection)
	end,
	["localPlayer"] = function(recommendedDetection)
		local zonesAndOccupants = {}
		local character = localPlayer.Character
		if not character then
			return zonesAndOccupants
		end
		local touchingZones = ZoneController.getTouchingZones(character, true, recommendedDetection, trackers.player)
		for _, zone in pairs(touchingZones) do
			if zone.activeTriggers["localPlayer"] then
				fillOccupants(zonesAndOccupants, zone, localPlayer)
			end
		end
		return zonesAndOccupants
	end,
	["item"] = function(recommendedDetection)
		return ZoneController._getZonesAndItems("item", activeZones, activeZonesTotalVolume, true, recommendedDetection)
	end,
}



-- PRIVATE FUNCTIONS
function ZoneController._registerZone(zone)
   	registeredZones[zone] = true
	local registeredJanitor = zone.janitor:add(Janitor.new(), "destroy")
	zone._registeredJanitor = registeredJanitor
	registeredJanitor:add(zone.updated:Connect(function()
		ZoneController._updateZoneDetails()
	end), "Disconnect")
   ZoneController._updateZoneDetails()
end

function ZoneController._deregisterZone(zone)
	registeredZones[zone] = nil
	zone._registeredJanitor:destroy()
	zone._registeredJanitor = nil
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
		local combinedTotalVolume = Tracker.getCombinedTotalVolumes()
		if detection == enum.Detection.Automatic then
			if combinedTotalVolume > WHOLE_BODY_DETECTION_LIMIT then
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
	-- a singular connection. This is particularly beneficial for player/item-orinetated
	-- checking, where a check only needs to be cast once per interval, as apposed
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

			-- If a zone belongs to a settingsGroup with 'onlyEnterOnceExitedAll = true' , and the occupant already exists in a member group, then
			-- ignore all incoming occupants for the other zones (preventing the enteredSignal from being fired until the occupant has left
			-- all other zones within the same settingGroup)
			local occupantsToBlock = {}
			local zonesToPotentiallyIgnore = {}
			for zone, newOccupants in pairs(zonesAndOccupants) do
				local settingsGroup = (zone.settingsGroupName and ZoneController.getGroup(zone.settingsGroupName))
				if settingsGroup and settingsGroup.onlyEnterOnceExitedAll == true then
					--local currentOccupants = zone.occupants[registeredTriggerType]
					--if currentOccupants then
						for newOccupant, _ in pairs(newOccupants) do
							--if currentOccupants[newOccupant] then
								local groupDetail = occupantsToBlock[zone.settingsGroupName]
								if not groupDetail then
									groupDetail = {}
									occupantsToBlock[zone.settingsGroupName] = groupDetail
								end
								groupDetail[newOccupant] = zone
							--end
						end
						zonesToPotentiallyIgnore[zone] = newOccupants
					--end
				end
			end
			for zone, newOccupants in pairs(zonesToPotentiallyIgnore) do
				local groupDetail = occupantsToBlock[zone.settingsGroupName]
				if groupDetail then
					for newOccupant, _ in pairs(newOccupants) do
						local occupantToKeepZone = groupDetail[newOccupant]
						if occupantToKeepZone and occupantToKeepZone ~= zone then
							newOccupants[newOccupant] = nil
						end
					end
				end
			end

			-- This deduces what signals should be fired
			local collectiveSignalsToFire = {{}, {}}
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
					local signalsToFire = zone:_updateOccupants(registeredTriggerType, occupantsDict)
					collectiveSignalsToFire[1][zone] = signalsToFire.exited
					collectiveSignalsToFire[2][zone] = signalsToFire.entered
				end
			end

			-- This ensures all exited signals and called before entered signals
			local indexToSignalType = {"Exited", "Entered"}
			for index, zoneAndOccupants in pairs(collectiveSignalsToFire) do
				local signalType = indexToSignalType[index]
				local signalName = registeredTriggerType..signalType
				for zone, occupants in pairs(zoneAndOccupants) do
					local signal = zone[signalName]
					if signal then
						for _, occupant in pairs(occupants) do
							signal:Fire(occupant)
						end
					end
				end
			end

			local cooldown = enum.Accuracy.getProperty(highestAccuracy)
			nextCheck = clockTime + cooldown
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
	else
		activeTriggers[registeredTriggerType] -= 1
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
		for _, zonePart in pairs(zone.zoneParts) do
			if isActive then
				table.insert(activeParts, zonePart)
				activePartToZone[zonePart] = zone
			end
			table.insert(allParts, zonePart)
			allPartToZone[zonePart] = zone
		end
	end
end

function ZoneController._getZonesAndItems(trackerName, zonesDictToCheck, zoneCustomVolume, onlyActiveZones, recommendedDetection)
	local totalZoneVolume = zoneCustomVolume
	if not totalZoneVolume then
		for zone, _ in pairs(zonesDictToCheck) do
			totalZoneVolume += zone.volume
		end
	end
	local zonesAndOccupants = {}
	local tracker = trackers[trackerName]
	if tracker.totalVolume < totalZoneVolume then
		-- If the volume of all *characters/items* within the server is *less than* the total
		-- volume of all active zones (i.e. zones which listen for .playerEntered)
		-- then it's more efficient cast checks within each character and
		-- then determine the zones they belong to
		for _, item in pairs(tracker.items) do
			local touchingZones = ZoneController.getTouchingZones(item, onlyActiveZones, recommendedDetection, tracker)
			for _, zone in pairs(touchingZones) do
				if not onlyActiveZones or zone.activeTriggers[trackerName] then
					local finalItem = item
					if trackerName == "player" then
						finalItem = players:GetPlayerFromCharacter(item)
					end
					if finalItem then
						fillOccupants(zonesAndOccupants, zone, finalItem)
					end
				end
			end
		end
	else
		-- If the volume of all *active zones* within the server is *less than* the total
		-- volume of all characters/items, then it's more efficient to perform the
		-- checks directly within each zone to determine players inside
		for zone, _ in pairs(zonesDictToCheck) do
			if not onlyActiveZones or zone.activeTriggers[trackerName] then
				local result = CollectiveWorldModel:GetPartBoundsInBox(zone.region.CFrame, zone.region.Size, tracker.whitelistParams)
				local finalItemsDict = {}
				for _, itemOrChild in pairs(result) do
					local correspondingItem = tracker.partToItem[itemOrChild]
					if not finalItemsDict[correspondingItem] then
						finalItemsDict[correspondingItem] = true
					end
				end
				for item, _ in pairs(finalItemsDict) do
					if trackerName == "player" then
						local player = players:GetPlayerFromCharacter(item)
						if zone:findPlayer(player) then
							fillOccupants(zonesAndOccupants, zone, player)
						end
					elseif zone:findItem(item) then
						fillOccupants(zonesAndOccupants, zone, item)
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

function ZoneController.getTouchingZones(item, onlyActiveZones, recommendedDetection, tracker)
	local exitDetection, finalDetection
	if tracker then
		exitDetection = tracker.exitDetections[item]
		tracker.exitDetections[item] = nil
	end
	finalDetection = exitDetection or recommendedDetection

	local itemSize, itemCFrame
	local itemIsBasePart = item:IsA("BasePart")
	local itemIsCharacter = not itemIsBasePart
	local bodyPartsToCheck = {}
	if itemIsBasePart then
		itemSize, itemCFrame = item.Size, item.CFrame
		table.insert(bodyPartsToCheck, item)
	elseif finalDetection == enum.Detection.WholeBody then
		itemSize, itemCFrame = Tracker.getCharacterSize(item)
		bodyPartsToCheck = item:GetChildren()
	else
		local hrp = item:FindFirstChild("HumanoidRootPart")
		if hrp then
			itemSize, itemCFrame = hrp.Size, hrp.CFrame
			table.insert(bodyPartsToCheck, hrp)
		end
	end
	if not itemSize or not itemCFrame then return {} end

	--[[
	local part = Instance.new("Part")
	part.Size = itemSize
	part.CFrame = itemCFrame
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Transparency = 0.4
	part.Parent = workspace
	game:GetService("Debris"):AddItem(part, 2)
	--]]
	local partsTable = (onlyActiveZones and activeParts) or allParts
	local partToZoneDict = (onlyActiveZones and activePartToZone) or allPartToZone

	local boundParams = OverlapParams.new()
	boundParams.FilterType = Enum.RaycastFilterType.Include
	boundParams.MaxParts = #partsTable
	boundParams.FilterDescendantsInstances = partsTable

	-- This retrieves the bounds (the rough shape) of all parts touching the item/character
	-- If the corresponding zone is made up of *entirely* blocks then the bound will
	-- be the actual shape of the part.
	local touchingPartsDictionary = {}
	local zonesDict = {}
	local boundParts = CollectiveWorldModel:GetPartBoundsInBox(itemCFrame, itemSize, boundParams)
	local boundPartsThatRequirePreciseChecks = {}
	for _, boundPart in pairs(boundParts) do
		local correspondingZone = partToZoneDict[boundPart]
		if correspondingZone and correspondingZone.allZonePartsAreBlocks then
			zonesDict[correspondingZone] = true
			touchingPartsDictionary[boundPart] = correspondingZone
		else
			table.insert(boundPartsThatRequirePreciseChecks, boundPart)
		end
	end

	-- If the bound parts belong to a zone that isn't entirely made up of blocks, then
	-- we peform additional checks using GetPartsInPart which enables shape
	-- geometries to be precisely determined for non-block baseparts.
	local totalRemainingBoundParts = #boundPartsThatRequirePreciseChecks
	local precisePartsCount = 0
	if totalRemainingBoundParts > 0 then
		
		local preciseParams = OverlapParams.new()
		preciseParams.FilterType = Enum.RaycastFilterType.Include
		preciseParams.MaxParts = totalRemainingBoundParts
		preciseParams.FilterDescendantsInstances = boundPartsThatRequirePreciseChecks

		local character = item
		for _, bodyPart in pairs(bodyPartsToCheck) do
			local endCheck = false
			if not bodyPart:IsA("BasePart") or (itemIsCharacter and Tracker.bodyPartsToIgnore[bodyPart.Name]) then
				continue
			end
			local preciseParts = CollectiveWorldModel:GetPartsInPart(bodyPart, preciseParams)
			for _, precisePart in pairs(preciseParts) do
				if not touchingPartsDictionary[precisePart] then
					local correspondingZone = partToZoneDict[precisePart]
					if correspondingZone then
						zonesDict[correspondingZone] = true
						touchingPartsDictionary[precisePart] = correspondingZone
						precisePartsCount += 1
					end
					if precisePartsCount == totalRemainingBoundParts then
						endCheck = true
						break
					end
				end
			end
			if endCheck then
				break
			end
		end
	end
	
	local touchingZonesArray = {}
	local newExitDetection
	for zone, _ in pairs(zonesDict) do
		if newExitDetection == nil or zone._currentExitDetection < newExitDetection then
			newExitDetection = zone._currentExitDetection
		end
		table.insert(touchingZonesArray, zone)
	end
	if newExitDetection and tracker then
		tracker.exitDetections[item] = newExitDetection
	end
	return touchingZonesArray, touchingPartsDictionary
end

local settingsGroups = {}
function ZoneController.setGroup(settingsGroupName, properties)
	local group = settingsGroups[settingsGroupName]
	if not group then
		group = {}
		settingsGroups[settingsGroupName] = group
	end
	

	-- PUBLIC PROPERTIES --
	group.onlyEnterOnceExitedAll = true
	
	-- PRIVATE PROPERTIES --
	group._name = settingsGroupName
	group._memberZones = {}


	if typeof(properties) == "table" then
		for k, v in pairs(properties) do
			group[k] = v
		end
	end
	return group
end

function ZoneController.getGroup(settingsGroupName)
	return settingsGroups[settingsGroupName]
end

local workspaceContainer
local workspaceContainerName = string.format("ZonePlus%sContainer", (runService:IsClient() and "Client") or "Server")
function ZoneController.getWorkspaceContainer()
	local container = workspaceContainer or workspace:FindFirstChild(workspaceContainerName)
	if not container then
		container = Instance.new("Folder")
		container.Name = workspaceContainerName
		container.Parent = workspace
		workspaceContainer = container
	end
	return container
end



return ZoneController