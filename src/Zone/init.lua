--[[ zone:header
[Accuracy Enum]: https://github.com/1ForeverHD/ZonePlus/blob/main/src/Zone/Enum/Accuracy.lua
[Detection Enum]: https://github.com/1ForeverHD/ZonePlus/blob/main/src/Zone/Enum/Detection.lua
[setAccuracy]: https://1foreverhd.github.io/ZonePlus/zone/#setaccuracy
[setDetection]: https://1foreverhd.github.io/ZonePlus/zone/#setdetection

## Construtors

#### new
```lua
local zone = Zone.new(group)
```
A group is used the define the boundaries of the zone. It can be any non-basepart instance (such as a Model, Folder, etc) that contain descendant baseparts. Alternatively a group can be a singular basepart instance, or a table containing an array of baseparts. 

----



## Methods

#### findLocalPlayer
```lua
local isWithinZoneBool = zone:findLocalPlayer()
```

----
#### findPlayer
```lua
local isWithinZoneBool = zone:findPlayer(player)
```

----
#### findPart
```lua
local isWithinZoneBool = zone:findPart(basePart)
```

----
#### getPlayers
```lua
local playersArray = zone:getPlayers()
```

----
#### getParts
```lua
local partsArray = zone:getParts()
```

----
#### getRandomPoint
```lua
local randomVector, touchingGroupPartsArray = zone:getRandomPoint()
```
Generates random points within the zones region until one falls within its bounds. It then returns this ``Vector3`` and a ``table array`` of group parts the point falls within.

----
#### setAccuracy
```lua
zone:setAccuracy(enumIdOrName)
```
Sets the frequency of checks based upon the [Accuracy Enum]. Defaults to 'High'.

----
#### setDetection
```lua
zone:setDetection(enumIdOrName)
```
Sets the precision of checks based upon the [Detection Enum]. Defaults to 'Automatic'.

----
#### destroy
```lua
zone:destroy()
```
Disconnects all connections within the zone.

----



## Events
#### localPlayerEntered 
{client-only}
```lua
zone.localPlayerEntered:Connect(function()
    print("you entered the zone!")
end)
```

----
#### localPlayerExited
{client-only}
```lua
zone.localPlayerExited:Connect(function()
    print("you exited the zone!")
end)
```

----
#### playerEntered
```lua
zone.playerEntered:Connect(function(player)
    print(("player '%s' entered the zone!"):format(player.Name))
end)
```

----
#### playerExited
```lua
zone.playerExited:Connect(function(player)
    print(("player '%s' exited the zone!"):format(player.Name))
end)
```

----
#### partEntered
```lua
zone.partEntered:Connect(function(part)
    print(("part '%s' entered the zone!"):format(part.Name))
end)
```

!!! info
	This event only works for non-anchored parts

!!! warning
    This connection will not fully optimise *until* [BasePart.CanTouch](https://developer.roblox.com/en-us/api-reference/property/BasePart/CanTouch) goes [live](https://developer.roblox.com/en-us/resources/release-note/Release-Notes-for-460).

----
#### partExited
```lua
zone.partExited:Connect(function(part)
    print(("part '%s' exited the zone!"):format(part.Name))
end)
```

!!! info
	This event only works for non-anchored parts

!!! warning
    This connection will not fully optimise *until* [BasePart.CanTouch](https://developer.roblox.com/en-us/api-reference/property/BasePart/CanTouch) goes [live](https://developer.roblox.com/en-us/resources/release-note/Release-Notes-for-460).

----



## Properties
#### accuracy
```lua
local accuracyEnumId = zone.accuracy --[default: 'Zone.enum.Accuracy.High']
```
To change ``accuracy`` you can use [setAccuracy] or do:

```lua
zone.accuracy = Zone.enum.Accuracy.ITEM_NAME
```

A list of Accuracy enum items can be found at [Accuracy Enum].

----
#### enterDetection
```lua
local enterDetection = zone.enterDetection --[default: 'Zone.enum.Detection.Automatic']
```
To change both detection types use [setDetection] otherwise to set individually do:

```lua
zone.enterDetection = Zone.enum.Detection.ITEM_NAME
```

A list of Detection enum items can be found at [Detection Enum].

----
#### exitDetection
```lua
local exitDetection = zone.exitDetection --[default: 'Zone.enum.Detection.Automatic']
```
To change both detection types use [setDetection] otherwise to set individually do:

```lua
zone.exitDetection = Zone.enum.Detection.ITEM_NAME
```

A list of Detection enum items can be found at [Detection Enum].

----
#### autoUpdate
```lua
local bool = zone.autoUpdate --[default: 'true']
```
When ``true``, the zone will update when its group parts change size or position, or when a descendant group part is added or removed from the group.

----
#### respectUpdateQueue
```lua
local bool = zone.respectUpdateQueue --[default: 'true']
```
When ``true``, will prevent the internal ``_update()`` from being called multiple times within a 0.1 second period.

----
#### groupParts
{read-only}

An array of baseparts, defined in the ``group`` constructor parameter, that form the zone.

----
#### region
{read-only}

----
#### volume
{read-only}
--]]



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
local ZonePlusReference = require(script.ZonePlusReference)
local referenceObject = ZonePlusReference.getObject()
local ZoneController = require(script.ZoneController)
local referenceLocation = (game:GetService("RunService"):IsClient() and "Client") or "Server"
local referencePresent = referenceObject and referenceObject:FindFirstChild(referenceLocation)
local Zone = (referencePresent and require(referenceObject.Value)) or {}
Zone.__index = Zone
if not referencePresent then
	ZonePlusReference.addToReplicatedStorage()
end
Zone.enum = enum



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
	self.accuracy = enum.Accuracy.High
	self.autoUpdate = true
	self.respectUpdateQueue = true
	--self.maxPartsAddition = 20
	--self.ignoreRecommendedMaxParts = false

	-- Variable
	local maid = Maid.new()
	self._maid = maid
	self._updateConnections = maid:give(Maid.new())
	self.group = group
	self.groupParts = {}
	self.region = nil
	self.volume = nil
	self.boundMin = nil
	self.boundMax = nil
	self.recommendedMaxParts = nil
	self.zoneId = httpService:GenerateGUID()
	self.activeTriggers = {}
	self.occupants = {}
	self.trackingTouchedTriggers = {}
	self.enterDetection = enum.Detection.Automatic
	self.exitDetection = enum.Detection.Automatic
	self._currentEnterDetection = nil -- This will update automatically internally
	self._currentExitDetection = nil -- This will also update automatically internally
	self.totalPartVolume = 0

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
		local previousActiveConnections = 0
		for i, triggerEvent in pairs(triggerEvents) do
			-- this enables us to determine when a developer connects to an event
			-- so that we can act accoridngly (i.e. begin or end a checker loop)
			local signal = maid:give(Signal.new(true))
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
	maid:give(function()
		ZoneController._deregisterZone(self)
	end)
	
	return self
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
	local exactRegion, _, _ = self:_calculateRegion(groupParts, true)
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
	local exitPosition
	local regionConstructor = self:_getRegionConstructor(part)
	local partMaid = self._maid:give(Maid.new())
	trackingDict[part] = partMaid
	part.CanTouch = false
	--
	local partVolume = round((part.Size.X * part.Size.Y * part.Size.Z), 5)
	self.totalPartVolume += partVolume
	--
	partMaid:give(heartbeat:Connect(function()
		local clockTime = os.clock()
		if clockTime >= nextCheck then
			----
			local cooldown = enum.Accuracy.getProperty(self.accuracy)
			nextCheck = clockTime + cooldown
			----
			local withinZone = self:findPart(part, regionConstructor)
			if not verifiedEntrance then
				if withinZone then
					verifiedEntrance = true
					self.partEntered:Fire(part)
				elseif (part.Position - enterPosition).Magnitude > 1.5 and clockTime - enterTime >= cooldown then
					-- Even after the part has exited the zone, we track it for a brief period of time based upon the criteria
					-- in the line above to ensure the .touched behaviours are not abused
					partMaid:clean()
				end
			elseif not withinZone then
				verifiedEntrance = false
				enterPosition = part.Position
				enterTime = os.clock()
				self.partExited:Fire(part)
			end
		end
	end))
	partMaid:give(function()
		trackingDict[part] = nil
		part.CanTouch = true
		self.totalPartVolume = round((self.totalPartVolume - partVolume), 5)
	end)
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
function Zone:findLocalPlayer()
	if not localPlayer then
		error("Can only call 'findLocalPlayer' on the client!")
	end
	return self:findPlayer(localPlayer)
end

function Zone:findPlayer(player)
	ZoneController.updateDetection(self)
	local touchingZones = ZoneController.getTouchingZones(player, false, self._currentEnterDetection)
	for _, zone in pairs(touchingZones) do
		if zone == self then
			return true
		end
	end
	return false
end

function Zone:findPart(part, regionConstructor, enterPosition, timeInZone)
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
	--local tinyCheckRegion = Region3.new((partCFrame * CFrame.new(0.1, 0.1, 0.1)).Position, (partCFrame * CFrame.new(-0.1, -0.1, -0.1)).Position)
	--local touchingGroupParts = workspace:FindPartsInRegion3WithWhiteList(tinyCheckRegion, self.groupParts, #self.groupParts)
	local tinyCheckRegion = RotatedRegion3[finalRegionConstructor](part.CFrame, Vector3.new(0.1, 0.1, 0.1))
	local touchingGroupParts = tinyCheckRegion:FindPartsInRegion3WithWhiteList(self.groupParts, #self.groupParts)
	if #touchingGroupParts > 0 then
		local partSizeXHalf = part.Size.X/2
		local pointsToVerify = {
			(partCFrame * CFrame.new(-partSizeXHalf, 0, 0)).Position,
			(partCFrame * CFrame.new(partSizeXHalf, 0, 0)).Position,
		}
		if not ZoneController.verifyTouchingParts(pointsToVerify, touchingGroupParts) then
			return false
		end
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

function Zone:getPlayers()
	ZoneController.updateDetection(self)
	local playersArray = {}
	local zonesAndOccupants = ZoneController._getZonesAndPlayers({self = true}, self.volume, false, self._currentEnterDetection)
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
	local region = self.exactRegion
	local size = region.Size
	local cframe = region.CFrame
	local random = Random.new()
	local randomCFrame
	local touchingGroupParts
	local pointIsWithinZone
	repeat
		randomCFrame = cframe * CFrame.new(random:NextNumber(-size.X/2,size.X/2), random:NextNumber(-size.Y/2,size.Y/2), random:NextNumber(-size.Z/2,size.Z/2))
		local randomRegion = RotatedRegion3.new(randomCFrame, Vector3.new(0.1, 0.1, 0.1))
		touchingGroupParts = randomRegion:FindPartsInRegion3WithWhiteList(self.groupParts, #self.groupParts)
		if #touchingGroupParts > 0 then
			pointIsWithinZone = ZoneController.verifyTouchingParts({randomCFrame.Position}, touchingGroupParts)
		end
	until pointIsWithinZone
	local randomVector = randomCFrame.Position
	return randomVector, touchingGroupParts
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

function Zone:destroy()
	self._maid:clean()
end
Zone.Destroy = Zone.destroy



return Zone