## [3.2.0] - September 7 2021
### Added
- ``Zone:onItemEnter(characterOrBasePart, callbackFunction)``
- ``Zone:onItemExit(characterOrBasePart, callbackFunction)``
- An error warning when a zone is constructed using parts that don't belong to the Default collision group
- Support for non-basepart HeadParts

### Changed
- Reorganised checker parts

### Fixed
- A bug preventing the disconnection of tracked character parts which resulted in a slight memory leak whenever a player reset or changed bodyparts



--------
## [3.1.0] - August 28 2021
### Added
- ``Zone.fromRegion(cframe, size)``
- ``zone:relocate()`` - Non-workspace zones are finally a possibility! Simply call this and the zones container will be moved into a WorldModel outside of Workspace.
- CollectiveWorldModel module
- ``zone.hasRelocated`` property
- ``zone.worldModel`` property
- ``zone.relocationContainer`` property
- ``CollectiveWorldModel.setupWorldModel(zone)``
- ``CollectiveWorldModel:GetPartBoundsInBox(cframe, size, overlapParams)``
- ``CollectiveWorldModel:GetPartBoundsInRadius(position, radius, overlapParams)``
- ``CollectiveWorldModel:GetPartsInPart(part, overlapParams)`

### Changed
- ``Zone.new(zoneGroup)`` to ``Zone.new(container)``
- ``zone.group`` property to ``zone.container``

### Fixed
- "ZoneController hrp is nil" bug



--------
## [3.0.0] - August 27 2021
### Added
- ``Zone:trackItem(characterOrBasePart)``
- ``Zone:untrackItem(characterOrBasePart)``
- ``Zone.itemEntered`` event
- ``Zone.itemExited`` event
- ``Zone:findItem(characterOrBasePart)``
- ``ZoneController.setGroup(settingsGroupName, properties)``
- ``ZoneController.getGroup(settingsGroupName)``
- ``SettingsGroup.onlyEnterOnceExitedAll`` property
- ``Zone:bindToGroup(settingsGroupName)``
- ``Zone:unbindFromGroup(settingsGroupName)``
- ``Zone.settingsGroupName`` property
- ``Zone:findPoint(position)``
- ``ZoneController.getCharacterSize(character)``

### Changed
- Internal behaviour to use the new Spatial [Query API](https://devforum.roblox.com/t/introducing-overlapparams-new-spatial-query-api/1435720) instead of the Region3 API.
- The default Detection from ``Automatic`` to ``Centre``.
- The behaviour of Detection ``Centre`` to include the whole HumanoidRootPart instead of a singular Vector within (this was required due to the new Spatial Query API).  
- ``Zone:findPart`` now returns array ``touchingZoneParts`` as its second value.
- ``Maid`` to [``Janitor``](https://github.com/howmanysmall/Janitor) by howmanysmall.
- ``Signal`` to [``GoodSignal``](https://devforum.roblox.com/t/lua-signal-class-comparison-optimal-goodsignal-class/1387063) by stravant.
- ``ZoneController.getTouchingZones(player)`` to ``ZoneController.getTouchingZones(characterOrBasePart)``.

### Removed
- RotatedRegion3
- ``ZoneController.getCharacterRegion``
- ``ZoneController.verifyTouchingParts``
- ``ZoneController.vectorIsBetweenYBounds``
- ``ZoneController.getHeightOfParts``
- ``Automatic`` Detection Enum.



--------
## [2.2.3] - June 17 2021
### Fixed
- The incorrect disabling of Seats and VehicleSeats within Part Zones.



--------
## [2.2.2] - June 4 2021
### Improved
- The accounting of character parts when removed/added via systems like HumanoidDescriptions.



--------
## [2.2.1] - May 21 2021
### Added
- Compatibility for Deferred Events



--------
## [2.1.3] - May 7 2021
### Fixed
- A bug that occured when disconnecting localPlayer events



--------
## [2.1.2] - April 15 2021
### Fixed
- ``playerExiting`` not firing when the player dies and respawns immidately within the zone.
- A rare nil checking bug within ``getTouchingZones`` in ``ZoneController``.



--------

## [2.1.1] - April 7 2021
### Fixed
- nil comparison within ZoneController getTouchingZones line 450



--------

## [2.1.0] - March 5 2021
### Added
- Detection Enum
- ``zone.enterDetection``
- ``zone.exitDetection``
- ``zone:setDetection(enumItemName)``
- An Optimisation section to Introduction



--------

## [2.0.0] - January 19 2021
### Added
- Non-player part checking! (see methods below)
- Infinite zone volume, zero change in performance - zones can now be as large as you like with no additional impact to performance assuming characters/parts entering the zone remain their normal size or relatively small
- Zones now support MeshParts and UnionOperations (however it's recommended to use simple parts where possible as the former require additional raycast checks)
- **Methods**
    - ``findLocalPlayer()``
    - ``findPlayer(player)``
    - ``findPart(basePart)``
    - ``getPlayers()``
    - ``getParts()``
    - ``setAccuracy(enumIdOrName)`` -- this enables you to customise the frequency of checks with enums 'Precise', 'High', 'Medium' and 'Low'
    - 'Destroy' alias of 'destroy'
- **Events**
    - ``localPlayerEntered``
    - ``localPlayerExited``
    - ``playerEntered``
    - ``playerExited``
    - ``partEntered``
    - ``partExited``

### Changed
- A players whole body is now considered as apposed to just their central position
- Region checking significantly optimised (e.g. the zones region now rest on the voxel grid)
- Zones now act as a 'collective' which has significantly improved and optimised player and localplayer detection
- Removed all original aliases and events, including ``:initLoop()`` which no longer has to be called (connections are detected and handled internally automatically)
- Replaced frustrating require() dependencies with static modules
- Made Zone the parent module and others as descendants
- Removed the ``additonalHeight`` constructor argument - this caused confusion and added additional complexities to support
- ``:getRandomPoint()`` now returns ``randomVector, touchingGroupParts`` instead of ``randomCFrame, hitPart, hitIntersection``
- ``zone.groupParts`` to ``zone.zoneParts``

### Fixed
- Rotational and complex geometry detection
- ``getRandomPoints()`` inaccuracies



```
-- This constructs a zone based upon a group of parts in Workspace and listens for when a player enters and exits this group
local container = workspace.AModelOfPartsRepresentingTheZone
local zone = Zone.new(container)

zone.playerEntered:Connect(function(player)
    print(("%s entered the zone!"):format(player.Name))
end)

zone.playerExited:Connect(function(player)
    print(("%s exited the zone!"):format(player.Name))
end)
```

```
-- This constructs a zone based upon a region, tracks a Zombie NPC, then listens for when the item (aka the Zombie) enters and exits the zone.
local zoneCFrame = CFrame.new()
local zoneSize = Vector3.new(100, 100, 100)
local zone = Zone.fromRegion(zoneCFrame, zoneSize)

zone.itemEntered:Connect(function(item)
    print(("%s entered the zone!"):format(item.Name))
end)

zone.itemExited:Connect(function(item)
    print(("%s exited the zone!"):format(item.Name))
end)
```