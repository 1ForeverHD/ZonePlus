-- LOCAL
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local heartbeat = runService.Heartbeat
local localPlayer = runService:IsClient() and players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpService = game:GetService("HttpService")
local Enum_ = require(script.Enum)
local enum = Enum_.enums
local Maid = require(script.Maid)
local RotatedRegion3 = require(script.RotatedRegion3)
local Signal = require(script.Signal)
local ZoneController = require(script.ZoneController)
local Zone = {}
Zone.__index = Zone



-- CONSTRUCTOR
function Zone.new(group)
	local self = {}
	setmetatable(self, Zone)
	
	-- Validate group
	local INVALID_TYPE_WARNING = "A zone group must be a model, folder, basepart or table!"
	local groupType = typeof(group)
	if not(groupType == "table" or groupType == "Instance") then
		error(INVALID_TYPE_WARNING)
	end

	-- Configurable
	self.accuracy = enum.Accuracy.Precise
	self.autoUpdate = true
	self.respectUpdateQueue = true
	self.bypassRaycastChecks = false
	--self.maxPartsAddition = 20
	--self.ignoreRecommendedMaxParts = false

	-- Variable
	local maid = Maid.new()
	self._maid = maid
	self._updateConnections = maid:give(Maid.new())
	self.group = group
	self.groupParts = {}
	self.volume = nil
	self.region = nil
	self.boundMin = nil
	self.boundMax = nil
	self.recommendedMaxParts = nil
	self.zoneId = httpService:GenerateGUID()
	self.activeTriggers = {}
	self.occupants = {}
	self.trackingTouchedTriggers = {}

	-- Signals
	self.updated = maid:give(Signal.new())
	local triggerTypes = {
		"player",
		"part",
		"localPlayer",
	}
	local triggerEvents = {
		"entered",
		"exited",
	}
	for _, triggerType in pairs(triggerTypes) do
		local activeConnections = 0
		local previousActiveConnections = activeConnections
		for i, triggerEvent in pairs(triggerEvents) do
			-- this enables us to determine when a developer connects to an event
			-- so that we can act accoridngly (i.e. begin or end a checker loop)
			local signal = maid:give(Signal.new())
			local increment = (i == 1 and 1) or -1
			local triggerEventUpper = triggerEvent:sub(1,1):upper()..triggerEvent:sub(2)
			local signalName = triggerType..triggerEventUpper
			self[signalName] = signal
			signal.connectionsChanged:Connect(function()
				if triggerType == "localPlayer" and not localPlayer then
					error(("Can only connect to .localPlayer%s on the client!"):format(triggerEventUpper))
				end
				activeConnections += increment
				print("-> connections changed: ", activeConnections)
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

	-- Register/deregister zone
	ZoneController._registerZone(self)
	maid:give(function()
		ZoneController._deregisterZone(self)
	end)

	-- Update
	self:_update()
	
	return self
end



-- PRIVATE METHODS
function Zone:_calculateRegion(tableOfParts)
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
			local roundOffset = (boundName == "Min" and -2) or 2
			local newV = roundToFour(v+roundOffset) -- +-2 to ensures the zones region is not rounded down/up
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
			self._maid:give(part)
		end
	end
end

function Zone:_update()
	local group = self.group
	local groupParts = {}
	local updateQueue = 0
	self._updateConnections:clean()
	
	local groupType = typeof(group)
	local containers = {}
	local INVALID_TYPE_WARNING = "A zone group must be a model, folder, basepart or table!"
	if groupType == "table" then
		for _, part in pairs(group) do
			if part:IsA("BasePart") then
				table.insert(groupParts, part)
			end
		end
	elseif groupType == "Instance" then
		if group:IsA("BasePart") then
			table.insert(groupParts, group)
		else
			table.insert(containers, group)
			for _, part in pairs(group:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(groupParts, part)
				else
					table.insert(containers, part)
				end
			end
		end
	end
	self.groupParts = groupParts
	
	-- this will call update on the zone when a group parts size or position changes, and when a
	-- child is removed or added from a container (anything which isn't a basepart)
	local function update()
		if self.autoUpdate then
			coroutine.wrap(function()
				if self.respectUpdateQueue then
					updateQueue = updateQueue + 1
					wait(0.1)
					updateQueue = updateQueue - 1
				end
				if updateQueue == 0 and self.zoneId then
					self:_update()
				end
			end)()
		end
	end
	local partProperties = {"Size", "Position"}
	for _, part in pairs(groupParts) do
		for _, prop in pairs(partProperties) do
			self._updateConnections:give(part:GetPropertyChangedSignal(prop):Connect(update))
		end
	end
	local groupEvents = {"ChildAdded", "ChildRemoved"}
	for _, container in pairs(containers) do
		for _, event in pairs(groupEvents) do
			self._updateConnections:give(self.group[event]:Connect(function(child)
				if child:IsA("BasePart") then
					update()
				end
			end))
		end
	end
	
	local region, boundMin, boundMax = self:_calculateRegion(groupParts)
	self.region = region
	self.boundMin = boundMin
	self.boundMax = boundMax
	local rSize = region.Size
	self.volume = rSize.X*rSize.Y*rSize.Z
	
	print("Update zone!")
	-- Update: I was going to use this for the old part detection until the CanTouch property was released
	-- everything below is now irrelevant however I'll keep just in case I use again for future
	-------------------------------------------------------------------------------------------------
	-- When a zones region is determined, we also check for parts already existing within the zone
	-- these parts are likely never to move or interact with the zone, so we set the number of these
	-- to the baseline MaxParts value. 'recommendMaxParts' is then determined through the sum of this
	-- and maxPartsAddition. This ultimately optimises region checks as they can be generated with
	-- minimal MaxParts (i.e. recommendedMaxParts can be used instead of math.huge every time)
	--[[
	local result = workspace:FindPartsInRegion3(region, nil, math.huge)
	local maxPartsBaseline = #result
	self.recommendedMaxParts = maxPartsBaseline + self.maxPartsAddition
	--]]
	
	self:_updateTouchedConnections()

	self.updated:Fire()
end

function Zone:_updateOccupants(triggerType, newOccupants)
	local previousOccupants = self.occupants[triggerType]
	if not previousOccupants then
		previousOccupants = {}
		self.occupants[triggerType] = previousOccupants
	end
	local exitedSignal = self[triggerType.."Exited"]
	local enteredSignal = self[triggerType.."Entered"]
	if exitedSignal then
		for occupant, _ in pairs(previousOccupants) do
			if newOccupants[occupant] == nil then
				previousOccupants[occupant] = nil
				exitedSignal:Fire(occupant)
			end
		end
	end
	if enteredSignal then
		for occupant, _ in pairs(newOccupants) do
			if previousOccupants[occupant] == nil then
				previousOccupants[occupant] = true
				enteredSignal:Fire(occupant)
			end
		end
	end
end

function Zone:_formTouchedConnection(triggerType)
	local touchedMaidName = "_touchedMaid"..triggerType
	local touchedMaid = self[touchedMaidName]
	if touchedMaid then
		touchedMaid:clean()
	else
		touchedMaid = self._maid:give(Maid.new())
		self[touchedMaidName] = touchedMaid
	end
	self:_updateTouchedConnection(triggerType)
end

function Zone:_updateTouchedConnection(triggerType)
	local touchedMaidName = "_touchedMaid"..triggerType
	local touchedMaid = self[touchedMaidName]
	if not touchedMaid then return end
	for _, basePart in pairs(self.groupParts) do
		touchedMaid:give(basePart.Touched:Connect(self.touchedConnectionActions[triggerType], self))
	end
end

function Zone:_updateTouchedConnections()
	for triggerType, _ in pairs(self.touchedConnectionActions) do
		local touchedMaidName = "_touchedMaid"..triggerType
		local touchedMaid = self[touchedMaidName]
		if touchedMaid then
			touchedMaid:clean()
			self:_updateTouchedConnection(triggerType)
		end
	end
end

function Zone:_disconnectTouchedConnection(triggerType)
	local touchedMaidName = "_touchedMaid"..triggerType
	local touchedMaid = self[touchedMaidName]
	if touchedMaid then
		touchedMaid:clean()
		self[touchedMaidName] = nil
	end
end

function Zone:_partTouchedZone(part)
	local trackingDict = self.trackingTouchedTriggers["part"]
	part.CanTouch = false
	if trackingDict[part] then return end
	local nextCheck = os.clock() + 0.1
	local regionConstructor = self:_getRegionConstructor(part)
	self.partEntered:Fire(part)
	trackingDict[part] = self._maid:give(heartbeat:Connect(function()
		local clockTime = os.clock()
		if clockTime >= nextCheck then
			----------
			--if .accuracy == enum.Accuracy.Precise
			nextCheck = clockTime + 0.1
			----------
			local withinZone = self:findPart(part, regionConstructor)
			if not withinZone then
				trackingDict[part]:Disconnect()
				trackingDict[part] = nil
				part.CanTouch = true
				self.partExited:Fire(part)
			end
		end
	end))
end

function Zone:_getRegionConstructor(part)
	local cSuccess, regionConstructor = pcall(function() return part.Shape.Name end)
	if not cSuccess then
		local validClassNames = {
			WedgePart = "Wedge",
			CornerWedgePart = "CornerWedge",
		}
		regionConstructor = validClassNames[part.ClassName] or "new"
	end
	return regionConstructor
end



-- PUBLIC METHODS
function Zone:findPlayer(player)
	local touchingZones = ZoneController.getTouchingZones(player)
	for _, zone in pairs(touchingZones) do
		if zone == self then
			return true
		end
	end
	return false
end

function Zone:findPart(part, regionConstructor)
	-- I was originally going to fire a 'tiny ray' within the part to determine whether they are touching a
	-- group part, however it turns out you can't do this. It appears instead a ray has to *pass through*
	-- a parts boundary for it to be detected. Then I tried raycasting from below the zone to the part,
	-- however this caused some inaccuracies for unusual geometries. Ultimately I've settled on casting a
	-- 'tiny region' instead which can detect group parts accurately and after running some benchmarks
	-- turns out to be slighly more optimal than raycasting
	--[[
	local withinZone
	local partY = part.Size.Y
	local partPos = part.Position
	local startVector = Vector3.new(partPos.X, self.boundMin.Y-0.1, partPos.Z)
	local endVector = (part.CFrame * CFrame.new(0, partY/2, 0)).p
	local directionVector = endVector - startVector
	local directionalMagnitude = directionVector.Magnitude
	if not self.bypassRaycastChecks and directionalMagnitude < self.region.Size.Y then
		local raycastResult = workspace:Raycast(startVector, directionVector, raycastParams)
		withinZone = raycastResult and raycastResult.Instance
	end--]]
	local finalRegionConstructor = regionConstructor or self:_getRegionConstructor(part)
	local partCFrame = part.CFrame
	local tinyCheckRegion = Region3.new((partCFrame * CFrame.new(0.1, 0.1, 0.1)).Position, (partCFrame * CFrame.new(-0.1, -0.1, -0.1)).Position)
	local touchingGroupParts = workspace:FindPartsInRegion3WithWhiteList(tinyCheckRegion, self.groupParts, #self.groupParts)
	if #touchingGroupParts > 0 then
		return true
	end
	-- Perform a 'whole body' region check to determine accurately whether the part is in the zone or not
	local partRegion = RotatedRegion3[finalRegionConstructor](part.CFrame, part.Size)
	touchingGroupParts = partRegion:FindPartsInRegion3WithWhiteList(self.groupParts, #self.groupParts)
	if #touchingGroupParts > 0 then
		return true
	end
	return false
end

function Zone:findLocalPlayer()
	return self:findPlayer(localPlayer)
end

function Zone:getPlayers()
	local playersArray = {}
	local zonesAndOccupants = ZoneController._getZonesAndPlayers({self = true}, self.volume)
	local occupantsDict = zonesAndOccupants[self]
	if occupantsDict then
		for plr, _ in pairs(occupantsDict) do
			table.insert(playersArray, plr)
		end
	end
	return playersArray
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
	local partsInRegion = workspace:FindPartsInRegion3WithIgnoreList(self.region, self.groupParts)
	for _, part in pairs(partsInRegion) do
		if self:findPart(part) then
			table.insert(partsArray, part)
		end
	end
	return partsArray
end

function Zone:getRandomPoint()

end

function Zone:destroy()
	self._maid:clean()
end
Zone.Destroy = Zone.destroy



return Zone