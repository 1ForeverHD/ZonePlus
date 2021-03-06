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

### Fixed
- Rotational and complex geometry detection
- ``getRandomPoints()`` inaccuracies