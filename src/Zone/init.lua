-- LOCAL
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local heartbeat = runService.Heartbeat
local localPlayer = runService:IsClient() and players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpService = game:GetService("HttpService")
local Enum_ = require(script.Enum)
local enum = Enum_.enums
local Janitor = require(script.Janitor)
local Signal = require(script.Signal)
local ZonePlusReference = require(script.ZonePlusReference)
local referenceObject = ZonePlusReference.getObject()
local zoneControllerModule = script.ZoneController
local trackerModule = zoneControllerModule.Tracker
local collectiveWorldModelModule = zoneControllerModule.CollectiveWorldModel
local ZoneController = require(zoneControllerModule)
local referenceLocation = (game:GetService("RunService"):IsClient() and "Client") or "Server"
local referencePresent = referenceObject and referenceObject:FindFirstChild(referenceLocation)
if referencePresent then
	return require(referenceObject.Value)
end

local Zone = {}
Zone.__index = Zone
if not referencePresent then
	ZonePlusReference.addToReplicatedStorage()
end
Zone.enum = enum



-- CONSTRUCTORS
function Zone.new(container)
	local self = {}
	setmetatable(self, Zone)
	
	-- Validate container
	local INVALID_TYPE_WARNING = "The zone container must be a model, folder, basepart or table!"
	local containerType = typeof(container)
	if not(containerType == "table" or containerType == "Instance") then
		error(INVALID_TYPE_WARNING)
	end

	-- Configurable
	self.accuracy = enum.Accuracy.High
	self.autoUpdate = true
	self.respectUpdateQueue = true
	--self.maxPartsAddition = 20
	--self.ignoreRecommendedMaxParts = false

	-- Variable
	local janitor = Janitor.new()
	self.janitor = janitor
	self._updateConnections = janitor:add(Janitor.new(), "destroy")
	self.container = container
	self.zoneParts = {}
	self.overlapParams = {}
	self.region = nil
	self.volume = nil
	self.boundMin = nil
	self.boundMax = nil
	self.recommendedMaxParts = nil
	self.zoneId = httpService:GenerateGUID()
	self.activeTriggers = {}
	self.occupants = {}
	self.trackingTouchedTriggers = {}
	self.enterDetection = enum.Detection.Centre
	self.exitDetection = enum.Detection.Centre
	self._currentEnterDetection = nil -- This will update automatically internally
	self._currentExitDetection = nil -- This will also update automatically internally
	self.totalPartVolume = 0
	self.allZonePartsAreBlocks = true
	self.trackedItems = {}
	self.settingsGroupName = nil
	self.worldModel = workspace
	self.onItemDetails = {}
	self.itemsToUntrack = {}

	-- This updates _currentEnterDetection and _currentExitDetection right away to prevent nil comparisons
	ZoneController.updateDetection(self)

	-- Signals
	self.updated = janitor:add(Signal.new(), "destroy")
	local triggerTypes = {
		"player",
		"part",
		"localPlayer",
		"item"
	}
	local triggerEvents = {
		"entered",
		"exited",
	}
	for _, triggerType in pairs(triggerTypes) do
		local activeConnections = 0
		local previousActiveConnections = 0
		for i, triggerEvent in pairs(triggerEvents) do
			-- this enables us to determine when a developer connects to an event
			-- so that we can act accoridngly (i.e. begin or end a checker loop)
			local signal = janitor:add(Signal.new(true), "destroy")
			local triggerEventUpper = triggerEvent:sub(1,1):upper()..triggerEvent:sub(2)
			local signalName = triggerType..triggerEventUpper
			self[signalName] = signal
			signal.connectionsChanged:Connect(function(increment)
				if triggerType == "localPlayer" and not localPlayer and increment == 1 then
					error(("Can only connect to 'localPlayer%s' on the client!"):format(triggerEventUpper))
				end
				previousActiveConnections = activeConnections
				activeConnections += increment
				if previousActiveConnections == 0 and activeConnections > 0 then
					-- At least 1 connection active, begin loop
					ZoneController._registerConnection(self, triggerType, triggerEventUpper)
				elseif previousActiveConnections > 0 and activeConnections == 0 then
					-- All connections have disconnected, end loop
					ZoneController._deregisterConnection(self, triggerType)
				end
			end)
		end
	end

	-- Setup touched receiver functions where applicable
	Zone.touchedConnectionActions = {}
	for _, triggerType in pairs(triggerTypes) do
		local methodName = ("_%sTouchedZone"):format(triggerType)
		local correspondingMethod = self[methodName]
		if correspondingMethod then
			self.trackingTouchedTriggers[triggerType] = {}
			Zone.touchedConnectionActions[triggerType] = function(touchedItem)
				correspondingMethod(self, touchedItem)
			end
		end
	end

	-- This constructs the zones boundaries, region, etc
	self:_update()

	-- Register/deregister zone
	ZoneController._registerZone(self)
	janitor:add(function()
		ZoneController._deregisterZone(self)
	end, true)
	
	return self
