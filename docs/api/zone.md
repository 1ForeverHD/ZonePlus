[Accuracy Enum]: https://github.com/1ForeverHD/ZonePlus/blob/main/src/Zone/Enum/Accuracy.lua
[Detection Enum]: https://github.com/1ForeverHD/ZonePlus/blob/main/src/Zone/Enum/Detection.lua
[setAccuracy]: https://1foreverhd.github.io/ZonePlus/api/zone/#setaccuracy
[setDetection]: https://1foreverhd.github.io/ZonePlus/api/zone/#setdetection
[icon:trackItem]: https://1foreverhd.github.io/ZonePlus/api/zone/#trackitem
[ZoneController.setGroup]: https://1foreverhd.github.io/ZonePlus/api/zone/#setgroup

## Construtors

#### new
```lua
local zone = Zone.new(container)
```
A container is used the define the boundaries of the zone. It can be any non-basepart instance (such as a Model, Folder, etc) that contain descendant baseparts. Alternatively a container can be a singular basepart instance, or a table containing an array of baseparts. 

----
#### fromRegion
```lua
local zone = Zone.fromRegion(cframe, size)
```
Constructs a zone from the given CFrame and Size. Underneath the hood, it's creating a part (or multiple parts if any size coordinage exceeds 2024), parenting this to a folder (the container), constructing a zone with this container, calling ``:relocate()`` on that zone (which parents it outside of workspace), then finally returning the zone.

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
local isWithinZoneBool, touchingZoneParts = zone:findPart(basePart)
```

----
#### findItem
```lua
local isWithinZoneBool, touchingZoneParts = zone:findItem(basePartOrCharacter)
```

----
#### findPoint
```lua
local isWithinZoneBool, touchingZoneParts = zone:findPoint(position)
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
#### getItems
```lua
local itemsArray = zone:getItems()
```

----
#### getRandomPoint
```lua
local randomVector, touchingZonePartsArray = zone:getRandomPoint()
```
Generates random points within the zones region until one falls within its bounds. It then returns this ``Vector3`` and a ``table array`` of group parts the point falls within.

----
#### trackItem
```lua
zone:trackItem(characterOrBasePart)
```
This is used to detect your own custom instances within zones, such as NPCs, and is a recommended replacement for part-events/methods.

An item can be any BasePart or Character/NPC (i.e. a model with a Humanoid and HumanoidRootPart). Once tracked, it can be listened for with the ``zone.itemEntered`` and ``zone.itemExited`` events.

An item will be automatically untracked if destroyed or has its parent set to ``nil``.


----
#### untrackItem
```lua
zone:untrackItem(characterOrBasePart)
```

----
#### bindToGroup
```lua
zone:bindToGroup(settingsGroupName)
```
This is used to bind the zone to a settingsGroup to enhance the default behaviour of a collection of zones. The properties of a settingsGroup can be viewed at and customised using [ZoneController.setGroup].

This method is particularly useful for zones where you want to guarantee the player/item is not in two zones at once. For example, when working with ambient/music/lighting zones which perfectly border each other.


----
#### unbindFromGroup
```lua
zone:bindToGroup(settingsGroupName)
```

----
#### setDetection
```lua
zone:setDetection(enumIdOrName)
```
Sets the precision of checks based upon the [Detection Enum]. Defaults to 'Automatic'.

----
#### relocate
```lua
zone:relocate()
```
Moves the zone outside of workspace into a separate WorldModel within ReplicatedStorage or ServerStorage. This action is irreversible - once called it cannot be undone.

----
#### onItemEnter
```lua
zone:onItemEnter(characterOrBasePart, callbackFunction)
```
Tracks the item until it has entered the zone, then calls the given function. If the item is already within the zone, the given function is called right away.

```lua
local item = character:FindFirstChild("HumanoidRootPart")
zone:onItemEnter(item, function()
    print("The item has entered the zone!"))
end)
```

----
#### onItemExit
```lua
zone:onItemExit(characterOrBasePart, callbackFunction)
```
Tracks the item until it has exited the zone, then calls the given function. If the item is already outside the zone, the given function is called right away.

```lua
local item = character:FindFirstChild("HumanoidRootPart")
zone:onItemExit(item, function()
    print("The item has exited the zone!"))
end)
```

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
    This event works only for unanchored parts and may interfere with the parts CanCollide property. It's recommended to use itemEntered instead where possible which is more optimal and overcomes these problems. 

----
#### partExited
```lua
zone.partExited:Connect(function(part)
    print(("part '%s' exited the zone!"):format(part.Name))
end)
```

!!! info
    This event works only for unanchored parts and may interfere with the parts CanCollide property. It's recommended to use itemExited instead where possible which is more optimal and overcomes these problems. 

----
#### itemEntered
```lua
zone.itemEntered:Connect(function(item)
    print(("item '%s' entered the zone!"):format(item.Name))
end)
```
See [icon:trackItem] for further details on items.


----
#### itemExited
```lua
zone.itemExited:Connect(function(item)
    print(("item '%s' exited the zone!"):format(item.Name))
end)
```
See [icon:trackItem] for further details on items.


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
#### zoneParts
{read-only}

An array of baseparts, defined in the ``container`` constructor parameter, that form the zone.

----
#### region
{read-only}

----
#### volume
{read-only}

----
#### worldModel
{read-only}