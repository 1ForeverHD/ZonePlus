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
local touchingZonesArray, touchingPartsDictionary = ZoneController.getTouchingZones(player)
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
