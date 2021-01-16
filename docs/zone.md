[Accuracy Enum]: https://github.com/1ForeverHD/ZonePlus/blob/main/src/Zone/Enum/Accuracy.lua
[setAccuracy]: https://1foreverhd.github.io/ZonePlus/zone/#setAccuracy

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
Sets the frequency of checks based upon the [Accuracy Enum].

----
#### destroy
```lua
zone:destroy()
```
Disconnects all connections within the zone.

----



## Properties
#### accuracy
*Default:* ``enum.Accuracy.High``

To change ``accuracy`` it's recommended you use [setAccuracy].

----
#### autoUpdate
*Default:* ``true``

When ``true``, the zone will update when its group parts change size or position, or when a descendant group part is added or removed from the group.

----
#### respectUpdateQueue
*Default:* ``true``

When ``true``, will prevent the internal ``_update()`` from being called multiple times within a 0.1 second period.

----
#### region
*Read-only*

----
#### volume
*Read-only*
]]



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
local ZoneController = require(script.ZoneController)
local Zone = {}
Zone.__index = Zone
ZonePlusReference.addToReplicatedStorage()



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
