[zone:bindToGroup]: https://1foreverhd.github.io/ZonePlus/api/zone/#bindtogroup

## Functions

#### getZones
```lua
local zonesArray = ZoneController.getZones()
```

----
#### getTouchingZones
```lua
local touchingZonesArray, touchingPartsDictionary = ZoneController.getTouchingZones(player)
```

----
#### setGroup
```lua
local settingsGroup = ZoneController.setGroup(settingsGroupName, properties)
```

``properties`` is a dictionary defining the groups settings. The default properties are:
```lua
{
	onlyEnterOnceExitedAll = true, -- When set to `true`, it prevents items (players, parts, etc) from entering multiple zones at once within that group.
}
```
A zone can be bound to a group using [zone:bindToGroup].

----
#### getGroup
```lua
local settingsGroup = ZoneController.getGroup(settingsGroupName)
```

----