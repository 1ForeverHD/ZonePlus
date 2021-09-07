[BasePart.CanTouch]: https://developer.roblox.com/en-us/api-reference/property/BasePart/CanTouch
[baseparts]: https://developer.roblox.com/en-us/api-reference/class/BasePart
[zone]: https://1foreverhd.github.io/ZonePlus/api/zone/
[Zone API]: https://1foreverhd.github.io/ZonePlus/api/zone/
[Accuracy Enum]: https://github.com/1ForeverHD/ZonePlus/blob/main/src/Zone/Enum/Accuracy.lua
[Detection Enum]: https://github.com/1ForeverHD/ZonePlus/blob/main/src/Zone/Enum/Detection.lua
[zone:relocate()]: https://1foreverhd.github.io/ZonePlus/api/zone/#relocate

## Summary

ZonePlus is a module enabling the construction of dynamic zones. These zones utilise the new Spacial Query API and [BasePart.CanTouch] property to effectively determine players and parts within their boundaries.

Creating a zone is as simple as:

``` lua
-- Assuming we place ZonePlus in ReplicatedStorage
local Zone = require(game:GetService("ReplicatedStorage").Zone)
local container = workspace.SafeZoneContainer
local zone = Zone.new(container)
```

Zones take one argument: a **container**. A container can be any non-basepart instance (such as a Model, Folder, etc) that contain descendant [baseparts]. Alternatively a container can be a singular basepart instance, or a table containing an array of baseparts. 

!!! info
    Zones are compatible with all basepart classes however it's recommended to use solely Blocks (i.e. Parts with Shape 'Block') when possible as these are better optimised (since only ``WorldRoot:GetPartBoundsInBox`` needs to be called instead of ``WorldRoot:GetPartsInPart``).
    
These group parts are then used to define the region and precise bounds of the zone.

!!! info
    Zones are dynamic. This means if a group part changes size or position, or if a basepart is added to or removed from the zone group, then an internal ``_update()`` method will be called to recalculate its bounds.

Once constructed, you can utilise zone events to determine players, parts and the localplayer *entering* or *exiting* a zone. For instance, to listen for a *player* entering and exiting a zone, do:

```lua
zone.playerEntered:Connect(function(player)
    print(("%s entered the zone!"):format(player.Name))
end)

zone.playerExited:Connect(function(player)
    print(("%s exited the zone!"):format(player.Name))
end)
```

!!! info
    On the client you may only wish to listen for the LocalPlayer (such as for an ambient system). To achieve this you would alternatively use the ``.localPlayer`` events.

!!! important
    Initially zone parts should be located within Workspace to function properly. If you wish to move zones outside of Workspace (e.g. to prevent them interacting with other parts), consider using [zone:relocate()].

!!! important
    Zone parts must belong to the 'Default' (0) collision group.

If you don't intend to frequently check for items entering and exiting a zone, you can utilise zone methods:

```lua
local playersArray = zone:getPlayers()
```

Discover the full set of methods, events and properties at the [Zone API].

----

## Optimisations
Zones by default perform up to 10 checks per second in the *centre* of characters. This behaviour can be changed by modifying the **Accuracy** and **Detection** of zones:

### Accuracy
This determines the *frequency* of checks per second.

The accuracy of a zone can be changed two ways with a corresponding [Accuracy Enum]:

1. Using the ``zone:setAccuracy(itemName)`` method:
    ```lua
    zone:setAccuracy("High")
    ```

2. Setting the ``zone.accuracy`` property:
    ```lua
    zone.accuracy = Zone.enum.Accuracy.High
    ```

By default accuracy is ``High``.

!!! info
    Modifying the accuracy of one zone may impact the accuracy of another due to the modules collaborative nature.


### Detection
This determines the *precision* of checks.

The way a zone detects players and parts can be changed two ways with a corresponding [Detection Enum]:

1. Using the ``zone:setDetection(itemName)`` method:
    ```lua
    zone:setDetection("WholeBody")
    ```

2. Setting the ``zone.enterDetection`` and ``zone.exitDetection`` properties:
    ```lua
    zone.enterDetection = Zone.enum.Detection.WholeBody
    zone.exitDetection = Zone.enum.Detection.WholeBody
    ```

By default enterDetection and exitDetection are ``Centre``.

!!! info
    Modifying the detection of one zone may impact the detection of another due to the modules collaborative nature.

!!! warning
    Setting ``enterDetection`` to (``Zone.enum.Detection.WholeBody`` or ``Zone.enum.Detection.Automatic``) and ``exitDetection`` to ``Zone.enum.Detection.Centre`` may cause the entered and exit events to trigger rapidly when the player lies on the bounds of the zone.

