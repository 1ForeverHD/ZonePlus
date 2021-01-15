[baseparts]: https://developer.roblox.com/en-us/api-reference/class/BasePart
[zone]: https://1foreverhd.github.io/ZonePlus/zone/
[Zone module docs]: https://1foreverhd.github.io/ZonePlus/zone/
[group]: https://1foreverhd.github.io/ZonePlus/zone/#new

ZonePlus is a module that enables the construction of dynamic zones. These zones utilise region checking, raycasting and the new BasePart.CanTouch property to effectively determine players and parts within their boundaries.

Creating a zone is as simple as:

``` lua
-- Assuming we place ZonePlus in ReplicatedStorage
local Zone = require(game:GetService("ReplicatedStorage").Zone)
local zoneGroup = workspace.SafeZoneGroup
local zone = Zone.new(safeZoneGroup)
```

A zone takes one argument - a [group]. A group can be any non-basepart instance (such as a Model, Folder, etc) that contains children or descendant baseparts. Alternatively a group can be a singular basepart instance, or a table containing an array of baseparts.

!!! info
    Zones are compatible with all BasePart classes, however it's recommended to use simple parts (blocks, balls, cylinders, wedges, etc) where possible as these are more efficient and accurate. Some classes for instance, such as MeshParts and UnionOperations, require additional raycast checks to verify their surface geometries.

Once constructed, you can utilise zone events to determine players, parts and the localplayer within. For instance, to listen for a player *entering* and *exiting* a zone, do:

```lua
zone.playerEntered:Connect(function(player)
    print((%s entered the zone!):format(player.Name))
end)
zone.playerExited:Connect(function(player)
    print((%s exited the zone!):format(player.Name))
end)
```

!!! info
    If you only needed to check for the localplayer on the client (such as for a music area system), you would alternatively use the ``.localPlayer`` events.

Alternatively for one-off scenarious, you can utilise zone methods:

```lua
local playersArray = zone:getPlayers()
```

Discover the full set of methods, events and properties at the [Zone module docs].