end

function Zone.fromRegion(cframe, size)
	local MAX_PART_SIZE = 2024
	local container = Instance.new("Model")
	local function createCube(cubeCFrame, cubeSize)
		if cubeSize.X > MAX_PART_SIZE or cubeSize.Y > MAX_PART_SIZE or cubeSize.Z > MAX_PART_SIZE then
			local quarterSize = cubeSize * 0.25
			local halfSize = cubeSize * 0.5
			createCube(cubeCFrame * CFrame.new(-quarterSize.X, -quarterSize.Y, -quarterSize.Z), halfSize)
			createCube(cubeCFrame * CFrame.new(-quarterSize.X, -quarterSize.Y, quarterSize.Z), halfSize)
			createCube(cubeCFrame * CFrame.new(-quarterSize.X, quarterSize.Y, -quarterSize.Z), halfSize)
			createCube(cubeCFrame * CFrame.new(-quarterSize.X, quarterSize.Y, quarterSize.Z), halfSize)
			createCube(cubeCFrame * CFrame.new(quarterSize.X, -quarterSize.Y, -quarterSize.Z), halfSize)
			createCube(cubeCFrame * CFrame.new(quarterSize.X, -quarterSize.Y, quarterSize.Z), halfSize)
			createCube(cubeCFrame * CFrame.new(quarterSize.X, quarterSize.Y, -quarterSize.Z), halfSize)
			createCube(cubeCFrame * CFrame.new(quarterSize.X, quarterSize.Y, quarterSize.Z), halfSize)
		else
			local part = Instance.new("Part")
			part.CFrame = cubeCFrame
			part.Size = cubeSize
			part.Anchored = true
			part.Parent = container
		end
	end
	createCube(cframe, size)
	local zone = Zone.new(container)
	zone:relocate()
	return zone
end



-- PRIVATE METHODS
function Zone:_calculateRegion(tableOfParts, dontRound)
	local bounds = {["Min"] = {}, ["Max"] = {}}
	for boundType, details in pairs(bounds) do
		details.Values = {}
		function details.parseCheck(v, currentValue)
			if boundType == "Min" then
				return (v <= currentValue)
			elseif boundType == "Max" then
				return (v >= currentValue)
			end
		end
		function details:parse(valuesToParse)
			for i,v in pairs(valuesToParse) do
				local currentValue = self.Values[i] or v
				if self.parseCheck(v, currentValue) then
					self.Values[i] = v
				end
			end
		end
	end
	for _, part in pairs(tableOfParts) do
		local sizeHalf = part.Size * 0.5
		local corners = {
			part.CFrame * CFrame.new(-sizeHalf.X, -sizeHalf.Y, -sizeHalf.Z),
			part.CFrame * CFrame.new(-sizeHalf.X, -sizeHalf.Y, sizeHalf.Z),
			part.CFrame * CFrame.new(-sizeHalf.X, sizeHalf.Y, -sizeHalf.Z),
			part.CFrame * CFrame.new(-sizeHalf.X, sizeHalf.Y, sizeHalf.Z),
			part.CFrame * CFrame.new(sizeHalf.X, -sizeHalf.Y, -sizeHalf.Z),
			part.CFrame * CFrame.new(sizeHalf.X, -sizeHalf.Y, sizeHalf.Z),
			part.CFrame * CFrame.new(sizeHalf.X, sizeHalf.Y, -sizeHalf.Z),
			part.CFrame * CFrame.new(sizeHalf.X, sizeHalf.Y, sizeHalf.Z),
		}
		for _, cornerCFrame in pairs(corners) do
			local x, y, z = cornerCFrame:GetComponents()
			local values = {x, y, z}
			bounds.Min:parse(values)
			bounds.Max:parse(values)
		end
	end
	local minBound = {}
	local maxBound = {}
	-- Rounding a regions coordinates to multiples of 4 ensures the region optimises the region
	-- by ensuring it aligns on the voxel grid
	local function roundToFour(to_round)
		local ROUND_TO = 4
		local divided = (to_round+ROUND_TO/2) / ROUND_TO
		local rounded = ROUND_TO * math.floor(divided)
		return rounded
	end
	for boundName, boundDetail in pairs(bounds) do
		for _, v in pairs(boundDetail.Values) do
			local newTable = (boundName == "Min" and minBound) or maxBound
			local newV = v
			if not dontRound then
				local roundOffset = (boundName == "Min" and -2) or 2
				newV = roundToFour(v+roundOffset) -- +-2 to ensures the zones region is not rounded down/up
			end
			table.insert(newTable, newV)
		end
	end
	local boundMin = Vector3.new(unpack(minBound))
	local boundMax = Vector3.new(unpack(maxBound))
	local region = Region3.new(boundMin, boundMax)
	return region, boundMin, boundMax
