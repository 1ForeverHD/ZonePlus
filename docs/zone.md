[Accuracy Enum]: https://github.com/1ForeverHD/ZonePlus/blob/main/src/Zone/Enum/Accuracy.lua
[setAccuracy]: https://1foreverhd.github.io/ZonePlus/zone/#setaccuracy

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

