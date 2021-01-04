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
	self.maxPartsAddition = 20
	self.ignoreRecommendedMaxParts = false

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
			local signalName = triggerType..triggerEvent:sub(1,1):upper()..triggerEvent:sub(2)
			self[signalName] = signal
			signal.connectionsChanged:Connect(function()
				activeConnections += increment
				if previousActiveConnections == 0 and activeConnections > 0 then
					-- At least 1 connection active, begin loop
					ZoneController._registerConnection(self, triggerType)
				elseif previousActiveConnections > 0 and activeConnections == 0 then
					-- All connections have disconnected, end loop
					ZoneController._deregisterConnection(self, triggerType)
				end
			end)
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
			for _, part in pairs(group:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(groupParts, part)
				end
			end
		end
	end
	self.groupParts = groupParts
	print("apply new group parts!! = ", #self.groupParts)

	-- this will call update on the zone when a relavent group part property changes such as its size
	for _, part in pairs(groupParts) do
		local partProperties = {"Size", "Position"}
		local groupEvents = {"ChildAdded", "ChildRemoved"}
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
		for _, prop in pairs(partProperties) do
			self._updateConnections:give(part:GetPropertyChangedSignal(prop):Connect(update))
		end
		for _, event in pairs(groupEvents) do
			self._updateConnections:give(self.group[event]:Connect(update))
		end
	end
	
	local region, boundMin, boundMax = self:_calculateRegion(groupParts)
	self.region = region
	self.boundMin = boundMin
	self.boundMax = boundMax
	local rSize = region.Size
	self.volume = rSize.X*rSize.Y*rSize.Z
	
	-- When a zones region is determined, we also check for parts already existing within the zone
	-- these parts are likely never to move or interact with the zone, so we set the number of these
	-- to the baseline MaxParts value. 'recommendMaxParts' is then determined through the sum of this
	-- and maxPartsAddition. This ultimately optimises region checks as they can be generated with
	-- minimal MaxParts (i.e. recommendedMaxParts can be used instead of math.huge every time)
	local result = workspace:FindPartsInRegion3(region, nil, math.huge)
	local maxPartsBaseline = #result
	self.recommendedMaxParts = maxPartsBaseline + self.maxPartsAddition
	
	self.updated:Fire()
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

function Zone:findPart()

end

function Zone:findLocalPlayer()
	return self:findPlayer(localPlayer)
end

function Zone:getPlayers()

end

function Zone:getParts()

end

function Zone:getParts()

end

function Zone:getRandomPoint()

end

function Zone:destroy()
	self._maid:clean()
end
Zone.Destroy = Zone.destroy



return Zone