end

function Zone:_displayBounds()
	if not self.displayBoundParts then
		self.displayBoundParts = true
		local boundParts = {BoundMin = self.boundMin, BoundMax = self.boundMax}
		for boundName, boundCFrame in pairs(boundParts) do
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.Transparency = 0.5
			part.Size = Vector3.new(1,1,1)
			part.Color = Color3.fromRGB(255,0,0)
			part.CFrame = CFrame.new(boundCFrame)
			part.Name = boundName
			part.Parent = workspace
			self.janitor:add(part, "Destroy")
		end
	end
end

function Zone:_update()
	local container = self.container
	local zoneParts = {}
	local updateQueue = 0
	self._updateConnections:clean()

	local containerType = typeof(container)
	local holders = {}
	local INVALID_TYPE_WARNING = "The zone container must be a model, folder, basepart or table!"
	if containerType == "table" then
		for _, part in pairs(container) do
			if part:IsA("BasePart") then
				table.insert(zoneParts, part)
			end
		end
	elseif containerType == "Instance" then
		if container:IsA("BasePart") then
			table.insert(zoneParts, container)
		else
			table.insert(holders, container)
			for _, part in pairs(container:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(zoneParts, part)
				else
					table.insert(holders, part)
				end
			end
		end
	end
	self.zoneParts = zoneParts
	self.overlapParams = {}
	
	local allZonePartsAreBlocksNew = true
	for _, zonePart in pairs(zoneParts) do
		local success, shapeName = pcall(function() return zonePart.Shape.Name end)
		if shapeName ~= "Block" then
			allZonePartsAreBlocksNew = false
		end
	end
	self.allZonePartsAreBlocks = allZonePartsAreBlocksNew
	
	local zonePartsWhitelist = OverlapParams.new()
	zonePartsWhitelist.FilterType = Enum.RaycastFilterType.Whitelist
	zonePartsWhitelist.MaxParts = #zoneParts
	zonePartsWhitelist.FilterDescendantsInstances = zoneParts
	self.overlapParams.zonePartsWhitelist = zonePartsWhitelist

	local zonePartsIgnorelist = OverlapParams.new()
	zonePartsIgnorelist.FilterType = Enum.RaycastFilterType.Blacklist
	zonePartsIgnorelist.FilterDescendantsInstances = zoneParts
	self.overlapParams.zonePartsIgnorelist = zonePartsIgnorelist
	
	-- this will call update on the zone when the container parts size or position changes, and when a
	-- child is removed or added from a holder (anything which isn't a basepart)
	local function update()
		if self.autoUpdate then
			local executeTime = os.clock()
			if self.respectUpdateQueue then
				updateQueue += 1
				executeTime += 0.1
			end
			local updateConnection
			updateConnection = runService.Heartbeat:Connect(function()
				if os.clock() >= executeTime then
					updateConnection:Disconnect()
					if self.respectUpdateQueue then
						updateQueue -= 1
					end
					if updateQueue == 0 and self.zoneId then
						self:_update()
					end
				end
			end)
		end
	end
	local partProperties = {"Size", "Position"}
	local function verifyDefaultCollision(instance)
		if instance.CollisionGroupId ~= 0 then
			error("Zone parts must belong to the 'Default' (0) CollisionGroup! Consider using zone:relocate() if you wish to move zones outside of workspace to prevent them interacting with other parts.")
		end
	end
	for _, part in pairs(zoneParts) do
		for _, prop in pairs(partProperties) do
			self._updateConnections:add(part:GetPropertyChangedSignal(prop):Connect(update), "Disconnect")
		end
		verifyDefaultCollision(part)
		self._updateConnections:add(part:GetPropertyChangedSignal("CollisionGroupId"):Connect(function()
			verifyDefaultCollision(part)
		end), "Disconnect")
	end
	local containerEvents = {"ChildAdded", "ChildRemoved"}
	for _, holder in pairs(holders) do
		for _, event in pairs(containerEvents) do
			self._updateConnections:add(self.container[event]:Connect(function(child)
				if child:IsA("BasePart") then
					update()
				end
			end), "Disconnect")
		end
	end
	
	local region, boundMin, boundMax = self:_calculateRegion(zoneParts)
	local exactRegion, _, _ = self:_calculateRegion(zoneParts, true)
	self.region = region
	self.exactRegion = exactRegion
	self.boundMin = boundMin
	self.boundMax = boundMax
	local rSize = region.Size
	self.volume = rSize.X*rSize.Y*rSize.Z
	
	-- Update: I was going to use this for the old part detection until the CanTouch property was released
	-- everything below is now irrelevant however I'll keep just in case I use again for future
	-------------------------------------------------------------------------------------------------
	-- When a zones region is determined, we also check for parts already existing within the zone
	-- these parts are likely never to move or interact with the zone, so we set the number of these
	-- to the baseline MaxParts value. 'recommendMaxParts' is then determined through the sum of this
	-- and maxPartsAddition. This ultimately optimises region checks as they can be generated with
	-- minimal MaxParts (i.e. recommendedMaxParts can be used instead of math.huge every time)
	--[[
	local result = self.worldModel:FindPartsInRegion3(region, nil, math.huge)
	local maxPartsBaseline = #result
	self.recommendedMaxParts = maxPartsBaseline + self.maxPartsAddition
	--]]
	
	self:_updateTouchedConnections()
	
	self.updated:Fire()
end

function Zone:_updateOccupants(trackerName, newOccupants)
	local previousOccupants = self.occupants[trackerName]
	if not previousOccupants then
		previousOccupants = {}
		self.occupants[trackerName] = previousOccupants
	end
	local signalsToFire = {}
	for occupant, prevItem in pairs(previousOccupants) do
		local newItem = newOccupants[occupant]
		if newItem == nil or newItem ~= prevItem then
			previousOccupants[occupant] = nil
			if not signalsToFire.exited then
				signalsToFire.exited = {}
			end
			table.insert(signalsToFire.exited, occupant)
		end
	end
	for occupant, _ in pairs(newOccupants) do
		if previousOccupants[occupant] == nil then
			local isAPlayer = occupant:IsA("Player")
			previousOccupants[occupant] = (isAPlayer and occupant.Character) or true
			if not signalsToFire.entered then
				signalsToFire.entered = {}
			end
			table.insert(signalsToFire.entered, occupant)
		end
	end 
	return signalsToFire
end

function Zone:_formTouchedConnection(triggerType)
	local touchedJanitorName = "_touchedJanitor"..triggerType
	local touchedJanitor = self[touchedJanitorName]
	if touchedJanitor then
		touchedJanitor:clean()
	else
		touchedJanitor = self.janitor:add(Janitor.new(), "destroy")
		self[touchedJanitorName] = touchedJanitor
	end
	self:_updateTouchedConnection(triggerType)
end

function Zone:_updateTouchedConnection(triggerType)
	local touchedJanitorName = "_touchedJanitor"..triggerType
	local touchedJanitor = self[touchedJanitorName]
	if not touchedJanitor then return end
	for _, basePart in pairs(self.zoneParts) do
		touchedJanitor:add(basePart.Touched:Connect(self.touchedConnectionActions[triggerType], self), "Disconnect")
	end
end

function Zone:_updateTouchedConnections()
	for triggerType, _ in pairs(self.touchedConnectionActions) do
		local touchedJanitorName = "_touchedJanitor"..triggerType
		local touchedJanitor = self[touchedJanitorName]
		if touchedJanitor then
			touchedJanitor:cleanup()
			self:_updateTouchedConnection(triggerType)
		end
	end
end

function Zone:_disconnectTouchedConnection(triggerType)
	local touchedJanitorName = "_touchedJanitor"..triggerType
	local touchedJanitor = self[touchedJanitorName]
	if touchedJanitor then
		touchedJanitor:cleanup()
		self[touchedJanitorName] = nil
	end
end

local function round(number, decimalPlaces)
	return math.round(number * 10^decimalPlaces) * 10^-decimalPlaces
end
function Zone:_partTouchedZone(part)
	local trackingDict = self.trackingTouchedTriggers["part"]
	if trackingDict[part] then return end
	local nextCheck = 0
	local verifiedEntrance = false
	local enterPosition = part.Position
	local enterTime = os.clock()
	local partJanitor = self.janitor:add(Janitor.new(), "destroy")
	trackingDict[part] = partJanitor
	local instanceClassesToIgnore = {Seat = true, VehicleSeat = true}
	local instanceNamesToIgnore = {HumanoidRootPart = true}
	if not (instanceClassesToIgnore[part.ClassName] or not instanceNamesToIgnore[part.Name])  then
		part.CanTouch = false
	end
	--
	local partVolume = round((part.Size.X * part.Size.Y * part.Size.Z), 5)
	self.totalPartVolume += partVolume
	--
	partJanitor:add(heartbeat:Connect(function()
		local clockTime = os.clock()
		if clockTime >= nextCheck then
			----
			local cooldown = enum.Accuracy.getProperty(self.accuracy)
			nextCheck = clockTime + cooldown
			----

			-- We initially perform a singular point check as this is vastly more lightweight than a large part check
			-- If the former returns false, perform a whole part check in case the part is on the outer bounds.
			local withinZone = self:findPoint(part.CFrame)
			if not withinZone then
				withinZone = self:findPart(part)
			end
			if not verifiedEntrance then
				if withinZone then
					verifiedEntrance = true
					self.partEntered:Fire(part)
				elseif (part.Position - enterPosition).Magnitude > 1.5 and clockTime - enterTime >= cooldown then
					-- Even after the part has exited the zone, we track it for a brief period of time based upon the criteria
					-- in the line above to ensure the .touched behaviours are not abused
					partJanitor:cleanup()
				end
			elseif not withinZone then
				verifiedEntrance = false
				enterPosition = part.Position
				enterTime = os.clock()
				self.partExited:Fire(part)
			end
		end
	end), "Disconnect")
	partJanitor:add(function()
		trackingDict[part] = nil
		part.CanTouch = true
		self.totalPartVolume = round((self.totalPartVolume - partVolume), 5)
	end, true)
end

local partShapeActions = {
	["Ball"] = function(part)
		return "GetPartBoundsInRadius", {part.Position, part.Size.X}
	end,
	["Block"] = function(part)
		return "GetPartBoundsInBox", {part.CFrame, part.Size}
	end,
	["Other"] = function(part)
		return "GetPartsInPart", {part}
	end,
}
function Zone:_getRegionConstructor(part, overlapParams)
	local success, shapeName = pcall(function() return part.Shape.Name end)
	local methodName, args
	if success and self.allZonePartsAreBlocks then
		local action = partShapeActions[shapeName]
		if action then
			methodName, args = action(part)
		end
	end
	if not methodName then
		methodName, args = partShapeActions.Other(part)
	end
	if overlapParams then
		table.insert(args, overlapParams)
	end
	return methodName, args
end



-- PUBLIC METHODS
function Zone:findLocalPlayer()
	if not localPlayer then
		error("Can only call 'findLocalPlayer' on the client!")
	end
	return self:findPlayer(localPlayer)
end

function Zone:_find(trackerName, item)
	ZoneController.updateDetection(self)
	local tracker = ZoneController.trackers[trackerName]
	local touchingZones = ZoneController.getTouchingZones(item, false, self._currentEnterDetection, tracker)
	for _, zone in pairs(touchingZones) do
		if zone == self then
			return true
		end
	end
	return false
end

function Zone:findPlayer(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	return self:_find("player", player.Character)
end

function Zone:findItem(item)
	return self:_find("item", item)
end

function Zone:findPart(part)
	local methodName, args = self:_getRegionConstructor(part, self.overlapParams.zonePartsWhitelist)
	local touchingZoneParts = self.worldModel[methodName](self.worldModel, unpack(args))
	--local touchingZoneParts = self.worldModel:GetPartsInPart(part, self.overlapParams.zonePartsWhitelist)
	if #touchingZoneParts > 0 then
		return true, touchingZoneParts
	end
	return false
end

function Zone:getCheckerPart()
	local checkerPart = self.checkerPart
	if not checkerPart then
		checkerPart = self.janitor:add(Instance.new("Part"), "Destroy")
		checkerPart.Size = Vector3.new(0.1, 0.1, 0.1)
		checkerPart.Name = "ZonePlusCheckerPart"
		checkerPart.Anchored = true
		checkerPart.Transparency = 1
		checkerPart.CanCollide = false
		self.checkerPart = checkerPart
	end
	local checkerParent = self.worldModel
	if checkerParent == workspace then
		checkerParent = ZoneController.getWorkspaceContainer()
	end
	if checkerPart.Parent ~= checkerParent then
		checkerPart.Parent = checkerParent
	end
	return checkerPart
end

function Zone:findPoint(positionOrCFrame)
	local cframe = positionOrCFrame
	if typeof(positionOrCFrame) == "Vector3" then
		cframe = CFrame.new(positionOrCFrame)
	end
	local checkerPart = self:getCheckerPart()
	checkerPart.CFrame = cframe
	--checkerPart.Parent = self.worldModel
	local methodName, args = self:_getRegionConstructor(checkerPart, self.overlapParams.zonePartsWhitelist)
	local touchingZoneParts = self.worldModel[methodName](self.worldModel, unpack(args))
	--local touchingZoneParts = self.worldModel:GetPartsInPart(self.checkerPart, self.overlapParams.zonePartsWhitelist)
	if #touchingZoneParts > 0 then
		return true, touchingZoneParts
	end
	return false
end

function Zone:_getAll(trackerName)
	ZoneController.updateDetection(self)
	local itemsArray = {}
	local zonesAndOccupants = ZoneController._getZonesAndItems(trackerName, {self = true}, self.volume, false, self._currentEnterDetection)
	local occupantsDict = zonesAndOccupants[self]
	if occupantsDict then
		for item, _ in pairs(occupantsDict) do
			table.insert(itemsArray, item)
		end
	end
	return itemsArray
end

function Zone:getPlayers()
	return self:_getAll("player")
end

function Zone:getItems()
	return self:_getAll("item")
end

function Zone:getParts()
	-- This is designed for infrequent 'one off' use
	-- If you plan on checking for parts within a zone frequently, it's recommended you
	-- use the .partEntered and .partExited events instead.
	local partsArray = {}
	if self.activeTriggers["part"] then
		local trackingDict = self.trackingTouchedTriggers["part"]
		for part, _ in pairs(trackingDict) do
			table.insert(partsArray, part)
		end
		return partsArray
	end
	local partsInRegion = self.worldModel:GetPartBoundsInBox(self.region.CFrame, self.region.Size, self.overlapParams.zonePartsIgnorelist)
	for _, part in pairs(partsInRegion) do
		if self:findPart(part) then
			table.insert(partsArray, part)
		end
	end
	return partsArray
end

function Zone:getRandomPoint()
	local region = self.exactRegion
	local size = region.Size
	local cframe = region.CFrame
	local random = Random.new()
	local randomCFrame
	local success, touchingZoneParts
	local pointIsWithinZone
	repeat
		randomCFrame = cframe * CFrame.new(random:NextNumber(-size.X/2,size.X/2), random:NextNumber(-size.Y/2,size.Y/2), random:NextNumber(-size.Z/2,size.Z/2))
		success, touchingZoneParts = self:findPoint(randomCFrame)
		if success then
			pointIsWithinZone = true
		end
	until pointIsWithinZone
	local randomVector = randomCFrame.Position
	return randomVector, touchingZoneParts
end

function Zone:setAccuracy(enumIdOrName)
	local enumId = tonumber(enumIdOrName)
	if not enumId then
		enumId = enum.Accuracy[enumIdOrName]
		if not enumId then
			error(("'%s' is an invalid enumName!"):format(enumIdOrName))
		end
	else
		local enumName = enum.Accuracy.getName(enumId)
		if not enumName then
			error(("%s is an invalid enumId!"):format(enumId))
		end
	end
	self.accuracy = enumId
end

function Zone:setDetection(enumIdOrName)
	local enumId = tonumber(enumIdOrName)
	if not enumId then
		enumId = enum.Detection[enumIdOrName]
		if not enumId then
			error(("'%s' is an invalid enumName!"):format(enumIdOrName))
		end
	else
		local enumName = enum.Detection.getName(enumId)
		if not enumName then
			error(("%s is an invalid enumId!"):format(enumId))
		end
	end
	self.enterDetection = enumId
	self.exitDetection = enumId
end

function Zone:trackItem(instance)
	local isBasePart = instance:IsA("BasePart")
	local isCharacter = false
	if not isBasePart then
		isCharacter = instance:FindFirstChildOfClass("Humanoid") and instance:FindFirstChild("HumanoidRootPart")
	end

	assert(isBasePart or isCharacter, "Only BaseParts or Characters/NPCs can be tracked!")

	if self.trackedItems[instance] then
		return
	end
	if self.itemsToUntrack[instance] then
		self.itemsToUntrack[instance] = nil
	end

	local itemJanitor = self.janitor:add(Janitor.new(), "destroy")
	local itemDetail = {
		janitor = itemJanitor,
		item = instance,
		isBasePart = isBasePart,
		isCharacter = isCharacter,
	}
	self.trackedItems[instance] = itemDetail

	itemJanitor:add(instance.AncestryChanged:Connect(function()
		if not instance:IsDescendantOf(game) then
			self:untrackItem(instance)
		end
	end), "Disconnect")

	local Tracker = require(trackerModule)
	Tracker.itemAdded:Fire(itemDetail)
end

function Zone:untrackItem(instance)
	local itemDetail = self.trackedItems[instance]
	if itemDetail then
		itemDetail.janitor:destroy()
	end
	self.trackedItems[instance] = nil

	local Tracker = require(trackerModule)
	Tracker.itemRemoved:Fire(itemDetail)
end

function Zone:bindToGroup(settingsGroupName)
	self:unbindFromGroup()
	local group = ZoneController.getGroup(settingsGroupName) or ZoneController.setGroup(settingsGroupName)
	group._memberZones[self.zoneId] = self
	self.settingsGroupName = settingsGroupName
end

function Zone:unbindFromGroup()
	if self.settingsGroupName then
		local group = ZoneController.getGroup(self.settingsGroupName)
		if group then
			group._memberZones[self.zoneId] = nil
		end
		self.settingsGroupName = nil
	end
end

function Zone:relocate()
	if self.hasRelocated then
		return
	end

	local CollectiveWorldModel = require(collectiveWorldModelModule)
	local worldModel = CollectiveWorldModel.setupWorldModel(self)
	self.worldModel = worldModel
	self.hasRelocated = true
	
	local relocationContainer = self.container
	if typeof(relocationContainer) == "table" then
		relocationContainer = Instance.new("Folder")
		for _, zonePart in pairs(self.zoneParts) do
			zonePart.Parent = relocationContainer
		end
	end
	self.relocationContainer = self.janitor:add(relocationContainer, "Destroy", "RelocationContainer")
	relocationContainer.Parent = worldModel
end

function Zone:_onItemCallback(eventName, desiredValue, instance, callbackFunction)
	local detail = self.onItemDetails[instance]
	if not detail then
		detail = {}
		self.onItemDetails[instance] = detail
	end
	if #detail == 0 then
		self.itemsToUntrack[instance] = true
	end
	table.insert(detail, instance)
	self:trackItem(instance)

	local function triggerCallback()
		callbackFunction()
		if self.itemsToUntrack[instance] then
			self.itemsToUntrack[instance] = nil
			self:untrackItem(instance)
		end
	end

	local inZoneAlready = self:findItem(instance)
	if inZoneAlready == desiredValue then
		triggerCallback()
	else
		local connection
		connection = self[eventName]:Connect(function(item)
			if connection and item == instance then
				connection:Disconnect()
				connection = nil
				triggerCallback()
			end
		end)
		--[[
		if typeof(expireAfterSeconds) == "number" then
			task.delay(expireAfterSeconds, function()
				if connection ~= nil then
					print("EXPIRE!")
					connection:Disconnect()
					connection = nil
					triggerCallback()
				end
			end)
		end
		--]]
	end
end

function Zone:onItemEnter(...)
	self:_onItemCallback("itemEntered", true, ...)
end

function Zone:onItemExit(...)
	self:_onItemCallback("itemExited", false, ...)
end

function Zone:destroy()
	self:unbindFromGroup()
	self.janitor:destroy()
end
Zone.Destroy = Zone.destroy



return Zone